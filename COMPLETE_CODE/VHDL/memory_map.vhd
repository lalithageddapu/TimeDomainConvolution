---------------------------------------------------------------------------
--  --
--     NALLATECH IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"  --
--     BY PROVIDING THIS DESIGN, CODE, OR INFORMATION                    --
--     AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION       --
--     OR STANDARD, NALLATECH IS MAKING NO REPRESENTATION THAT THIS      --
--     IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,           --
--     AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE  --
--     FOR YOUR IMPLEMENTATION.  NALLATECH EXPRESSLY DISCLAIMS ANY       --
--     WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE           --
--     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR    --
--     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF   --
--     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   --
--     FOR A PARTICULAR PURPOSE.                                         --
--                                                                       --
--     Nallatech products are not intended for use in life support       --
--     appliances, devices, or systems. Use in such applications are     --
--     expressly prohibited.                                             --
---------------------------------------------------------------------------
-- Title       : DimeTalk Memory Map Slave
-- Project     : DimeTalk
-- File        : memory_map.vhd
---------------------------------------------------------------------------
-- Description :
--
-- This is the memory map slave node, it provides a user interface that can be
-- used to interface to external block ram or registers. Sequential or individual
-- accesses are possible.
--
--
---------------------------------------------------------------------------
-- Known Issues and Omissions :
--  - none
--
---------------------------------------------------------------------------
--     (c) Copyright 1995-2005 Nallatech Ltd.                            --
--     All rights reserved.                                              --
---------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.pkg_dimetalk_global.all;

entity memory_map is
  generic(
    node_ID                :     std_logic_vector(NODEID_SZ-1 downto 0) := x"00"
    );
  port (
    reset                  : in  std_logic;
    -- DimeTalk port 
    dt_clk                 : in  std_logic;
    data_in                : in  std_logic_vector(DT_DATA_SZ-1 downto 0);
    data_out               : out std_logic_vector(DT_DATA_SZ-1 downto 0);
    data_in_ack            : out std_logic;
    data_out_ack           : in  std_logic;
    -- User port
    user_addr       : out std_logic_vector(31 downto 0);
    user_enable     : out std_logic;
    user_wenable    : out std_logic;
    user_data_out   : out std_logic_vector(31 downto 0);
    user_data_in    : in  std_logic_vector(31 downto 0);
    -- Doorbells
    user_doorbell_status0  : in  std_logic;
    user_doorbell_status1  : in  std_logic;
    user_doorbell_status2  : in  std_logic;
    user_doorbell_status3  : in  std_logic;
    user_doorbell_control0 : out std_logic;
    user_doorbell_control1 : out std_logic;
    user_doorbell_control2 : out std_logic;
    user_doorbell_control3 : out std_logic
    );
    
  attribute dtinfo_MemoryMap_icon : string;
  attribute dtinfo_MemoryMap_icon of Memory_Map : entity is "icon=memmap.bmp";
  attribute dtinfo_MemoryMap_color : string;
  attribute dtinfo_MemoryMap_color of Memory_Map : entity is "color=0x00f4f0c0";
  attribute dtinfo_MemoryMap_description : string;
  attribute dtinfo_MemoryMap_description of Memory_Map : entity is "description=Simple Memory Map Node";
  attribute dtinfo_MemoryMap_shortdesc : string;
  attribute dtinfo_MemoryMap_shortdesc of Memory_Map : entity is "shortdesc=Memory Map";
  attribute dtinfo_MemoryMap_enumerated : string;
  attribute dtinfo_MemoryMap_enumerated of Memory_Map : entity is "enumerated=1";
  attribute dtinfo_MemoryMap_type : string;
  attribute dtinfo_MemoryMap_type of Memory_Map : entity is "type=2";
  attribute dtinfo : string;
  attribute dtinfo of reset : signal is "reset";
  attribute dtinfo of dt_clk : signal is "clk1";
  attribute dtinfo of data_in : signal is "dtport,DIMEtalk";
  attribute dtinfo of user_addr : signal is "usergroup,UserInterface";
  attribute dtinfo of user_doorbell_status0 : signal is "usergroup,Doorbells";
end memory_map;


architecture rtl of memory_map is

  -------------------------------------------------------------------------------
  -- component declarations
  -------------------------------------------------------------------------------

  component bretime
    generic (
      DEPTH :     integer);
    port (
      reset : in  std_logic;
      clock : in  std_logic;
      d     : in  std_logic;
      q     : out std_logic);
  end component;

  component dtnode_slave_control
    port (
      reset            : in  std_logic;
      clock            : in  std_logic;
      data_in          : in  std_logic_vector(DT_DATA_SZ-1 downto 0);
      data_out         : out std_logic_vector(DT_DATA_SZ-1 downto 0);
      data_in_ack      : out std_logic;
      data_out_ack     : in  std_logic;
      node_ID          : in  std_logic_vector(NODEID_SZ-1 downto 0);
      rd_data          : in  std_logic_vector(DT_DATA_SZ-1 downto 0);
      accept_packet    : in  boolean;
      start_rd_wr      : out std_logic;
      start_pkt_rd     : out std_logic;
      transID          : out std_logic_vector(DTRANID_SZ-1 downto 0);
      DataSize         : out std_logic_vector(DDAT_SZ-1 downto 0);
      address          : out std_logic_vector(DT_DATA_SZ-1 downto 0);
      ready            : in  std_logic;
      capability       : in  std_logic_vector(CAP_DATA_SZ-1 downto 0);
      doorbell_status  : in  std_logic_vector(DB_DATA_SZ-1 downto 0);
      doorbell_control : out std_logic_vector(DB_DATA_SZ-1 downto 0));
  end component;


  --=============================================================================
  -- Capability Register Constants
  --=============================================================================
  -- Byte 0 : Type
  constant TYPE_MM : std_logic_vector( 7 downto 0) := x"01";
  -------------------------------------------------------------------------------
  -- Byte 1 : node_ID
  -------------------------------------------------------------------------------
  -- Byte 2 : Subtype - unused on this module
  constant CAP_SUBTYPE : std_logic_vector(7 downto 0) := x"00";
  -------------------------------------------------------------------------------
  -- Byte 3 : node version
  -- module version number, increment on each new version
  constant VERSION_NUMBER : std_logic_vector(7 downto 0) := x"00";
  -------------------------------------------------------------------------------
  -- Byte 4 : Node Capability
  --      0 : Writeable                   : YES
  --      1 : Readable                    : YES
  --      2 : Accepts atomic operations   : NO 
  --      3 : Multiple doorbells          : YES
  --   5..4 : Number of write doorbells   : "11"  
  --   7..6 : Number of read doorbells    : "11"
  constant NODE_CAP : std_logic_vector(7 downto 0) := x"FB"; 
  -------------------------------------------------------------------------------
  -- Byte 5 : unused
  -------------------------------------------------------------------------------
  -- Byte 6 : unused
  -------------------------------------------------------------------------------
  -- Byte 7 : Status
  --   6..0 : Status (unused at present)
  --      7 : Error condition detected
  constant CAP_STATUS :  std_logic_vector(7 downto 0) := x"00";
  --=============================================================================

  

  -------------------------------------------------------------------------------
  -- signal declarations
  -------------------------------------------------------------------------------
  -- Dimetalk clock domain reset signals
  signal reset_dt : std_logic;

  type t_state is ( Idle, ReceivePacketData, ReadSlaveData, ReadyDelay);

  signal state : t_state;

  signal start_rd_wr  : std_logic;
  signal start_pkt_rd : std_logic;
  signal ready        : std_logic;
  signal transID      : std_logic_vector(DTRANID_SZ-1 downto 0);

  -- packet content counter
  signal pword_count     : std_logic_vector(6 downto 0);
  signal inc_pword_count : std_logic;

  -- Dimetalk Protocol signals
  -- Physical Header 
  signal Source       : std_logic_vector(PSRC_ID_SZ-1 downto 0);
  signal Destination  : std_logic_vector(PDST_ID_SZ-1 downto 0);
  signal PacketSize   : std_logic_vector(PPKT_SZ-1 downto 0);
  signal ResponseSize : std_logic_vector(PRESP_SZ-1 downto 0);

  -- Dimetalk Header
  -- Max 64 word data packets, numbering 1-64
  signal DataSize    : std_logic_vector(DDAT_SZ-1 downto 0);
  signal SourceID    : std_logic_vector( 7 downto 0);
  signal address     : std_logic_vector(DT_DATA_SZ-1 downto 0);
  signal user_addr_i : std_logic_vector(DT_DATA_SZ-1 downto 0);

  signal dt_doorbell_status  : std_logic_vector(DB_DATA_SZ-1 downto 0);
  signal dt_doorbell_control : std_logic_vector(DB_DATA_SZ-1 downto 0);
  signal capability          : std_logic_vector(CAP_DATA_SZ-1 downto 0);
  
  signal user_renable  : std_logic;
  signal user_wenablei : std_logic;


begin

  capability <= (CAP_STATUS & GND8 & GND8 & NODE_CAP & VERSION_NUMBER & CAP_SUBTYPE & node_ID & TYPE_MM);

  -------------------------------------------------------------------------------
  -- DIMETalk Network Interface (dt_clk domain)
  -------------------------------------------------------------------------------

  i_dtnode_slave_control : dtnode_slave_control
    port map (
      reset            => reset_dt,              -- in  
      clock            => dt_clk,                -- in  
      data_in          => data_in,               -- in  
      data_out         => data_out,              -- out 
      data_in_ack      => data_in_ack,           -- out 
      data_out_ack     => data_out_ack,          -- in  
      node_ID          => node_ID,               -- in  
      rd_data          => user_data_in,          -- in
      accept_packet    => true,
      start_rd_wr      => start_rd_wr,           -- out
      start_pkt_rd     => start_pkt_rd,
      transID          => transID,               -- out
      DataSize         => DataSize,
      address          => address,               -- out 
      ready            => ready,                 -- in  
      capability       => capability,            -- in  
      doorbell_status  => dt_doorbell_status,    -- in  
      doorbell_control => dt_doorbell_control);  -- out

  dt_reset_retime : bretime
    generic map (
      DEPTH => META_DEPTH)
    port map (
      reset => '0',                     -- in  
      clock => dt_clk,                  -- in  
      d     => reset,                   -- in  
      q     => reset_dt);               -- out


  user_enable <= user_renable or user_wenablei;
  user_wenable <= user_wenablei;

  dt_control : process(dt_clk, reset_dt)
  begin
    if (reset_dt = '1') then
      state           <= Idle;
      pword_count     <= (others => '0');
      inc_pword_count <= '0';
      user_addr_i     <= (others => '0');
      user_wenablei    <= '0';
      user_renable    <= '0';
      user_data_out   <= (others => '0');
      ready           <= '0';
    elsif rising_edge(dt_clk) then

      -- default assignment for control signals
      user_wenablei    <= '0';
      user_renable    <= '0';
      inc_pword_count <= '0';
      ready           <= '0';

      case state is

        when Idle =>
          -- This flags transfer of write data to slave
          if start_rd_wr = '1' then

            case transId is

              when TID_NRES | TID_RES =>  -- Write (no response | response)
                state           <= ReceivePacketData;
                inc_pword_count <= '1';
                user_wenablei    <= '1';

              when others =>
                state <= Idle;
                ready <= '1';

            end case;
            -- This flags transfer of read data from slave omto DT bus

          elsif start_pkt_rd = '1' then
            case transId is
              
              when TID_READ =>          -- Read
                state           <= ReadSlaveData;
                inc_pword_count <= '1';
                user_renable    <= '1';

              when others =>
                state <= Idle;
                ready <= '1';

            end case;
          end if;



          -- Write data packet to slave
        when ReceivePacketData =>
          -- write packet data to fifo
          inc_pword_count   <= '1';
          user_wenablei      <= '1';
          if pword_count = DataSize then
            state           <= Idle;
            ready           <= '1';
            inc_pword_count <= '0';
            user_wenablei    <= '0';
          end if;

          -- Read data from fifo
        when ReadSlaveData =>
          inc_pword_count   <= '1';
          user_renable      <= '1';
          if pword_count = DataSize then
            state           <= Idle;
            ready           <= '1';
            inc_pword_count <= '0';
            user_renable    <= '0';
          end if;

          -- delay generation of ready by one cycle here to allow handshaking
          -- with dt state machine
        when ReadyDelay =>
          state <= Idle;
          ready <= '1';

          -----------------------------------------------------------------------

      end case;  -- state

      -- packet word counter - used for incoming and packets
      if inc_pword_count = '1' then
        pword_count <= pword_count + '1';
        user_addr_i <= user_addr_i + '1';
      else
        pword_count <= (0 => '1', others => '0');
        -- latch the address
        user_addr_i <= address;
      end if;


      user_data_out <= data_in;

    end if;

  end process;

  -- may have to delay this by a cycle
  user_addr <= user_addr_i;


  -- Dimetalk does not allow breakout at vector level so to utilise the bits
  -- separately these vectors are split into scalars. 
  user_doorbell_control0 <= dt_doorbell_control(0);
  user_doorbell_control1 <= dt_doorbell_control(1);
  user_doorbell_control2 <= dt_doorbell_control(2);
  user_doorbell_control3 <= dt_doorbell_control(3);

  dt_doorbell_status <= user_doorbell_status3 & user_doorbell_status2 & user_doorbell_status1 & user_doorbell_status0;


end rtl;
