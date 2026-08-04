--------------  Execute module (implements the data ALU and Branch Address Adder for the MIPS computer) ----------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE IEEE.numeric_std.ALL;
USE work.aux_package.ALL;
------------ Entity -----------------
ENTITY  Execute IS
	PORT(	Read_data_1 	: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Read_data_2 	: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Sign_extend 	: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Function_opcode : IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			Opcode			: IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			ALUOp 			: IN 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
			ALUSrc 			: IN 	STD_LOGIC;
			Zero 			: OUT	STD_LOGIC;
			RegDst			: IN    STD_LOGIC_VECTOR( 1 DOWNTO 0 );
			ALU_Result 		: OUT	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			PC_plus_4 		: IN 	STD_LOGIC_VECTOR( 9 DOWNTO 0 );
			Wr_reg_addr     : OUT   STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			Wr_reg_addr_0	: IN    STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			Wr_reg_addr_1	: IN    STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			Wr_data_FW_WB	: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Wr_data_FW_MEM	: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			ForwardA 		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);		
			ForwardB		: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			WriteData_EX    : OUT   STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Flush_EX		: IN 	STD_LOGIC;
			clock, reset	: IN 	STD_LOGIC );
END Execute;
------------ Architecture -----------------
ARCHITECTURE behavior OF Execute IS
SIGNAL Ainput, Binput 			  : STD_LOGIC_VECTOR( 31 DOWNTO 0 );
SIGNAL Aforward_mux, Bforward_mux : STD_LOGIC_VECTOR( 31 DOWNTO 0 );
SIGNAL ALU_output_mux			  : STD_LOGIC_VECTOR( 31 DOWNTO 0 );
--SIGNAL Branch_Add 				  : STD_LOGIC_VECTOR( 7 DOWNTO 0 );
SIGNAL ALU_ctl					  : STD_LOGIC_VECTOR( 3 DOWNTO 0 );
SIGNAL write_register_address 	  : STD_LOGIC_VECTOR( 4 DOWNTO 0 );
SIGNAL write_register_address_1	  : STD_LOGIC_VECTOR( 4 DOWNTO 0 );
SIGNAL write_register_address_0	  : STD_LOGIC_VECTOR( 4 DOWNTO 0 );
BEGIN
--------------- ALU Inputs: A,B ----------------				
	------------ Forwarding ----------------
		-- Forward A
	WITH ForwardA SELECT 
			Aforward_mux <= Read_data_1    WHEN "00",
							Wr_data_FW_WB  WHEN "01",
							Wr_data_FW_MEM WHEN "10",
							X"00000000"	   WHEN OTHERS;
		-- Forward B
	WITH ForwardB SELECT 
			Bforward_mux <= Read_data_2    WHEN "00",
							Wr_data_FW_WB  WHEN "01",
							Wr_data_FW_MEM WHEN "10",
							X"00000000"	   WHEN OTHERS;
							
	-- ALU A input mux after forwarding (mux for adding shift)
	Ainput <= 	Bforward_mux WHEN (ALUOp = "11") ELSE  -- When Performing Shift, A should get data from reg2
				Aforward_mux;
	-- ALU B input mux after forwarding
	Binput <= 	Bforward_mux WHEN ( ALUSrc = '0' ) ELSE
				Sign_extend( 31 DOWNTO 0 );		
	WriteData_EX <= Bforward_mux;

-------------- Generate ALU control bits -------------
ALUCTL: 
	ALU_CONTROL PORT MAP(ALUOp, Function_opcode, Opcode, ALU_ctl);
----------------- Mux for Register Write Address ---------------------
	 Wr_reg_addr <= "11111"			WHEN RegDst = "10" ELSE -- jal
					Wr_reg_addr_1 	WHEN RegDst = "01" ELSE 
					Wr_reg_addr_0;
------------ Generate Zero Flag ----------------------------
	Zero <= '1' WHEN ( ALU_output_mux( 31 DOWNTO 0 ) = X"00000000"  ) ELSE	
			'0';    
------------- Select ALU output  ----------------------------      
	-- FIX: SLT is now resolved correctly inside the ALU, so this extra
	-- 32-bit mux is gone.  That also removes a level of logic from the
	-- EX critical path.
	ALU_result <= ALU_output_mux( 31 DOWNTO 0 );
		
------------ Adder to compute Branch Address ----------------
--	Branch_Add	<= PC_plus_4( 9 DOWNTO 2 ) +  Sign_extend( 7 DOWNTO 0 ) ;
--	Add_result 	<= Branch_Add( 7 DOWNTO 0 );

------------ ALU Proces -----------------------------

ALUProc:  ALU PORT MAP(Ainput, Binput, ALU_ctl, ALU_output_mux);



  
END behavior;