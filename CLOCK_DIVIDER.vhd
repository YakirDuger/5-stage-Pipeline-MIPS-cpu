--------------- Configurable Clock Divider Module
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

-------------- ENTITY --------------------
ENTITY CLOCK_DIVIDER IS
    GENERIC(
        DIVIDE_FACTOR : INTEGER := 7500  -- Default: 75MHz -> 10KHz
    );
    PORT( 
        clk_in      : IN  STD_LOGIC;    -- Input clock (PLL output)
        reset       : IN  STD_LOGIC;    -- Reset (active high)
        clk_out     : OUT STD_LOGIC     -- Output divided clock
    );
END CLOCK_DIVIDER;

------------ ARCHITECTURE ----------------
ARCHITECTURE behavioral OF CLOCK_DIVIDER IS
    
    SIGNAL counter      : INTEGER RANGE 0 TO DIVIDE_FACTOR-1;
    SIGNAL clk_reg      : STD_LOGIC;
    
BEGIN

    -- Output the registered clock
    clk_out <= clk_reg;
    
    -- Clock divider process
    PROCESS(clk_in, reset)
    BEGIN
        IF reset = '1' THEN
            counter <= 0;
            clk_reg <= '0';
        ELSIF rising_edge(clk_in) THEN
            IF counter = DIVIDE_FACTOR-1 THEN
                counter <= 0;
                clk_reg <= NOT clk_reg;  -- Toggle output clock
            ELSE
                counter <= counter + 1;
            END IF;
        END IF;
    END PROCESS;
    
END behavioral;
