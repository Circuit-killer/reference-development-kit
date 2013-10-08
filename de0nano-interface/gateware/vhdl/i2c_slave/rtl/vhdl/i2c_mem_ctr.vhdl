-- Copyright (c) 2006 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- An entity like the PCA9555, but without interrupt and maybe different latching timings.
-- Fireset a byte is written for addressing a register:
-- 0: input port 0
-- 1: input port 1
-- 2: output port 0
-- 3: output port 1
-- 4: input polarity inversion port 0 (1=input is inverted)
-- 5: input polarity inversion port 1
-- 6: configuration port 0 (1=pin is input)
-- 7: configuration port 0
-- Then you can write to the register or you can send a repeated start with
-- read bit set and read from it.
-- For details see http://www.nxp.com/acrobat_download/datasheets/PCA9555_6.pdf

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_mem_ctr is
	generic(
		clock_frequency: natural := 1e7;
		address: unsigned(6 downto 0) := b"0000000");
	port(
		clock: in std_logic;
		reset: in std_logic;
		scl: in std_logic;
		sda: inout std_logic;
		porti_0: in unsigned(7 downto 0);
		porti_1: in unsigned(7 downto 0);
		porto_00: out unsigned(7 downto 0);
		porto_01: out unsigned(7 downto 0);	
		porto_02: out unsigned(7 downto 0);
		porto_03: out unsigned(7 downto 0);	
		porto_04: out unsigned(7 downto 0);
		porto_05: out unsigned(7 downto 0);
		porto_06: out unsigned(7 downto 0);
		porto_07: out unsigned(7 downto 0);
		porto_08: out unsigned(7 downto 0);
		porto_09: out unsigned(7 downto 0);
		porto_10: out unsigned(7 downto 0);
		porto_11: out unsigned(7 downto 0);
		porto_12: out unsigned(7 downto 0)
		);
end entity i2c_mem_ctr;

architecture rtl of i2c_mem_ctr is

	component i2c_slave is
		generic(
			clock_frequency: natural;
			address: unsigned(6 downto 0));
		port(
			clock: in std_logic;
			reset: in std_logic;
			data_out: in unsigned(7 downto 0);
			data_in: out unsigned(7 downto 0);
			read_mode: out boolean;
			start_detected: out boolean;
			stop_detected: out boolean;
			transfer_started: out boolean;
			data_out_requested: out boolean;
			data_in_valid: out boolean;
			sda: inout std_logic;
			scl: in std_logic);
	end component i2c_slave;

	-- I2C slave signals
	signal data_out: unsigned(7 downto 0);
	signal data_in: unsigned(7 downto 0);
	signal stop_detected: boolean;
	signal transfer_started: boolean;
	signal data_out_requested: boolean;
	signal data_in_valid: boolean;
	
	-- PCA9555 signals
	type registers_type is array (0 to 14) of unsigned(7 downto 0);
	signal registers: registers_type := (others => x"00");
	signal selected_register_index: unsigned(3 downto 0);

	type state_type is (
		idle,
		wait_for_command,
		wait_for_read_write,
		wait_for_event_released);

	signal state: state_type := idle;

begin

	i2c_slave_instance: i2c_slave
		generic map(
			clock_frequency => clock_frequency,
			address => address)
		port map(
			clock => clock,
			reset => reset,
			data_out => data_out,
			data_in => data_in,
			read_mode => open,
			start_detected => open,
			stop_detected => stop_detected,
			transfer_started => transfer_started,
			data_out_requested => data_out_requested,
			data_in_valid => data_in_valid,
			sda => sda,
			scl => scl);

	test_process: process(clock, reset)
	begin
		if reset = '1' then
			-- input
			registers(0) <= x"00";
			registers(1) <= x"00";	--
			-- output
			registers(2) <= x"03";	--
			registers(3) <= x"00";	--
			registers(4) <= x"00";
			registers(5) <= x"00";
			registers(6) <= x"00";
			registers(7) <= x"00";
			registers(8) <= x"00";
			registers(9)  <= x"01";
			registers(10) <= x"01";
			registers(11) <= x"33";	--FCW0
			registers(12) <= x"33";	--FCW1
			registers(13) <= x"33";	--FCW2
			registers(14) <= x"33";	--FCW3

			state <= idle;
		else
			if rising_edge(clock) then
				-- I2C send/receive
				case state is
					when idle =>
						if transfer_started then
							state <= wait_for_command;
						end if;
					when wait_for_command =>
						if data_in_valid then
							selected_register_index <= data_in(3 downto 0);-- xor b"001";
							state <= wait_for_event_released;
						end if;
					when wait_for_read_write =>
						if data_in_valid then
							registers(to_integer(selected_register_index)) <= data_in;
							state <= wait_for_event_released;
						end if;
						if data_out_requested then
							data_out <= registers(to_integer(selected_register_index));
							state <= wait_for_event_released;
						end if;
					when wait_for_event_released =>
						if (data_in_valid = false) and (data_out_requested = false) then
							--selected_register_index(0) <= not selected_register_index(0);
							state <= wait_for_read_write;
						end if;
				end case;

				if stop_detected then
					state <= idle;
				end if;

				-- update input registers
				registers(0) <= porti_0;
				registers(1) <= porti_1;
				
				-- update port by output registers or set to tri-state
--				for i in 0 to 7 loop 
--					if registers(6)(i) = '1' then
--						port0(i) <= 'Z';
--					else
--						port0(i) <= registers(2)(i) xor registers(4)(i);
--					end if;
--					if registers(7)(i) = '1' then
--						port1(i) <= 'Z';
--					else
--						port1(i) <= registers(3)(i) xor registers(5)(i);
--					end if;
--				end loop;
			end if;
		end if;
	end process;

	porto_00 <= registers(2);
	porto_01 <= registers(3);
	porto_02 <= registers(4);
	porto_03 <= registers(5);
	porto_04 <= registers(6);
	porto_05 <= registers(7);
	porto_06 <= registers(8);
	porto_07 <= registers(9);
	porto_08 <= registers(10);
	
	porto_09 <= registers(11);
	porto_10 <= registers(12);
	porto_11 <= registers(13);
	porto_12 <= registers(14);

end architecture rtl;
