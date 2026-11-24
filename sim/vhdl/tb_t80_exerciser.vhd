--============================================================================
--  T80 against the canonical Z80 exercisers.
--
--  tb_t80_timing proves T80 spends the right number of clocks per instruction.
--  It says nothing about whether the instruction computed the right ANSWER, and
--  it covers unprefixed opcodes only. A census of rallyx.rom says that is the
--  smaller half of the problem: the game executes 163 distinct unprefixed
--  opcodes and 708 prefixed sites -- LDIR, NEG, SBC HL, IX/IY loads and
--  arithmetic, DD CB bit operations. None of that was under test.
--
--  This bench runs the exercisers instead of inventing expectations. prelim.com
--  checks that the basic machine works at all; zexdoc.cim is Frank Cringle's
--  exerciser, which CRCs the result and documented flags of every instruction
--  against a real Z80. Their expected values come from hardware, not from this
--  repository's reading of the datasheet.
--
--  Both are CP/M programs, so the harness is a minimal CP/M:
--
--    $0000  JP $0100     launch (and the warm-boot exit the programs jump to)
--    $0005  JP $FF00     BDOS entry; the word at $0006 is also what zexdoc
--                        loads as its stack pointer
--    $0100  the image
--    $FF00  BDOS shim, in Z80 -- functions 2 and 9, writing each character to
--           port $00 so the testbench can watch it on the bus
--
--  The shim is Z80 code rather than testbench magic because C, D and E are
--  inside the CPU: an OUT is the only way to get a character out where a
--  black-box bench can see it.
--
--  Set the image with -gIMAGE=<path>; tools/sim.py --image does it for you.
--  If the file is missing the bench reports a skip and passes, the same way the
--  suite treats a missing GHDL -- run tools/sync.py --repo z80-exercisers.
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_t80_exerciser is
    generic (
        IMAGE : string := ".repos/z80-exercisers/roms/prelim.com";
        -- Millions of T-states. A VHDL integer stops at 2^31, and zexdoc runs
        -- past that, so the budget and the counter are both kept in millions.
        MAX_MCYCLES : integer := 40
    );
end entity;

architecture sim of tb_t80_exerciser is

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal di      : std_logic_vector(7 downto 0);
    signal do      : std_logic_vector(7 downto 0);
    signal a       : std_logic_vector(15 downto 0);
    signal m1_n    : std_logic;
    signal mreq_n  : std_logic;
    signal iorq_n  : std_logic;
    signal rd_n    : std_logic;
    signal wr_n    : std_logic;
    signal rfsh_n  : std_logic;
    signal halt_n  : std_logic;
    signal busak_n : std_logic;

    signal running : boolean := true;

    constant TPA   : integer := 16#0100#;
    constant SHIM  : integer := 16#FF00#;

    type mem_t is array (0 to 65535) of std_logic_vector(7 downto 0);

    function b(v : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(v, 8));
    end function;

    impure function present(name : string) return boolean is
        type charfile is file of character;
        file f : charfile;
        variable status : file_open_status;
    begin
        file_open(status, f, name, read_mode);
        if status /= open_ok then
            return false;
        end if;
        file_close(f);
        return true;
    end function;

    impure function load(name : string) return mem_t is
        type charfile is file of character;
        file f : charfile;
        variable status : file_open_status;
        variable ch     : character;
        variable m      : mem_t := (others => x"00");
        variable addr   : integer := TPA;
    begin
        -- launcher: the CPU resets to $0000, the image lives at $0100
        m(16#0000#) := x"C3"; m(16#0001#) := x"00"; m(16#0002#) := x"01";

        -- BDOS entry. The word at $0006 doubles as zexdoc's initial SP, so the
        -- shim sits at the top of memory and the stack grows down from it.
        m(16#0005#) := x"C3";
        m(16#0006#) := b(SHIM mod 256);
        m(16#0007#) := b(SHIM / 256);

        -- BDOS shim: dispatch on C
        m(SHIM + 0) := x"79";                                  -- LD A,C
        m(SHIM + 1) := x"FE"; m(SHIM + 2) := x"02";            -- CP 2
        m(SHIM + 3) := x"CA";                                  -- JP Z,conout
        m(SHIM + 4) := b((SHIM + 16) mod 256);
        m(SHIM + 5) := b((SHIM + 16) / 256);
        m(SHIM + 6) := x"FE"; m(SHIM + 7) := x"09";            -- CP 9
        m(SHIM + 8) := x"CA";                                  -- JP Z,prstr
        m(SHIM + 9) := b((SHIM + 32) mod 256);
        m(SHIM + 10) := b((SHIM + 32) / 256);
        m(SHIM + 11) := x"C9";                                 -- RET

        -- function 2: character in E
        m(SHIM + 16) := x"7B";                                 -- LD A,E
        m(SHIM + 17) := x"D3"; m(SHIM + 18) := x"00";          -- OUT ($00),A
        m(SHIM + 19) := x"C9";                                 -- RET

        -- function 9: '$'-terminated string at DE
        m(SHIM + 32) := x"1A";                                 -- LD A,(DE)
        m(SHIM + 33) := x"FE"; m(SHIM + 34) := x"24";          -- CP '$'
        m(SHIM + 35) := x"C8";                                 -- RET Z
        m(SHIM + 36) := x"D3"; m(SHIM + 37) := x"00";          -- OUT ($00),A
        m(SHIM + 38) := x"13";                                 -- INC DE
        m(SHIM + 39) := x"C3";                                 -- JP prstr
        m(SHIM + 40) := b((SHIM + 32) mod 256);
        m(SHIM + 41) := b((SHIM + 32) / 256);

        file_open(status, f, name, read_mode);
        if status /= open_ok then
            return m;
        end if;
        while not endfile(f) and addr <= 65535 loop
            read(f, ch);
            m(addr) := b(character'pos(ch));
            addr := addr + 1;
        end loop;
        file_close(f);
        return m;
    end function;

    signal mem : mem_t := load(IMAGE);

    signal errors : integer := 0;

begin

    clk <= not clk after 5 ns when running else '0';

    cpu : entity work.T80s
        generic map (Mode => 0, T2Write => 0, IOWait => 1)
        port map (
            RESET_n => reset_n, CLK => clk, WAIT_n => '1',
            INT_n   => '1', NMI_n => '1', BUSRQ_n => '1',
            DI      => di,
            M1_n    => m1_n, MREQ_n => mreq_n, IORQ_n => iorq_n,
            RD_n    => rd_n, WR_n => wr_n, RFSH_n => rfsh_n,
            HALT_n  => halt_n, BUSAK_n => busak_n,
            A       => a, DO => do
        );

    di <= mem(to_integer(unsigned(a)));

    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if mreq_n = '0' and wr_n = '0' then
                mem(to_integer(unsigned(a))) <= do;
            end if;
        end if;
    end process;

    run_proc : process
        variable cycles    : integer := 0;   -- within the current million
        variable mcycles   : integer := 0;   -- completed millions
        variable beat      : integer := 0;   -- last heartbeat, in millions
        variable started   : boolean := false;
        variable finished  : boolean := false;
        variable io_prev   : boolean := false;
        variable io_now    : boolean;
        variable ch        : character;
        variable line_buf  : string(1 to 256);
        variable line_len  : integer := 0;
        variable saw_error : boolean := false;
        variable out_chars : integer := 0;

        procedure flush_line is
        begin
            if line_len > 0 then
                report "  | " & line_buf(1 to line_len);
                line_len := 0;
            end if;
        end procedure;

        -- case-sensitive substring test over the current line
        function has(s : string; sub : string) return boolean is
        begin
            if sub'length > s'length then
                return false;
            end if;
            for i in s'low to s'high - sub'length + 1 loop
                if s(i to i + sub'length - 1) = sub then
                    return true;
                end if;
            end loop;
            return false;
        end function;
    begin
        report "T80 instruction exerciser";
        report "  image: " & IMAGE;

        if not present(IMAGE) then
            report "  SKIPPED -- image not found. " &
                   "Run: python tools/sync.py --repo z80-exercisers";
            report "";
            report "PASS  T80 exerciser (skipped)";
            running <= false;
            wait;
        end if;

        reset_n <= '0';
        for i in 0 to 7 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';

        loop
            wait until rising_edge(clk);
            cycles := cycles + 1;
            if cycles = 1000000 then
                cycles := 0;
                mcycles := mcycles + 1;
                -- A zexdoc pass runs for hours; say something occasionally so
                -- the run is visibly alive between test lines.
                if mcycles - beat >= 50 then
                    beat := mcycles;
                    report "  ... " & integer'image(mcycles) &
                           "M T-states elapsed";
                end if;
            end if;

            -- character out of the BDOS shim
            io_now := (iorq_n = '0' and wr_n = '0' and m1_n = '1');
            if io_now and not io_prev then
                ch := character'val(to_integer(unsigned(do)));
                out_chars := out_chars + 1;
                if ch = CR or ch = LF then
                    if line_len > 0 and has(line_buf(1 to line_len), "ERROR") then
                        saw_error := true;
                    end if;
                    flush_line;
                elsif line_len < line_buf'length then
                    line_len := line_len + 1;
                    line_buf(line_len) := ch;
                end if;
            end if;
            io_prev := io_now;

            -- opcode fetch tells us where we are
            if m1_n = '0' and mreq_n = '0' and rd_n = '0' then
                if to_integer(unsigned(a)) >= TPA then
                    started := true;
                elsif started and to_integer(unsigned(a)) = 0 then
                    finished := true;      -- warm boot: the program is done
                end if;
            end if;

            exit when finished;
            exit when mcycles >= MAX_MCYCLES;
        end loop;

        if line_len > 0 and has(line_buf(1 to line_len), "ERROR") then
            saw_error := true;
        end if;
        flush_line;

        report "";
        report "  info  " & integer'image(mcycles) & "M + " &
               integer'image(cycles) & " T-states, " &
               integer'image(out_chars) & " characters out";

        if not finished then
            report "FAIL  exerciser did not finish within " &
                   integer'image(MAX_MCYCLES) & "M cycles";
        elsif out_chars = 0 then
            -- prelim signals failure by jumping to 0 without printing anything
            report "FAIL  exerciser exited without printing -- " &
                   "that is how prelim reports a failed check";
        elsif saw_error then
            report "FAIL  exerciser reported ERROR (see the lines above)";
        else
            report "PASS  T80 exerciser -- no errors reported";
        end if;

        running <= false;
        wait;
    end process;

end architecture;
