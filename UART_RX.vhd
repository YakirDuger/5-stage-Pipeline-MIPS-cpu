----------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
----------------------------------------------------------------------
-- This file contains the UART Receiver.  This receiver is able to
-- receive 8 bits of serial data, one start bit, one stop bit,
-- and no parity bit.  When receive is complete o_rx_dv will be
-- driven high for one clock cycle.
-- 
-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 10 MHz Clock, 115200 baud UART
-- (10000000)/(115200) = 87
-- In our case:
-- 50 MHz Clock, 115200 baud UART - (50000000)/(115200) = 434
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
USE work.aux_package.all;
 
entity UART_RX is
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
	g_CLKS_PER_BIT : IN INTEGER     -- 50Mhz clk, 115200 
    );
end UART_RX;
 
 
architecture rtl of UART_RX is
 
  type t_SM_Main is (s_Idle, s_RX_Start_Bit, s_RX_Data_Bits, s_RX_Parity,
                     s_RX_Stop_Bit, s_Cleanup);
  signal r_SM_Main : t_SM_Main := s_Idle;
 
  signal r_RX_Data_R : std_logic := '1';
  signal r_RX_Data   : std_logic := '1';
   
  signal r_Clk_Count : integer  := 0;
  signal r_Bit_Index : integer range 0 to 7 := 0;  -- 8 Bits Total
  signal r_RX_Byte   : std_logic_vector(7 downto 0) := (others => '0');
  signal r_RX_DV     : std_logic := '0';
  signal parity_check		 : std_logic := '0';
   
begin
 
 
  -- Purpose: Double-register the incoming data.
  -- This allows it to be used in the UART RX Clock Domain.
  -- (It removes problems caused by metastabiliy)
  p_SAMPLE : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
      r_RX_Data_R <= i_RX_Serial;
      r_RX_Data   <= r_RX_Data_R;
    end if;
  end process p_SAMPLE;
   
 
  -- Purpose: Control RX state machine
  p_UART_RX : process (i_Clk)
  begin
    if rising_edge(i_Clk) then

		-- FIX: error flags are now single-cycle pulses. They used to latch to
		-- '1' with no way back, so one framing error poisoned UCTL forever.
		-- USART.vhd holds the sticky copy that software can clear.
		FE <= '0';
		PE <= '0';
		OE <= '0';

		-- FIX: SWRST now wraps the FSM instead of preceding it. Previously the
		-- case statement re-assigned r_SM_Main on the same clock and overrode
		-- the reset, so SWRST could not abort a reception in progress.
		IF SWRST = '1' THEN
			r_SM_Main   <= s_Idle;
			r_RX_DV     <= '0';
			r_Clk_Count <= 0;
			r_Bit_Index <= 0;
			BUSY        <= '0';
		ELSE

      case r_SM_Main is
 
        when s_Idle =>
          r_RX_DV		<= '0';
          r_Clk_Count 	<= 0;
          r_Bit_Index 	<= 0;
		  BUSY			<= '0';
 
          if r_RX_Data = '0' then       -- Start bit detected
            r_SM_Main <= s_RX_Start_Bit;
          else
            r_SM_Main <= s_Idle;
          end if;
 
           
        -- Check middle of start bit to make sure it's still low
        when s_RX_Start_Bit =>
		  if r_Clk_Count = (g_CLKS_PER_BIT-1)/2 then
			if r_RX_Data = '0' then
			  r_Clk_Count <= 0;  -- reset counter since we found the middle
			  r_SM_Main   <= s_RX_Data_Bits;
			else
			  r_SM_Main   <= s_Idle;
			end if;
		  else
			r_Clk_Count <= r_Clk_Count + 1;
			r_SM_Main   <= s_RX_Start_Bit;
		  end if;
		  BUSY <= '1'; -- operation is in progress
           
        -- Wait g_CLKS_PER_BIT-1 clock cycles to sample serial data
        when s_RX_Data_Bits =>
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Data_Bits;
          else
            r_Clk_Count            <= 0;
            r_RX_Byte(r_Bit_Index) <= r_RX_Data;
             
            -- Check if we have sent out all bits
            if r_Bit_Index < 7 then
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= s_RX_Data_Bits;
            else
				IF PENA = '0' THEN
					r_Bit_Index <= 0;
					r_SM_Main   <= s_RX_Stop_Bit;
				ELSE
					r_SM_Main 	<= s_RX_Parity;
				END IF;
            end if;
          end if;
		
		-- Parity error occured.
		when s_RX_Parity =>
		  if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Parity;
          else
			PE <= parity_check XOR PEV XOR r_RX_Data;
			r_Bit_Index <= 0;
			r_SM_Main   <= s_RX_Stop_Bit;	
		  end if;
		
		
        -- Receive Stop bit.  Stop bit = 1
        when s_RX_Stop_Bit =>
          -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_RX_Stop_Bit;
          else
            r_RX_DV     <= '1';
            r_Clk_Count <= 0;
            r_SM_Main   <= s_Cleanup;
			-- Framing error if the stop bit is '0'
			IF r_RX_Data = '0' THEN
				FE <= '1';
			END IF;
          end if;
 
                   
        -- Stay here 1 clock
        when s_Cleanup =>
          r_SM_Main <= s_Idle;
          r_RX_DV   <= '0';
		  BUSY		<= '0';
             
        when others =>
          r_SM_Main <= s_Idle;
 
      end case;

		END IF;  -- SWRST

		-- NOTE: overrun cannot be detected here - it depends on whether RXBUF
		-- has been read, which only USART.vhd knows. The old test
		--   IF (i_RX_Serial = '0' AND r_RX_DV = '1')
		-- compared the raw serial line against the data-valid strobe and never
		-- indicated a real overrun. Detection now lives in USART.vhd.
    end if;
  end process p_UART_RX;
 
  o_RX_DV   	<= r_RX_DV;
  o_RX_Byte 	<= r_RX_Byte;
  parity_check 	<= (r_RX_Byte(0) XOR r_RX_Byte(1) XOR r_RX_Byte(2) XOR r_RX_Byte(3) XOR
				r_RX_Byte(4) XOR r_RX_Byte(5) XOR r_RX_Byte(6) XOR r_RX_Byte(7));
   
end rtl;