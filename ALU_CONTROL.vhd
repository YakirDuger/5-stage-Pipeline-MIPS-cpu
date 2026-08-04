LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
------------ Entity -----------------
ENTITY  ALU_CONTROL IS
	PORT(	ALUOp 	: IN 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
			Funct 	: IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			Opcode 	: IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			ALU_ctl : OUT   STD_LOGIC_VECTOR( 3 DOWNTO 0 ));
END ALU_CONTROL;
------------ Architecture -----------------
ARCHITECTURE behavior OF ALU_CONTROL IS
BEGIN
----------- ALU Control Process -----------------
	PROCESS (ALUOp, Funct, Opcode)
	BEGIN
 	CASE ALUOp IS
		WHEN "10" => -- r-type
			CASE Funct IS
				WHEN "100000" => ALU_ctl <= "0010"; -- add
				WHEN "100001" => ALU_ctl <= "0010"; -- mov
				WHEN "100010" => ALU_ctl <= "0110"; -- sub
				WHEN "000010" => ALU_ctl <= "0011"; -- mul
				WHEN "100100" => ALU_ctl <= "0000"; -- and
				WHEN "100101" => ALU_ctl <= "0001"; -- or
				WHEN "100110" => ALU_ctl <= "0100"; -- xor
				WHEN "101010" => ALU_ctl <= "0111"; -- slt
				WHEN OTHERS   => ALU_ctl <= "1111"; -- else
			END CASE;				
		WHEN "00" => -- i-type
			CASE Opcode IS
				WHEN "100011" => ALU_ctl <= "0010"; -- lw
				WHEN "101011" => ALU_ctl <= "0010"; -- sw
				WHEN "001000" => ALU_ctl <= "0010"; -- addi
				WHEN "001100" => ALU_ctl <= "0000"; -- andi
				WHEN "001101" => ALU_ctl <= "0001"; -- ori
				WHEN "001110" => ALU_ctl <= "0100"; -- xori
				WHEN "001111" => ALU_ctl <= "1001"; -- lui
				WHEN "001010" => ALU_ctl <= "0111"; -- slti
		        WHEN OTHERS   => ALU_ctl <= "1111"; -- else
			END CASE;			
		WHEN "01" 	=> -- beq, bne
								 ALU_ctl <= "0110"; 		
 	 	WHEN "11"	=>  -- shift
			CASE Funct IS
				WHEN "000000" => ALU_ctl <= "0101"; -- sll
				WHEN "000010" => ALU_ctl <= "1000"; -- srl
				WHEN OTHERS   => ALU_ctl <= "1111"; -- else
			END CASE;
		
		WHEN OTHERS =>  
								 ALU_ctl <= "1111"; -- else	
  	END CASE;
  END PROCESS;


END behavior;