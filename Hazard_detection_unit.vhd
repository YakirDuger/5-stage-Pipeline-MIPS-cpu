library IEEE;
use ieee.std_logic_1164.all;

ENTITY Hazard_Detection_unit IS
   PORT( 	
		RegRtEx							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRtID							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRdEx							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRsID							: 	IN 		STD_LOGIC_VECTOR(4 DOWNTO 0);
		Reg_writeEx						:	IN 		STD_LOGIC;
		Branch_cond						: 	IN 		STD_LOGIC;
		RegDstEx						: 	IN 		STD_LOGIC;  -- NEW: 1=R-type (rd dest), 0=I-type (rt dest)
		stall_cnt						: 	OUT 	STD_LOGIC;
		stall_pc						: 	OUT   	STD_LOGIC
	);
END Hazard_Detection_unit;

ARCHITECTURE Hazarads OF Hazard_Detection_unit IS
	SIGNAL  LW_stall,BranchStall  : STD_LOGIC;

BEGIN           
	LW_stall 	<= '1' WHEN  (('1' =  Reg_writeEx) and (
		-- R-type instruction: destination is RegRdEx (rd field)
		(RegDstEx = '1' AND RegRdEx /= "00000" AND (RegRdEx = RegRsID OR RegRdEx = RegRtID)) OR
		-- I-type instruction: destination is RegRtEx (rt field)  
		(RegDstEx = '0' AND RegRtEx /= "00000" AND (RegRtEx = RegRsID OR RegRtEx = RegRtID))
	)) ELSE '0';
	stall_cnt 	<= '1' WHEN (LW_stall OR BranchStall) ELSE '0';
	stall_pc 	<= '1' WHEN (LW_stall OR BranchStall) ELSE '0';
	BranchStall <= '1' WHEN ((Branch_cond = '1' AND Reg_writeEx = '1') AND (
		-- R-type instruction: destination is RegRdEx (rd field)
		(RegDstEx = '1' AND RegRdEx /= "00000" AND (RegRdEx = RegRsID OR RegRdEx = RegRtID)) OR
		-- I-type instruction: destination is RegRtEx (rt field)
		(RegDstEx = '0' AND RegRtEx /= "00000" AND (RegRtEx = RegRsID OR RegRtEx = RegRtID))
	)) ELSE '0';

END Hazarads;