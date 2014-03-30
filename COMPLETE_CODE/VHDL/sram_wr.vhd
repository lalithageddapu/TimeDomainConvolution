----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:57:02 11/20/2013 
-- Design Name: 
-- Module Name:    sram_wr - Behavioral 
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
use work.mem_pkg.all;
use work.user_pkg.all;


---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sram_wr is
    Port ( sram_clk : in  STD_LOGIC;
           user_clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           clear : in  STD_LOGIC;
           go : in  STD_LOGIC;
           wr_en : in  STD_LOGIC;
           stall : in  STD_LOGIC := C_0;
		   start_addr : in std_logic_vector (SRAM_ADDR_RANGE);
           size : in  STD_LOGIC_vector(SIZE_RANGE);
           data : in  STD_LOGIC_vector (15 downto 0);
           done : out  STD_LOGIC;
		   ready : out STD_LOGIC;
		
			  
	      sram_request    : out std_logic;
         sram_addr       : out std_logic_vector(SRAM_ADDR_RANGE);
         sram_ld_n       : out std_logic;
         sram_rw_n       : out std_logic;
         sram_bw_n       : out std_logic_vector(SRAM_BW_RANGE);
         sram_wdata      : out std_logic_vector(SRAM_DATA_RANGE);
    		sram_fifo_full  : in  std_logic:='X';
         sram_fifo_empty : in  std_logic:='X';
         sram_calibrated : in  std_logic:='X');
			
end sram_wr;

architecture Behavioral of sram_wr is

signal ag_received, empty, send, fifo_wr,fifo_rd, fifo_full,wr_en_delay, sram_fifo_empty_s,ff3_out,ff4_out,count_done_z_s  : std_logic;
signal count_done, count_done_z, count_sel_z, ag_done, ff1_out, ff2_out,rstclear,ack_s,done_s,sram_request_s,wrc: std_logic;
signal start_addr_inter:std_logic_vector(SRAM_ADDR_RANGE);
signal fifo_data : std_logic_vector(15 downto 0);
signal fifo_wdata : std_logic_vector(63 downto 0);
begin

rstclear <= rst or clear;
sram_bw_n<=(others=>'0');

	U_AG: entity work.add_gen
		port map (
			  clk => sram_clk,
              rst => rstclear,
              start_addr => start_addr_inter,
              stall => stall,
				  done => ag_done,
				  --fifo_full => fifo_full,
			     sram_request => sram_request_s, 
			     sram_ld_n => sram_ld_n,
			     sram_rw_n => sram_rw_n,
			     ag_valid => ag_received,
              sram_addr => sram_addr,
				  stall_fifo => empty
			  );
	sram_request<=sram_request_s;
	U_HS: entity work.handshake
		port map (
			  clk_src => user_clk, 
			  clk_dest => sram_clk,
			  rst => rstclear,     
			  go => send,     
			  delay_ack => C_0,
			  rcv => ag_received,   
			  ack => ack_s
			  );
	
	
	U_FIFO: entity work.fifo_64_w
		port map(
			  wr_clk => user_clk,
			  rd_clk => sram_clk,
			  rst => rstclear,
			  rd_en => fifo_rd,
			  wr_en => fifo_wr,
			  full => fifo_full,
			  empty => empty,
			  din => fifo_data,
			  dout => fifo_wdata
			  );
			  
--sram_wdata <= fifo_wdata(15 downto 0) & fifo_wdata(31 downto 16) & fifo_wdata(47 downto 32) & fifo_wdata(63 downto 48);
sram_wdata <=fifo_wdata;
fifo_wr <=  wr_en_delay or wrc;
fifo_rd <= not empty;			  

	U_C: entity work.count_w
		port map(
				clk   => user_clk,
				rst 	   => rstclear,
				size => size,
				wr_en => fifo_wr,
				done  => count_done,
				send  => send,
				go    => wr_en,
				start_addr => start_addr,
				out_addr   => start_addr_inter,
				rcv 	   => ack_s );
			  
	U_C_z: entity work.zerocounter
		port map(
			  clk => user_clk,
			  rst => rstclear,
			  count_start=>count_done,
              size => size,
              sel => count_sel_z,
				  wrc=>wrc,
			  done => count_done_z
			  );
--			  and sram_fifo_empty_s
done_s <= count_done and count_done_z_s and sram_fifo_empty_s;
done <= done_s;
ready <= not fifo_full;
						
U_mux : entity work.mux_2_1
	generic map (
				width => 16)
			port map ( input1 => data,
					   input2 => data,
					   sel => count_sel_z,
					   output => fifo_data);

	U_count_done: entity work.delay
	generic map (cycles=>5,
				width => 1)
			port map ( clk => sram_clk,
						rst => rstclear,
						en => C_1,
						input(0) => count_done_z,
						output(0) => count_done_z_s);
	U_FF1 : entity work.reg
	generic map (
				width => 1)
			port map ( clk => user_clk,
						rst => rstclear,
						en =>C_1,
						input(0) => done_s,
						output(0) => ff1_out);

	U_FF2 : entity work.reg
	generic map(
				width => 1)
			port map ( clk => sram_clk,
						rst => rstclear,
						en => C_1,
						input(0) => ff1_out,
						output(0) => ff2_out);
						
  
  	U_FF3 : entity work.reg
	generic map (
				width => 1)
			port map ( clk => sram_clk,
						rst => rstclear,
						en => C_1,
						input(0) => ff2_out,
						output(0) => ag_done);
	U_write_delay : entity work.reg
	generic map (
				width => 1)
			port map ( clk => user_clk,
						rst => rstclear,
						en => C_1,
						input(0) => wr_en,
						output(0) => wr_en_delay);
						
	
	U_FF6 : entity work.reg
	generic map (
				width => 1)
			port map ( clk => sram_clk,
						rst => rstclear,
						en =>C_1,
						input(0) => sram_fifo_empty,
						output(0) => ff3_out);

	U_FF4 : entity work.reg
	generic map(
				width => 1)
			port map ( clk => user_clk,
						rst => rstclear,
						en => C_1,
						input(0) => ff3_out,
						output(0) => ff4_out);
						
  
  	U_FF5 : entity work.reg
	generic map (
				width => 1)
			port map ( clk => user_clk,
						rst => rstclear,
						en => C_1,
						input(0) => ff4_out,
						output(0) => sram_fifo_empty_s);
end Behavioral;

