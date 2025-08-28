LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
USE work.aux_package.all;
--------------------------------------------------------
entity Shifter is
    generic (
        n : integer := 8;
        k : integer := 3;
        m : integer := 4
    );
    port (
        x,y           : in  std_logic_vector(n-1 downto 0);
        ALUFN       : in std_logic_vector(2 downto 0);
        res : out std_logic_vector(n-1 downto 0);
        cout: out std_logic
    );
end Shifter;

--------------------------------------------------------
architecture dataflow of Shifter is
    subtype vector is std_logic_vector(n-1 downto 0);
    type matrix is array (0 to k) of vector;
    signal shiftMat : matrix;
    signal carry : std_logic_vector(k-1 downto 0);
    signal zero_vector : std_logic_vector(n-1 downto 0) := (others => '0');

begin
    --Initialization of firt stage with input
    first_stage: for i in 0 to n-1 generate
        shiftMat(0)(i) <= y(i) when (ALUFN = "000") else
                        y(n-1-i) when (ALUFN = "001") else --reverse bits for shift right
                        '0';
    end generate first_stage;
    
    next_stages: for i in 1 to k generate      
        -- Adding zeros to the shift matrix
        shiftMat(i)(2**(i-1)-1 DOWNTO 0)<= zero_vector(2**(i-1)-1 DOWNTO 0)  when x(i-1)='1' else
                                    shiftMat(i-1)(2**(i-1)-1 DOWNTO 0)  when x(i-1)='0';
                    
        -- Perform shift when needed
        shiftMat(i)(n-1 DOWNTO 2**(i-1)) <=shiftMat(i-1)(n-1-2**(i-1) DOWNTO 0)  when x(i-1)='1' else
                                shiftMat(i-1)(n-1 DOWNTO 2**(i-1))  when x(i-1)='0';

        end generate;	

        -- Writing results to output vector	
        invert: for i in 0 to n-1 generate
        res(i)	<= 	shiftMat(k)(i) 	WHEN (ALUFN="000") else
                    shiftMat(k)(n-1-i) WHEN  (ALUFN="001") ELSE -- Reverse bits for shift right
                    '0' ;
        end generate; 

        -- Writing the cout signal
        carry(0) <= shiftMat(0)(n-1) when x(0)= '1' else 
                    '0'	WHEN x(0)= '0';
		
        carry_out : for i in 1 to k-1 generate
        carry(i)<=  shiftMat(i)(n-2**(i))	WHEN x(i)='1' else
                carry(i-1)  WHEN x(i) = '0' ELSE
                '0';
            end generate;

        cout<= carry(k-1) WHEN (ALUFN = "000" or ALUFN = "001") ELSE
        '0';


end dataflow;
