--============================================================================
--  T80 interrupt acknowledge, mode 0.
--
--  Rally-X runs in interrupt mode 0 -- `ED 46` appears in the ROM, `ED 56` and
--  `ED 5E` do not. In mode 0 the CPU does not read a vector table: it latches
--  whatever byte is on the data bus during the acknowledge cycle and executes
--  it as an instruction. fpga_nrx.v drives that byte itself --
--
--      wire [7:0] irqv = ( (~m1) & (~ie) ) ? intv : 8'h00;
--
--  -- where intv is whatever the game last wrote with OUT. So the frame
--  interrupt only works if T80 asserts M1 and IORQ together, takes the byte
--  from the bus, and executes it. That handshake is glue we own and the timing
--  bench never touched it: tb_t80_timing ties INT_n high.
--
--  The memory model here mirrors fpga_nrx's data bus selector, vector included,
--  so what is under test is the arrangement the bitstream actually ships.
--
--  Method: hold INT_n low from reset and watch one interrupt all the way
--  through -- when it is accepted, where it vectors, what it stacked, how long
--  it took, and that it does not fire twice.
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_t80_interrupt is
end entity;

architecture sim of tb_t80_interrupt is

    signal clk     : std_logic := '0';
    signal reset_n : std_logic := '0';
    signal int_n   : std_logic := '1';
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

    -- The byte the game would have written with OUT. RST 30h, so a correct
    -- mode 0 acknowledge lands the CPU on $0030.
    constant VECTOR : std_logic_vector(7 downto 0) := x"F7";

    constant HANDLER   : integer := 16#30#;
    constant STACK_TOP : integer := 16#F0#;

    -- Where the interrupt must be taken. EI at $0005 does not open the window
    -- until the instruction after it retires, so the NOP at $0006 runs and the
    -- fetch that gets pre-empted is $0007.
    constant LAST_FETCH_EXPECT : integer := 16#06#;
    constant RETURN_EXPECT     : integer := 16#07#;

    -- Z80 mode 0 acknowledge with an RST on the bus: a 4T opcode fetch with two
    -- wait states, then the two stack writes. 13 T-states, M1 to M1.
    constant ACK_T_EXPECT : integer := 13;

    type mem_t is array (0 to 255) of std_logic_vector(7 downto 0);

    signal mem : mem_t := (
        16#00# => x"ED", 16#01# => x"46",                   -- IM 0
        16#02# => x"31", 16#03# => x"F0", 16#04# => x"00",  -- LD SP,$00F0
        16#05# => x"FB",                                    -- EI
        16#06# => x"00",                                    -- NOP   (EI shadow)
        16#07# => x"00",                                    -- NOP   (pre-empted)
        16#08# => x"18", 16#09# => x"FE",                   -- JR $  (park)

        -- RST 30h handler. No EI, so a second interrupt must not be accepted.
        16#30# => x"3E", 16#31# => x"5A",                   -- LD A,$5A
        16#32# => x"C9",                                    -- RET
        others => x"00"
    );

    -- Acknowledge is M1 and IORQ together -- exactly what fpga_nrx decodes.
    signal intack : std_logic;

    signal errors : integer := 0;

begin

    clk <= not clk after 5 ns when running else '0';

    cpu : entity work.T80s
        generic map (Mode => 0, T2Write => 0, IOWait => 1)
        port map (
            RESET_n => reset_n, CLK => clk, WAIT_n => '1',
            INT_n   => int_n, NMI_n => '1', BUSRQ_n => '1',
            DI      => di,
            M1_n    => m1_n, MREQ_n => mreq_n, IORQ_n => iorq_n,
            RD_n    => rd_n, WR_n => wr_n, RFSH_n => rfsh_n,
            HALT_n  => halt_n, BUSAK_n => busak_n,
            A       => a, DO => do
        );

    intack <= '1' when (m1_n = '0' and iorq_n = '0') else '0';

    -- The vector wins the bus during acknowledge, memory otherwise. This is
    -- fpga_nrx's selector in miniature.
    di <= VECTOR when intack = '1'
          else mem(to_integer(unsigned(a(7 downto 0))));

    write_proc : process(clk)
    begin
        if rising_edge(clk) then
            if mreq_n = '0' and wr_n = '0' then
                mem(to_integer(unsigned(a(7 downto 0)))) <= do;
            end if;
        end if;
    end process;

    watch : process
        variable cycles     : integer := 0;
        variable m1_prev    : std_logic := '1';
        variable m1_start   : integer := 0;
        variable started    : boolean := false;
        variable this_is_ack: boolean := false;
        variable ack_start  : integer := -1;
        variable ack_count  : integer := 0;
        variable ack_t      : integer := -1;
        variable last_fetch : integer := -1;
        variable fetch_before_ack : integer := -1;
        variable after_addr : integer := -1;
        variable ret_lo     : integer := -1;
        variable ret_hi     : integer := -1;

        procedure check_i(what : string; got : integer; want : integer) is
        begin
            if got = want then
                report "  ok    " & what & " = " & integer'image(got);
            else
                report "  FAIL  " & what & " = " & integer'image(got) &
                       ", expected " & integer'image(want);
                errors <= errors + 1;
            end if;
        end procedure;

    begin
        report "T80 interrupt acknowledge (mode 0)";

        reset_n <= '0';
        for i in 0 to 7 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';

        -- Held low for the whole run: one interrupt must be taken, and exactly
        -- one, because accepting it clears IFF1 and the handler never sets it.
        int_n <= '0';

        loop
            wait until rising_edge(clk);
            cycles := cycles + 1;

            -- start of an M1 cycle
            if m1_prev = '1' and m1_n = '0' then
                if started and this_is_ack and ack_t < 0 then
                    ack_t := cycles - ack_start;
                end if;
                m1_start := cycles;
                this_is_ack := false;
                started := true;
            end if;
            m1_prev := m1_n;

            -- acknowledge seen inside the current M1
            if intack = '1' and not this_is_ack then
                this_is_ack := true;
                ack_count := ack_count + 1;
                ack_start := m1_start;
                fetch_before_ack := last_fetch;
            end if;

            -- normal opcode fetch: M1 with memory, not with IORQ
            if m1_n = '0' and mreq_n = '0' and rd_n = '0' then
                last_fetch := to_integer(unsigned(a));
                if ack_count > 0 and after_addr < 0 then
                    after_addr := to_integer(unsigned(a));
                end if;
            end if;

            exit when cycles > 800;
        end loop;

        ret_lo := to_integer(unsigned(mem(STACK_TOP - 2)));
        ret_hi := to_integer(unsigned(mem(STACK_TOP - 1)));

        -- 1. the handshake itself
        check_i("acknowledge cycles (M1 + IORQ)", ack_count, 1);

        -- 2. EI opens the window one instruction late
        check_i("last fetch before acknowledge", fetch_before_ack,
                LAST_FETCH_EXPECT);

        -- 3. the bus byte was executed, not a vector table entry
        check_i("vectored to (RST 30h from the bus)", after_addr, HANDLER);

        -- 4. the pre-empted address was stacked
        check_i("stacked return address low", ret_lo, RETURN_EXPECT);
        check_i("stacked return address high", ret_hi, 0);

        -- 5. published Z80 cost of a mode 0 acknowledge with RST
        if ack_t = ACK_T_EXPECT then
            report "  ok    acknowledge = " & integer'image(ack_t) &
                   " T-states";
        else
            report "  FAIL  acknowledge = " & integer'image(ack_t) &
                   " T-states, expected " & integer'image(ACK_T_EXPECT);
            errors <= errors + 1;
        end if;

        wait for 1 ns;
        report "";
        if errors = 0 then
            report "PASS  T80 mode 0 interrupt acknowledge";
        else
            report "FAIL  T80 mode 0 interrupt acknowledge -- " &
                   integer'image(errors) & " mismatch(es)";
        end if;

        running <= false;
        wait;
    end process;

end architecture;
