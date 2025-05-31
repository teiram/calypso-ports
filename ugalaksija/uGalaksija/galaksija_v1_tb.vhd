--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   20:19:35 01/09/2010
-- Design Name:   
-- Module Name:   /home/dusang/repository/galaksija/galaksija_soc/galaksija_v1/galaksija_soc/galaksija_v1_tb.vhd
-- Project Name:  galaksija_soc
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Galaksija
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
 
ENTITY galaksija_v1_tb IS
END galaksija_v1_tb;
 
ARCHITECTURE behavior OF galaksija_v1_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Galaksija
    PORT(
         extCLK_50M : IN  std_logic;
			PS2_CLK : in std_logic;
			PS2_DATA : in std_logic;
			LINE_IN : in std_logic;
         VIDEO_DATA : OUT  std_logic;
         VIDEO_SYNC : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK_50M : std_logic := '0';

 	--Outputs
   signal VIDEO_DATA : std_logic;
   signal VIDEO_SYNC : std_logic;
 
	signal SW0 : std_logic := '0';
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Galaksija PORT MAP (
          extCLK_50M => CLK_50M,
			 PS2_CLK => '1',
			 PS2_DATA => '1',
          VIDEO_DATA => VIDEO_DATA,
          VIDEO_SYNC => VIDEO_SYNC,
          LINE_IN => '1'
        );
 
   -- No clocks detected in port list. Replace <clock> below with 
   -- appropriate port name 
  

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100ms.
      --wait for 100 ns;	

      -- insert stimulus here 

      wait;
   end process;

	process
	begin
		CLK_50M <= not CLK_50M;
		wait for 10 ns;
	end process;

END;
