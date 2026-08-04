LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.aux_package.all;

-- =============================================================================
-- BTIMER: Configurable 32-bit Timer with PWM Output and Interrupt Capability
-- =============================================================================
-- Features:
--   * Configurable clock division (1x, 2x, 4x, 8x)
--   * Two PWM modes: set/reset and reset/set
--   * Automatic compare register transfer
--   * Multiple interrupt sources (HEU0, Q24, Q28, Q32)
--   * Forced overflow reset for continuous operation
-- =============================================================================
ENTITY BTIMER IS
    GENERIC (
        CLOCK_DIV_WIDTH : integer := 4;  -- Width of clock divider counter (supports up to div/16)
        TIMER_WIDTH     : integer := 32   -- Width of timer counter (32-bit for large count range)
    );
    PORT(
        mclk_i : IN STD_LOGIC;                                    -- Master clock input (system clock)
        rst_i : IN STD_LOGIC;                                      -- Active-high reset (synchronous)
        BTCTL : IN STD_LOGIC_VECTOR(7 DOWNTO 0);                  -- Timer control register
        BTCCR0 : IN STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);     -- Compare register 0 (period)
        BTCCR1 : IN STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);     -- Compare register 1 (duty cycle)
        BTCNT : INOUT STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);   -- Timer counter (read/write)

        PWMout : OUT STD_LOGIC;                                    -- PWM output signal
        BTIFG : OUT STD_LOGIC                                      -- Timer interrupt flag
    );
END BTIMER;

-- =============================================================================
-- ARCHITECTURE: Timer Implementation with Clock Division, PWM, and Interrupts
-- =============================================================================
ARCHITECTURE behavior OF BTIMER IS
    -- Internal compare register latches (auto-transferred from BTCCRx when BTCNT=0)
    -- These hold the actual compare values used during timer operation
    SIGNAL BTCL0 : STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0) := (TIMER_WIDTH-1 DOWNTO 0 => '0'); -- Period latch
    SIGNAL BTCL1 : STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0) := (TIMER_WIDTH-1 DOWNTO 0 => '0'); -- Duty cycle latch
    
    -- Clock division system: generates slower clock for timer counting
    SIGNAL clock_div : STD_LOGIC_VECTOR(CLOCK_DIV_WIDTH-1 DOWNTO 0); -- Division factor (1,2,4,8)
    SIGNAL clk_counter : STD_LOGIC_VECTOR(CLOCK_DIV_WIDTH-1 DOWNTO 0) := (CLOCK_DIV_WIDTH-1 DOWNTO 0 => '0'); -- Division counter
    SIGNAL clk : STD_LOGIC; -- Divided clock output (single pulse per division cycle)
    
    -- Control signals decoded from BTCTL register for cleaner code
    SIGNAL BTOUTMD : STD_LOGIC; -- Timer output mode (0: set/reset, 1: reset/set)
    SIGNAL BTOUTEN : STD_LOGIC; -- Timer output enable (0: disabled, 1: enabled)
    SIGNAL BTHOLD : STD_LOGIC;  -- Timer hold mode (0: run, 1: pause)
    SIGNAL BTSSEL : STD_LOGIC_VECTOR(1 DOWNTO 0); -- Clock source selection (00:1x, 01:2x, 10:4x, 11:8x)
    SIGNAL BTCLR : STD_LOGIC;   -- Timer clear signal (1: reset counter to 0)
    SIGNAL BTIP : STD_LOGIC_VECTOR(1 DOWNTO 0);   -- Interrupt source priority
    
    -- PWM and interrupt generation signals
    SIGNAL pwm_output : STD_LOGIC; -- Internal PWM signal before output enable
    SIGNAL interrupt_flag : STD_LOGIC; -- Internal interrupt flag before output
    SIGNAL HEU0 : STD_LOGIC; -- Hardware Event Unit signal (period end indicator)
    
    -- Specific bit interrupt sources from BTCNT for periodic interrupts
    -- These provide interrupts at specific count values for timing applications
    SIGNAL Q24 : STD_LOGIC; -- BTCNT bit 24 (interrupt at count 2^24)
    SIGNAL Q28 : STD_LOGIC; -- BTCNT bit 28 (interrupt at count 2^28)
    SIGNAL Q32 : STD_LOGIC; -- BTCNT bit 31 (interrupt at count 2^31, MSB)
    
BEGIN
    -- =============================================================================
    -- CONTROL SIGNAL DECODING: Extract control bits from BTCTL register
    -- =============================================================================
    BTOUTMD <= BTCTL(7); -- Bit 7: PWM mode selection
    BTOUTEN <= BTCTL(6); -- Bit 6: Output enable control
    BTHOLD  <= BTCTL(5); -- Bit 5: Timer hold/pause control
    BTSSEL  <= BTCTL(4 DOWNTO 3); -- Bits 4-3: Clock division selection
    BTCLR   <= BTCTL(2); -- Bit 2: Timer clear/reset control
    BTIP    <= BTCTL(1 DOWNTO 0); -- Bits 1-0: Interrupt source priority

    -- =============================================================================
    -- INTERRUPT SOURCE EXTRACTION: Monitor specific BTCNT bits for interrupts
    -- =============================================================================
    Q24 <= BTCNT(24); -- Interrupt when bit 24 changes (every 16,777,216 counts)
    Q28 <= BTCNT(28); -- Interrupt when bit 28 changes (every 268,435,456 counts)
    Q32 <= BTCNT(31); -- Interrupt when bit 31 changes (every 2,147,483,648 counts)

    -- =============================================================================
    -- CLOCK DIVISION SYSTEM: Generate configurable clock for timer counting
    -- =============================================================================
    -- Select division factor based on BTSSEL control bits
    with BTSSEL select
    clock_div <= "0001" when "00",  -- No division (1x): count every master clock cycle
                 "0010" when "01",  -- Divide by 2: count every 2nd master clock cycle
                 "0100" when "10",  -- Divide by 4: count every 4th master clock cycle
                 "1000" when "11",  -- Divide by 8: count every 8th master clock cycle
                 "0001" when others; -- Default to no division for safety
        
    -- Clock divider process: creates single pulse per division cycle
    -- This ensures timer counts at the desired rate relative to master clock
    process(mclk_i, rst_i)
    begin
        if rst_i = '1' then
            clk_counter <= (clk_counter'range => '0');
            clk <= '0';
        elsif rising_edge(mclk_i) then
            if clk_counter = std_logic_vector(unsigned(clock_div) - 1) then
                clk_counter <= (clk_counter'range => '0');
                clk <= not clk;                 -- Toggle clock for 50% duty cycle
            else
                clk_counter <= std_logic_vector(unsigned(clk_counter) + 1); -- Increment counter
            end if;
        end if;
    end process;

    -- =============================================================================
    -- TIMER COUNTING: Main 32-bit up-counter with control logic
    -- =============================================================================
    -- Timer counts up on divided clock, resets on overflow or control signals
    process(clk, rst_i)
    begin
        if rst_i = '1' then
            BTCNT <= (BTCNT'range => '0'); -- System reset: clear timer
            HEU0 <= '0';
        elsif rising_edge(clk) then
            if BTCLR = '1' then
                BTCNT <= (BTCNT'range => '0'); -- Control reset or period end: restart timer
                HEU0 <= '1';
            elsif BTHOLD = '0' then
                -- Handle edge case: if BTCNT exceeds BTCL0, reset to start over
                -- This prevents counter from running beyond intended range
                if unsigned(BTCNT) >= unsigned(BTCL0) then
                    BTCNT <= (BTCNT'range => '0'); -- Force reset on overflow
                    HEU0 <= '1';
                else
                    BTCNT <= std_logic_vector(unsigned(BTCNT) + 1); -- Normal increment
                    HEU0 <= '0';
                end if;
            else
                HEU0 <= '0';
            end if;
            -- Note: If BTHOLD = '1', timer pauses (no change to BTCNT)
        end if;
    end process;

    -- =============================================================================
    -- COMPARE REGISTER AUTO-TRANSFER: Load new values when timer resets
    -- =============================================================================
    -- When BTCNT reaches zero, automatically transfer compare register values
    -- This ensures smooth transitions between different timer periods
    process(BTCNT, BTCCR0, BTCCR1)
    begin
        if BTCNT = (BTCNT'range => '0') then
            BTCL0 <= BTCCR0; -- Load new period value
            BTCL1 <= BTCCR1; -- Load new duty cycle value
        end if;
    end process;

    -- =============================================================================
    -- PWM OUTPUT GENERATION: Two modes with automatic period control
    -- =============================================================================
    -- Generates PWM output based on timer count and compare values
    -- HEU0 signal indicates when timer period is complete
    process(BTCNT, BTCL0, BTCL1, BTOUTMD, BTOUTEN)
    begin
        if BTOUTEN = '0' then
            -- Timer output disabled: force outputs low
            pwm_output <= '0';
        else
            case BTOUTMD is
                when '0' => -- Mode 0: set/reset (normal PWM)
                    -- Output is 0 when BTCNT is 0 to BTCL1 (duty cycle low)
                    -- Output is 1 when BTCNT is BTCL1+1 to BTCL0 (duty cycle high)
                    if (unsigned(BTCNT) >= 0) and (unsigned(BTCNT) <= unsigned(BTCL1)) then
                        pwm_output <= '0';
                    elsif (unsigned(BTCNT) > unsigned(BTCL1)) and (unsigned(BTCNT) <= unsigned(BTCL0)) then
                        pwm_output <= '1';
                    else
                        pwm_output <= '0'; -- Default case (safety)
                    end if;
                    
                when '1' => -- Mode 1: reset/set (inverted PWM)
                    -- Output is 1 when BTCNT is 0 to BTCL1 (duty cycle high)
                    -- Output is 0 when BTCNT is BTCL1+1 to BTCL0 (duty cycle low)
                    if (unsigned(BTCNT) >= 0) and (unsigned(BTCNT) <= unsigned(BTCL1)) then
                        pwm_output <= '1';
                    elsif (unsigned(BTCNT) > unsigned(BTCL1)) and (unsigned(BTCNT) <= unsigned(BTCL0)) then
                        pwm_output <= '0';
                    else
                        pwm_output <= '0'; -- Default case (safety)
                    end if;
                    
                when others =>
                    pwm_output <= '0'; -- Invalid mode: safe default
            end case;
        end if;
    end process;

    -- =============================================================================
    -- INTERRUPT SELECTION: 4-to-1 multiplexer for interrupt source selection
    -- =============================================================================
    -- Selects which event generates the interrupt flag based on BTIP control
    -- Provides flexibility for different timing applications
    process(BTIP, HEU0, Q24, Q28, Q32)
    begin
        case BTIP is
            when "00" => -- HEU0: Interrupt on timer period completion
                interrupt_flag <= HEU0;
            when "01" => -- Q24: Interrupt when bit 24 changes
                interrupt_flag <= Q24;
            when "10" => -- Q28: Interrupt when bit 28 changes
                interrupt_flag <= Q28;
            when "11" => -- Q32: Interrupt when bit 31 (MSB) changes
                interrupt_flag <= Q32;
            when others =>
                interrupt_flag <= '0'; -- Invalid selection: no interrupt
        end case;
    end process;

    -- =============================================================================
    -- OUTPUT ASSIGNMENTS: Connect internal signals to module outputs
    -- =============================================================================
    PWMout <= pwm_output; -- PWM output signal
    BTIFG <= interrupt_flag; -- Timer interrupt flag

END behavior;