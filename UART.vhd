-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 10 MHz Clock, 115200 baud UART
-- (10000000)/(115200) = 87
-- 50 MHz Clock, 9600 baud UART - (50000000)/(9600) = 5208
-- In our case:
-- 50 MHz Clock, 115200 baud UART - (50000000)/(115200) = 434

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE work.aux_package.all;
 
entity USART is
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
			MemReadBus	: IN	STD_LOGIC := '0';
			MemWriteBus	: IN	STD_LOGIC := '0'
		);
end USART;
 
 
architecture structure of USART is

	SIGNAL UCTL											: STD_LOGIC_VECTOR( 7 DOWNTO 0 ) := "00001001";
	SIGNAL RXBUF										: STD_LOGIC_VECTOR( 7 DOWNTO 0 ) := "00000000";
	SIGNAL TXBUF										: STD_LOGIC_VECTOR( 7 DOWNTO 0 ) := "00000000";
	SIGNAL g_CLKS_PER_BIT								: integer;

	SIGNAL FULLBUFF_FG									: STD_LOGIC := '0';
	SIGNAL RX_NEW										: STD_LOGIC := '0';  -- 1-clock pulse per byte
	SIGNAL RX_OVERRUN									: STD_LOGIC := '0';  -- 1-clock pulse
	SIGNAL TX_PEND										: STD_LOGIC := '0';  -- transmit request held
	SIGNAL RX_BUSY										: STD_LOGIC := '0';
	SIGNAL TX_BUSY										: STD_LOGIC := '0';
	SIGNAL s_BUSY										: STD_LOGIC := '0';
	SIGNAL Data_RX										: STD_LOGIC_VECTOR( 7 DOWNTO 0 );
	SIGNAL Data_VLD_RX									: STD_LOGIC;	
	SIGNAL Data_VLD_TX									: STD_LOGIC := '0';  -- FIX: was uninitialised
	SIGNAL s_TX_Done									: STD_LOGIC;
	---- Error signals
	SIGNAL FRAMING_ERROR								: STD_LOGIC;
	SIGNAL PARITY_ERROR									: STD_LOGIC;
	SIGNAL OVERRUN_ERROR								: STD_LOGIC;

	--- UCTL ALIAS	
	ALIAS SWRST		IS UCTL(0);
	ALIAS PENA		IS UCTL(1);
	ALIAS PEV		IS UCTL(2);
	ALIAS BAUDRATE	IS UCTL(3);
	ALIAS FE		IS UCTL(4);
	ALIAS PE		IS UCTL(5);
	ALIAS OE	IS UCTL(6);
	ALIAS BUSY		IS UCTL(7);
	
 
begin
	
	
	g_CLKS_PER_BIT <= 434 WHEN BAUDRATE = '1' ELSE 5208;

	

	
	
-- OUTPUT TO MCU -- 
DataBus <=	X"000000" 		& UCTL 		WHEN (AddressBus = X"818" AND MemReadBus = '1') ELSE
			X"000000"		& RXBUF 	WHEN (AddressBus = X"819" AND MemReadBus = '1') ELSE
			X"000000"		& TXBUF		WHEN (AddressBus = X"81A" AND MemReadBus = '1') ELSE
			(OTHERS => 'Z');		
	
	
----- Error -------
	-- pulses, so the interrupt controller (which latches on a rising edge)
	-- sees one edge per event
	IFG_STATUS_ERROR <= FRAMING_ERROR OR PARITY_ERROR OR RX_OVERRUN;
----- UCTL(7) --------
	s_BUSY <= RX_BUSY OR TX_BUSY ;
----- RX/TX Intr	
	-- FIX: RXIFG used to be the FULLBUFF_FG level. A byte arriving while the
	-- previous one was still unread produced no new rising edge, so the
	-- interrupt controller never saw it. It is now one pulse per byte.
	RXIFG <= RX_NEW;
	TXIFG <= s_TX_Done;	

------------ RX PORT MAP	
    RX_RECEIVE : entity work.UART_RX
	PORT MAP (	
				--Inputs:
				i_Clk			=> clock,
				i_RX_Serial		=> B_RX,
				o_RX_DV 		=> Data_VLD_RX,
				o_RX_Byte		=> Data_RX,	
				SWRST			=> SWRST,
				PENA			=> PENA,
				PEV				=> PEV,	
				FE				=> FRAMING_ERROR,			
				PE				=> PARITY_ERROR,
				OE				=> OVERRUN_ERROR,
				BUSY			=> RX_BUSY,
				g_CLKS_PER_BIT 	=> g_CLKS_PER_BIT
				);

-------------- TX PORT MAP
    TX_TRANSMIT : entity work.UART_TX
	PORT MAP (	
				i_Clk			=> clock,
				i_TX_DV			=> Data_VLD_TX,
				i_TX_Byte 		=> TXBUF,
				o_TX_Active		=> TX_BUSY,
				o_TX_Serial		=> B_TX,
				o_TX_Done		=> s_TX_Done,
				SWRST			=> SWRST,
				PENA			=> PENA,
				PEV				=> PEV,
				g_CLKS_PER_BIT 	=> g_CLKS_PER_BIT
				); 
 
 
---- UCTL / BUFFER PROCESS

	PROCESS (clock)
	BEGIN
		IF rising_edge(clock) THEN

			IF (reset = '1') THEN
				UCTL        <= "00001001";
				RXBUF       <= "00000000";
				TXBUF       <= "00000000";
				FULLBUFF_FG <= '0';
				RX_NEW      <= '0';
				RX_OVERRUN  <= '0';
				TX_PEND     <= '0';
				-- FIX: Data_VLD_TX was never assigned during reset, so it sat at
				-- 'U'. UART_TX read that as "not '0'" and launched a spurious
				-- frame at power-up, blocking real writes for a whole frame time.
				Data_VLD_TX <= '0';
			ELSE

				RX_NEW     <= '0';   -- default: single-cycle pulses
				RX_OVERRUN <= '0';

				--------------------------------------------------------
				-- UCTL
				-- FE/PE/OE are sticky here and cleared by writing UCTL or
				-- by SWRST. UART_RX only pulses them for one clock now.
				--------------------------------------------------------
				IF (AddressBus = X"818" AND MemWriteBus = '1') THEN
					UCTL <= DataBus(7 DOWNTO 0);
				ELSIF SWRST = '1' THEN
					UCTL <= "00001001";
				ELSE
					BUSY <= s_BUSY;
					FE   <= FE OR FRAMING_ERROR;
					PE   <= PE OR PARITY_ERROR;
					OE   <= OE OR RX_OVERRUN;
				END IF;

				--------------------------------------------------------
				-- RX BUFFER
				--------------------------------------------------------
				IF (Data_VLD_RX = '1') THEN
					RXBUF       <= Data_RX;
					FULLBUFF_FG <= '1';
					RX_NEW      <= '1';
					-- real overrun: a byte lands before the previous one is read
					IF FULLBUFF_FG = '1' THEN
						RX_OVERRUN <= '1';
					END IF;
				ELSIF (AddressBus = X"819" AND MemReadBus = '1') THEN
					RXBUF       <= "00000000";
					FULLBUFF_FG <= '0';
				END IF;

				--------------------------------------------------------
				-- TX BUFFER
				-- The request is held in TX_PEND until the transmitter is
				-- free. Previously a write while busy was silently dropped.
				--------------------------------------------------------
				IF (AddressBus = X"81A" AND MemWriteBus = '1') THEN
					TXBUF       <= DataBus(7 DOWNTO 0);
					TX_PEND     <= '1';
					Data_VLD_TX <= '0';
				ELSIF (TX_PEND = '1' AND TX_BUSY = '0' AND SWRST = '0') THEN
					Data_VLD_TX <= '1';
					TX_PEND     <= '0';
				ELSE
					Data_VLD_TX <= '0';
				END IF;

			END IF;
		END IF;
	END PROCESS;
end structure;