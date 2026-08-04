-------- Ifetch module (provides the PC and instruction memory for the MIPS computer)
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
---------------- ENTITY ------------------
ENTITY Ifetch IS
	GENERIC (MemWidth	: INTEGER;
			 SIM 		: BOOLEAN);
	PORT(	Instruction							   	: OUT	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
        	PC_plus_4_out 						   	: OUT	STD_LOGIC_VECTOR( 9 DOWNTO 0 );
        	Add_result 							   	: IN 	STD_LOGIC_VECTOR( 7 DOWNTO 0 );
        	PCSrc 								   	: IN 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
      		PC_out 								   	: OUT	STD_LOGIC_VECTOR( 9 DOWNTO 0 );
			JumpAddr							   	: IN	STD_LOGIC_VECTOR( 7 DOWNTO 0 );
        	clock, ena, Stall_IF,  reset 			: IN 	STD_LOGIC;
			INTA									: IN	STD_LOGIC;
			Read_ISR_PC								: IN	STD_LOGIC;
			HOLD_PC									: IN 	STD_LOGIC;
			ISRAddr									: IN	STD_LOGIC_VECTOR(31 DOWNTO 0)
			);
END Ifetch;
--------------- ARCHITECTURE --------------
ARCHITECTURE behavior OF Ifetch IS
	SIGNAL PC, PC_plus_4 	 : STD_LOGIC_VECTOR( 9 DOWNTO 0 );
	SIGNAL next_PC			 : STD_LOGIC_VECTOR( 7 DOWNTO 0 );
	SIGNAL Mem_Addr 		 : STD_LOGIC_VECTOR( MemWidth-1 DOWNTO 0 );
	SIGNAL Mem_clock		 : STD_LOGIC;
BEGIN
--------------- ROM for Instruction Memory ---------------
inst_memory: altsyncram
	
	GENERIC MAP (
		operation_mode => "ROM",
		width_a => 32,
		widthad_a => MemWidth,
		numwords_a => 256,
		lpm_hint => "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type => "altsyncram",
		outdata_reg_a => "UNREGISTERED",
		init_file => "D:\MIPS PIPELINE\207063322_ 341011849\CODE\ITCM.hex",
		intended_device_family => "Cyclone"
	)
	PORT MAP (
		clock0     => Mem_clock,  -- Falling Edge
		address_a 	=> Mem_Addr, 
		q_a 			=> Instruction
		);
--------------------------------------------------------------	
		Mem_clock <= not clock;
--------- Instructions always start on word address - not byte -------
		PC(1 DOWNTO 0) <= "00";
--------- Copy output signals - allows read inside module -----------
		PC_out 			<= PC;
		PC_plus_4_out 	<= PC_plus_4;
---------- Send address to inst. memory address register ---------

			ModelSim: IF (SIM = TRUE) GENERATE
			Mem_Addr <= PC( 9 DOWNTO 2 );
	END GENERATE ModelSim;
		
		FPGA: IF (SIM = FALSE) GENERATE
				Mem_Addr <= "00" & PC( 9 DOWNTO 2 );
		END GENERATE FPGA;
		
---------- Adder to increment PC by 4 ----------------------       
      	PC_plus_4( 9 DOWNTO 2 )  <= PC( 9 DOWNTO 2 ) + 1;
       	PC_plus_4( 1 DOWNTO 0 )  <= "00";
		
---------- Mux to select Branch Address or PC + 4 -----------       
		Next_PC  <= X"00" 				WHEN Reset = '1' 		ELSE
					ISRAddr(9 DOWNTO 2)	WHEN Read_ISR_PC = '1'	ELSE	-- Interrupt!
					Add_result 			WHEN PCSrc = "01" 		ELSE 	-- branch
					JumpAddr			WHEN PCSrc = "10"		ELSE	-- jump
					PC_plus_4(9 DOWNTO 2);
			
---------- PC Proccess (CLK on rising edge) --------------			
	PROCESS  BEGIN
		WAIT UNTIL ( clock'EVENT ) AND ( clock = '1' );
		IF reset = '1' THEN
			   PC( 9 DOWNTO 2) <= "00000000"; 
		ELSIF (ena = '1' AND HOLD_PC = '0' AND (Stall_IF = '0' OR Read_ISR_PC = '1')) THEN
			   PC( 9 DOWNTO 2 ) <= next_PC;
		END IF;
	END PROCESS;
END behavior;


