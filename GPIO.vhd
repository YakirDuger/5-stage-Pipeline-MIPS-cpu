--------------- Input Peripheral Module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY GPIO IS
	GENERIC(CtrlBusSize	: integer := 8;
			AddrBusSize	: integer := 32;
			DataBusSize	: integer := 32
			);
	PORT( 
		-- ControlBus	: IN	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
		INTA						: IN	STD_LOGIC;
		MemReadBus					: IN 	STD_LOGIC;
		clock						: IN 	STD_LOGIC;
		reset						: IN 	STD_LOGIC;
		MemWriteBus					: IN 	STD_LOGIC;
		AddressBus					: IN	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);
		DataBus						: INOUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
		HEX0, HEX1					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2, HEX3					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4, HEX5					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		LEDR						: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		Switches					: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		CS_LEDR, CS_SW				: IN 	STD_LOGIC;
		CS_HEX0_HEX1, CS_HEX2_HEX3, CS_HEX4_HEX5	: IN 	STD_LOGIC

		);
END GPIO;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF GPIO IS
	---- CONTROL SIGNALS ----
	SIGNAL ChipSelect	: STD_LOGIC_VECTOR(6 DOWNTO 0);
	-- SIGNAL MemRead		: STD_LOGIC;
	-- SIGNAL MemWrite		: STD_LOGIC;
	SIGNAL OADAddr		: STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL cs_hex0, cs_hex1, cs_hex2, cs_hex3, cs_hex4, cs_hex5 : STD_LOGIC;
	---- GPIO SIGNALS ----
	-- SIGNAL LEDR			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	-- SIGNAL HEX0_CS, HEX1_CS, HEX2_CS : STD_LOGIC;
	-- SIGNAL HEX3_CS, HEX4_CS, HEX5_CS : STD_LOGIC;
	
BEGIN	
	cs_hex0 <= CS_HEX0_HEX1 AND (NOT AddressBus(0));  -- HEX0 when CS2=1 and A0=0
    cs_hex1 <= CS_HEX0_HEX1 AND AddressBus(0);        -- HEX1 when CS2=1 and A0=1
    cs_hex2 <= CS_HEX2_HEX3 AND (NOT AddressBus(0));  -- HEX2 when CS3=1 and A0=0  
    cs_hex3 <= CS_HEX2_HEX3 AND AddressBus(0);        -- HEX3 when CS3=1 and A0=1
    cs_hex4 <= CS_HEX4_HEX5 AND (NOT AddressBus(0));  -- HEX4 when CS4=1 and A0=0
    cs_hex5 <= CS_HEX4_HEX5 AND AddressBus(0);        -- HEX5 when CS4=1 and A0=1
	--OADAddr <= AddressBus(11) & AddressBus(4 DOWNTO 2);
	
	--OAD : 	OptAddrDecoder
	--PORT MAP(	Address		=> OADAddr,
	--			ChipSelect 	=> ChipSelect);
		
	LED:	OutputPeripheral
	GENERIC MAP(SevenSeg => FALSE,
				IOSize	 => 8)
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> CS_LEDR,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> LEDR
			);
	
	-- HEX0_CS	<=	ChipSelect(1) AND (NOT AddressBus(0));
	-- HEX1_CS	<=	ChipSelect(1) AND AddressBus(0);
	-- HEX2_CS	<=	ChipSelect(2) AND (NOT AddressBus(0));
	-- HEX3_CS	<=	ChipSelect(2) AND AddressBus(0);
	-- HEX4_CS	<=	ChipSelect(3) AND (NOT AddressBus(0));
	-- HEX5_CS	<=	ChipSelect(3) AND AddressBus(0);
	
	-- RE-ENABLED HEX OutputPeripherals for test4 (DataBus conflicts resolved)
	HEX0_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,	
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex0,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX0
			);
			
	HEX1_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex1,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX1
			);
	
	HEX2_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex2,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX2
			);
	
	HEX3_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex3,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX3
			);
			
	HEX4_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex4,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX4
			);
			
	HEX5_7SEG:	OutputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				clock 		=> clock,
				reset		=> reset,
				MemWrite	=> MemWriteBus,
				ChipSelect	=> cs_hex5,
				Data		=> DataBus(7 DOWNTO 0),
				GPOutput	=> HEX5
			);
	
	SW:			InputPeripheral
	PORT MAP(	MemRead		=> MemReadBus,
				ChipSelect	=> CS_SW,
				INTA		=> INTA,
				Data		=> DataBus,
				GPInput		=> Switches
			);
		
	
END structure;