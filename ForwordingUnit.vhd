library IEEE;
use ieee.std_logic_1164.all;
ENTITY ForwordingUnit IS
   PORT( 
		clk					: IN STD_LOGIC;
		RegisterRdMEM		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterRdWB		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterRsEX		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterRtEX		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterRsDEC		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterRtDEC		: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisteWriteMem		: IN STD_LOGIC;
		RegisteWriteWB		: IN STD_LOGIC;
		ForwardRS_Exe		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		ForwardRT_Exe		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		ForwardRT_Dec		: OUT STD_LOGIC;
		ForwardRS_Dec		: OUT STD_LOGIC
	);
END ForwordingUnit;
-- 00 is take from execute, 01 is take from memory, 10 is take from writeback
-- Need to check if Double Data Hazard doesn't affect us, shouldn't because the IF for MEM happens before the one for WB
ARCHITECTURE Forword OF ForwordingUnit IS
BEGIN           
	PROCESS (RegisterRdMEM,RegisterRdWB,RegisterRsEX,RegisterRtEX,RegisteWriteMem,RegisteWriteWB,RegisterRsDEC,RegisterRtDEC)-- unsure if clk is needed
	BEGIN		-- Forward RT to execute from Mem
		IF ((RegisterRdMEM = RegisterRtEX) AND (RegisteWriteMem = '1') AND (RegisterRdMEM /= "00000")) THEN
			ForwardRT_Exe <= "01";
		-- Forward RT to execute from WB
		ELSIF ((RegisterRdWB = RegisterRtEX) AND (RegisteWriteWB = '1') AND (RegisterRdMEM /= "00000")
				AND NOT((RegisterRdMEM = RegisterRtEX) AND (RegisteWriteMem = '1') AND (RegisterRdMEM /= "00000"))
				) THEN
			ForwardRT_Exe <= "10";
		ELSE
			ForwardRT_Exe <= "00";
		END IF;
		
		-- Forward RS to execute from Mem
		IF ((RegisterRdMEM = RegisterRsEX) AND (RegisteWriteMem = '1') AND (RegisterRdMEM /= "00000")) THEN
			ForwardRS_Exe <= "01";
		-- Forward RS to execute from WB
		ELSIF ((RegisterRdWB = RegisterRsEX) AND (RegisteWriteWB = '1') AND (RegisterRdMEM /= "00000")
			AND NOT ((RegisterRdMEM = RegisterRsEX) AND (RegisteWriteMem = '1') AND (RegisterRdMEM /= "00000"))	) THEN
			ForwardRS_Exe <= "10";
		ELSE
			ForwardRS_Exe <= "00";
		END IF;
		
		-- Forward RS to Decode 
		IF  ((RegisterRdMEM /= "00000") AND (RegisterRsDEC = RegisterRdMEM) AND (RegisteWriteMEM = '1') ) THEN 
			ForwardRS_Dec <= '1';
		ELSE
			ForwardRS_Dec <= '0';
		END IF;
		
		-- Forward RT to decode
		IF  ((RegisterRdMEM /= "00000") AND (RegisterRtDEC = RegisterRdMEM) AND (RegisteWriteMEM = '1') ) THEN
			ForwardRT_Dec <= '1';
		ELSE
			ForwardRT_Dec <= '0';
		END IF;
		
	end process;



END Forword;