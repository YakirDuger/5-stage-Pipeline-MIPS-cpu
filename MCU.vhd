--------------- MCU System Architecture Module 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.aux_package.ALL;
-------------- ENTITY --------------------
ENTITY MCU IS
	GENERIC(MemWidth	: INTEGER := 10;
			SIM 		: BOOLEAN := FALSE;
			CtrlBusSize	: integer := 8;
			AddrBusSize	: integer := 32;
			DataBusSize	: integer := 32;
			IrqSize		: integer := 8;  -- Updated to accommodate FIR filter interrupt
			RegSize		: integer := 8
			);
	PORT( 
			reset, clock, ena	: IN	STD_LOGIC;
			HEX0, HEX1, HEX2	: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX3, HEX4, HEX5	: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			LEDR				: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			Switches			: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
			BTOUT				: OUT   STD_LOGIC;
			KEY1, KEY2, KEY3	: IN	STD_LOGIC;
			UART_RX				: IN 	STD_LOGIC := '1';
			UART_TX				: OUT	STD_LOGIC := '1';
			DEBUG_FIFO_COUNT1    : out std_logic_vector(4 downto 0);
			DEBUG_FIFO_EMPTY1    : out std_logic;
			DEBUG_FIFO_FULL1     : out std_logic;
			DEBUG_W_PTR1         : out std_logic_vector(3 downto 0);
			DEBUG_R_PTR1         : out std_logic_vector(3 downto 0);
			DEBUG_PENDING_REQ1   : out std_logic;
			DEBUG_REQ_TOG_FIR1  : out std_logic;
			DEBUG_ACK_TOG_FIFO1 : out std_logic;
			DEBUG_OUTSTANDING1   : out std_logic;
			DEBUG_SAMPLE_VALID1  : out std_logic;
			DEBUG_Y_VALID_R1     : out std_logic;
			DEBUG_FIFO_DATA1     : out std_logic_vector(23 downto 0);
			DEBUG_Y_OUTPUT1      : out std_logic_vector(23 downto 0)
			
		);
END MCU;
------------ ARCHITECTURE ----------------
ARCHITECTURE structure OF MCU IS
	

	SIGNAL resetSim		: STD_LOGIC;
	SIGNAL enaSim		: STD_LOGIC;

	-- TEMP SIGNALS - DELETE LATER --
	SIGNAL PC			:	STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL CLKCNT		: 	STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL STCNT		: 	STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL FHCNT		: 	STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL BPADD		: 	STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ST_trigger	: 	STD_LOGIC;
	
	-- CHIP SELECT SIGNALS --
	SIGNAL CS_LEDR, CS_SW, CS_KEY		: STD_LOGIC;
	SIGNAL CS_HEX0_HEX1, CS_HEX2_HEX3, CS_HEX4_HEX5	: STD_LOGIC;
	-- FIR Filter chip selects
	SIGNAL CS_FIRCTL, CS_FIRIN, CS_FIROUT	: STD_LOGIC;
	SIGNAL CS_COEF3_0, CS_COEF7_4		: STD_LOGIC;

	
	
	-- GPIO SIGNALS -- 
	SIGNAL MemReadBus	: 	STD_LOGIC;
	SIGNAL MemWriteBus	:	STD_LOGIC;
	SIGNAL ControlBus	: 	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
	SIGNAL AddressBus	: 	STD_LOGIC_VECTOR(AddrBusSize-1 DOWNTO 0);
	SIGNAL DataBus		: 	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	
	-- BASIC TIMER --
	SIGNAL BTCTL		:	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
	SIGNAL BTCNT		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL BTCCR0		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL BTCCR1		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL BTIFG		:	STD_LOGIC;

	-- FIR FILTER --
	SIGNAL FIRCTL		:	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
	SIGNAL FIRCTL_STATUS	:	STD_LOGIC_VECTOR(CtrlBusSize-1 DOWNTO 0);
	SIGNAL FIRIN		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL FIROUT		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL FIRIFG		:	STD_LOGIC;
	-- FIR Coefficients stored as packed words
	SIGNAL COEF3_0		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);
	SIGNAL COEF7_4		:	STD_LOGIC_VECTOR(DataBusSize-1 DOWNTO 0);

	
	-- INTERRUPT MODULE --
	SIGNAL IntrEn		:	STD_LOGIC_VECTOR(RegSize-1 DOWNTO 0);
	SIGNAL IFG			:	STD_LOGIC_VECTOR(RegSize-1 DOWNTO 0);
	SIGNAL TypeReg		:	STD_LOGIC_VECTOR(RegSize-1 DOWNTO 0);
	SIGNAL IntrSrc		:	STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	SIGNAL IRQ_OUT		:	STD_LOGIC_VECTOR(IrqSize-1 DOWNTO 0);
	SIGNAL IntrTx		:	STD_LOGIC;
	SIGNAL IntrRx		:	STD_LOGIC;
	SIGNAL INTR			:	STD_LOGIC;
	SIGNAL INTA			:	STD_LOGIC;  
	SIGNAL GIE			:	STD_LOGIC;
	SIGNAL INTR_Active	:	STD_LOGIC;
	SIGNAL CLR_IRQ		:	STD_LOGIC_VECTOR(7 DOWNTO 0);
	-- Uart
	SIGNAL IFG_STATUS_ERROR : STD_LOGIC;
	signal DEBUG_FIFO_COUNT    : std_logic_vector(4 downto 0);
	signal DEBUG_FIFO_EMPTY   : std_logic;
	signal DEBUG_FIFO_FULL    : std_logic;
	signal DEBUG_W_PTR        : std_logic_vector(3 downto 0);
	signal DEBUG_R_PTR        : std_logic_vector(3 downto 0);
	signal DEBUG_PENDING_REQ  : std_logic;
	signal DEBUG_REQ_TOG_FIR : std_logic;
	signal DEBUG_ACK_TOG_FIFO: std_logic;
	signal DEBUG_OUTSTANDING  : std_logic;
	signal DEBUG_SAMPLE_VALID : std_logic;
	signal DEBUG_Y_VALID_R    : std_logic;
	signal DEBUG_FIFO_DATA    : std_logic_vector(23 downto 0);
	signal DEBUG_Y_OUTPUT     : std_logic_vector(23 downto 0);
	signal clock_div          : std_logic;
	
BEGIN	

	-------------------------- FPGA or ModelSim -----------------------
	resetSim 	<= reset WHEN SIM ELSE not reset;


	
	CPU: MIPS
		GENERIC MAP(
					MemWidth	=> MemWidth,
					SIM 		=> SIM)
		PORT MAP(
					reset		=> resetSim,
					clock		=> clock,
					ena			=> ena,
					PC			=> PC,
					CLKCNT		=> CLKCNT,
					STCNT		=> STCNT,
					FHCNT		=> FHCNT,
					BPADD		=> BPADD,
					ST_trigger	=> ST_trigger,
					ControlBus	=> ControlBus,
					MemReadBus	=> MemReadBus,
					MemWriteBus	=> MemWriteBus,
					AddressBus	=> AddressBus,
					GIE			=> GIE,
					INTR		=> INTR,
					INTA		=> INTA,
					INTR_Active	=> INTR_Active,
					CLR_IRQ		=> CLR_IRQ,
					DataBus		=> DataBus,
					FIROUT		=> FIROUT,
					BTCNT		=> BTCNT,
					CS_FIROUT	=> CS_FIROUT,
					COEF3_0		=> COEF3_0,
					COEF7_4		=> COEF7_4,
					CS_COEF3_0	=> CS_COEF3_0,
					CS_COEF7_4	=> CS_COEF7_4,
					FIRCTL_STATUS	=> FIRCTL_STATUS,
					CS_FIRCTL		=> CS_FIRCTL
		);
		

	OAD : 	OptAddrDecoder
	PORT MAP(	reset		=> resetSim,
				AddressBus	=> AddressBus(11 DOWNTO 0),
				CS_LEDR		=> CS_LEDR,
				CS_SW		=> CS_SW,
				CS_KEY		=> CS_KEY,
				CS_HEX0_HEX1		=> CS_HEX0_HEX1,
				CS_HEX2_HEX3		=> CS_HEX2_HEX3,
				CS_HEX4_HEX5		=> CS_HEX4_HEX5,
				-- FIR Filter chip selects
				CS_FIRCTL	=> CS_FIRCTL,
				CS_FIRIN	=> CS_FIRIN,
				CS_FIROUT	=> CS_FIROUT,
				CS_COEF3_0	=> CS_COEF3_0,
				CS_COEF7_4	=> CS_COEF7_4
				);
		
	
	IO_interface: GPIO
		PORT MAP(
			INTA		=> INTA,
			MemReadBus	=> MemReadBus,
			clock		=> clock,
			reset		=> resetSim,
			MemWriteBus	=> MemWriteBus,
			AddressBus	=> AddressBus,
			DataBus		=> DataBus,
			HEX0		=> HEX0,
			HEX1		=> HEX1,
			HEX2		=> HEX2,
			HEX3		=> HEX3,
			HEX4		=> HEX4,
			HEX5		=> HEX5,
			LEDR		=> LEDR,
			Switches	=> Switches,
			CS_LEDR		=> CS_LEDR,
			CS_SW		=> CS_SW,
			CS_HEX0_HEX1		=> CS_HEX0_HEX1,
			CS_HEX2_HEX3		=> CS_HEX2_HEX3,
			CS_HEX4_HEX5		=> CS_HEX4_HEX5

		);

	CLK_DIVIDER_inst: CLOCK_DIVIDER
		PORT MAP(
			clk_in	=> clock,
			reset	=> resetSim,
			clk_out	=> clock_div
		);

	-- BTIMER and FIR Filter Memory-Mapped I/O with proper reset
	PROCESS(clock, resetSim)
	BEGIN
		if (resetSim = '1') then
			-- Reset all memory-mapped registers to known values
			BTCTL <= (others => '0');
			BTCCR0 <= (others => '0');
			BTCCR1 <= (others => '0');
			-- Initialize FIR registers to prevent XXX propagation
			FIRCTL <= (others => '0');
			FIRIN <= (others => '0');
			COEF3_0 <= (others => '0');
			COEF7_4 <= (others => '0');
		elsif (falling_edge(clock)) then
			-- BTIMER Registers
			if(AddressBus(11 DOWNTO 0) = X"81C" AND MemWriteBus = '1') then
				BTCTL <= ControlBus;
			END IF;
			if(AddressBus(11 DOWNTO 0) = X"824" AND MemWriteBus = '1') then
				BTCCR0 <= DataBus;
			END IF;
			if(AddressBus(11 DOWNTO 0) = X"828" AND MemWriteBus = '1') then
				BTCCR1 <= DataBus;
			END IF;
			
			-- FIR Filter Registers with FIFOWEN auto-clear
			if(CS_FIRCTL = '1' AND MemWriteBus = '1') then
				FIRCTL <= DataBus(CtrlBusSize-1 DOWNTO 0);
			-- AUTO-CLEAR FIFOWEN after one cycle (hardware requirement)
			ELSIF(FIRCTL(5) = '1') THEN  -- FIFOWEN bit is set
				FIRCTL(5) <= '0';        -- Auto-clear FIFOWEN to 0
			END IF;
			if(CS_FIRIN = '1' AND MemWriteBus = '1') then
				FIRIN <= DataBus;
			END IF;
			if(CS_COEF3_0 = '1' AND MemWriteBus = '1') then
				COEF3_0 <= DataBus;
			END IF;
			if(CS_COEF7_4 = '1' AND MemWriteBus = '1') then
				COEF7_4 <= DataBus;
			END IF;
		END IF;
		
	END PROCESS;
	


	
	Basic_Timer: BTIMER
		PORT MAP(
			mclk_i	=> clock,
			rst_i	=> resetSim,
			BTCTL	=> BTCTL,
			BTCCR0	=> BTCCR0,
			BTCCR1	=> BTCCR1,
			BTCNT	=> BTCNT,
			BTIFG	=> BTIFG,
			PWMout	=> BTOUT
		);

	-- RE-ENABLED: FIR filter with proper XXX contamination prevention
	FIR_Filter_inst: FIR_FILTER
		GENERIC MAP(
			DATA_WIDTH => 24,
			COEF_WIDTH => 8,
			M_TAPS => 8,
			Q_PARAM => 8,
			FIFO_DEPTH => 16
		)
		PORT MAP(
			FIRCLK	=> clock_div,
			FIFOCLK	=> clock,
			FIRCTL	=> FIRCTL,
			FIRCTL_STATUS	=> FIRCTL_STATUS,
			FIRIN	=> FIRIN,
			FIROUT	=> FIROUT,
			FIRIFG	=> FIRIFG,
			CS_FIROUT => CS_FIROUT,
			-- Extract coefficients from packed words (8-bit each)
			COEF0	=> COEF3_0(7 downto 0),   -- Coefficient 0: bits 7:0
			COEF1	=> COEF3_0(15 downto 8),  -- Coefficient 1: bits 15:8
			COEF2	=> COEF3_0(23 downto 16), -- Coefficient 2: bits 23:16
			COEF3	=> COEF3_0(31 downto 24), -- Coefficient 3: bits 31:24
			COEF4	=> COEF7_4(7 downto 0),   -- Coefficient 4: bits 7:0
			COEF5	=> COEF7_4(15 downto 8),  -- Coefficient 5: bits 15:8
			COEF6	=> COEF7_4(23 downto 16), -- Coefficient 6: bits 23:16
			COEF7	=> COEF7_4(31 downto 24),  -- Coefficient 7: bits 31:24
			DEBUG_FIFO_COUNT    => DEBUG_FIFO_COUNT,
			DEBUG_FIFO_EMPTY    => DEBUG_FIFO_EMPTY,
			DEBUG_FIFO_FULL     => DEBUG_FIFO_FULL,
			DEBUG_W_PTR         => DEBUG_W_PTR,
			DEBUG_R_PTR         => DEBUG_R_PTR,
			DEBUG_PENDING_REQ   => DEBUG_PENDING_REQ,
			DEBUG_REQ_TOG_FIR  => DEBUG_REQ_TOG_FIR,
			DEBUG_ACK_TOG_FIFO => DEBUG_ACK_TOG_FIFO,
			DEBUG_OUTSTANDING   => DEBUG_OUTSTANDING,
			DEBUG_SAMPLE_VALID  => DEBUG_SAMPLE_VALID,
			DEBUG_Y_VALID_R     => DEBUG_Y_VALID_R,
			DEBUG_FIFO_DATA     => DEBUG_FIFO_DATA,
			DEBUG_Y_OUTPUT      => DEBUG_Y_OUTPUT
		);
		
	DEBUG_FIFO_COUNT1 <= DEBUG_FIFO_COUNT;
	DEBUG_FIFO_EMPTY1 <= DEBUG_FIFO_EMPTY;
	DEBUG_FIFO_FULL1 <= DEBUG_FIFO_FULL;
	DEBUG_W_PTR1 <= DEBUG_W_PTR;
	DEBUG_R_PTR1 <= DEBUG_R_PTR;
	DEBUG_PENDING_REQ1 <= DEBUG_PENDING_REQ;
	DEBUG_REQ_TOG_FIR1 <= DEBUG_REQ_TOG_FIR;
	DEBUG_ACK_TOG_FIFO1 <= DEBUG_ACK_TOG_FIFO;
	DEBUG_OUTSTANDING1 <= DEBUG_OUTSTANDING;
	DEBUG_SAMPLE_VALID1 <= DEBUG_SAMPLE_VALID;
	DEBUG_Y_VALID_R1 <= DEBUG_Y_VALID_R;
	DEBUG_FIFO_DATA1 <= DEBUG_FIFO_DATA;
	DEBUG_Y_OUTPUT1 <= DEBUG_Y_OUTPUT;


	-- Interrupt sources: KEY3, KEY2, KEY1, BTIFG, FIRIFG, IntrTx, IntrRx (expand to 7 bits)
	-- Correct interrupt source mapping to match interrupt controller expectations:
	-- IntrSrc(6) -> FIR Filter, IntrSrc(5) -> KEY3, IntrSrc(4) -> KEY2, IntrSrc(3) -> KEY1, 
	-- IntrSrc(2) -> BTIMER, IntrSrc(1) -> UART TX, IntrSrc(0) -> UART RX
	IntrSrc	<= FIRIFG & FIRIFG & (NOT KEY3) & (NOT KEY2) & (NOT KEY1) & BTIFG & IntrTx & IntrRx;
	Intr_Controller: INTERRUPT
		GENERIC MAP(
			DataBusSize	=> DataBusSize,
			AddrBusSize	=> AddrBusSize,
			IrqSize		=> IrqSize,
			RegSize 	=> RegSize
		)
		PORT MAP(
			reset		=> resetSim,
		    clock		=> clock,
		    MemReadBus	=> MemReadBus,
		    MemWriteBus	=> MemWriteBus,
		    AddressBus	=> AddressBus,
		    DataBus		=> DataBus,
		    IntrSrc		=> IntrSrc,
		    ChipSelect	=> '0',
		    INTR		=> INTR,
		    INTA		=> INTA,
			IRQ_OUT		=> IRQ_OUT,
			INTR_Active	=> INTR_Active,
			CLR_IRQ_OUT	=> CLR_IRQ,
			IFG_STATUS_ERROR => IFG_STATUS_ERROR,
		    GIE			=> GIE
		);
		
		
	---- Uart Support
	UsartSupport: USART
		GENERIC MAP(
			DataBusSize	=> DataBusSize,
			AddrBusSize	=> 12,
			IrqSize		=> IrqSize,
			RegSize 	=> RegSize			
		)
		PORT MAP(
			clock	 		=> clock,
			reset		 	=> resetSim,
			RXIFG			=> IntrRx,
			TXIFG			=> IntrTx,
			B_RX			=> UART_RX,
			B_TX			=> UART_TX,
			IFG_STATUS_ERROR=> IFG_STATUS_ERROR,
			AddressBus		=> AddressBus(11 DOWNTO 0),
			DataBus			=> DataBus,
			MemReadBus		=> MemReadBus,
		    MemWriteBus		=> MemWriteBus
		);
		
END structure;