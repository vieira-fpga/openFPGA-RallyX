# sim/

Icarus Verilog testbenches asserting this core's timing against the numbers the
original Namco board ran at. Run them with:

```
python tools/sim.py              # everything
python tools/sim.py --test sound # one
```

The runner exits non-zero if any testbench fails, and each testbench prints
what it measured rather than just a verdict — the numbers are the point.

## What each one pins down

| Testbench | Asserts |
|---|---|
| `tb_hvgen` | 384x264 raster, 288x224 active, 16.000 kHz line rate, 60.6061 Hz frame rate |
| `tb_fpga_nrx` | Z80 at 3.072 MHz; frame interrupt on line 224, inside vblank, at 60.606 Hz; IN0/IN1/DSW decode at $A000/$A080/$A100, read unlatched |
| `tb_nrx_video` | PCLK at 6.144 MHz, 50% duty; sprite divider holds constant phase against it |
| `tb_nrx_sprite` | 95-pixel blanking budget, and the sprite scan finishing inside it |
| `tb_nrx_sound` | 96.000 kHz WSG sampling; pitch = 96000 x freq / 2^20; wave ROM outruns sampling |
| `tb_nrx_bang` | 2000.000 Hz noise clock, 3584-tick burst = 1.792 s |
| `tb_pocket_i2s` | MCLK 12.288 MHz, SCLK 3.072 MHz, LRCK 48.000 kHz, 64 bit clocks per frame |
| `tb_rams` | One-clock registered read latency on every memory primitive |
| `tb_t80_timing` | Z80 instruction cycle counts — T-states per unprefixed instruction, measured M1-to-M1 |
| `tb_t80_prefixed` | T-states for the CB/ED/DD/FD instructions the game uses — LDIR 21/16, IX/IY, `DD CB` |
| `tb_t80_interrupt` | Mode 0 interrupt acknowledge: the EI shadow, the vector taken off the bus, RST 30h, 13 T-states |
| `tb_t80_exerciser` | T80's actual results and flags, against prelim.com — and zexdoc/zexall on demand |
| `tb_t80` | T80 compiled with Verilator: FUSE's per-opcode registers, memory and bus-cycle timing, prelim; with `--exercisers`, z80test, zexdoc, zexall and the CPU test ROM |

## Two things you need to know

**The clock dividers have no initial value and no reset.** `_CCLK`,
`VCLKx2`/`VCLK`, `clkcnt`, `ccnt` and NPSG_WAV's `ad` all power up to 0 on
Cyclone V, but under Icarus they stay X forever and the clocks never start — the
module just looks dead. Every testbench here opens with an `initial` block
forcing them to 0. Copy that pattern for any new one.

**The Z80 runs under GHDL, not Icarus.** `T80s` is VHDL, so the four `tb_t80_*`
benches live in `sim/vhdl/` and `tools/sim.py` routes them to GHDL automatically. If GHDL
is missing the runner skips it and says so rather than failing. The Verilog
benches still use the inert `T80s` in `stubs.v` — they measure the glue around
the CPU, not the CPU.

Four GHDL flags are load-bearing: `--std=93` (T80 is VHDL-93), `-fsynopsys`
(its non-standard IEEE packages), `-fexplicit` (it compares vectors with both
`std_logic_1164` and `std_logic_unsigned` in scope), and `--syn-binding`.
Without the last one GHDL refuses to bind `T80` inside `T80s` — the component is
declared in `T80_Pack` rather than in the architecture, and GHDL's strict
default-binding rule will not resolve that. The symptom is a silent `instance
"u0" of component "T80" is not bound` warning and a CPU that never executes
anything.

**Where T80 comes from.** `src/fpga/rtl/cpu/` is the T80 that
MiSTer-devel/ZX-Spectrum_MISTer maintains (`rtl/T80` at `af0e672`), not the 2002
release 0247 the MiSTer Rally-X core carried. Against FUSE's tests, 0247 got 532
of 1352 cases wrong. Three local changes sit on top, each marked in the file it
touches:

- `T80.vhd`: SCF and CCF take YF/XF from whether the previous instruction wrote
  F, not from whether F changed value. z80ccf failed 33 tests without it.
- `T80.vhd`: in interrupt mode 0, a 00 on the bus runs as NOP. T80's microcode
  took it for the start of its IM 2 sequence.
- `T80s.vhd`: an I/O write drives WR with IORQ from T2. `T2Write => 0` holds WR
  back to T3, which suits memory writes but put I/O writes two clocks late.

**T80 against outside references.** GHDL runs T80 at roughly 100,000 T-states
per second, too slow for anything but prelim. `tb_t80` has GHDL synthesise T80
to a Verilog netlist and Verilator compile that, then `sim/verilator/tb_t80.cpp`
drives it from the pins at a few million T-states per second. It needs GHDL and
Verilator; `tools/sim.py` looks for both in MSYS2's `ucrt64`. Fetch the
references first:

```
python tools/sync.py --repo fuse
python tools/sync.py --repo z80-exercisers
python tools/sync.py --repo z80test
```

Every run includes FUSE's Z80 core tests and prelim, under a minute together.
FUSE gives each opcode a starting state and expects the T-state count, the final
registers, the memory, and the T-state of every bus cycle. All 1355 cases a Z80
can reach pass; the one skipped starts with IFF1 set and IFF2 clear. Two of
FUSE's expectations are out of date, and the harness corrects them where it
says why: FUSE skips the displacement read of a JR cc or DJNZ that is not taken,
and it predates David Banks's measurements of the flags while a block
instruction repeats.

The long references are opt-in:

```
python tools/sim.py --test tb_t80 --exercisers
```

That adds Patrik Rak's z80test (z80full, z80doc, z80flags, z80docflags,
z80memptr, z80ccf), every entry of Frank Cringle's zexdoc and zexall, and the
CPU test ROM, spread across every core. Their CRCs come from real Zilog Z80s, so
they do not depend on this repository's reading of the datasheet; z80test also
reaches MEMPTR and SCF/CCF, which zex does not. Budget an afternoon: one
entry, `aluop a,<b,c,d,e,h,l,(hl),a>`, is 20 billion T-states in each of
zexdoc, zexall and the test ROM, two to three hours on a core of its own. On a
machine with a core per entry, everything else is done inside the first hour.

`LINEBUF` is the better case: it wraps an `altsyncram` megafunction, and
`tools/sim.py` compiles Quartus's own simulation model
(`quartus/eda/sim_lib/altera_mf.v`) so the real thing is under test. Only if
that model cannot be found does it fall back to the behavioural stand-in in
`stubs.v`, and it says so when it does.

## Not covered

- `core_top.v` — the 96 kHz to 48 kHz audio decimation lives inline in a module
  that also instantiates the PLL, the APF bridge and the Analogizer, so it is
  not reachable as a unit without restructuring it.
- The clock-domain crossings in `core_top.v`, including the controller
  synchroniser feeding `CTR1`. Icarus has no metastability model: a missing
  synchroniser simulates exactly like a correct one. Read those against the
  reference cores and confirm them on hardware, never in a waveform.
- `core_bridge_cmd.v`, `data_loader.sv` — host bridge and ROM download. Their
  behaviour is protocol, not clock timing.
- `mf_pllbase` — a hard PLL; its output frequencies are a fitter constraint,
  checked by the Quartus compile rather than by simulation.
- T80 inside the board. `tb_t80` drives the CPU alone, and the Verilog
  benches stub it out, so nothing simulates the game's own code on the real
  CPU. The CPU test ROM on the Pocket is that check.
