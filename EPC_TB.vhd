--------------------------------------------------------------------------------
-- tb_epc.vhd - acceptance testbench for the EPC / interrupt-flush fix
--
-- Runs epc_test.asm (ITCM.hex / DTCM.hex) on the MCU while driving a
-- continuous stream of KEY1 interrupts, so interrupts land in every kind of
-- pipeline state: straight-line code, taken branches, jumps and load-use
-- stalls.
--
-- The program counts iterations of four workload shapes with exact expected
-- totals, checks them itself, and reports the verdict on LEDR:
--
--     LEDR = 0x5A          all four counts exact  -> PASS
--     LEDR = 0xE0 | mask   mask bit n set => phase n+1 wrong
--         bit 0  P1 straight-line   (expected 100)
--         bit 1  P2 branch-dense    (expected 200)
--         bit 2  P3 load-use stalls (expected 50)
--         bit 3  P4 jump loop       (expected 100)
--
-- A low count means an instruction was lost (EPC named something younger than
-- the oldest flushed instruction); a high count means one was duplicated
-- (EPC named something older).
--
-- Raw counters are also written to data memory for inspection:
--     word 16 (0x40) = P1 count    word 19 (0x4C) = P4 count
--     word 17 (0x44) = P2 count    word 20 (0x50) = interrupts serviced
--     word 18 (0x48) = P3 count
--
-- NOTE for simulation: reduce DIVIDE_FACTOR in the CLOCK_DIVIDER *component
-- declaration* in aux_package.vhd. MCU.vhd instantiates without a generic map,
-- so the component default is what takes effect, not the entity default.
--------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.cond_compilation_package.ALL;
USE work.aux_package.ALL;

ENTITY tb_epc IS
END tb_epc;

ARCHITECTURE behavior OF tb_epc IS

  constant CLK_HALF : time := 50 ns;    -- 10 MHz
  constant KEY_LOW  : time := 1 us;     -- KEY1 held down
  constant KEY_HIGH : time := 2 us;     -- KEY1 released
  constant TIMEOUT  : time := 5 ms;     -- give up if the program never finishes

  constant PASS_CODE : integer := 16#5A#;

  signal clock   : std_logic := '0';
  signal reset   : std_logic := '1';
  signal ena     : std_logic := '1';
  signal HEX0, HEX1, HEX2 : std_logic_vector(6 downto 0);
  signal HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
  signal LEDR    : std_logic_vector(7 downto 0);
  signal Switches: std_logic_vector(7 downto 0) := x"00";
  signal BTOUT   : std_logic;
  signal KEY1    : std_logic := '1';    -- active low
  signal KEY2    : std_logic := '1';
  signal KEY3    : std_logic := '1';
  signal UART_RX : std_logic := '1';
  signal UART_TX : std_logic;

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

  signal running  : boolean := true;
  signal key_hits : natural := 0;       -- driven only by key_gen

BEGIN

  ------------------------------------------------------------------ clock
  clk_gen : process
  begin
    while running loop
      clock <= '0'; wait for CLK_HALF;
      clock <= '1'; wait for CLK_HALF;
    end loop;
    wait;
  end process;

  ------------------------------------------------------------------ DUT
  U_MCU : entity work.MCU
    GENERIC MAP (MemWidth => 8, SIM => TRUE, IrqSize => 8)
    PORT MAP (
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

  ------------------------------------------------------------------ interrupts
  -- Free-running KEY1 presses. The phase relative to the instruction stream
  -- drifts, so interrupts land in every pipeline state over a full run.
  key_gen : process
  begin
    KEY1 <= '1';
    wait until reset = '0';
    wait for 15 us;                      -- let main enable GIE first
    while running loop
      KEY1 <= '0';
      key_hits <= key_hits + 1;
      wait for KEY_LOW;
      KEY1 <= '1';
      wait for KEY_HIGH;
    end loop;
    wait;
  end process;

  ------------------------------------------------------------------ checker
  stim : process
    variable code : integer;
    variable mask : integer;
  begin
    report "===== EPC / interrupt-flush testbench start =====" severity note;

    reset <= '1';
    wait for 300 ns;
    reset <= '0';

    -- wait for the program to publish its verdict on LEDR
    wait until LEDR /= x"00" for TIMEOUT;

    if LEDR = x"00" then
      report "RESULT: FAIL - timed out, program never reported a verdict"
        severity error;
    else
      wait for 1 us;                     -- let the value settle
      code := to_integer(unsigned(LEDR));
      report "LEDR verdict (decimal) = " & integer'image(code) &
             "   [90 = 0x5A = pass]" severity note;
      report "KEY1 presses issued = " & integer'image(key_hits) severity note;

      if code = PASS_CODE then
        report "P1 straight-line   : 100  OK" severity note;
        report "P2 branch-dense    : 200  OK" severity note;
        report "P3 load-use stalls :  50  OK" severity note;
        report "P4 jump loop       : 100  OK" severity note;
        report "RESULT: PASS - no instruction lost or duplicated" severity note;
      else
        mask := code mod 16;
        if (mask / 1) mod 2 = 1 then
          report "FAIL P1 straight-line count wrong (expected 100)" severity error;
        end if;
        if (mask / 2) mod 2 = 1 then
          report "FAIL P2 branch-dense count wrong (expected 200)" severity error;
        end if;
        if (mask / 4) mod 2 = 1 then
          report "FAIL P3 load-use count wrong (expected 50)" severity error;
        end if;
        if (mask / 8) mod 2 = 1 then
          report "FAIL P4 jump-loop count wrong (expected 100)" severity error;
        end if;
        report "RESULT: FAIL - check data memory words 16..19 for the counts"
          severity error;
      end if;
    end if;

    report "===== EPC testbench done =====" severity note;
    running <= false;
    wait;
  end process;

END behavior;