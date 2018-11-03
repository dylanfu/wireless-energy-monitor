-------------------------------------------------------------------------------
 --Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
-------------------------------------------------------------------------------

--Version 1: Adding logic to skeleton code provided
--Version 2: Bug fixes
--Version 3: Adding 7 segment decoder and position mux
--Version 4: Adding registers to store voltage, current and powerDigit
--Version 5: Add push button functionality (and debouncer)
--Version 6: Finalisation
-------------------------------------------------------------------------------

--Inputs and outputs of Datapath 
entity Datapath is
 port (	
	--External Inputs
	rx				:	in	std_logic;
	clk			:	in	std_logic;
	PB0			:  in std_logic;
	PB1			:  in std_logic;
	
	--Control signals from FSM
	S_res 		: 	in std_logic;
	S_en 			:	in std_logic;
	n_en 			: 	in std_logic;
	n_res 		: 	in std_logic;
	sh_en 		: 	in std_logic;
	load      	: 	in std_logic;
	
	--Status signals to FSM
	cmp7_s 		:	out std_logic;
	cmp15_s 		:	out std_logic;
	cmp7_n 		:	out std_logic;
	
	--External Output to CPLD
	ledsegment 	: 	out std_logic_vector(6 downto 0);
	led_dp		:  out std_logic;
	ledsel 		:  out std_logic_vector(3 downto 0)
	
 );
end entity;
-------------------------------------------------------------------------------
 
 --Internal logic of datapath
architecture beh of datapath is
	--Internal signals for datapath
	signal S 					: std_logic_vector(3 downto 0);
	signal n 					: std_logic_vector(2 downto 0);
	signal databits 			: std_logic_vector(7 downto 0);
	signal ss 					: std_logic_vector(6 downto 0);
	signal slow_counter		: std_logic_vector(1 downto 0);
	signal digit_display 	: std_logic_vector(4 downto 0);	
	signal write_digit		:std_logic_vector(3 downto 0);
	signal write_position	:std_logic_vector(1 downto 0);
	signal write_parameter	:std_logic_vector(1 downto 0);
	signal clk_count 			:std_logic_vector(15 downto 0);
	
	--Registers
	signal voltageDigits 	: std_logic_vector(19 downto 0); --	Changed from 15 to store decimals
	signal currentDigits 	: std_logic_vector(19 downto 0);
	signal powerDigits 		: std_logic_vector(19 downto 0);
	signal display_parameter: std_logic_vector(19 downto 0);
	signal parameter_counter: std_logic_vector(1 downto 0) := "11";
	

	
	--Signals for Button
	signal debounce0 			:std_logic;
	signal debounce1 			:std_logic;
	signal strobe0 			:std_logic;
	signal strobe1 			:std_logic;
	signal debounce_prev0 	:std_logic;
	signal debounce_prev1 	:std_logic;
	signal dbCount0		 	:std_logic_vector(3 downto 0);
	signal dbCount1		 	:std_logic_vector(3 downto 0);

begin
-------------------------------------------------------------------------------
--Oversampling clock counter
Scounter_process:process(clk)
begin
	if clk'event and clk = '1' then --check for rising edge
		if s_res = '1' then	
		  S <= "0000";			--Resets sample counter
		 elsif S_en = '1' then
			s <= s + 1;       --Increment sample counter
		 end if;
	end if;	
end process;

-------------------------------------------------------------------------------
--Increase number of databits received when a databit has been read
ncounter_process: process (clk)
begin
	  if clk'event and clk = '1'  then
			if n_res='1' then
				n <= "000";			--Resets databit counter
			elsif n_en = '1' then
				n <= n + 1;			--Increment databit counter
			end if;
		end if;
end process;

-------------------------------------------------------------------------------
--Checks data when the middle of a databit is sampled
cmp7_s_process: process(s)
begin
	if s = "0111" then
		cmp7_s <= '1';
	else
		cmp7_s <= '0';
	end if;
end process;	

-------------------------------------------------------------------------------
--Checks when 7 databits have been received
cmp7_n_process: process(n)
begin
	if n = "111" then
		cmp7_n <= '1';
	else
		cmp7_n <= '0';	
	end if;
end process;

-------------------------------------------------------------------------------
--Checks when the end of a databit is sampled
cmp15_process: process(s)
begin
	if s = "1111" then
		cmp15_s <= '1';
	else
		cmp15_s <= '0';	
		
	end if;
end process;

-------------------------------------------------------------------------------
--Shifts databits right and stores the new data sampled in the most significant bit
ShiftRegister_process: process(clk, databits)
begin
	if clk'event and clk = '1' then
		if sh_en = '1' then
			databits<= rx & databits(7 downto 1);
		end if;
	end if;	
end process;

--Seperate dataframe
write_digit <= databits(3 downto 0);
write_position <= databits(5 downto 4);
write_parameter <= databits(7 downto 6);

-------------------------------------------------------------------------------
store_registers:process (write_parameter, write_position, write_digit, clk)
begin
	if clk'event and clk = '1' then
	  if load = '1' then
			--Stores voltage readings (or decimal point) in corresponding register	
				if write_parameter = "01" then 
					if write_position = "00" then
						voltageDigits (4 downto 0)  <= '0' & "1010"; --Hard code for V symbol
					elsif write_position = "01" then 
						if write_digit = "1111" then
							voltageDigits (9)  <= '1';
						else
							voltageDigits (9 downto 5)  <= '0' & write_digit;
						end if;
					elsif write_position = "10" then
						if write_digit = "1111" then
							voltageDigits (14)  <= '1';
						else 
							voltageDigits (14 downto 10) <= '0' & write_digit;
						end if;
					elsif write_position = "11" then
						if write_digit = "1111" then
							voltageDigits (19)  <= '1';
						else 
							voltageDigits (19 downto 15) <= '0' & write_digit;
						end if;
					end if;
				
				--Stores current readings (or decimal point) in corresponding register
				elsif write_parameter = "10" then 
					if write_position = "00" then
						currentDigits (4 downto 0)  <= '0' & "1011"; --Hard code for A symbol
					elsif write_position = "01" then 
						if write_digit = "1111" then
							currentDigits (9)  <= '1';
						else
							currentDigits (9 downto 5)  <= '0' & write_digit;
						end if;
					elsif write_position = "10" then
						if write_digit = "1111" then
							currentDigits (14)  <= '1';
						else 
							currentDigits (14 downto 10) <= '0' & write_digit;
						end if;
					elsif write_position = "11" then
						if write_digit = "1111" then
							currentDigits (19)  <= '1';
						else
							currentDigits (19 downto 15) <= '0' & write_digit;
						end if;
					end if;
				
				--Stores power readings (or decimal point) in corresponding register
				elsif write_parameter = "11" then 
					if write_position = "00" then
							powerDigits (4 downto 0)  <= '0' & "1100"; --hard code for P symbol
					elsif write_position = "01" then 
						if write_digit = "1111" then
							powerDigits (9)  <= '1';
						else
							powerDigits (9 downto 5)  <= '0' & write_digit;
						end if;
					elsif write_position = "10" then
						if write_digit = "1111" then
							powerDigits (14)  <= '1';
						else 
							powerDigits (14 downto 10) <= '0' & write_digit;
						end if;
					elsif write_position = "11" then
						if write_digit = "1111" then
							powerDigits (19)  <= '1';
						else
							powerDigits (19 downto 15) <= '0' & write_digit; --15 12
						end if;
				
				--Does not store values if not above parameters
				else 
				end if;
			end if;
		end if;
	end if;
end process;

-------------------------------------------------------------------------------
--Slows clock down to cycle through all 7-segment LEDs
clock_slow: process(clk)
begin
	if rising_edge(clk) then
		clk_count <= clk_count + 1;
		if clk_count = x"0200" then -- 5ms is roughly 768 clock cycles.
			slow_counter <= slow_counter + 1;
			clk_count <= x"0000";
		end if;
	end if;
end process;
-------------------------------------------------------------------------------
--Chooses register to read based on parameter
parameter_mux: process(parameter_counter, voltageDigits, currentDigits, powerDigits)
begin
 
	case parameter_counter is 
		when "00" =>
			display_parameter <= x"7BC49"; --hard code for "--29"
		when "01" =>
			display_parameter <= voltageDigits;
		when "10" =>
			display_parameter <= currentDigits;
		when "11" =>
			display_parameter <= powerDigits;
		
		end case;
end process;
-------------------------------------------------------------------------------
--Updates digits to be displayed
sel_digit: process(slow_counter, display_parameter)
begin
	case slow_counter is
		when "00" =>
			digit_display <= display_parameter (4 downto 0);
		when "01" =>
			digit_display <= display_parameter (9 downto 5);
		when "10" =>
			digit_display <= display_parameter (14 downto 10);
		when "11" =>
			digit_display <= display_parameter (19 downto 15);
	end case;
end process;

-------------------------------------------------------------------------------
--Selects which seven segment to turn on
multiplex_7seg: process(slow_counter, clk)
begin
	case slow_counter is
		when "00" =>
			ledsel <= "0001";
		when "01" =>
			ledsel <= "0010";
		when "10" =>
			ledsel <= "0100";
		when others =>
			ledsel <= "1000";
	end case;
end process;

-------------------------------------------------------------------------------
--Reads databits refering to a digit between 0 to 9 inclusive and displays it the seven segment
bcd_process: process(digit_display, ss)
begin
	--Turn on or off dp led behind a digit
	case digit_display(4) is
		when '1' =>
			led_dp <= '1';
		when others =>
			led_dp <= '0';
	end case;
	
	case digit_display(3 downto 0) is
		when"0000"=>
			ss<="0111111"; --0
		when"0001"=>
			ss<="0000110"; --1 
		when"0010"=>
			ss<="1011011"; --2
		when"0011"=>
			ss<="1001111"; --3
		when"0100"=>
			ss<="1100110"; --4
		when"0101"=>
			ss<="1101101"; --5
		when"0110"=>
			ss<="1111101"; --6
		when"0111"=>
			ss<="0000111"; --7
		when"1000"=>
			ss<="1111111"; --8
		when"1001"=>
			ss<="1101111"; --9 
		when "1010" =>
			ss<="0111110"; --V
		when "1011" =>
			ss<="1110111"; --A
		when "1100" =>
			ss<="1110011"; --P 
		when others =>
			ss<="1000000"; --when invalid databits are read
	end case;

	ledsegment <= ss;
end process;
-------------------------------------------------------------------------------
--Eliminates false triggering of the buttons
debouncer: process(clk, PB1, PB0)
begin 
	if rising_edge(clk) then
		--Recognises the a valid trigger of the button (15 bounces)
		debounce1 <= '0';
		if PB1 = '1' then
			if dbCount1 <= x"F" then 
				debounce1 <= '1';
			else
				dbCount1 <= dbCount1 + 1;
			end if;
		else 
			dbCount1 <= (others => '0');
		end if;
		
		--Recognises the a valid trigger of the button (15 bounces)
		debounce0 <= '0';
		if PB0 = '1' then
			if dbCount0 <= x"F" then 
				debounce0 <= '1';
			else
				dbCount0 <= dbCount0 + 1;
			end if;
		else 
			dbCount0 <= (others => '0');
		end if;
	end if;
end process;

-------------------------------------------------------------------------------
--Stops button from triggering multiple times
strober: process(debounce1, debounce0, clk)
begin
	if rising_edge(clk) then
		strobe1 <= '0';
		strobe0 <= '0';
		debounce_prev1 <= debounce1;
		debounce_prev0 <= debounce0;
		
		--Checks for change in button state 
		if debounce_prev1 = '0' and debounce1 = '1' then
			strobe1 <= '1';
		end if;
		
		--Checks for change in button state 
		if debounce_prev0 = '0' and debounce0 = '1' then
			strobe0 <= '1';
		end if;
	end if;	
end process;

-------------------------------------------------------------------------------
--PB1 to increment parameter select lines
--PB0 to decrement parameter selcet lines 
push_button: process(strobe0, strobe1, display_parameter, clk)
begin
	--When signal is received change the parameter to be displayed
	if clk'event and clk = '1' then
		if strobe0 = '1' then
			parameter_counter <= parameter_counter - 1;
		end if;
		if strobe1 = '1' then
			parameter_counter <= parameter_counter + 1;
		end if;
	end if;
end process;
-------------------------------------------------------------------------------
end architecture;