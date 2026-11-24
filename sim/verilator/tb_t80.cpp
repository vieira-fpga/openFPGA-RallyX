//============================================================================
//  T80 against outside references, at compiled speed.
//
//  GHDL simulates T80 at roughly 100,000 T-states per second. zexall needs
//  46.7 billion. So tools/sim.py has GHDL synthesise the VHDL to a Verilog
//  netlist, Verilator compiles that to C++, and this file drives it. The CPU
//  is a black box here, the same as in the VHDL benches: everything below is
//  read off the pins of T80s.
//
//    tb_t80 fuse <tests.in> <tests.expected>
//        FUSE's Z80 core tests: one or more cases per opcode, documented or
//        not. Each gives a starting state and expects the T-state count, the
//        final registers, the memory written, and the T-state at which every
//        bus cycle lands. This is the cycle-timing reference.
//
//    tb_t80 cpm <image> [--test N]
//        prelim, zexdoc and zexall under a minimal CP/M. They CRC the results
//        and flags of every instruction against a real Z80. --test N runs one
//        entry of the zexdoc/zexall test table, so tools/sim.py can spread a
//        run across cores.
//
//    tb_t80 tap <z80test.tap>
//        Patrik Rak's z80test under a three-routine stand-in for the
//        Spectrum ROM. Also CRCs against a real Zilog Z80, and reaches what
//        zex does not: MEMPTR through BIT n,(HL), and SCF/CCF's YF/XF.
//
//  Bus conventions, all from T80s with T2Write => 0. One T-state is one rising
//  clock edge, and a strobe is visible in the T-state after the one that
//  raised it:
//
//    opcode fetch   M1 + MREQ + RD visible in T2
//    memory read    MREQ + RD visible in T2
//    memory write   MREQ + WR visible in T3
//    port read      IORQ + RD visible in T2
//    port write     IORQ + WR visible in T2
//============================================================================
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "Vt80s.h"
#include "verilated.h"

double sc_time_stamp() { return 0; }

namespace {

struct Pins {
    bool fetch;      // opcode fetch
    bool read;       // any memory read, fetch included
    bool write;      // memory write
    bool port_read;
    bool port_write;
    bool int_ack;
    bool halted;
    uint16_t addr;
    uint8_t data;
};

// Strobes are reported on the T-state they first appear in. A port access
// holds its strobes through the automatic wait state, and one bus cycle must
// not count twice.
class Cpu {
  public:
    Cpu() {
        top_.CEN = 1;
        top_.OUT0 = 0;
        top_.WAIT_n = 1;
        top_.INT_n = 1;
        top_.NMI_n = 1;
        top_.BUSRQ_n = 1;
        top_.DI = 0;
    }

    void reset() {
        top_.INT_n = 1;
        top_.RESET_n = 0;
        for (int i = 0; i < 4; i++) {
            clock();
        }
        top_.RESET_n = 1;

        ticks_ = 0;
        was_read_ = false;
        was_write_ = false;
        was_port_read_ = false;
        was_port_write_ = false;
        was_int_ack_ = false;
    }

    // Advances one T-state and returns the bus as it stands during it. `data`
    // is what the previous T-state left on DI: T80s samples DI on this edge.
    Pins step(uint8_t data) {
        top_.DI = data;
        clock();
        ticks_++;

        bool read = !top_.MREQ_n && !top_.RD_n;
        bool write = !top_.MREQ_n && !top_.WR_n;
        bool port_read = !top_.IORQ_n && !top_.RD_n && top_.M1_n;
        bool port_write = !top_.IORQ_n && !top_.WR_n;
        bool int_ack = !top_.IORQ_n && !top_.M1_n;

        Pins pins;
        pins.read = read && !was_read_;
        pins.fetch = pins.read && !top_.M1_n;
        pins.write = write && !was_write_;
        pins.port_read = port_read && !was_port_read_;
        pins.port_write = port_write && !was_port_write_;
        pins.int_ack = int_ack && !was_int_ack_;
        pins.halted = !top_.HALT_n;
        pins.addr = top_.A;
        pins.data = top_.DO;

        was_read_ = read;
        was_write_ = write;
        was_port_read_ = port_read;
        was_port_write_ = port_write;
        was_int_ack_ = int_ack;
        return pins;
    }

    void set_int(bool asserted) { top_.INT_n = asserted ? 0 : 1; }
    void set_nmi(bool asserted) { top_.NMI_n = asserted ? 0 : 1; }

    // T-states since reset. The T-state returned by the latest step() is
    // number ticks() - 1.
    uint64_t ticks() const { return ticks_; }

  private:
    void clock() {
        top_.CLK = 0;
        top_.eval();
        top_.CLK = 1;
        top_.eval();
    }

    Vt80s top_;
    uint64_t ticks_ = 0;
    bool was_read_ = false;
    bool was_write_ = false;
    bool was_port_read_ = false;
    bool was_port_write_ = false;
    bool was_int_ack_ = false;
};

//----------------------------------------------------------------------------
//  FUSE core tests
//----------------------------------------------------------------------------

struct Registers {
    // AF BC DE HL AF' BC' DE' HL' IX IY SP PC MEMPTR, in FUSE's file order.
    unsigned word[13] = {};
    unsigned i = 0;
    unsigned r = 0;
    unsigned iff1 = 0;
    unsigned iff2 = 0;
    unsigned im = 0;
    unsigned halted = 0;
    unsigned tstates = 0;
};

enum { AF, BC, DE, HL, AF_, BC_, DE_, HL_, IX, IY, SP, PC, MEMPTR };
const char* const kWordNames[] = {"AF", "BC", "DE", "HL", "AF'", "BC'", "DE'",
                                  "HL'", "IX", "IY", "SP", "PC", "MEMPTR"};

struct Event {
    unsigned time;
    char type[3];
    unsigned addr;
    unsigned data;

    bool operator==(const Event& other) const {
        return time == other.time && strcmp(type, other.type) == 0 &&
               addr == other.addr && data == other.data;
    }
};

struct Patch {
    unsigned addr;
    std::vector<uint8_t> bytes;
};

struct FuseTest {
    std::string name;
    Registers start;
    std::vector<Patch> memory;

    Registers end;
    std::vector<Event> events;
    std::vector<Patch> changed;
};

bool read_line(FILE* f, std::string* line) {
    char buf[4096];
    if (!fgets(buf, sizeof buf, f)) {
        return false;
    }
    *line = buf;
    while (!line->empty() && (line->back() == '\n' || line->back() == '\r')) {
        line->pop_back();
    }
    return true;
}

bool read_registers(FILE* f, Registers* regs) {
    std::string line;
    if (!read_line(f, &line)) {
        return false;
    }
    unsigned* w = regs->word;
    int got = sscanf(line.c_str(), "%x %x %x %x %x %x %x %x %x %x %x %x %x",
                     &w[0], &w[1], &w[2], &w[3], &w[4], &w[5], &w[6], &w[7],
                     &w[8], &w[9], &w[10], &w[11], &w[12]);
    if (got != 13 || !read_line(f, &line)) {
        return false;
    }
    got = sscanf(line.c_str(), "%x %x %u %u %u %u %u", &regs->i, &regs->r,
                 &regs->iff1, &regs->iff2, &regs->im, &regs->halted,
                 &regs->tstates);
    return got == 7;
}

// "<addr> <byte> <byte> ... -1" lines. tests.in closes the list with a lone
// "-1"; tests.expected closes it with a blank line.
bool read_patches(FILE* f, std::vector<Patch>* patches) {
    std::string line;
    while (read_line(f, &line)) {
        if (line.empty() || line == "-1") {
            return true;
        }

        Patch patch;
        const char* p = line.c_str();
        int used = 0;
        if (sscanf(p, "%x%n", &patch.addr, &used) != 1) {
            return false;
        }
        p += used;

        int value;
        while (sscanf(p, "%x%n", (unsigned*)&value, &used) == 1 && value != -1) {
            patch.bytes.push_back((uint8_t)value);
            p += used;
        }
        patches->push_back(patch);
    }
    return true;
}

bool next_name(FILE* f, std::string* name) {
    while (read_line(f, name)) {
        if (!name->empty()) {
            return true;
        }
    }
    return false;
}

std::vector<FuseTest> load_fuse(const char* in_path, const char* expected_path) {
    std::vector<FuseTest> tests;
    // Binary mode: ftell and fseek are not reliable on a text-mode stream.
    FILE* in = fopen(in_path, "rb");
    FILE* expected = fopen(expected_path, "rb");
    if (!in || !expected) {
        return tests;
    }

    std::string name;
    while (next_name(in, &name)) {
        FuseTest test;
        test.name = name;
        if (!read_registers(in, &test.start) || !read_patches(in, &test.memory)) {
            fprintf(stderr, "tests.in: malformed test %s\n", name.c_str());
            exit(2);
        }

        std::string expected_name;
        if (!next_name(expected, &expected_name) || expected_name != name) {
            fprintf(stderr, "tests.expected: expected test %s, found %s\n",
                    name.c_str(), expected_name.c_str());
            exit(2);
        }

        // Event lines are indented; the register line that follows is not.
        long mark = ftell(expected);
        std::string line;
        while (read_line(expected, &line) && !line.empty() && line[0] == ' ') {
            Event event = {};
            int got = sscanf(line.c_str(), "%u %2s %x %x", &event.time,
                             event.type, &event.addr, &event.data);
            // MC and PC are contention markers for the Spectrum's ULA. They
            // carry no data and say nothing the read and write events do not.
            if (got == 4) {
                test.events.push_back(event);
            }
            mark = ftell(expected);
        }
        fseek(expected, mark, SEEK_SET);

        if (!read_registers(expected, &test.end) ||
            !read_patches(expected, &test.changed)) {
            fprintf(stderr, "tests.expected: malformed test %s\n", name.c_str());
            exit(2);
        }
        tests.push_back(test);
    }

    fclose(in);
    fclose(expected);
    return tests;
}

// IFF1 clear with IFF2 set is the state an NMI leaves behind when it is taken
// with interrupts enabled. No instruction sequence reaches it on its own.
bool needs_nmi(const Registers& s) { return s.iff1 == 0 && s.iff2 == 1; }

// Stands for the opcode an NMI acknowledge fetches and throws away.
const uint8_t kNmiFetch = 0x00;

// The CPU is a black box, so its registers are set by feeding it instructions
// straight after reset, whatever address it asks for, and read back the same
// way once the test is over. Every byte here is delivered on a read strobe.
std::vector<uint8_t> preamble(const Registers& s) {
    const unsigned* w = s.word;
    auto lo = [](unsigned v) { return (uint8_t)(v & 0xFF); };
    auto hi = [](unsigned v) { return (uint8_t)(v >> 8); };

    // LD R,A is followed by six opcode fetches before the test's own first
    // fetch (IM is two, then LD SP, POP AF, DI or EI, JP), each of which
    // increments the low seven bits of R. An NMI acknowledge is a seventh,
    // and its two pushes leave SP two lower.
    bool nmi = needs_nmi(s);
    unsigned fetches = nmi ? 7 : 6;
    unsigned sp = nmi ? w[SP] : w[SP] - 2;
    uint8_t r = (uint8_t)((s.r & 0x80) | ((s.r - fetches) & 0x7F));
    const uint8_t im_opcode[] = {0x46, 0x56, 0x5E};
    uint8_t ei_or_di = (s.iff1 || nmi) ? 0xFB : 0xF3;

    std::vector<uint8_t> tail = {ei_or_di};
    if (nmi) {
        tail.push_back(kNmiFetch);
    }
    tail.insert(tail.end(), {0xC3, lo(w[PC]), hi(w[PC])});  // JP pc

    std::vector<uint8_t> stream = {
        0x31, 0x00, 0x00,                       // LD SP,0
        0xF1, lo(w[AF_]), hi(w[AF_]),           // POP AF
        0x08,                                   // EX AF,AF'
        0x01, lo(w[BC_]), hi(w[BC_]),           // LD BC,nn
        0x11, lo(w[DE_]), hi(w[DE_]),           // LD DE,nn
        0x21, lo(w[HL_]), hi(w[HL_]),           // LD HL,nn
        0xD9,                                   // EXX
        0x01, lo(w[BC]), hi(w[BC]),
        0x11, lo(w[DE]), hi(w[DE]),
        0x21, lo(w[HL]), hi(w[HL]),
        0xDD, 0x21, lo(w[IX]), hi(w[IX]),       // LD IX,nn
        0xFD, 0x21, lo(w[IY]), hi(w[IY]),       // LD IY,nn
        0x3E, (uint8_t)s.i, 0xED, 0x47,         // LD A,i / LD I,A
        0x3E, r, 0xED, 0x4F,                    // LD A,r / LD R,A
        0xED, im_opcode[s.im],                  // IM n
        0x31, lo(sp), hi(sp),                   // LD SP,sp
        0xF1, lo(w[AF]), hi(w[AF]),             // POP AF
    };
    stream.insert(stream.end(), tail.begin(), tail.end());
    return stream;
}

// Twelve pushes, so 24 writes: AF BC DE HL IX IY AF' BC' DE' HL', then AF
// after LD A,I (A = I, P/V = IFF2) and AF after LD A,R.
const uint8_t kPostamble[] = {
    0xF5, 0xC5, 0xD5, 0xE5,                     // PUSH AF, BC, DE, HL
    0xDD, 0xE5, 0xFD, 0xE5,                     // PUSH IX, IY
    0x08, 0xF5,                                 // EX AF,AF' / PUSH AF
    0xD9, 0xC5, 0xD5, 0xE5,                     // EXX / PUSH BC, DE, HL
    0xED, 0x57, 0xF5,                           // LD A,I / PUSH AF
    0xED, 0x5F, 0xF5,                           // LD A,R / PUSH AF
};
// Opcode fetches from the start of the postamble through the 5F of LD A,R,
// which is the last one R counts before it is read.
const unsigned kPostambleFetchesBeforeR = 19;
const unsigned kPostamblePushes = 12;
// NOP: what the CPU is fed once the postamble has run out.
const uint8_t kFiller = 0x00;

bool is_prefix(uint8_t op) {
    return op == 0xCB || op == 0xED || op == 0xDD || op == 0xFD;
}

class FuseRun {
  public:
    FuseRun(Cpu* cpu, const FuseTest& test) : cpu_(cpu), test_(test) {
        for (unsigned i = 0; i < 65536; i += 4) {
            mem_[i] = 0xDE;
            mem_[i + 1] = 0xAD;
            mem_[i + 2] = 0xBE;
            mem_[i + 3] = 0xEF;
        }
        apply(test.memory, mem_);
    }

    // Returns an empty string on a pass, otherwise what differed.
    std::string run() {
        if (test_.start.iff1 == 1 && test_.start.iff2 == 0) {
            return "skip: starts with IFF1 set and IFF2 clear, which a Z80 "
                   "never reaches";
        }

        load_state();
        execute();
        if (!halted_) {
            read_back();
            probe_interrupts();
        }
        return compare();
    }

  private:
    static void apply(const std::vector<Patch>& patches, uint8_t* mem) {
        for (const Patch& patch : patches) {
            for (size_t i = 0; i < patch.bytes.size(); i++) {
                mem[(patch.addr + i) & 0xFFFF] = patch.bytes[i];
            }
        }
    }

    void fail(const std::string& what) {
        if (!diff_.empty()) {
            diff_ += "; ";
        }
        diff_ += what;
    }

    void load_state() {
        cpu_->reset();
        std::vector<uint8_t> stream = preamble(test_.start);
        size_t next = 0;
        uint8_t data = 0;

        // For an NMI, pull NMI low once EI is on the bus, so the CPU takes it
        // when EI finishes, and let go once the acknowledge has fetched. The
        // stream ends EI, the acknowledge's byte, then JP's three.
        size_t nmi_at = needs_nmi(test_.start) ? stream.size() - 5 : 0;

        while (next < stream.size()) {
            Pins pins = cpu_->step(data);
            if (pins.read) {
                data = stream[next++];
            }
            if (nmi_at && next == nmi_at + 1) {
                cpu_->set_nmi(true);
            }
            if (nmi_at && next == nmi_at + 2) {
                cpu_->set_nmi(false);
            }
        }
        // The last byte is still on the bus and has to be clocked in. The
        // T-state that does it belongs to JP, not to the test.
        pending_ = data;
    }

    // Runs the instructions under test against real memory and logs every bus
    // cycle. FUSE stamps a read or write at the end of its machine cycle,
    // three T-states after it starts and four for an opcode fetch, and a port
    // access one T-state in.
    void execute() {
        uint8_t data = pending_;
        bool started = false;
        bool continuation = false;
        uint8_t prefix = 0;
        uint64_t origin = 0;
        const unsigned limit = 100000;

        for (unsigned guard = 0; guard < limit; guard++) {
            Pins pins = cpu_->step(data);
            // The strobe is visible in T2, so the cycle began one T-state ago.
            uint64_t t1 = cpu_->ticks() - 2;

            if (pins.fetch) {
                if (!started) {
                    started = true;
                    origin = t1;
                }
                fetch_starts_.push_back((unsigned)(t1 - origin));
                if (!continuation && t1 - origin >= test_.start.tstates) {
                    tstates_ = (unsigned)(t1 - origin);
                    pc_ = pins.addr;
                    halted_ = pins.halted;
                    return;
                }

                // A prefix byte is fetched like an opcode but does not end
                // the instruction. After DD CB or FD CB the displacement and
                // the opcode are plain reads, so the chain ends there.
                uint8_t op = mem_[pins.addr];
                bool indexed = prefix == 0xDD || prefix == 0xFD;
                bool was_cb = continuation && op == 0xCB && indexed;
                bool chains = !continuation || indexed;
                continuation = chains && is_prefix(op) && !was_cb;
                prefix = continuation ? op : 0;
            }

            if (started) {
                unsigned rel = (unsigned)(t1 - origin);
                if (pins.read) {
                    log(rel + (pins.fetch ? 4 : 3), "MR", pins.addr,
                        mem_[pins.addr]);
                }
                if (pins.write) {
                    // WR appears in T3, one T-state later than RD would.
                    log(rel + 2, "MW", pins.addr, pins.data);
                    mem_[pins.addr] = pins.data;
                }
                if (pins.port_read) {
                    log(rel + 1, "PR", pins.addr, pins.addr >> 8);
                }
                if (pins.port_write) {
                    log(rel + 1, "PW", pins.addr, pins.data);
                }
            }

            // FUSE's test harness answers a port read with the high byte of
            // the port address.
            data = (pins.port_read || port_reading_) ? (uint8_t)(pins.addr >> 8)
                                                     : mem_[pins.addr];
            port_reading_ = pins.port_read;
        }
        fail("did not reach an instruction boundary");
        timed_out_ = true;
    }

    void log(unsigned time, const char* type, unsigned addr, unsigned data) {
        Event event = {};
        event.time = time;
        strcpy(event.type, type);
        event.addr = addr;
        event.data = data;
        events_.push_back(event);
    }

    // Feeds the postamble from the boundary fetch onward and collects what it
    // pushes. Nothing here reaches mem_: the test's memory is already final.
    void read_back() {
        if (timed_out_) {
            return;
        }
        size_t next = 0;
        uint8_t data = kPostamble[next++];
        std::vector<uint8_t> pushed;
        unsigned first_push_addr = 0;

        for (unsigned guard = 0; guard < 400; guard++) {
            Pins pins = cpu_->step(data);
            if (pins.read && next < sizeof kPostamble) {
                data = kPostamble[next++];
            } else if (pins.read) {
                data = kFiller;
            }
            if (pins.write) {
                if (pushed.empty()) {
                    first_push_addr = pins.addr;
                }
                pushed.push_back(pins.data);
                if (pushed.size() == kPostamblePushes * 2) {
                    break;
                }
            }
        }
        if (pushed.size() != kPostamblePushes * 2) {
            fail("could not read the registers back");
            timed_out_ = true;
            return;
        }

        // A push writes the high byte first.
        auto word = [&](unsigned n) {
            return (unsigned)(pushed[n * 2] << 8 | pushed[n * 2 + 1]);
        };
        const int order[] = {AF, BC, DE, HL, IX, IY, AF_, BC_, DE_, HL_};
        for (unsigned n = 0; n < 10; n++) {
            got_.word[order[n]] = word(n);
        }
        got_.word[SP] = (first_push_addr + 1) & 0xFFFF;

        got_.i = word(10) >> 8;
        got_.iff2 = (word(10) >> 2) & 1;
        unsigned r = word(11) >> 8;
        got_.r = (r & 0x80) | ((r - kPostambleFetchesBeforeR) & 0x7F);
    }

    // IFF1 and the interrupt mode never reach a register that can be pushed,
    // so they are read from how the CPU answers an interrupt. With NOP on the
    // bus, mode 0 runs it and stacks nothing, mode 1 stacks PC and goes to
    // $0038, and mode 2 stacks PC and then reads a two-byte vector.
    void probe_interrupts() {
        if (timed_out_) {
            return;
        }
        cpu_->set_int(true);
        bool acked = wait_for_ack(40);
        got_.iff1 = acked ? 1 : 0;

        if (!acked) {
            // EI, then NOPs until its one-instruction delay has passed. The
            // byte is clocked in by the step after the one showing the fetch.
            uint8_t data = 0xFB;
            bool fetched = false;
            for (unsigned guard = 0; guard < 60 && !acked; guard++) {
                Pins pins = cpu_->step(data);
                if (fetched) {
                    data = kFiller;
                }
                fetched = fetched || pins.fetch;
                acked = pins.int_ack;
            }
        }
        cpu_->set_int(false);
        if (!acked) {
            fail("interrupt was never acknowledged");
            return;
        }

        unsigned writes = 0;
        unsigned vector_reads = 0;
        for (unsigned guard = 0; guard < 30; guard++) {
            Pins pins = cpu_->step(kFiller);
            if (pins.write) {
                writes++;
            }
            if (pins.fetch) {
                break;
            }
            if (pins.read) {
                vector_reads++;
            }
        }
        got_.im = writes == 0 ? 0 : (vector_reads == 0 ? 1 : 2);
    }

    bool wait_for_ack(unsigned budget) {
        for (unsigned guard = 0; guard < budget; guard++) {
            if (cpu_->step(kFiller).int_ack) {
                return true;
            }
        }
        return false;
    }

    std::string compare() {
        const Registers& want = test_.end;
        char buf[160];

        if (tstates_ != want.tstates) {
            snprintf(buf, sizeof buf, "T-states %u, expected %u", tstates_,
                     want.tstates);
            fail(buf);
        }
        if ((unsigned)halted_ != want.halted) {
            snprintf(buf, sizeof buf, "halted %d, expected %u", (int)halted_,
                     want.halted);
            fail(buf);
        }

        // A halted Z80 has already stepped PC past the HALT and is fetching
        // the byte after it. FUSE models the halt by holding PC on the HALT.
        unsigned pc = halted_ ? (pc_ - 1) & 0xFFFF : pc_;
        if (pc != want.word[PC]) {
            snprintf(buf, sizeof buf, "PC %04x, expected %04x", pc,
                     want.word[PC]);
            fail(buf);
        }

        if (!halted_ && !timed_out_) {
            compare_registers();
        }
        compare_events();
        compare_memory();
        return diff_;
    }

    void compare_registers() {
        const Registers& want = test_.end;
        char buf[160];

        for (int n = AF; n <= SP; n++) {
            unsigned got = got_.word[n];
            unsigned expected = want.word[n];
            if (n == AF && flags_follow_memptr()) {
                got &= ~0x28u;
                expected &= ~0x28u;
            }
            if (n == AF) {
                expected = (expected & 0xFF00) | repeat_flags(expected & 0xFF);
            }
            if (got != expected) {
                snprintf(buf, sizeof buf, "%s %04x, expected %04x",
                         kWordNames[n], got_.word[n], want.word[n]);
                fail(buf);
            }
        }

        const struct {
            const char* name;
            unsigned got;
            unsigned want;
        } small[] = {
            {"I", got_.i, want.i},          {"R", got_.r, want.r},
            {"IFF1", got_.iff1, want.iff1}, {"IFF2", got_.iff2, want.iff2},
            {"IM", got_.im, want.im},
        };
        for (const auto& reg : small) {
            if (reg.got != reg.want) {
                snprintf(buf, sizeof buf, "%s %02x, expected %02x", reg.name,
                         reg.got, reg.want);
                fail(buf);
            }
        }
    }

    // BIT n,(HL) copies bits 5 and 3 of F from MEMPTR, an internal register no
    // instruction can load directly. The preamble's JP leaves it equal to PC,
    // so a test that starts with any other value cannot be reproduced here.
    bool flags_follow_memptr() const {
        unsigned pc = test_.start.word[PC];
        bool bit_hl = mem_initial(pc) == 0xCB &&
                      (mem_initial(pc + 1) & 0xC7) == 0x46;
        return bit_hl && test_.start.word[MEMPTR] != pc;
    }

    // FUSE predates David Banks's 2018 logic-analyser measurements of block
    // instructions on Zilog NMOS parts. When LDxR, CPxR, INxR or OTxR is about
    // to repeat, FUSE gives the flags of the instruction that does not, but
    // the extra five T-states change YF and XF, and for INxR and OTxR also PF
    // and HF. This applies those changes to FUSE's F, following
    // https://github.com/hoglet67/Z80Decoder/wiki/Undocumented-Flags
    unsigned repeat_flags(unsigned f) const {
        unsigned pc = test_.start.word[PC];
        uint8_t op = mem_initial(pc + 1);
        bool block = mem_initial(pc) == 0xED && (op & 0xF4) == 0xB0;
        if (!block || test_.end.word[PC] != pc) {
            return f;
        }
        f = (f & ~0x28u) | ((pc >> 8) & 0x28);
        if ((op & 0x02) == 0) {
            return f;  // LDxR, CPxR
        }

        // INxR reads the port at BC, which FUSE answers with B. OTxR writes
        // the byte at HL. B here is after the decrement.
        unsigned b = test_.end.word[BC] >> 8;
        bool in = (op & 0x01) == 0;
        uint8_t data = in ? (uint8_t)(test_.start.word[BC] >> 8)
                          : mem_initial(test_.start.word[HL]);
        auto even = [](unsigned v) { return __builtin_parity(v & 0xFF) == 0; };

        unsigned p = (f >> 2) & 1;
        if (f & 0x01) {
            unsigned adjusted = (data & 0x80) ? b - 1 : b + 1;
            bool h = (data & 0x80) ? (b & 0x0F) == 0x00 : (b & 0x0F) == 0x0F;
            p ^= even(adjusted & 0x07) ^ 1;
            f = (f & ~0x10u) | (h ? 0x10 : 0);
        } else {
            p ^= even(b & 0x07) ^ 1;
        }
        return (f & ~0x04u) | (p << 2);
    }

    uint8_t mem_initial(unsigned addr) const {
        static const uint8_t fill[] = {0xDE, 0xAD, 0xBE, 0xEF};
        addr &= 0xFFFF;
        uint8_t value = fill[addr & 3];
        for (const Patch& patch : test_.memory) {
            if (addr >= patch.addr && addr < patch.addr + patch.bytes.size()) {
                value = patch.bytes[addr - patch.addr];
            }
        }
        return value;
    }

    // A JR cc or DJNZ that is not taken still reads its displacement in M2,
    // as the Z80 data sheet shows and T80 does. FUSE skips that read and logs
    // nothing. The read is the one straight after the opcode fetch whose
    // cycle ends as the next fetch begins; a taken jump spends five more
    // T-states before it fetches.
    bool fuse_skips(size_t i) const {
        const Event& event = events_[i];
        if (i == 0 || strcmp(event.type, "MR") != 0) {
            return false;
        }
        const Event& opcode = events_[i - 1];
        uint8_t op = mem_initial(event.addr - 1);
        bool relative = op == 0x10 || op == 0x20 || op == 0x28 || op == 0x30 ||
                        op == 0x38;
        // An opcode fetch is stamped four T-states after it starts.
        auto fetch_starts_at = [&](unsigned t) {
            for (unsigned start : fetch_starts_) {
                if (start == t) {
                    return true;
                }
            }
            return false;
        };
        bool after_fetch = strcmp(opcode.type, "MR") == 0 &&
                           opcode.addr == ((event.addr - 1) & 0xFFFF) &&
                           opcode.time >= 4 && fetch_starts_at(opcode.time - 4);
        return relative && after_fetch && fetch_starts_at(event.time);
    }

    void compare_events() {
        const std::vector<Event>& want = test_.events;
        char buf[200];

        std::vector<Event> kept;
        for (size_t i = 0; i < events_.size(); i++) {
            if (!fuse_skips(i)) {
                kept.push_back(events_[i]);
            }
        }
        events_ = kept;

        size_t n = events_.size() < want.size() ? events_.size() : want.size();
        for (size_t i = 0; i < n; i++) {
            if (!(events_[i] == want[i])) {
                snprintf(buf, sizeof buf,
                         "bus cycle %zu is %u %s %04x %02x, expected "
                         "%u %s %04x %02x",
                         i, events_[i].time, events_[i].type, events_[i].addr,
                         events_[i].data, want[i].time, want[i].type,
                         want[i].addr, want[i].data);
                fail(buf);
                return;
            }
        }
        if (events_.size() != want.size()) {
            snprintf(buf, sizeof buf, "%zu bus cycles, expected %zu",
                     events_.size(), want.size());
            fail(buf);
        }
    }

    void compare_memory() {
        static uint8_t want[65536];
        for (unsigned i = 0; i < 65536; i++) {
            want[i] = mem_initial_fill(i);
        }
        apply(test_.memory, want);
        apply(test_.changed, want);

        for (unsigned i = 0; i < 65536; i++) {
            if (mem_[i] != want[i]) {
                char buf[80];
                snprintf(buf, sizeof buf, "memory %04x is %02x, expected %02x",
                         i, mem_[i], want[i]);
                fail(buf);
                return;
            }
        }
    }

    static uint8_t mem_initial_fill(unsigned addr) {
        static const uint8_t fill[] = {0xDE, 0xAD, 0xBE, 0xEF};
        return fill[addr & 3];
    }

    Cpu* cpu_;
    const FuseTest& test_;
    uint8_t mem_[65536];

    uint8_t pending_ = 0;
    bool port_reading_ = false;
    bool timed_out_ = false;
    bool halted_ = false;
    unsigned tstates_ = 0;
    unsigned pc_ = 0;
    Registers got_;
    std::vector<Event> events_;
    std::vector<unsigned> fetch_starts_;
    std::string diff_;
};

int run_fuse(const char* in_path, const char* expected_path) {
    printf("T80 against FUSE's Z80 core tests\n");

    std::vector<FuseTest> tests = load_fuse(in_path, expected_path);
    if (tests.empty()) {
        printf("  SKIPPED -- %s not found. "
               "Run: python tools/sync.py --repo fuse\n\n", in_path);
        printf("PASS  T80 FUSE tests (skipped)\n");
        return 0;
    }

    Cpu cpu;
    unsigned failed = 0;
    unsigned skipped = 0;
    unsigned wrong_time = 0;

    for (const FuseTest& test : tests) {
        std::string diff = FuseRun(&cpu, test).run();
        if (diff.empty()) {
            continue;
        }
        if (diff.rfind("skip:", 0) == 0) {
            skipped++;
            printf("  skip  %-8s %s\n", test.name.c_str(), diff.c_str() + 6);
            continue;
        }
        failed++;
        if (diff.find("T-states") != std::string::npos ||
            diff.find("bus cycle") != std::string::npos) {
            wrong_time++;
        }
        printf("  FAIL  %-8s %s\n", test.name.c_str(), diff.c_str());
    }

    unsigned ran = (unsigned)tests.size() - skipped;
    printf("\n  info  %u tests run, %u skipped, %u failed, %u of those on "
           "timing\n", ran, skipped, failed, wrong_time);
    if (failed) {
        printf("FAIL  T80 differs from FUSE on %u of %u tests\n", failed, ran);
        return 1;
    }
    printf("PASS  T80 matches FUSE on all %u tests: T-states, registers, "
           "memory and bus cycle times\n", ran);
    return 0;
}

//----------------------------------------------------------------------------
//  CP/M exercisers
//----------------------------------------------------------------------------

//    $0000  JP $0100     launch, and the warm-boot exit the programs jump to
//    $0005  JP $FF00     BDOS entry; the word at $0006 is also what zexdoc
//                        loads as its stack pointer
//    $0100  the image
//    $FF00  BDOS shim, in Z80: functions 2 and 9, writing each character to
//           port $00. C, D and E are inside the CPU, so an OUT is the only way
//           to get a character out where the pins can show it.
const unsigned kTpa = 0x0100;
const unsigned kShim = 0xFF00;
const uint8_t kShimCode[] = {
    0x79,                   // LD A,C
    0xFE, 0x02,             // CP 2
    0xCA, 0x10, 0xFF,       // JP Z,conout
    0xFE, 0x09,             // CP 9
    0xCA, 0x20, 0xFF,       // JP Z,prstr
    0xC9,                   // RET
    0, 0, 0, 0,
    0x7B,                   // conout: LD A,E
    0xD3, 0x00,             // OUT ($00),A
    0xC9,                   // RET
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0x1A,                   // prstr: LD A,(DE)
    0xFE, 0x24,             // CP '$'
    0xC8,                   // RET Z
    0xD3, 0x00,             // OUT ($00),A
    0x13,                   // INC DE
    0xC3, 0x20, 0xFF,       // JP prstr
};

// zexdoc and zexall open with JP start, and start loads the address of a
// zero-terminated table of test pointers into HL. Keeping one entry runs one
// test.
bool keep_one_test(uint8_t* mem, int index) {
    // start: LD HL,(6) / LD SP,HL / LD DE,msg / LD C,9 / CALL bdos / LD HL,tests
    unsigned start = mem[kTpa + 1] | mem[kTpa + 2] << 8;
    unsigned load = start + 12;
    if (mem[kTpa] != 0xC3 || mem[load] != 0x21) {
        return false;
    }
    unsigned table = mem[load + 1] | mem[load + 2] << 8;

    int count = 0;
    while (mem[table + count * 2] || mem[table + count * 2 + 1]) {
        count++;
    }
    if (index < 0 || index >= count) {
        return false;
    }

    mem[table] = mem[table + index * 2];
    mem[table + 1] = mem[table + index * 2 + 1];
    mem[table + 2] = 0;
    mem[table + 3] = 0;
    return true;
}

int run_cpm(const char* image, int only_test) {
    static uint8_t mem[65536];
    FILE* f = fopen(image, "rb");
    if (!f) {
        printf("  SKIPPED -- %s not found. "
               "Run: python tools/sync.py --repo z80-exercisers\n\n", image);
        printf("PASS  T80 exerciser (skipped)\n");
        return 0;
    }
    size_t loaded = fread(mem + kTpa, 1, kShim - kTpa, f);
    fclose(f);
    (void)loaded;

    mem[0x0000] = 0xC3;
    mem[0x0001] = kTpa & 0xFF;
    mem[0x0002] = kTpa >> 8;
    mem[0x0005] = 0xC3;
    mem[0x0006] = kShim & 0xFF;
    mem[0x0007] = kShim >> 8;
    memcpy(mem + kShim, kShimCode, sizeof kShimCode);

    if (only_test >= 0 && !keep_one_test(mem, only_test)) {
        printf("FAIL  %s has no test %d\n", image, only_test);
        return 1;
    }

    Cpu cpu;
    cpu.reset();

    std::string output;
    bool started = false;
    bool finished = false;
    uint8_t data = mem[0];

    // zexall runs for 46.7 billion T-states. Anything past this is a hang.
    const uint64_t limit = 60000000000ull;

    while (!finished && cpu.ticks() < limit) {
        Pins pins = cpu.step(data);
        if (pins.write) {
            mem[pins.addr] = pins.data;
        }
        if (pins.port_write) {
            output += (char)pins.data;
            putchar(pins.data);
            fflush(stdout);
        }
        if (pins.fetch) {
            started = started || pins.addr >= kTpa;
            finished = started && pins.addr == 0;
        }
        data = mem[pins.addr];
    }

    printf("\n  info  %llu T-states\n", (unsigned long long)cpu.ticks());

    if (!finished) {
        printf("FAIL  exerciser did not finish\n");
        return 1;
    }
    // prelim reports a failed check by jumping to 0 without printing.
    if (output.empty()) {
        printf("FAIL  exerciser exited without printing, which is how prelim "
               "reports a failed check\n");
        return 1;
    }
    if (output.find("ERROR") != std::string::npos) {
        printf("FAIL  exerciser reported ERROR (see the lines above)\n");
        return 1;
    }
    printf("PASS  T80 exerciser reported no errors\n");
    return 0;
}

//----------------------------------------------------------------------------
//  Patrik Rak's z80test
//----------------------------------------------------------------------------

// z80full, z80doc, z80flags, z80memptr and z80ccf are ZX Spectrum programs.
// They CRC each instruction's results, flags, MEMPTR (through BIT n,(HL)) and
// the undocumented SCF/CCF behaviour against a real Zilog NMOS Z80. Of the
// Spectrum they need only three things, all stood in for here:
//
//    $0000  LD SP,$7F00 / CALL $8000 / HALT    launch; HALT marks the end
//    $0010  OUT ($00),A / RET                  RST $10, print a character
//    $1601  RET                                CHAN-OPEN, nothing to open
//
// Port reads answer $BF, the idle Spectrum keyboard port the IN tests expect.
const uint8_t kSpectrumLaunch[] = {0x31, 0x00, 0x7F, 0xCD, 0x00, 0x80, 0x76};
const uint8_t kSpectrumRst10[] = {0xD3, 0x00, 0xC9};
const unsigned kSpectrumChanOpen = 0x1601;
const uint8_t kSpectrumPortValue = 0xBF;

// Loads every CODE block of a .tap file at the address its header names.
// Each block is a two-byte length, a flag byte, the data and a checksum.
// A header (flag $00) of type 3 is CODE, with its load address at offset 14.
bool load_tap(const char* path, uint8_t* mem) {
    FILE* f = fopen(path, "rb");
    if (!f) {
        return false;
    }
    std::vector<uint8_t> tap;
    int c;
    while ((c = fgetc(f)) != EOF) {
        tap.push_back((uint8_t)c);
    }
    fclose(f);

    bool loaded = false;
    int code_addr = -1;
    size_t at = 0;
    while (at + 2 <= tap.size()) {
        size_t length = tap[at] | tap[at + 1] << 8;
        const uint8_t* block = tap.data() + at + 2;
        at += 2 + length;
        if (length < 2 || at > tap.size()) {
            break;
        }

        if (block[0] == 0x00 && length >= 19) {
            code_addr = block[1] == 3 ? (block[14] | block[15] << 8) : -1;
        } else if (block[0] == 0xFF && code_addr >= 0) {
            // The payload sits between the flag and the checksum.
            for (size_t i = 0; i < length - 2; i++) {
                mem[(code_addr + i) & 0xFFFF] = block[1 + i];
            }
            loaded = true;
            code_addr = -1;
        }
    }
    return loaded;
}

int run_spectrum(const char* tap) {
    static uint8_t mem[65536];
    if (!load_tap(tap, mem)) {
        printf("  SKIPPED -- %s not found or holds no CODE block. "
               "Run: python tools/sync.py --repo z80test\n\n", tap);
        printf("PASS  T80 z80test (skipped)\n");
        return 0;
    }
    memcpy(mem, kSpectrumLaunch, sizeof kSpectrumLaunch);
    memcpy(mem + 0x10, kSpectrumRst10, sizeof kSpectrumRst10);
    mem[kSpectrumChanOpen] = 0xC9;

    Cpu cpu;
    cpu.reset();

    std::string output;
    bool port_reading = false;
    unsigned last_fetch = 0;
    int skip = 0;
    uint8_t data = mem[0];
    const uint64_t limit = 20000000000ull;

    while (cpu.ticks() < limit) {
        Pins pins = cpu.step(data);
        if (pins.halted) {
            break;
        }
        if (pins.write) {
            mem[pins.addr] = pins.data;
        }
        if (pins.fetch) {
            last_fetch = pins.addr;
        }

        // The tests write to ports themselves, so only the OUT at $0010
        // prints. Spectrum control codes: 13 is a new line, 23 is TAB with
        // two operand bytes, 127 is the copyright sign.
        if (pins.port_write && last_fetch == 0x10) {
            uint8_t ch = pins.data;
            if (skip > 0) {
                skip--;
            } else if (ch == 23) {
                skip = 2;
                output += ' ';
                putchar(' ');
            } else {
                char out = ch == 13 ? '\n' : (ch == 127 ? 'c' : (char)ch);
                output += out;
                putchar(out);
            }
            fflush(stdout);
        }

        data = (pins.port_read || port_reading) ? kSpectrumPortValue
                                                : mem[pins.addr];
        port_reading = pins.port_read;
    }

    printf("\n  info  %llu T-states\n", (unsigned long long)cpu.ticks());

    if (output.find("all tests passed") != std::string::npos) {
        printf("PASS  T80 z80test: all tests passed\n");
        return 0;
    }
    if (output.find("Result:") == std::string::npos) {
        printf("FAIL  z80test did not finish\n");
        return 1;
    }
    printf("FAIL  z80test reported failures (see the lines above)\n");
    return 1;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc == 3 && strcmp(argv[1], "tap") == 0) {
        return run_spectrum(argv[2]);
    }
    if (argc == 4 && strcmp(argv[1], "fuse") == 0) {
        return run_fuse(argv[2], argv[3]);
    }
    if (argc == 3 && strcmp(argv[1], "cpm") == 0) {
        return run_cpm(argv[2], -1);
    }
    if (argc == 5 && strcmp(argv[1], "cpm") == 0 &&
        strcmp(argv[3], "--test") == 0) {
        return run_cpm(argv[2], atoi(argv[4]));
    }

    fprintf(stderr,
            "usage: tb_t80 fuse <tests.in> <tests.expected>\n"
            "       tb_t80 cpm <image> [--test N]\n"
            "       tb_t80 tap <z80test.tap>\n");
    return 2;
}
