--------------- Corrected Address Decoder Module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY OptAddrDecoder IS
	PORT( 
		reset						: IN	STD_LOGIC;
		AddressBus					: IN	STD_LOGIC_VECTOR(11 DOWNTO 0);
		CS_LEDR, CS_SW, CS_KEY		: OUT	STD_LOGIC;
		CS_HEX0_HEX1, CS_HEX2_HEX3, CS_HEX4_HEX5	: OUT	STD_LOGIC;
		-- FIR Filter chip selects
		CS_FIRCTL, CS_FIRIN, CS_FIROUT	: OUT	STD_LOGIC;
		CS_COEF3_0, CS_COEF7_4		: OUT	STD_LOGIC
	);
END OptAddrDecoder;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF OptAddrDecoder IS

signal        A11 : STD_LOGIC := '0';
signal        A4_A2 : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
signal        A1_A0 : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
signal        A5 : STD_LOGIC := '0';
BEGIN
	A11 	<= AddressBus(11);
	A4_A2   <= AddressBus(4 downto 2);
	A1_A0   <= AddressBus(1 downto 0);
	A5	    <= AddressBus(5);


	-- GPIO and Display Peripherals
	CS_LEDR <= '1' WHEN (AddressBus = X"800") ELSE '0'; -- 0x800 - LED
    CS_HEX0_HEX1 <= '1' WHEN (A11 = '1' AND A4_A2 = "001" AND A5 = '0') ELSE '0'; -- 0x804/0x805 - HEX0_HEX1
    CS_HEX2_HEX3 <= '1' WHEN (A11 = '1' AND A4_A2 = "010" AND A5 = '0') ELSE '0'; -- 0x808/0x809 - HEX2_HEX3
    CS_HEX4_HEX5 <= '1' WHEN (A11 = '1' AND A4_A2 = "011" AND A5 = '0') ELSE '0'; -- 0x80C/0x80D - HEX4_HEX5
    CS_SW <= '1' WHEN (A11 = '1' AND A4_A2 = "100" AND A1_A0 = "00") ELSE '0'; -- 0x810 - Switches
    CS_KEY <= '1' WHEN (A11 = '1' AND A4_A2 = "100" AND A1_A0 = "01") ELSE '0'; -- 0x811 - Keys (if needed)
    
    -- FIR Filter Peripherals  
    CS_FIRCTL <= '1' WHEN (AddressBus = X"82C") ELSE '0'; -- 0x82C - FIR Control
    CS_FIRIN <= '1' WHEN (AddressBus = X"830") ELSE '0';  -- 0x830 - FIR Input
    CS_FIROUT <= '1' WHEN (AddressBus = X"834") ELSE '0'; -- 0x834 - FIR Output
    CS_COEF3_0 <= '1' WHEN (AddressBus = X"838") ELSE '0'; -- 0x838 - Coefficients 3-0
    CS_COEF7_4 <= '1' WHEN (AddressBus = X"83C") ELSE '0'; -- 0x83C - Coefficients 7-4
	
END structure;