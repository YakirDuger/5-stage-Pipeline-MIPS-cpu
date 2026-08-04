library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

ENTITY  ALU IS
	PORT(	Ainput 			: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Binput 			: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			ALU_ctl		 	: IN 	STD_LOGIC_VECTOR( 3 DOWNTO 0 );
			ALU_output_mux	: OUT   STD_LOGIC_VECTOR( 31 DOWNTO 0 )
			);
END ALU;
------------ Architecture -----------------
ARCHITECTURE behavior OF ALU IS
BEGIN

------------ ALU Proces -----------------------------
PROCESS ( ALU_ctl, Ainput, Binput )
	variable product : STD_LOGIC_VECTOR(63 downto 0); 
	variable diff    : STD_LOGIC_VECTOR(31 downto 0);
	variable slt_bit : STD_LOGIC;
	BEGIN
	-- Computed once, outside the CASE, so synthesis shares ONE 32-bit
	-- subtractor between SUB and SLT instead of inferring two.
	diff := Ainput - Binput;
	-- Signed compare: when the operand signs differ the result is simply
	-- A's sign bit (and that is exactly when A-B could overflow); when the
	-- signs match the subtract cannot overflow, so its sign bit is valid.
	IF ( Ainput(31) /= Binput(31) ) THEN
		slt_bit := Ainput(31);
	ELSE
		slt_bit := diff(31);
	END IF;
	--------------- Select ALU operation ---------------------
 	CASE ALU_ctl IS
		-- ALU performs ALUresult = A_input AND B_input
		WHEN "0000" 	=>	ALU_output_mux 	<= Ainput AND Binput; 
		-- ALU performs ALUresult = A_input OR B_input
     	WHEN "0001" 	=>	ALU_output_mux 	<= Ainput OR Binput;
		-- ALU performs ALUresult = A_input + B_input
	 	WHEN "0010" 	=>	ALU_output_mux 	<= Ainput + Binput; 
		-- ALU performs ALUresult = A_input * B_input
 	 	WHEN "0011" 	=>	product := Ainput * Binput; -- result 64 bit
							ALU_output_mux <= product(31 DOWNTO 0); -- Take Lower Part
		-- ALU performs ALUresult = A_input XOR B_input
 	 	WHEN "0100" 	=>	ALU_output_mux 	<= Ainput XOR Binput;
		-- ALU performs ALUresult = A_input SLL B_input
 	 	WHEN "0101" 	=>	ALU_output_mux 	<=	std_logic_vector(shift_left(unsigned(Ainput),to_integer(unsigned(Binput(10 downto 6)))));

		-- ALU performs ALUresult = A_input SRL B_input
 	 	WHEN "1000" 	=>	ALU_output_mux 	<=	std_logic_vector(shift_right(unsigned(Ainput),to_integer(unsigned(Binput(10 downto 6))))); 

		-- ALU performs ALUresult = A_input -B_input
 	 	WHEN "0110" 	=>	ALU_output_mux 	<= diff;
		-- ALU performs SLT
		-- FIX: this used to return the raw A-B and let Execute pick bit 31.
		-- A-B overflows whenever the operands have opposite signs, so the
		-- sign bit lied (e.g. 0x80000000 - 1 wraps to 0x7FFFFFFF).
		-- When the signs differ the answer is simply A's sign bit; when they
		-- match the subtraction cannot overflow, so bit 31 is trustworthy.
  	 	WHEN "0111" 	=>	ALU_output_mux <= X"0000000" & "000" & slt_bit;
		-- ALU performs LUI
  	 	WHEN "1001" 	=>	ALU_output_mux 	<= Binput(15 DOWNTO 0) & "0000000000000000";
		-- OUTPUT ZERO
 	 	WHEN OTHERS	=>	ALU_output_mux 	<= X"00000000" ;
  	END CASE;
  END PROCESS;



END behavior;