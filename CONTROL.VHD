------------ Control module (implements MIPS control unit)------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
------------ Entity -----------------
ENTITY control IS
   PORT( 	
		Opcode 			: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);
		Funct			: IN 	STD_LOGIC_VECTOR(5 DOWNTO 0);
		RegDst 			: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUSrc 			: OUT 	STD_LOGIC;
		MemtoReg 		: OUT 	STD_LOGIC;
		RegWrite 		: OUT 	STD_LOGIC;
		MemRead 		: OUT 	STD_LOGIC;
		MemWrite 		: OUT 	STD_LOGIC;
		BranchBeq 		: OUT 	STD_LOGIC;
		BranchBne 		: OUT 	STD_LOGIC;
		Jump			: OUT 	STD_LOGIC;
		Jal				: OUT 	STD_LOGIC;
		ALUop 			: OUT 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
		INTR			: IN 	STD_LOGIC;
		-- INTA			: INOUT STD_LOGIC;
		IF_FLUSH		: OUT 	STD_LOGIC;
		ID_FLUSH		: OUT 	STD_LOGIC;
		EX_FLUSH		: OUT 	STD_LOGIC;
		HOLD_PC			: IN 	STD_LOGIC;
		Read_ISR_PC		: IN 	STD_LOGIC;		
		clock, reset	: IN 	STD_LOGIC );
END control;
------------ Architecture -----------------
ARCHITECTURE behavior OF control IS
	SIGNAL  R_format, I_format, Lw, Sw, Beq, Bne, Addi, Ori, Xori, Andi, Shift, Lui, Slti, JalSignal	: STD_LOGIC;
	
	-- SIGNAL	IF_FLUSH, ID_FLUSH, EX_FLUSH	: STD_LOGIC;
	-- Add Relvant Signals Later if needed
BEGIN           
------- Code to generate control signals using opcode bits -------------
	-- If interrupt occurs then FLUSH IF, ID and EX
	-- INTA		<= '0' WHEN INTR = '1' ELSE 'Z';
	IF_FLUSH 	<= '1' WHEN INTR = '1' OR HOLD_PC = '1' OR Read_ISR_PC = '1' ELSE '0';
	ID_FLUSH 	<= '1' WHEN INTR = '1' OR HOLD_PC = '1' OR Read_ISR_PC = '1' ELSE '0';
	EX_FLUSH 	<= '1' WHEN INTR = '1' OR HOLD_PC = '1' OR Read_ISR_PC = '1' ELSE '0';
	
	-- OPcode Decoder --
	R_format 	<=  '1' WHEN Opcode = "000000" OR Opcode = "011100" ELSE '0';
	Lw          <=  '1' WHEN Opcode = "100011" ELSE '0';
 	Sw          <=  '1' WHEN Opcode = "101011" ELSE '0';
   	Beq         <=  '1' WHEN Opcode = "000100" ELSE '0';
	Bne			<=	'1' WHEN Opcode = "000101" ELSE '0';
	Addi		<=  '1' WHEN Opcode = "001000" ELSE '0';
	Andi 		<=  '1' WHEN Opcode = "001100" ELSE '0';
	Slti		<= 	'1' WHEN Opcode = "001010" ELSE '0';
	Ori			<=  '1' WHEN Opcode = "001101" ELSE '0';
	Xori		<=  '1' WHEN Opcode = "001110" ELSE '0';
	Lui			<=	'1' WHEN Opcode = "001111" ELSE '0';
	JalSignal	<=	'1' WHEN Opcode = "000011" ELSE '0';
	Jump		<=	'1' WHEN Opcode = "000010" OR Opcode = "000011" OR (Opcode = "000000" AND Funct = "001000") ELSE '0';
	Shift		<=  '1' WHEN Opcode = "000000" AND (Funct = "000000" OR Funct = "000010") ELSE '0';

	-- EXEC -- 
	RegDst(1)	<= JalSignal; -- jal
	RegDst(0)  	<= R_format;
	ALUSrc  	<= Lw OR Sw OR Addi OR Andi OR Ori OR Xori OR Shift OR Lui OR Slti;
	ALUOp(1) 	<= R_format;
	ALUOp(0) 	<= Beq OR Bne OR Shift; 

		-- MEM -- 
	MemRead 	<= Lw;
   	MemWrite 	<= Sw; 
 	BranchBeq   <= Beq;
	BranchBne	<= Bne;
	Jal 		<= JalSignal;
	
	-- WB --
	MemtoReg 	<= Lw;
  	RegWrite 	<= R_format OR Lw OR Addi OR Andi OR Ori OR Xori OR Lui OR Slti OR JalSignal;


END behavior;


