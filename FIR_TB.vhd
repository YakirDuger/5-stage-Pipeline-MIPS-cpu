-------------------------------------------------------------------------------
-- tb_fir.vhd  --  self-checking end-to-end testbench for test_fir.asm
--
-- Runs the MCU with ITCM.hex / DTCM.hex built from test_fir.asm and checks the
-- FIR accelerator's output stream against the reference response.
--
--   h = { 16, 32, 48, 64, 48, 32, 16, 0 } / 256   (unity DC gain)
--   x = { 1000, 0, 0, 0, 2000, 2000, 2000, 2000 }
--   y = {   62, 125, 187, 250,  312,  500,  812, 1250 }
--
-- The primary checks look only at the FIR datapath, so they pass or fail
-- independently of the interrupt subsystem.  Interrupt delivery is checked
-- separately and reported as INFO, because a failure there is a CPU/interrupt
-- bug, not a filter bug.
--
--   ghdl -a --std=93c -fsynopsys -fexplicit tb_fir.vhd
--   ghdl -e --std=93c -fsynopsys -fexplicit tb_fir
--   ghdl -r --std=93c -fsynopsys -fexplicit tb_fir
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_fir is
    generic (
        CLK_PERIOD : time    := 100 ns;   -- 10 MHz
        TIMEOUT    : time    := 80 ms;    -- see note on CLOCK_DIVIDER below
        NSAMP      : integer := 8
    );
end tb_fir;

architecture behavior of tb_fir is

    signal clock    : std_logic := '0';
    signal reset    : std_logic := '1';
    signal ena      : std_logic := '1';
    signal sim_done : boolean   := false;

    signal HEX0, HEX1, HEX2 : std_logic_vector(6 downto 0);
    signal HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal LEDR     : std_logic_vector(7 downto 0);
    signal Switches : std_logic_vector(7 downto 0) := x"00";
    signal BTOUT    : std_logic;
    signal KEY1, KEY2, KEY3 : std_logic := '1';   -- active low, released
    signal UART_RX  : std_logic := '1';
    signal UART_TX  : std_logic;

    signal DBG_FIFO_COUNT   : std_logic_vector(4 downto 0);
    signal DBG_FIFO_EMPTY   : std_logic;
    signal DBG_FIFO_FULL    : std_logic;
    signal DBG_W_PTR        : std_logic_vector(3 downto 0);
    signal DBG_R_PTR        : std_logic_vector(3 downto 0);
    signal DBG_PENDING_REQ  : std_logic;
    signal DBG_REQ_TOG_FIR  : std_logic;
    signal DBG_ACK_TOG_FIFO : std_logic;
    signal DBG_OUTSTANDING  : std_logic;
    signal DBG_SAMPLE_VALID : std_logic;
    signal DBG_Y_VALID_R    : std_logic;
    signal DBG_FIFO_DATA    : std_logic_vector(23 downto 0);
    signal DBG_Y_OUTPUT     : std_logic_vector(23 downto 0);

    type int_array is array (natural range <>) of integer;
    constant Y_EXPECTED : int_array(0 to 7) :=
        (62, 125, 187, 250, 312, 500, 812, 1250);

    -- scoreboard
    signal pass_cnt   : integer := 0;
    signal fail_cnt   : integer := 0;
    signal got_cnt    : integer := 0;
    signal ledr_writes: integer := 0;
    signal all_done   : boolean := false;

    function slv2int(v : std_logic_vector) return integer is
        variable u : unsigned(v'length-1 downto 0);
    begin
        for i in v'range loop
            if v(i) /= '0' and v(i) /= '1' then
                return -1;              -- contains X/U
            end if;
        end loop;
        u := unsigned(v);
        return to_integer(u);
    end function;

begin

    ---------------------------------------------------------------------
    -- Clock / reset
    ---------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clock <= '0'; wait for CLK_PERIOD/2;
            clock <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    rst_gen : process
    begin
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';
        wait;
    end process;

    ---------------------------------------------------------------------
    -- DUT.  SIM => TRUE makes resetSim active-high inside MCU and selects
    -- the 8-bit ITCM address slice in IFETCH.
    ---------------------------------------------------------------------
    DUT : entity work.MCU
        generic map (MemWidth => 8, SIM => TRUE)
        port map (
            reset => reset, clock => clock, ena => ena,
            HEX0 => HEX0, HEX1 => HEX1, HEX2 => HEX2,
            HEX3 => HEX3, HEX4 => HEX4, HEX5 => HEX5,
            LEDR => LEDR, Switches => Switches, BTOUT => BTOUT,
            KEY1 => KEY1, KEY2 => KEY2, KEY3 => KEY3,
            UART_RX => UART_RX, UART_TX => UART_TX,
            DEBUG_FIFO_COUNT1   => DBG_FIFO_COUNT,
            DEBUG_FIFO_EMPTY1   => DBG_FIFO_EMPTY,
            DEBUG_FIFO_FULL1    => DBG_FIFO_FULL,
            DEBUG_W_PTR1        => DBG_W_PTR,
            DEBUG_R_PTR1        => DBG_R_PTR,
            DEBUG_PENDING_REQ1  => DBG_PENDING_REQ,
            DEBUG_REQ_TOG_FIR1  => DBG_REQ_TOG_FIR,
            DEBUG_ACK_TOG_FIFO1 => DBG_ACK_TOG_FIFO,
            DEBUG_OUTSTANDING1  => DBG_OUTSTANDING,
            DEBUG_SAMPLE_VALID1 => DBG_SAMPLE_VALID,
            DEBUG_Y_VALID_R1    => DBG_Y_VALID_R,
            DEBUG_FIFO_DATA1    => DBG_FIFO_DATA,
            DEBUG_Y_OUTPUT1     => DBG_Y_OUTPUT
        );

    ---------------------------------------------------------------------
    -- CHECK GROUP 1 : FIR output stream
    --
    -- y_output is loaded on the FIRCLK edge *after* y_valid_r asserts, so the
    -- value is sampled once y_valid_r has fallen again.
    ---------------------------------------------------------------------
    checker : process
        variable got : integer;
        variable n   : integer := 0;
    begin
        wait until reset = '0';

        for n in 0 to NSAMP-1 loop
            wait until falling_edge(DBG_Y_VALID_R);
            wait for CLK_PERIOD;              -- let y_output settle
            got := slv2int(DBG_Y_OUTPUT);
            got_cnt <= n + 1;

            if got = Y_EXPECTED(n) then
                pass_cnt <= pass_cnt + 1;
                report "PASS  y[" & integer'image(n) & "] = "
                     & integer'image(got) severity note;
            elsif got < 0 then
                fail_cnt <= fail_cnt + 1;
                report "FAIL  y[" & integer'image(n)
                     & "] contains X/U (expected "
                     & integer'image(Y_EXPECTED(n)) & ")" severity error;
            else
                fail_cnt <= fail_cnt + 1;
                report "FAIL  y[" & integer'image(n) & "] = "
                     & integer'image(got) & "  expected "
                     & integer'image(Y_EXPECTED(n)) severity error;
            end if;
            wait for 0 ns;
        end loop;

        all_done <= true;
        wait;
    end process;

    ---------------------------------------------------------------------
    -- CHECK GROUP 2 : interrupt delivery (informational)
    --
    -- FIR_ISR writes the low byte of y[n] to the LEDs.  If LEDR never moves,
    -- the filter ran but no interrupt reached the CPU.
    ---------------------------------------------------------------------
    ledr_mon : process(LEDR)
    begin
        if reset = '0' and now > 1 us then
            ledr_writes <= ledr_writes + 1;
            report "INFO  LEDR <- " & integer'image(slv2int(LEDR))
                 & "  at " & time'image(now) severity note;
        end if;
    end process;

    ---------------------------------------------------------------------
    -- Progress monitor
    ---------------------------------------------------------------------
    monitor : process
    begin
        wait until reset = '0';
        while not sim_done loop
            wait for TIMEOUT / 40;
            report "t=" & time'image(now)
                 & " | got="        & integer'image(got_cnt) & "/"
                                    & integer'image(NSAMP)
                 & " | FIFO_CNT="   & integer'image(slv2int(DBG_FIFO_COUNT))
                 & " | EMPTY="      & std_logic'image(DBG_FIFO_EMPTY)
                 & " | FULL="       & std_logic'image(DBG_FIFO_FULL)
                 & " | OUTSTANDING="& std_logic'image(DBG_OUTSTANDING)
                 & " | Y_OUT="      & integer'image(slv2int(DBG_Y_OUTPUT))
                 severity note;
        end loop;
        wait;
    end process;

    ---------------------------------------------------------------------
    -- Verdict + watchdog
    ---------------------------------------------------------------------
    verdict : process
        variable timed_out : boolean := false;
    begin
        wait until reset = '0';
        while (not all_done) and (now < TIMEOUT) loop
            wait for CLK_PERIOD * 100;
        end loop;
        timed_out := not all_done;

        report "==================================================" severity note;
        report "  FIR end-to-end test" severity note;
        report "    outputs observed : " & integer'image(got_cnt)
             & " of " & integer'image(NSAMP) severity note;
        report "    passed           : " & integer'image(pass_cnt) severity note;
        report "    failed           : " & integer'image(fail_cnt) severity note;
        report "    LEDR writes      : " & integer'image(ledr_writes)
             & "   (0 => FIR interrupt never reached the CPU)" severity note;
        if timed_out then
            report "    TIMED OUT after " & time'image(TIMEOUT) severity note;
        end if;
        report "==================================================" severity note;

        sim_done <= true;
        wait for CLK_PERIOD;

        if timed_out then
            report "TEST FAILED - timeout, only "
                 & integer'image(got_cnt) & " of " & integer'image(NSAMP)
                 & " outputs seen" severity failure;
        elsif fail_cnt /= 0 then
            report "TEST FAILED - " & integer'image(fail_cnt)
                 & " mismatched output(s)" severity failure;
        else
            report "TEST PASSED - all " & integer'image(NSAMP)
                 & " FIR outputs correct" severity note;
        end if;
        wait;
    end process;

end behavior;