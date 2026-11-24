--============================================================================
--  T80 instruction cycle timing.
--
--  Every other testbench in sim/ proves a clock RATE. This one proves the CPU
--  does the right amount of WORK per clock: that T80 spends the same number of
--  T-states on each instruction as a real Z80. Rally-X is interrupt-paced, so a
--  CPU that is clocked correctly but executes fast or slow still drifts against
--  the original -- and no raster or audio test would ever see it.
--
--  Method: run a program of known instructions and measure the gap between
--  consecutive M1_n assertions. M1_n falls at T1 of every opcode fetch, so the
--  clocks from one M1 to the next are exactly the T-states of the instruction
--  that was fetched first. Expected values are the published Z80 timings.
--
--  Only unprefixed opcodes are used: CB/ED/DD/FD prefixes assert M1 twice, so
--  an M1-to-M1 delta would report the prefix and the opcode separately rather
--  than the instruction as a whole.
--
--  T80s is instantiated with the same generics fpga_NRX ships (Mode=0 Z80,
--  T2Write=0, IOWait=1) so this measures what is actually in the bitstream.
--
--  Run:  ghdl -a --std=93 -fsynopsys <T80 sources> tb_t80_timing.vhd
--        ghdl -r --std=93 -fsynopsys tb_t80_timing
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_t80_timing is
end entity;

architecture sim of tb_t80_timing is

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal di      : std_logic_vector(7 downto 0) := (others => '0');
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

    type mem_t is array (0 to 255) of std_logic_vector(7 downto 0);

    -- Test program. Each entry is measured by the M1 that follows it, so the
    -- instructions are laid out to run straight through with no prefixes.
    signal mem : mem_t := (
        --   addr  bytes                        instruction        expected T
        16#00# => x"00",                     -- NOP                        4
        16#01# => x"3E", 16#02# => x"55",    -- LD A,$55                   7
        16#03# => x"06", 16#04# => x"AA",    -- LD B,$AA                   7
        16#05# => x"78",                     -- LD A,B                     4
        16#06# => x"3C",                     -- INC A                      4
        16#07# => x"80",                     -- ADD A,B                    4
        16#08# => x"21", 16#09# => x"80", 16#0A# => x"00", -- LD HL,$0080 10
        16#0B# => x"23",                     -- INC HL                     6
        16#0C# => x"09",                     -- ADD HL,BC                 11
        16#0D# => x"EB",                     -- EX DE,HL                   4
        16#0E# => x"07",                     -- RLCA                       4
        16#0F# => x"21", 16#10# => x"80", 16#11# => x"00", -- LD HL,$0080 10
        16#12# => x"77",                     -- LD (HL),A                  7
        16#13# => x"7E",                     -- LD A,(HL)                  7
        16#14# => x"31", 16#15# => x"F0", 16#16# => x"00", -- LD SP,$00F0 10
        16#17# => x"C5",                     -- PUSH BC                   11
        16#18# => x"C1",                     -- POP BC                    10
        16#19# => x"CD", 16#1A# => x"40", 16#1B# => x"00", -- CALL $0040  17
        16#1C# => x"CD", 16#1D# => x"40", 16#1E# => x"00", -- CALL $0040  17
        16#1F# => x"AF",                     -- XOR A  (sets Z=1)          4
        16#20# => x"CD", 16#21# => x"50", 16#22# => x"00", -- CALL $0050  17
        16#23# => x"CD", 16#24# => x"60", 16#25# => x"00", -- CALL $0060  17
        16#26# => x"18", 16#27# => x"02",    -- JR +2                     12
        16#2A# => x"00",                     -- NOP                        4
        16#2B# => x"C3", 16#2C# => x"2B", 16#2D# => x"00", -- JP $002B (park)

        16#40# => x"C9",                     -- RET                       10
        16#50# => x"C0",                     -- RET NZ (Z=1, not taken)    5
        16#51# => x"C9",                     -- RET                       10
        16#60# => x"C8",                     -- RET Z  (Z=1, taken)       11
        others => x"00"
    );

    type name_t  is array (0 to 28) of string(1 to 13);
    type ticks_t is array (0 to 28) of integer;

    constant NAMES : name_t := (
        "NOP          ", "LD A,n       ", "LD B,n       ",
        "LD A,B       ", "INC A        ", "ADD A,B      ",
        "LD HL,nn     ", "INC HL       ", "ADD HL,BC    ",
        "EX DE,HL     ", "RLCA         ", "LD HL,nn     ",
        "LD (HL),A    ", "LD A,(HL)    ", "LD SP,nn     ",
        "PUSH BC      ", "POP BC       ", "CALL nn      ",
        "RET          ", "CALL nn      ", "RET          ",
        "XOR A        ", "CALL nn      ", "RET NZ (nt)  ",
        "RET          ", "CALL nn      ", "RET Z (taken)",
        "JR e         ", "NOP          "
    );

    -- Published Z80 T-states for the sequence above.
    constant EXPECT : ticks_t := (
        4, 7, 7, 4, 4, 4, 10, 6, 11, 4, 4, 10, 7, 7, 10, 11, 10, 17, 10, 17, 10, 4, 17, 5, 10, 17, 11, 12, 4
    );

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

    -- Combinational read, registered write. WAIT_n is tied high, so the CPU
    -- never stalls and every measured gap is pure instruction timing.
    di <= mem(to_integer(unsigned(a(7 downto 0))));

    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if mreq_n = '0' and wr_n = '0' then
                mem(to_integer(unsigned(a(7 downto 0)))) <= do;
            end if;
        end if;
    end process;

    measure : process
        variable cycles   : integer := 0;
        variable last_m1  : integer := -1;
        variable idx      : integer := 0;
        variable m1_prev  : std_logic := '1';
        variable delta    : integer;
        variable ok       : integer := 0;
    begin
        report "T80 instruction cycle timing";

        -- hold reset, then release
        reset_n <= '0';
        for i in 0 to 7 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';

        loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            if m1_prev = '1' and m1_n = '0' then
                if last_m1 >= 0 then
                    delta := cycles - last_m1;
                    if idx <= NAMES'high then
                        if delta = EXPECT(idx) then
                            report "  ok    " & NAMES(idx) & " = " &
                                   integer'image(delta) & " T-states";
                            ok := ok + 1;
                        else
                            report "  FAIL  " & NAMES(idx) & " = " &
                                   integer'image(delta) & " T-states, expected " &
                                   integer'image(EXPECT(idx));
                            errors <= errors + 1;
                        end if;
                        idx := idx + 1;
                    end if;
                end if;
                last_m1 := cycles;
            end if;
            m1_prev := m1_n;

            exit when idx > NAMES'high;
            exit when cycles > 4000;   -- guard
        end loop;

        report "";
        if idx <= NAMES'high then
            report "FAIL  T80 cycle timing -- only " & integer'image(idx) &
                   " of " & integer'image(NAMES'length) & " instructions retired";
        elsif errors = 0 then
            report "PASS  T80 cycle timing matches the Z80 on all " &
                   integer'image(ok) & " instructions";
        else
            report "FAIL  T80 cycle timing -- " & integer'image(errors) &
                   " unexpected mismatch(es)";
        end if;

        running <= false;
        wait;
    end process;

end architecture;
