-------------------------------------------------------------------------------
-- tb_cpu.vhd  --  stimulus-only testbench for the co-simulation CPU test
--
-- Deliberately has NO checks.  Its only job is to reset the MCU, let
-- test_cpu.asm run to its idle loop, and stop.  All checking happens
-- afterwards by diffing the trace files against the golden model:
--
--     python3 compare.py golden.reg.trace rtl.reg.trace
--     python3 compare.py golden.mem.trace rtl.mem.trace
--
-- Requires retire_tracer.vhd to be instantiated inside MIPS.vhd, otherwise
-- no trace files are produced.
--
-- Load ITCM.hex / DTCM.hex built from test_cpu.asm before running.
--
--   ghdl:      ghdl -a --std=93c -fsynopsys -fexplicit tb_cpu.vhd
--              ghdl -e --std=93c -fsynopsys -fexplicit tb_cpu
--              ghdl -r --std=93c -fsynopsys -fexplicit tb_cpu --ieee-asserts=disable
--   ModelSim:  vcom -93 tb_cpu.vhd ; vsim -t ps work.tb_cpu ; run 45 us
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity tb_cpu is
    generic (
        CLK_PERIOD : time    := 100 ns;   -- 10 MHz
        RUN_CYCLES : integer := 400       -- test_cpu.asm needs ~120; 400 is slack
    );
end tb_cpu;

architecture behavior of tb_cpu is

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

    -- FIR debug ports: unused here, but the port map must be complete
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

begin

    ---------------------------------------------------------------------
    -- Clock.  Stops on sim_done so the run terminates by itself.
    ---------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clock <= '0'; wait for CLK_PERIOD/2;
            clock <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    ---------------------------------------------------------------------
    -- DUT.  MemWidth => 8 is required with SIM => TRUE: the SIM branch in
    -- IFETCH drives Mem_Addr from PC(9 downto 2), which is 8 bits wide.
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
    -- Reset, run, stop.
    ---------------------------------------------------------------------
    stim : process
    begin
        reset <= '1';
        wait for 5 * CLK_PERIOD;
        reset <= '0';

        wait for RUN_CYCLES * CLK_PERIOD;

        report "tb_cpu: run complete after " & integer'image(RUN_CYCLES)
             & " cycles - now diff rtl.reg.trace / rtl.mem.trace "
             & "against the golden traces" severity note;

        sim_done <= true;
        wait for CLK_PERIOD;
        wait;
    end process;

end behavior;