--------------- Corrected Output Peripheral Module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY OutputPeripheral IS
	GENERIC (SevenSeg	: BOOLEAN := TRUE;
			 IOSize		: INTEGER := 7); -- 7 WHEN HEX, 8 WHEN LEDs
	PORT( 
		MemRead		: IN	STD_LOGIC;
		clock		: IN 	STD_LOGIC;
		reset		: IN 	STD_LOGIC;
		MemWrite	: IN	STD_LOGIC;
		ChipSelect	: IN 	STD_LOGIC;
		Data		: INOUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		GPOutput	: OUT	STD_LOGIC_VECTOR(IOSize-1 DOWNTO 0)
		);
END OutputPeripheral;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF OutputPeripheral IS
	SIGNAL Latch_o			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL write_enable		: STD_LOGIC;
	SIGNAL read_enable		: STD_LOGIC;
BEGIN
	-- Generate control signals
	write_enable <= MemWrite AND ChipSelect;
	read_enable  <= MemRead AND ChipSelect;
	
	-- FIXED: Proper register process - latch on write cycle
	PROCESS(clock, reset)
	BEGIN
		IF (reset = '1') THEN
			Latch_o <= (others => '0');
		ELSIF (rising_edge(clock)) THEN  -- Use falling edge to avoid race conditions
			-- Latch data when write is enabled
			IF (write_enable = '1') THEN
				Latch_o <= Data;
			END IF;
		END IF;
	END PROCESS;

	-- FIXED: Proper tri-state control
	-- Drive the bus only during read operations, when we're not writing
	Data <= Latch_o WHEN (read_enable = '1') ELSE (others => 'Z');

	-- Generate seven segment or direct output
	SEG: IF (SevenSeg = TRUE) GENERATE
			SevenSegDec: 	SevenSegDecoder
							PORT MAP(	data	=> Latch_o(3 DOWNTO 0),
										seg		=> GPOutput);
	END GENERATE SEG;
	
	NO_SEG: IF (SevenSeg = FALSE) GENERATE
			GPOutput <= Latch_o(IOSize-1 DOWNTO 0);
	END GENERATE NO_SEG;
	
END structure;