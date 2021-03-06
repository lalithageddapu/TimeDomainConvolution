----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    06:01:45 11/30/2013 
-- Design Name: 
-- Module Name:    kernel_buffer - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.user_pkg.all;
---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity kernel_buffer is

generic (cycles : positive := 96;
				width : positive := 16);
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           --en : in  STD_LOGIC;
           full : out  STD_LOGIC;
           empty : out  STD_LOGIC;
           wr : in  STD_LOGIC;
           rd : in  STD_LOGIC;
			  clear: in std_logic;
           data_input : in  STD_LOGIC_VECTOR (width-1 downto 0);
           data_output : out  data_array(0 to 95));
end kernel_buffer;

architecture Behavioral of kernel_buffer is

signal count : integer range 0 to 96 := 0;
  signal reg_val : data_array(0 to 95);
  
  component reg
    generic (width :     positive  := 32);
    port(clk       : in  std_logic;
         rst       : in  std_logic;
         en        : in  std_logic;
         input     : in  std_logic_vector(width-1 downto 0);
         output    : out std_logic_vector(width-1 downto 0));
  end component;
signal full_s,empty_s,rst_s:std_logic;

begin  
rst_s<= rst or clear;

-- U_REG: reg
--		generic map (width => width)
--      port map (clk                 => clk,
--                rst                 => rst,
--                en                  => wr,
--                input               => data_input,
--                output              => reg_val(0));
--  
 U_REG : reg generic map (width => 16)
      port map (clk                 => clk,
                rst                 => rst_s,
                en                  => wr,
                input               => data_input,
                output              => reg_val(95));
  
  U_DELAY : for i in 0 to 94 generate
    U_DREG : reg generic map (width => 16)
      port map (clk                 => clk,
                rst                 => rst_s,
                en                  => wr,
                input               => reg_val(95-i),
                output              => reg_val(94-i));
  end generate U_DELAY;

process (clk,rst,data_input,rd,wr,reg_val)	
	begin
	if(rst_s ='1') then
		full_s <= '0';
		empty_s <= '1';
		count <= 0;
	elsif(clk'event and clk='1') then
	if(wr='1' and rd='0') then
		count<=count+1;
	elsif(wr='1' and rd='1') then
		count<=count;
	elsif(wr='0' and rd='1') then
		count<=count-1;
	elsif(wr='0' and rd='0') then
		count<=count;
	end if;
	if(count<96) then
		empty_s<='1';
		full_s<='0';
	else
		empty_s<='0';
			if(rd='1') then
				full_s<='0';
			else
				full_s<='1';
			end if;
	end if;end if;
	end process;
	full<=full_s;
	empty<=empty_s;
	
		data_output<=reg_val;

end Behavioral;

