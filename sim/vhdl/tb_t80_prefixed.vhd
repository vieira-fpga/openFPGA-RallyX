--============================================================================
--  T80 instruction cycle timing -- prefixed opcodes.
--
--  tb_t80_timing measures M1 to M1 and so can only cover unprefixed opcodes: a
--  prefixed instruction asserts M1 twice, and the raw delta reports the prefix
--  and the opcode as if they were two instructions. That left the busiest half
--  of Rally-X's instruction mix unmeasured -- the ROM has 708 prefixed sites,
--  against 163 distinct unprefixed opcodes.
--
--  This bench closes that by tracking the prefix state instead of assuming one
--  M1 per instruction. An M1 starts a new instruction only when the previous
--  M1 did not fetch a prefix, so the two fetches of a prefixed instruction are
--  measured as one. The awkward case is DD CB d op: it fetches DD and CB with
--  M1, then reads the displacement and the opcode WITHOUT M1, so the
--  instruction ends at the next instruction's M1 like any other.
--
--  Expected values are the published Z80 timings. The instructions chosen are
--  the ones rallyx.rom actually executes -- LDIR, NEG, SBC HL, the IX/IY loads
--  and arithmetic, the CB bit operations, and one DD CB.
--
--  Same generics fpga_NRX ships (Mode=0, T2Write=0, IOWait=1).
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_t80_prefixed is
end entity;

architecture sim of tb_t80_prefixed is

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

    type mem_t is array (0 to 255) of std_logic_vector(7 downto 0);

    -- Writes land in $C0-$D3 (the LDIR buffers and the IX/IY scratch) and in
    -- $EE-$F1 (the stack and the (nn) slot). Nothing touches the program.
    signal mem : mem_t := (
        16#00# => x"ED", 16#01# => x"46",                     -- IM 0        8
        16#02# => x"31", 16#03# => x"F0", 16#04# => x"00",    -- LD SP,nn   10
        16#05# => x"21", 16#06# => x"C0", 16#07# => x"00",    -- LD HL,nn   10
        16#08# => x"11", 16#09# => x"D0", 16#0A# => x"00",    -- LD DE,nn   10
        16#0B# => x"01", 16#0C# => x"02", 16#0D# => x"00",    -- LD BC,2    10

        16#0E# => x"ED", 16#0F# => x"B0",                     -- LDIR    21/16

        16#10# => x"ED", 16#11# => x"44",                     -- NEG         8
        16#12# => x"ED", 16#13# => x"52",                     -- SBC HL,DE  15
        16#14# => x"ED", 16#15# => x"53", 16#16# => x"F0", 16#17# => x"00",
                                                              -- LD (nn),DE 20
        16#18# => x"ED", 16#19# => x"5B", 16#1A# => x"F0", 16#1B# => x"00",
                                                              -- LD DE,(nn) 20
        16#1C# => x"ED", 16#1D# => x"4B", 16#1E# => x"F0", 16#1F# => x"00",
                                                              -- LD BC,(nn) 20
        16#20# => x"ED", 16#21# => x"5F",                     -- LD A,R      9

        16#22# => x"CB", 16#23# => x"3F",                     -- SRL A       8
        16#24# => x"CB", 16#25# => x"7F",                     -- BIT 7,A     8
        16#26# => x"21", 16#27# => x"C0", 16#28# => x"00",    -- LD HL,nn   10
        16#29# => x"CB", 16#2A# => x"46",                     -- BIT 0,(HL) 12
        16#2B# => x"CB", 16#2C# => x"86",                     -- RES 0,(HL) 15
        16#2D# => x"CB", 16#2E# => x"16",                     -- RL (HL)    15

        16#2F# => x"DD", 16#30# => x"21", 16#31# => x"C0", 16#32# => x"00",
                                                              -- LD IX,nn   14
        16#33# => x"DD", 16#34# => x"7E", 16#35# => x"00",    -- LD A,(IX+0) 19
        16#36# => x"DD", 16#37# => x"77", 16#38# => x"01",    -- LD (IX+1),A 19
        16#39# => x"DD", 16#3A# => x"36", 16#3B# => x"02", 16#3C# => x"5A",
                                                              -- LD (IX+2),n 19
        16#3D# => x"DD", 16#3E# => x"34", 16#3F# => x"02",    -- INC (IX+2)  23
        16#40# => x"DD", 16#41# => x"19",                     -- ADD IX,DE   15
        16#42# => x"DD", 16#43# => x"23",                     -- INC IX      10
        16#44# => x"DD", 16#45# => x"E5",                     -- PUSH IX     15
        16#46# => x"DD", 16#47# => x"E1",                     -- POP IX      14
        16#48# => x"DD", 16#49# => x"2A", 16#4A# => x"F0", 16#4B# => x"00",
                                                              -- LD IX,(nn)  20
        16#4C# => x"DD", 16#4D# => x"86", 16#4E# => x"00",    -- ADD A,(IX+0)19
        16#4F# => x"DD", 16#50# => x"CB", 16#51# => x"00", 16#52# => x"06",
                                                              -- RLC (IX+0)  23

        16#53# => x"FD", 16#54# => x"21", 16#55# => x"C0", 16#56# => x"00",
                                                              -- LD IY,nn    14
        16#57# => x"FD", 16#58# => x"7E", 16#59# => x"00",    -- LD A,(IY+0) 19

        16#5A# => x"00",                                      -- NOP          4
        16#5B# => x"C3", 16#5C# => x"5B", 16#5D# => x"00",    -- JP $5B (park)

        -- LDIR source data
        16#C0# => x"11", 16#C1# => x"22",
        others => x"00"
    );

    constant N : integer := 33;

    type name_t  is array (0 to N) of string(1 to 14);
    type ticks_t is array (0 to N) of integer;

    constant NAMES : name_t := (
        "IM 0          ", "LD SP,nn      ", "LD HL,nn      ",
        "LD DE,nn      ", "LD BC,nn      ", "LDIR (repeat) ",
        "LDIR (final)  ", "NEG           ", "SBC HL,DE     ",
        "LD (nn),DE    ", "LD DE,(nn)    ", "LD BC,(nn)    ",
        "LD A,R        ", "SRL A         ", "BIT 7,A       ",
        "LD HL,nn      ", "BIT 0,(HL)    ", "RES 0,(HL)    ",
        "RL (HL)       ", "LD IX,nn      ", "LD A,(IX+d)   ",
        "LD (IX+d),A   ", "LD (IX+d),n   ", "INC (IX+d)    ",
        "ADD IX,DE     ", "INC IX        ", "PUSH IX       ",
        "POP IX        ", "LD IX,(nn)    ", "ADD A,(IX+d)  ",
        "RLC (IX+d)    ", "LD IY,nn      ", "LD A,(IY+d)   ",
        "NOP           "
    );

    -- Published Z80 T-states.
    constant EXPECT : ticks_t := (
        8, 10, 10, 10, 10, 21, 16, 8, 15, 20, 20, 20, 9, 8, 8, 10, 12, 15, 15,
        14, 19, 19, 19, 23, 15, 10, 15, 14, 20, 19, 23, 14, 19, 4
    );

    -- No characterised deviations here yet. Kept so a real one can be recorded
    -- the way tb_t80_timing records its RET, rather than deleting the check.
    constant ALLOW : ticks_t := (
        8, 10, 10, 10, 10, 21, 16, 8, 15, 20, 20, 20, 9, 8, 8, 10, 12, 15, 15,
        14, 19, 19, 19, 23, 15, 10, 15, 14, 20, 19, 23, 14, 19, 4
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
        variable cycles     : integer := 0;
        variable m1_prev    : std_logic := '1';
        variable start_at   : integer := -1;
        variable idx        : integer := 0;
        variable delta      : integer;
        variable ok_n       : integer := 0;
        variable devs       : integer := 0;
        -- 0 = next M1 starts an instruction
        -- 1 = previous M1 fetched DD/FD
        -- 2 = previous M1 fetched CB/ED
        variable state      : integer := 0;
        variable want_byte  : boolean := false;
        variable op         : std_logic_vector(7 downto 0);
    begin
        report "T80 prefixed instruction cycle timing";

        reset_n <= '0';
        for i in 0 to 7 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';

        loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- An M1 falling edge only ends the previous instruction when the
            -- previous M1 was not a prefix.
            if m1_prev = '1' and m1_n = '0' then
                if state = 0 then
                    if start_at >= 0 and idx <= N then
                        delta := cycles - start_at;
                        if delta = EXPECT(idx) then
                            report "  ok    " & NAMES(idx) & " = " &
                                   integer'image(delta) & " T-states";
                            ok_n := ok_n + 1;
                        elsif delta = ALLOW(idx) then
                            report "  DEV   " & NAMES(idx) & " = " &
                                   integer'image(delta) & " T-states, Z80 is " &
                                   integer'image(EXPECT(idx)) &
                                   "  (known T80 deviation)";
                            devs := devs + 1;
                        else
                            report "  FAIL  " & NAMES(idx) & " = " &
                                   integer'image(delta) & " T-states, expected " &
                                   integer'image(EXPECT(idx));
                            errors <= errors + 1;
                        end if;
                        idx := idx + 1;
                    end if;
                    start_at := cycles;
                end if;
                want_byte := true;
            end if;
            m1_prev := m1_n;

            -- the opcode is on the bus during the fetch itself
            if want_byte and m1_n = '0' and mreq_n = '0' and rd_n = '0' then
                op := di;
                want_byte := false;
                case state is
                    when 0 =>
                        if op = x"DD" or op = x"FD" then
                            state := 1;
                        elsif op = x"CB" or op = x"ED" then
                            state := 2;
                        else
                            state := 0;
                        end if;
                    when 1 =>
                        -- DD CB fetches nothing else with M1, and a repeated
                        -- DD/FD just replaces the index prefix.
                        if op = x"DD" or op = x"FD" then
                            state := 1;
                        else
                            state := 0;
                        end if;
                    when others =>
                        state := 0;
                end case;
            end if;

            exit when idx > N;
            exit when cycles > 6000;
        end loop;

        report "";
        if idx <= N then
            report "FAIL  T80 prefixed timing -- only " & integer'image(idx) &
                   " of " & integer'image(N + 1) & " instructions retired";
        elsif errors = 0 and devs = 0 then
            report "PASS  T80 prefixed timing matches the Z80 on all " &
                   integer'image(ok_n) & " instructions";
        elsif errors = 0 then
            report "PASS  T80 prefixed timing: " & integer'image(ok_n) &
                   " match the Z80, " & integer'image(devs) &
                   " known deviation(s)";
        else
            report "FAIL  T80 prefixed timing -- " & integer'image(errors) &
                   " unexpected mismatch(es)";
        end if;

        running <= false;
        wait;
    end process;

end architecture;
