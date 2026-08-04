--------------- Interrupt Controller Module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY INTERRUPT IS
	GENERIC(DataBusSize	: integer := 32;
			AddrBusSize	: integer := 12;
			IrqSize	    : integer := 8;
			RegSize		: integer := 8
			);
	PORT( 
			reset		: IN	STD_LOGIC;
			clock		: IN	STD_LOGIC;
			MemReadBus	: IN	STD_LOGIC;
			MemWriteBus	: IN	STD_LOGIC;
			AddressBus	: IN	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);
			DataBus		: INOUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
			IntrSrc		: IN	STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0); -- IRQ
			ChipSelect	: IN	STD_LOGIC;
			INTR		: OUT	STD_LOGIC;
			INTA		: IN	STD_LOGIC;
			IRQ_OUT		: OUT   STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
			INTR_Active	: OUT	STD_LOGIC;
			CLR_IRQ_OUT	: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			IFG_STATUS_ERROR : IN STD_LOGIC;
			GIE			: IN	STD_LOGIC
		);
END INTERRUPT;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF INTERRUPT IS
	SIGNAL IRQ			: STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	SIGNAL CLR_IRQ		: STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	
	-- UART 
	SIGNAL IRQ_STATUS, CLR_IRQ_STATUS : STD_LOGIC;
	--
		
	SIGNAL IntrEn		: STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	SIGNAL IFG			: STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	SIGNAL TypeReg		: STD_LOGIC_VECTOR(RegSize-1 DOWNTO 0);
	
	SIGNAL INTA_Delayed : STD_LOGIC;
	
	
	
BEGIN
--------------------------- IO MCU ---------------------------
-- OUTPUT TO MCU -- 
-- FIXED: Only drive DataBus when explicitly reading interrupt registers or during interrupt acknowledge WITHOUT other memory operations
DataBus <=	X"000000" 		& TypeReg 	WHEN ((INTA = '0' AND MemReadBus = '0' AND MemWriteBus = '0')) ELSE
			X"000000" 	& IntrEn 	WHEN (AddressBus = X"840" AND MemReadBus = '1') ELSE
			X"000000" 	& IFG		WHEN (AddressBus = X"841" AND MemReadBus = '1') ELSE
			(OTHERS => 'Z');

--INPUT FROM MCU -- 

PROCESS(clock) 
BEGIN
	IF (falling_edge(clock)) THEN
		IF (AddressBus = X"840" AND MemWriteBus = '1') THEN
			IntrEn 	<=	DataBus(IrqSize-1 DOWNTO 0);
		END IF;		
	END IF;
END PROCESS;

IFG		<=	DataBus(IrqSize-1 DOWNTO 0)	WHEN (AddressBus = X"841" AND MemWriteBus = '1') ELSE
			IRQ AND IntrEn;		
-- TypeReg is now read-only (determined by interrupt priority)
-- TypeReg	<=	DataBus(RegSize-1 DOWNTO 0)	WHEN (AddressBus = X"842" AND MemWriteBus = '1') ELSE
--			(OTHERS => 'Z');
-------------------------------------------------------------

-- Find the INTR output
PROCESS (clock, IFG) BEGIN 
	IF (rising_edge(CLOCK)) THEN
		IF (IFG(0) = '1' OR IFG(1) = '1' OR IFG(2) = '1' OR
			IFG(3) = '1' OR IFG(4) = '1' OR IFG(5) = '1' OR IFG(6) = '1' OR IFG(7) = '1') THEN
			
			INTR <= GIE;
		ELSE 
			INTR <= '0';
		END IF;
	END IF;
END PROCESS;
------------ UART STATUS ---------------
PROCESS (reset, CLR_IRQ_STATUS, IFG_STATUS_ERROR)
BEGIN
	IF (reset = '1') THEN
		IRQ_STATUS <= '0';
	ELSIF CLR_IRQ_STATUS = '0' THEN
		IRQ_STATUS <= '0';
	ELSIF rising_edge(IFG_STATUS_ERROR) THEN
		IRQ_STATUS <= '1';
	END IF;
END PROCESS;


------------ RX ---------------
PROCESS (clock, reset, CLR_IRQ(0), IntrSrc(0))
BEGIN
	IF (reset = '1') THEN
		IRQ(0) <= '0';
	ELSIF CLR_IRQ(0) = '0' THEN
		IRQ(0) <= '0';
	ELSIF rising_edge(IntrSrc(0)) THEN
		IRQ(0) <= '1';
	END IF;
END PROCESS;
------------ TX ---------------
PROCESS (clock, reset, CLR_IRQ(1), IntrSrc(1))
BEGIN
	IF (reset = '1') THEN
		IRQ(1) <= '0';
	ELSIF CLR_IRQ(1) = '0' THEN
		IRQ(1) <= '0';
	ELSIF rising_edge(IntrSrc(1)) THEN
		IRQ(1) <= '1';
	END IF;
END PROCESS;
------------ BTIMER ---------------
PROCESS (clock, reset, CLR_IRQ(2), IntrSrc(2))
BEGIN
	IF falling_edge(clock) THEN
		IF (reset = '1') THEN
			IRQ(2) <= '0';
		ELSIF CLR_IRQ(2) = '0' THEN
			IRQ(2) <= '0';
		ELSIF IntrSrc(2) = '1' THEN
			IRQ(2) <= '1';
		END IF;
	END IF;
END PROCESS;
------------ KEY1 ---------------
PROCESS (clock, reset, CLR_IRQ(3), IntrSrc(3))
BEGIN
	IF (reset = '1') THEN
		IRQ(3) <= '0';
	ELSIF CLR_IRQ(3) = '0' THEN
		IRQ(3) <= '0';
	ELSIF rising_edge(IntrSrc(3)) THEN
		IRQ(3) <= '1';
	END IF;
END PROCESS;
------------ KEY2 ---------------
PROCESS (clock, reset, CLR_IRQ(4), IntrSrc(4))
BEGIN
	IF (reset = '1') THEN
		IRQ(4) <= '0';
	ELSIF CLR_IRQ(4) = '0' THEN
		IRQ(4) <= '0';
	ELSIF rising_edge(IntrSrc(4)) THEN
		IRQ(4) <= '1';
	END IF;
END PROCESS;
------------ KEY3 ---------------
PROCESS (clock, reset, CLR_IRQ(5), IntrSrc(5))
BEGIN
	IF (reset = '1') THEN
		IRQ(5) <= '0';
	ELSIF CLR_IRQ(5) = '0' THEN
		IRQ(5) <= '0';
	ELSIF rising_edge(IntrSrc(5)) THEN
		IRQ(5) <= '1';
	END IF;
END PROCESS;
------------ FIR FILTER ---------------
PROCESS (clock, reset, CLR_IRQ(6), IntrSrc(6))
BEGIN
	IF (reset = '1') THEN
		IRQ(6) <= '0';
	ELSIF CLR_IRQ(6) = '0' THEN
		IRQ(6) <= '0';
	ELSIF rising_edge(IntrSrc(6)) THEN
		IRQ(6) <= '1';
	END IF;
END PROCESS;
------------ FIR FILTER ---------------
PROCESS (clock, reset, CLR_IRQ(7), IntrSrc(7))
BEGIN
	IF (reset = '1') THEN
		IRQ(7) <= '0';
	ELSIF CLR_IRQ(7) = '0' THEN
		IRQ(7) <= '0';
	ELSIF rising_edge(IntrSrc(7)) THEN
		IRQ(7) <= '1';
	END IF;
END PROCESS;
---


IRQ_OUT <= IRQ;

PROCESS (clock) BEGIN
	IF (reset = '1') THEN
		INTA_Delayed <= '1';
	ELSIF (falling_edge(clock)) THEN
		INTA_Delayed <= INTA;
	END IF;
END PROCESS;

-- Clear IRQ When Interrupt Ack recv
CLR_IRQ(0) <= '0' WHEN (TypeReg = X"08" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(1) <= '0' WHEN (TypeReg = X"0C" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(2) <= '0' WHEN (TypeReg = X"10" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(3) <= '0' WHEN (TypeReg = X"14" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(4) <= '0' WHEN (TypeReg = X"18" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(5) <= '0' WHEN (TypeReg = X"1C" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(6) <= '0' WHEN (TypeReg = X"24" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ(7) <= '0' WHEN (TypeReg = X"20" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';
CLR_IRQ_STATUS <= '0' WHEN (TypeReg = X"04" AND INTA = '1' AND INTA_Delayed = '0') ELSE '1';


CLR_IRQ_OUT <= CLR_IRQ;

-- Determinate if interrupt is currently active
INTR_Active	<= 	IFG(0) OR IFG(1) OR IFG(2) OR
				IFG(3) OR IFG(4) OR IFG(5) OR IFG(6) OR IFG(7);

-- Interrupt Vectors (Priority Order - Highest to Lowest)
TypeReg	<= 	X"00" WHEN reset  = '1' ELSE -- RESET (highest priority)
		X"04" WHEN (IRQ_STATUS = '1' AND IntrEn(0) = '1') ELSE  -- UART Status Error  
		X"08" WHEN IFG(0) = '1' ELSE  	-- UART RX
		X"0C" WHEN IFG(1) = '1' ELSE  	-- UART TX
		X"10" WHEN IFG(2) = '1' ELSE  	-- Basic Timer
		X"14" WHEN IFG(3) = '1' ELSE  	-- KEY1
		X"18" WHEN IFG(4) = '1' ELSE	-- KEY2 
		X"1C" WHEN IFG(5) = '1' ELSE	-- KEY3
		X"24" WHEN IFG(6) = '1' ELSE	-- FIR Filter (lowest priority)
		X"20" WHEN IFG(7) = '1' ELSE	-- FIR Filter (lowest priority)
		(OTHERS => 'Z');

END structure;