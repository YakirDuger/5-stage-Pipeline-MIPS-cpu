library IEEE;
USE work.cond_compilation_package.all;
use ieee.std_logic_1164.all;

package aux_package is
--------------------------- MIPS ---------------------------
	COMPONENT MIPS IS
		GENERIC (	MemWidth 	: INTEGER := 8;
					SIM 		: BOOLEAN := FALSE;
					CtrlBusSize	: integer := 8;
					AddrBusSize	: integer := 32;
					DataBusSize	: integer := 32;
					IOSize		: integer := 8
				 );
		PORT( reset, clock, ena	: IN 	STD_LOGIC; 
			-- Output important signals to pins for easy display in Simulator
			PC					: OUT  	STD_LOGIC_VECTOR(9 DOWNTO 0);
			CLKCNT				: OUT  	STD_LOGIC_VECTOR(15 DOWNTO 0);
			STCNT				: OUT  	STD_LOGIC_VECTOR(7 DOWNTO 0);
			FHCNT				: OUT  	STD_LOGIC_VECTOR(7 DOWNTO 0);
			BPADD				: IN  	STD_LOGIC_VECTOR(7 DOWNTO 0);
			ST_trigger			: OUT	STD_LOGIC;
			ControlBus			: OUT	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
			MemReadBus			: OUT 	STD_LOGIC;
			MemWriteBus			: OUT 	STD_LOGIC;
			AddressBus			: OUT	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);
			GIE					: OUT	STD_LOGIC;
			INTR				: IN	STD_LOGIC;
			INTA				: OUT	STD_LOGIC;
			INTR_Active			: IN	STD_LOGIC;
			CLR_IRQ				: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			DataBus				: INOUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
			FIROUT				: IN	STD_LOGIC_VECTOR(31 DOWNTO 0);	
			BTCNT				: IN	STD_LOGIC_VECTOR(31 DOWNTO 0);
			CS_FIROUT			: IN	STD_LOGIC;
			COEF3_0				: IN	STD_LOGIC_VECTOR(31 DOWNTO 0);
			COEF7_4				: IN	STD_LOGIC_VECTOR(31 DOWNTO 0);
			CS_COEF3_0			: IN	STD_LOGIC;
			CS_COEF7_4			: IN	STD_LOGIC;
			FIRCTL_STATUS		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			CS_FIRCTL			: IN	STD_LOGIC
			);
	END COMPONENT;

	COMPONENT Ifetch IS
	GENERIC (MemWidth	: INTEGER;
			 SIM 		: BOOLEAN);
	PORT(	Instruction						       	: OUT	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
        	PC_plus_4_out 					       	: OUT	STD_LOGIC_VECTOR( 9 DOWNTO 0 );
        	Add_result 						       	: IN 	STD_LOGIC_VECTOR( 7 DOWNTO 0 );
        	PCSrc 							       	: IN 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
      		PC_out 							       	: OUT	STD_LOGIC_VECTOR( 9 DOWNTO 0 );
			JumpAddr						       	: IN	STD_LOGIC_VECTOR( 7 DOWNTO 0 );
        	clock, ena, Stall_IF,  reset 			: IN 	STD_LOGIC;
			INTA									: IN	STD_LOGIC;
			Read_ISR_PC								: IN	STD_LOGIC;
			HOLD_PC									: IN 	STD_LOGIC;
			ISRAddr									: IN	STD_LOGIC_VECTOR(31 DOWNTO 0)
			);
	END COMPONENT;

	COMPONENT Idecode
	PORT(	read_data_1						: OUT 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			read_data_2						: OUT 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			write_register_address_0 		: OUT   STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			write_register_address_1 		: OUT   STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			write_register_address      	: IN    STD_LOGIC_VECTOR( 4 DOWNTO 0 );
			Instruction 					: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			PC_plus_4_shifted				: IN 	STD_LOGIC_VECTOR(7 DOWNTO 0);
			RegWrite						: IN 	STD_LOGIC;
			ForwardA_ID, ForwardB_ID		: IN 	STD_LOGIC;
			BranchBeq, BranchBne, Jump, JAL	: IN 	STD_LOGIC; -- Added JAL
			Stall_ID					: IN    STD_LOGIC;
			write_data				: IN	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Branch_read_data_FW			: IN	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Sign_extend 				: OUT 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			PCSrc		 				: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			JumpAddr					: OUT   STD_LOGIC_VECTOR( 7 DOWNTO 0 );
			PCBranch_addr 				: OUT 	STD_LOGIC_VECTOR(7 DOWNTO 0);
			GIE							: OUT 	STD_LOGIC;
			Read_ISR_PC					: IN	STD_LOGIC;
			EPC							: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			INTR						: IN	STD_LOGIC;
			INTR_Active					: IN	STD_LOGIC;
			CLR_IRQ						: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			clock,reset					: IN 	STD_LOGIC );
	END COMPONENT;

	COMPONENT control
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
	END COMPONENT;

	COMPONENT  Execute
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
	END COMPONENT;

	COMPONENT dmemory IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM : integer := 256
		);
		PORT(	clk_i,rst_i			: IN 	STD_LOGIC;
				dtcm_addr_i 		: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
				dtcm_data_wr_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
				MemRead_ctrl_i  	: IN 	STD_LOGIC;
				MemWrite_ctrl_i 	: IN 	STD_LOGIC;
				dtcm_data_rd_o 		: OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT WRITE_BACK IS
	PORT( 
		ALU_Result, read_data	: IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		PC_plus_4_shifted		: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		MemtoReg, Jal			: IN  STD_LOGIC;
		write_data 				: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		write_data_mux			: OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT;
		
	COMPONENT ALU_CONTROL IS
	PORT(	ALUOp 						: IN 	STD_LOGIC_VECTOR( 1 DOWNTO 0 );
			Funct 						: IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			Opcode 						: IN 	STD_LOGIC_VECTOR( 5 DOWNTO 0 );
			ALU_ctl 					: OUT   STD_LOGIC_VECTOR( 3 DOWNTO 0 ));
	END COMPONENT;
		
	COMPONENT  ALU IS
	PORT(	Ainput 			: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			Binput 			: IN 	STD_LOGIC_VECTOR( 31 DOWNTO 0 );
			ALU_ctl		 	: IN 	STD_LOGIC_VECTOR( 3 DOWNTO 0 );
			ALU_output_mux	: OUT   STD_LOGIC_VECTOR( 31 DOWNTO 0 )
			);
	END COMPONENT;
		
	COMPONENT HazardUnit IS
	PORT( 
		MemtoReg_EX, MemtoReg_MEM	 		 : IN STD_LOGIC;
		WriteReg_EX, WriteReg_MEM, WriteReg_WB : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRs_ID, RegRt_ID 					 : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegRs_EX, RegRt_EX					 : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_RegWr, MEM_RegWr, WB_RegWr		 : IN  STD_LOGIC;
		BranchBeq_ID, BranchBne_ID, Jump_ID	 : IN STD_LOGIC;
		Stall_IF, Stall_ID, Flush_EX 	 	 : OUT STD_LOGIC;
		ForwardA, ForwardB				     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		ForwardA_Branch, ForwardB_Branch		     : OUT STD_LOGIC
		);
	END 	COMPONENT;
-----------------------------------------------------------------------------------

--------------------------- GPIO ---------------------------
	COMPONENT InputPeripheral IS
		GENERIC(DataBusSize	: integer := 32);
		PORT( 
			MemRead		: IN	STD_LOGIC;
			ChipSelect	: IN 	STD_LOGIC;
			INTA		: IN	STD_LOGIC;
			Data		: OUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
			GPInput		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0)
			);
	END COMPONENT;

	COMPONENT OutputPeripheral IS
		GENERIC (SevenSeg	: BOOLEAN := TRUE; 
				 IOSize		: INTEGER := 7); -- 7 WHEN HEX, 8 WHEN LEDs
		PORT( 
			MemRead		: IN	STD_LOGIC;
			clock		: IN 	STD_LOGIC;
			reset		: IN 	STD_LOGIC;
			MemWrite	: IN	STD_LOGIC;
			ChipSelect	: IN 	STD_LOGIC;
			Data		: INOUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			GPOutput	: OUT	STD_LOGIC_VECTOR(IOSize-1 DOWNTO 0)
			);
	END COMPONENT;

	COMPONENT OptAddrDecoder IS
		PORT( 
			reset						: IN	STD_LOGIC;
			AddressBus					: IN	STD_LOGIC_VECTOR(11 DOWNTO 0);
			CS_LEDR, CS_SW, CS_KEY		: OUT	STD_LOGIC;
			CS_HEX0_HEX1, CS_HEX2_HEX3, CS_HEX4_HEX5	: OUT	STD_LOGIC;
			-- FIR Filter chip selects
			CS_FIRCTL, CS_FIRIN, CS_FIROUT	: OUT	STD_LOGIC;
			CS_COEF3_0, CS_COEF7_4		: OUT	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT SevenSegDecoder IS
	  GENERIC (SegmentSize	: integer := 7);
	  PORT (data		: in STD_LOGIC_VECTOR (3 DOWNTO 0);
			seg   		: out STD_LOGIC_VECTOR (SegmentSize-1 downto 0));
	END COMPONENT;

	COMPONENT GPIO IS
		GENERIC(CtrlBusSize	: integer := 8;
				AddrBusSize	: integer := 32;
				DataBusSize	: integer := 32
		);
		PORT( 
			-- ControlBus	: IN	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
			INTA						: IN	STD_LOGIC;
			MemReadBus					: IN 	STD_LOGIC;
			clock						: IN 	STD_LOGIC;
			reset						: IN 	STD_LOGIC;
			MemWriteBus					: IN 	STD_LOGIC;
			AddressBus					: IN	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);
			DataBus						: INOUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
			HEX0, HEX1					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX2, HEX3					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX4, HEX5					: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			LEDR						: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			Switches					: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			CS_LEDR, CS_SW				: IN 	STD_LOGIC;
			CS_HEX0_HEX1, CS_HEX2_HEX3, CS_HEX4_HEX5	: IN 	STD_LOGIC
		);
	END COMPONENT;
------------------ BASIC TIMER ---------------------------
	COMPONENT BTIMER IS
	GENERIC (
		CLOCK_DIV_WIDTH : integer := 4;  
		TIMER_WIDTH     : integer := 32   
	);
	PORT(
		mclk_i : IN STD_LOGIC;                                    
		rst_i : IN STD_LOGIC;                                      
		BTCTL : IN STD_LOGIC_VECTOR(7 DOWNTO 0);                  
		BTCCR0 : IN STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);     
		BTCCR1 : IN STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);     
		BTCNT : INOUT STD_LOGIC_VECTOR(TIMER_WIDTH-1 DOWNTO 0);   

		PWMout : OUT STD_LOGIC;                                    
		BTIFG : OUT STD_LOGIC                                      
		);
	END COMPONENT;

	------------------ FIR FILTER ---------------------------

	COMPONENT FIR_FILTER IS
		generic (
		  DATA_WIDTH : integer := 24;   -- UQ24.0
		  COEF_WIDTH : integer := 8;    -- UQ0.8
		  M_TAPS     : integer := 8;
		  Q_PARAM    : integer := 8;    -- fractional bits (coeff Q)
		  FIFO_DEPTH : integer := 16
		);
		port (
		  FIRCLK   : in  std_logic;
		  FIFOCLK  : in  std_logic;
	  
		  -- Control Register Interface
		  FIRCTL        : in  std_logic_vector(7 downto 0);  -- sw writes
		  FIRCTL_STATUS : out std_logic_vector(7 downto 0);  -- sw reads
	  
		  -- Data
		  FIRIN   : in  std_logic_vector(31 downto 0);  -- {0@8, x(23:0)}
		  FIROUT  : out std_logic_vector(31 downto 0);  -- {0@8, y(23:0)}
	  
		  -- Interrupt (new output ready pulse in FIRCLK domain)
		  FIRIFG  : out std_logic;
	  
		  -- Coefficients (UQ0.8)
		  COEF0 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF1 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF2 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF3 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF4 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF5 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF6 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  COEF7 : in std_logic_vector(COEF_WIDTH-1 downto 0);
		  CS_FIROUT : in std_logic;
		          -- DEBUG OUTPUTS - Add these new signals
		-- FIFO Status
		DEBUG_FIFO_COUNT    : out std_logic_vector(4 downto 0);    -- FIFO count (0-16)
		DEBUG_FIFO_EMPTY   : out std_logic;                        -- FIFO empty flag
		DEBUG_FIFO_FULL    : out std_logic;                        -- FIFO full flag
		DEBUG_W_PTR        : out std_logic_vector(3 downto 0);     -- Write pointer
		DEBUG_R_PTR        : out std_logic_vector(3 downto 0);     -- Read pointer
		
		-- Handshake Status
		DEBUG_PENDING_REQ  : out std_logic;                        -- Pending request flag
		DEBUG_REQ_TOG_FIR : out std_logic;                         -- Request toggle from FIR
		DEBUG_ACK_TOG_FIFO: out std_logic;                         -- Ack toggle to FIR
		DEBUG_OUTSTANDING  : out std_logic;                         -- Outstanding request flag
		
		-- FIR Processing Status
		DEBUG_SAMPLE_VALID : out std_logic;                         -- Sample valid pulse
		DEBUG_Y_VALID_R    : out std_logic;                         -- Output valid flag
		DEBUG_FIFO_DATA    : out std_logic_vector(23 downto 0);    -- Current FIFO data being processed
		DEBUG_Y_OUTPUT     : out std_logic_vector(23 downto 0)     -- Current FIR output
		);
	  END COMPONENT;

------------------ Interrupt Controller --------------------
	COMPONENT INTERRUPT IS
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
	END COMPONENT;

------------------ UART --------------------
	COMPONENT USART is
		GENERIC(DataBusSize		: integer := 32;
				AddrBusSize		: integer := 12;
				IrqSize	    	: integer := 8;
				RegSize			: integer := 8
				);
		PORT(
				clock, reset      	: in  	std_logic;
				RXIFG 		: out  	std_logic := '0';
				TXIFG		: out	std_logic := '0';
				B_RX		: in	std_logic := '1';
				B_TX     	: out 	std_logic := '1';
				IFG_STATUS_ERROR	:	out	std_logic;
				AddressBus	: IN	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);	
				DataBus		: INOUT	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
				MemReadBus	: IN	STD_LOGIC;
				MemWriteBus	: IN	STD_LOGIC
			);
	end COMPONENT;
	
	COMPONENT UART_RX is
		port (
			i_Clk       : in 	std_logic;
			i_RX_Serial : in  	std_logic := '1';
			o_RX_DV     : out	std_logic;
			o_RX_Byte   : out 	std_logic_vector(7 downto 0);
			-- UCTL register bits
			SWRST		: in	std_logic := '0';
			PENA		: in	std_logic := '0';
			PEV			: in	std_logic := '0';
			FE			: out	std_logic := '0';
			PE			: out	std_logic := '0';
			OE			: out	std_logic := '0';
			BUSY		: out	std_logic := '0';
			g_CLKS_PER_BIT	: IN INTEGER
		);
	end COMPONENT;

	COMPONENT UART_TX is
		port (
			i_Clk       : in  std_logic;
			i_TX_DV     : in  std_logic;
			i_TX_Byte   : in  std_logic_vector(7 downto 0);
			o_TX_Active : out std_logic; -- BUSY
			o_TX_Serial : out std_logic;
			o_TX_Done   : out std_logic;
			SWRST		: in  std_logic := '0'; -- Software reset enable
			PENA		: in  std_logic := '0'; -- Parity enable
			g_CLKS_PER_BIT	: IN INTEGER
		);
	end COMPONENT;


	COMPONENT CLOCK_DIVIDER IS
    GENERIC(
        DIVIDE_FACTOR : INTEGER := 7500  -- Default: 75MHz -> 10KHz
    );
    PORT( 
        clk_in      : IN  STD_LOGIC;    -- Input clock (PLL output)
        reset       : IN  STD_LOGIC;    -- Reset (active high)
        clk_out     : OUT STD_LOGIC     -- Output divided clock
    );
	END COMPONENT;

end aux_package;

