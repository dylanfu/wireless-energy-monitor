-------------------------------------------------------------------------------
 --Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
--Inputs and Outputs for the FSM

-------------------------------------------------------------------------------
--Version 1: Adding logic to skeleton code
--Version 2: Bugfixes

-------------------------------------------------------------------------------
--External inputs and outputs
entity FSM is
 port (	
	reset		:	in std_logic;
	clk		:	in	std_logic;
	rx			:	in std_logic;
	
	--Status signals
	cmp15_s	:	in std_logic;
	cmp7_n 	:  in std_logic;
	cmp7_s	:  in std_logic;

	--Control signals
	S_res 	: out std_logic;
	Sh_en 	: out std_logic;
	S_en 		: out std_logic;
	n_en 		: out std_logic;
	load   : out std_logic;
	n_res 	: out std_logic
		);
end entity FSM;

-------------------------------------------------------------------------------
--Internal logic of FSM 
Architecture behavior of FSM is
	type usart_states is (idle, start, data, stop);
	signal CS, NS : usart_states:= idle;
	
begin

-------------------------------------------------------------------------------
--Set current state
Asynchronous_process: process (reset, clk)
 begin
	if reset = '1' then 
	 CS <= idle;
	elsif clk'event and clk = '1' then --Checking for rising edge
		CS <= NS;
	end if;
end process;

-------------------------------------------------------------------------------
--Determine next state
NextState_logic: process (CS,rx, cmp15_s, cmp7_n, cmp7_s)
 begin
	case CS is
		when idle =>                       
			if rx = '0' then	--  Check for start bit
				NS <= start;
			else
				NS <= idle;
			end if;
		
		when start =>
			if cmp7_s = '1' and rx = '1' then --False start detection
				NS <= idle;
			elsif cmp7_s = '1' then
				NS <= data;
			else 
				NS <= start;
			end if;
			
		when data =>
			if cmp15_s = '1' and cmp7_n = '1' then --Check if sampling middle of the databit
				NS <= stop;
			else 
				NS <= data;
			end if;
			
		when stop => 
			if cmp15_s = '0' then 		--Checks for stop bit
				NS <= stop;
			else 
				NS <= idle;
			end if;
	end case;
 end process;
 
-----------------------------------------
--Determine control signal outputs to datapath
Output_logic: process (CS, rx, cmp7_s, cmp15_s, cmp7_n)
 begin
	--Reset control signals
	S_res <= '0';
	s_en <= '0';
	sh_en <= '0';
	n_en <= '0';
	n_res <= '0';
	load <= '0';
	
	case CS is
		when idle =>
			--When start bit occurs reset sample counter
			if rx = '0' then		
				S_res <= '1';
			else
				S_res<= '0';
			end if;
		
		when start => 
			--If not false start, begin sampling
			if cmp7_s = '0' then
				S_en <= '1';
			else 
				S_res <=	'1';
				n_res <= '1';
				
				load <= '0';
			end if;
			
		when data =>
			--When it reaches the end of the databit, increase sample counter
			if cmp15_s = '0' then
				s_en <= '1';
			--When a data is sampled, increase databit counter
			elsif cmp15_s = '1' and cmp7_n = '0' then 
				s_res <= '1';
				sh_en <= '1';
				n_en <= '1';
			--When 7 databits have been received, sample one more
			elsif cmp15_s = '1' and cmp7_n = '1' then 
				s_res <= '1';
				sh_en <= '1';
			end if;
			
		when stop => 
			--If stop bit is received then enable the register to load new data
			if cmp15_s = '0' then 
				s_en <= '1';
			else 
				load <= '1';
			end if;
	end case;
 end process;
 -------------------------------------------------------------------------------
 
end architecture;