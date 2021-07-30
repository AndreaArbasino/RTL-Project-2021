
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.ALL;
use STD.textio.ALL;

entity project_tb is
end project_tb;

architecture projecttb of project_tb is
constant c_CLOCK_PERIOD         : time := 15 ns;
signal   tb_done                : std_logic;
signal   mem_address            : std_logic_vector (15 downto 0) := (others => '0');
signal   tb_rst                 : std_logic := '0';
signal   tb_start               : std_logic := '0';
signal   tb_clk                 : std_logic := '0';
signal   mem_o_data,mem_i_data  : std_logic_vector (7 downto 0);
signal   enable_wire            : std_logic;
signal   mem_we                 : std_logic;

type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);

signal RAM: ram_type;

signal mem_load : boolean := false;
signal load_done : boolean := false;
signal all_tests_loaded : boolean := false;                        

component project_reti_logiche is
port (
      i_clk         : in  std_logic;
      i_rst         : in  std_logic;
      i_start       : in  std_logic;
      i_data        : in  std_logic_vector(7 downto 0);
      o_address     : out std_logic_vector(15 downto 0);
      o_done        : out std_logic;
      o_en          : out std_logic;
      o_we          : out std_logic;
      o_data        : out std_logic_vector (7 downto 0)
      );
end component project_reti_logiche;


begin
UUT: project_reti_logiche
port map (
          i_clk      	=> tb_clk,
          i_rst      	=> tb_rst,
          i_start       => tb_start,
          i_data    	=> mem_o_data,
          o_address  	=> mem_address,
          o_done      	=> tb_done,
          o_en      	=> enable_wire,
          o_we 		    => mem_we,
          o_data    	=> mem_i_data
          );

p_CLK_GEN : process is
begin
    wait for c_CLOCK_PERIOD/2;
    tb_clk <= not tb_clk;
end process p_CLK_GEN;


MEM : process(tb_clk)
    file read_file : text open read_mode is "path/to/ramData.txt";  --change to the correct path
    variable read_line : line;
    variable input : integer;
    variable rows : integer;
    variable columns : integer;
    
begin
    if tb_clk'event and tb_clk = '1' then
        if(mem_load) then
            readline(read_file, read_line);
            read(read_line, rows);
            RAM(0) <= std_logic_vector(TO_UNSIGNED(rows, 8));
            
            readline(read_file, read_line);
            read(read_line, columns);
            RAM(1) <= std_logic_vector(TO_UNSIGNED(columns, 8));
            
            for i in 0 to rows*columns-1 loop
                readline(read_file, read_line);
                read(read_line, input);
                RAM(i+2) <= std_logic_vector(TO_UNSIGNED(input, 8));
            end loop;
            
            if endfile(read_file) then
                all_tests_loaded <= true;
            end if;
            
        elsif enable_wire = '1' then
            if mem_we = '1' then
                RAM(conv_integer(mem_address))  <= mem_i_data;
                mem_o_data                      <= mem_i_data after 1 ns;
            else
                mem_o_data <= RAM(conv_integer(mem_address)) after 1 ns;
            end if;
        end if;
    end if;
end process;


test : process is
    file read_file : text open read_mode is "path/to/ramResult.txt";  --change to the correct path
    file write_file : text open write_mode is "path/to/NotPassed.txt";  --change to the correct path
    variable write_line : line;
    variable read_line : line;
    variable result : integer;
    variable test_number : integer := 0;
begin 
    wait for 100 ns;
    tb_rst <= '1';  --RESET SIGNAL UP
    wait for c_CLOCK_PERIOD;
    wait for 100 ns;
    tb_rst <= '0';  --RESET SIGNAL DOWN
    wait for c_CLOCK_PERIOD;
    
    loop
        test_number := test_number + 1;
        report string'("TEST ") & integer'image(test_number);
        mem_load <= true; --Carica il test da file
        wait for c_CLOCK_PERIOD;
        mem_load <= false; --Carica il test da file
        wait for c_CLOCK_PERIOD;
        
        wait for 100 ns;
        tb_start <= '1';  --START SIGNAL UP
        wait for c_CLOCK_PERIOD;
        wait until tb_done = '1'; --WAIT FOR DONE
        wait for c_CLOCK_PERIOD;
        tb_start <= '0';  --START SIGNAL DOWN
        wait until tb_done = '0';
        wait for 100 ns;
        
        for i in 0 to TO_INTEGER(unsigned(RAM(0)))*TO_INTEGER(unsigned(RAM(1)))-1 loop
            readline(read_file, read_line);
            read(read_line, result);
            
            if(TO_INTEGER(unsigned(RAM(i+2+TO_INTEGER(unsigned(RAM(0)))*TO_INTEGER(unsigned(RAM(1)))))) /= result) then
                write(write_line, string'("TEST ") & integer'image(test_number) & string'(": pixel ") & integer'image(i) & string'(" expected ") & integer'image(result) & string'(" found ") & integer'image(TO_INTEGER(unsigned(RAM(i+2+TO_INTEGER(unsigned(RAM(0)))*TO_INTEGER(unsigned(RAM(1))))))));
                writeline(write_file, write_line);
            end if;
        end loop;
        
        if(all_tests_loaded) then
            exit;
        end if;
    
    end loop;
    
    assert false report "Simulation Ended!" severity failure;
    
end process test;

end projecttb; 



