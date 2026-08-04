----------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
----------------------------------------------------------------------
-- This file contains the UART Transmitter.  This transmitter is able
-- to transmit 8 bits of serial data, one start bit, one stop bit,
-- and no parity bit.  When transmit is complete o_TX_Done will be
-- driven high for one clock cycle.
--
-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 10 MHz Clock, 115200 baud UART
-- (10000000)/(115200) = 87
-- In our case:
-- 50 MHz Clock, 115200 baud UART - (50000000)/(115200) = 434
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE work.aux_package.all;
 
entity UART_TX is
  port (
    i_Clk       : in  std_logic;
    i_TX_DV     : in  std_logic;
    i_TX_Byte   : in  std_logic_vector(7 downto 0);
    o_TX_Active : out std_logic; -- BUSY
    o_TX_Serial : out std_logic;
    o_TX_Done   : out std_logic;
	SWRST		: in  std_logic := '0'; -- Software reset enable
	PENA		: in  std_logic := '0'; -- Parity enable
	PEV			: in  std_logic := '0'; -- FIX: parity select (0=even,1=odd)
	g_CLKS_PER_BIT : IN INTEGER     -- 50Mhz clk, 115200 
    );
end UART_TX;
 
 
architecture RTL of UART_TX is
 
  type t_SM_Main is (s_Idle, s_TX_Start_Bit, s_TX_Data_Bits, s_TX_Parity,
                     s_TX_Stop_Bit, s_Cleanup);
  signal r_SM_Main : t_SM_Main := s_Idle;
 
  signal r_Clk_Count 		: integer := 0;
  signal r_Bit_Index 		: integer range 0 to 7 := 0;  -- 8 Bits Total
  signal r_TX_Data   		: std_logic_vector(7 downto 0) := (others => '0');
  signal r_TX_Done   		: std_logic := '0';
  signal parity_check		: std_logic := '0';
  signal TX_VLD				: std_logic := '0';
   
begin
 
   
  p_UART_TX : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
	
		-- VALID BIT
       	if i_TX_DV = '0' then
				TX_VLD <= '0';
		else
				TX_VLD <= '1';
		end if;
		
		-- FIX: SWRST now wraps the FSM. Previously the case statement ran
		-- afterwards and overrode r_SM_Main, so SWRST could not abort a
		-- transmission already in progress.
		IF SWRST = '1' THEN
			r_SM_Main   <= s_Idle;
			o_TX_Serial <= '1';
			o_TX_Active <= '0';
			r_TX_Done   <= '0';
			r_Clk_Count <= 0;
			r_Bit_Index <= 0;
		ELSE
		--- FSM ----
      case r_SM_Main is
 
        when s_Idle =>
          o_TX_Active <= '0';			-- BUSY
          o_TX_Serial <= '1';         -- Drive Line High for Idle
          r_TX_Done   <= '0';
          r_Clk_Count <= 0;
          r_Bit_Index <= 0;
 
          if TX_VLD = '1' then
            r_TX_Data <= i_TX_Byte;
            r_SM_Main <= s_TX_Start_Bit;
          else
            r_SM_Main <= s_Idle;
          end if;
 
           
        -- Send out Start Bit. Start bit = 0
        when s_TX_Start_Bit =>
          o_TX_Active <= '1'; -- BUSY
          o_TX_Serial <= '0';
 
          -- Wait g_CLKS_PER_BIT-1 clock cycles for start bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Start_Bit;
          else
            r_Clk_Count <= 0;
            r_SM_Main   <= s_TX_Data_Bits;
          end if;
 
           
        -- Wait g_CLKS_PER_BIT-1 clock cycles for data bits to finish          
        when s_TX_Data_Bits =>
          o_TX_Serial <= r_TX_Data(r_Bit_Index);
           
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Data_Bits;
          else
            r_Clk_Count <= 0;
             
            -- Check if we have sent out all bits
            if r_Bit_Index < 7 then
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= s_TX_Data_Bits;
            else
			  if PENA = '0' then
				r_Bit_Index <= 0;
				r_SM_Main   <= s_TX_Stop_Bit;
			  else
				r_SM_Main   <= s_TX_Parity;
			  end if;
            end if;
          end if;
		
		-- Parity error occured.
 		when s_TX_Parity =>
			o_TX_Serial <= parity_check XOR PEV;   -- FIX: PEV was ignored
			if r_Clk_Count < g_CLKS_PER_BIT-1 then
				r_Clk_Count <= r_Clk_Count + 1;
				r_SM_Main   <= s_TX_Parity;
			else
				r_Clk_Count <= 0;
				r_SM_Main   <= s_TX_Stop_Bit;
			end if;
			  
        -- Send out Stop bit.  Stop bit = 1
        when s_TX_Stop_Bit =>
          o_TX_Serial <= '1';
 
          -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if r_Clk_Count < g_CLKS_PER_BIT-1 then
            r_Clk_Count <= r_Clk_Count + 1;
            r_SM_Main   <= s_TX_Stop_Bit;
          else
            r_Clk_Count <= 0;
            r_SM_Main   <= s_Cleanup;
          end if;
 
                   
        -- Stay here 1 clock
        when s_Cleanup =>
          o_TX_Active <= '0';
          r_TX_Done   <= '1';
          r_SM_Main   <= s_Idle;
           
             
        when others =>
          r_SM_Main <= s_Idle;
 
      end case;

		END IF;  -- SWRST
    end if;
  end process p_UART_TX;
 
  o_TX_Done <= r_TX_Done;
  -- FIX: computed from the latched byte, not the live TXBUF port, so a
  -- TXBUF write during a transmission cannot corrupt the parity bit.
  parity_check 	<= (r_TX_Data(0) XOR r_TX_Data(1) XOR r_TX_Data(2) XOR r_TX_Data(3) XOR
				r_TX_Data(4) XOR r_TX_Data(5) XOR r_TX_Data(6) XOR r_TX_Data(7));  
   
end RTL;