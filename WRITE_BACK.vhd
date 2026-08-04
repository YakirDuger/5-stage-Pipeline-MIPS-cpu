--------------- Write Back module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY WRITE_BACK IS
	PORT( 
		ALU_Result, read_data	: IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		PC_plus_4_shifted		: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		MemtoReg, Jal			: IN  STD_LOGIC;
		write_data 				: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		write_data_mux			: OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
END 	WRITE_BACK;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF WRITE_BACK IS
	SIGNAL write_data_sig : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN

	write_data_sig	<= ALU_Result WHEN MemtoReg = '0' ELSE read_data;
	--write_data 			<= ALU_Result WHEN MemtoReg = '0' ELSE read_data; -- NEW 14:15
	write_data 		<= write_data_sig;
	write_data_mux 	<= write_data_sig WHEN Jal = '0' ELSE "000000000000000000000000" & PC_plus_4_shifted;

END structure;