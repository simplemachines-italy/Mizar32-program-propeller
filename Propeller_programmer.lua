local button					= pio.PX_16 -- on board SW2 switch
local	pin_reset_VGA		= pio.PA_8
local pin_sda					= pio.PA_29
local pin_scl					= pio.PA_30
local led      		    = pio.PB_29

local	id								= 0
local	uartid						= 0
local	VGA_addr					=	80
local	timer_id					= 0
local	write_punto 			=	1
local	repeat_test 			= 1
local	eeprom_error			= 0
local	no_error					= 0
local	no_ack						= 1
local	nbr_byte_to_read	= 32

function delay( delay_time )
	--local	new_elua		= true	-- if tmr.delay have the format ( number of ms, id )
														-- delete if the format is ( id, number of ms )
		if new_elua then
			tmr.delay( delay_time, timer_id )
		else
			tmr.delay( timer_id, delay_time )
		end
end

function	search_file( file_to_serch )
	f	=	io.open( file_to_serch, "rb" )
		if	not	f	then
			if file_to_serch == "/mmc/PropTerm_for_Mizar32.binary" then
				PropTermFile = false
			end

			return
		end
	f:close()
			if file_to_serch == "/mmc/PropTerm_for_Mizar32.binary" then
				PropTermFile = true
			end
end

function get_file_contents( file_to_read )
 f = io.open( file_to_read, "rb" )
 if not f then
    print( "\n " .. inputfile .. " do not found." )
			if file_to_read == "/mmc/PropTerm_for_Mizar32.binary" then
				PropTermFile = false
			end
		print	( "\n Select a new command or type L to rewrite the command list." )
    return	get_menu_select()
 end
 s = f:read( "*all" )
 if not s then
		print( "\n" .. inputfile .. " is unreadable or in wrong format." )
			if file_to_read == "/mmc/PropTerm_for_Mizar32.binary" then
				PropTermFile = false
			end
		print	( "\n Select a new command or type L to rewrite the command list." )
		return	get_menu_select()
 end
 f:close()
 print( "\n " .. inputfile .. " found." )
			if file_to_read == "/mmc/PropTerm_for_Mizar32.binary" then
				PropTermFile = true
			end
 return s
end

function	test_i2c_address( addr ) -- test up to 500 times if EEprom is detected
																	 -- acked = true if eeprom is detected
																	 -- false otherwise
						repeat_test = 1
						repeat
							i2c.start( id )
							acked = i2c.address( id, addr, i2c.TRANSMITTER )
							i2c.stop(id)
							repeat_test = repeat_test + 1
						until	acked == true or repeat_test == 500
end

function	Propeller_in_stand_by()
						pio.pin.sethigh( pin_reset_VGA )
-- take eeprom control. Test the EEprom 700 times to be sure to take the EEprom 
-- control and put the propeller chip in stand-by mode
						repeat_test = 1
						repeat
							i2c.start( id )
							acked = i2c.address( id, VGA_addr, i2c.TRANSMITTER )
							i2c.stop(id)
							repeat_test = repeat_test + 1
						until	repeat_test == 700
						pio.pin.setlow( pin_reset_VGA )
end

function	reset_VGA()
			pio.pin.sethigh( pin_reset_VGA )
			delay( 300000 )
			pio.pin.setlow( pin_reset_VGA )
end

function	eeprom_missed()
		if not acked then
			print( "\n Error: EEprom missed. Reset the hardware and try again." )
			while	true do			-- turn on the led and do nothing else
				led_on()
			end
		end
end

function	eeprom_pointer_to( addr, MBS_addr, LSB_addr )
			i2c.start( id )
			acked = i2c.address( id, addr, i2c.TRANSMITTER )
			i2c.write( id, MBS_addr, LSB_addr )
			i2c.stop( id )
			eeprom_missed()
end

function	current_read( addr, nbr_byte )
			i2c.start( id )
			acked = i2c.address( id, addr, i2c.RECEIVER )
			eeprom_data_readed = i2c.read( id, nbr_byte )
			i2c.stop( id )
			eeprom_missed()
end

function	erase_eeprom ( addr )

			print( "\n Erase EEprom. Wait please." )
			io.write( " 0   EEprom pages cleared.\r")
			Propeller_in_stand_by()
			for	addr_high 	= 0, 0xff do
				addr_low	= 0
				repeat_test = 1
				repeat
					test_i2c_address ( addr )
					eeprom_missed()
					i2c.start( id )
					acked = i2c.address( id, addr, i2c.TRANSMITTER )
					i2c.write( id, addr_high, addr_low, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff )
					i2c.stop( id )
					addr_low	=	addr_low + 32
				until addr_low >= 0xff
				if	addr_high == 0xff then
							addr_high	=	0x100
				end
				io.write( " " .. ( addr_high * 2 ).. "\r" )
			end
			print( "\n EEprom erased." )
end

function	blank_check( addr )

			print( "\n Blank check EEprom. Wait please." )
			io.write( " 0   EEprom pages checked.\r")
			Propeller_in_stand_by()
			test_i2c_address ( addr )
			eeprom_missed()
			eeprom_pointer_to( VGA_addr, 0, 0 )
			for	addr_high = 0, 0xff do
				addr_low = 0
				repeat
					current_read( VGA_addr, nbr_byte_to_read )
						for	character_test = 1, #eeprom_data_readed do
							if	string.byte( eeprom_data_readed, character_test ) ~= 0xff then
								print( "\n EEprom not blank." )
								print( " Location 0x" .. string.format( "%02x%02x", addr_high, ( addr_low + character_test - 1) ) .. " contain " .. string.byte( eeprom_data_readed, character_test ) )
								return
							end
						end	
					addr_low	=	addr_low + 32
				until
					addr_low >= 0xff
				if	addr_high == 0xff then
					addr_high	=	0x100
				end
				io.write( " " .. ( addr_high * 2 ).. "\r" )
			end
			print( "\n The EEprom is blank." )
end

function	verify_eeprom( addr, verify_with_this_string )
			if	#verify_with_this_string >= 65535 then
				print( "\n The file " ..filename.. " is too large. Select anothr file.")
				return
			end
			io.write( "\n 0   EEprom pages verified.\r" )
			Propeller_in_stand_by()
			eeprom_pointer_to( VGA_addr, 0, 0 )
			character_count = 1
			end_of_file = #verify_with_this_string
			addr_high, addr_low = 0, 0
				repeat
					current_read( VGA_addr, nbr_byte_to_read )
						for	character_test = 1, #eeprom_data_readed do
							if	string.byte( eeprom_data_readed, character_test ) ~= string.byte( verify_with_this_string, character_count ) then
								print( "\n Verify Error." )
								print( " Location 0x" .. string.format( "%02x%02x", addr_high, ( addr_low + character_test - 1) ) .. " contain " .. string.byte( eeprom_data_readed, character_test ) .. " expected " .. string.byte( verify_with_this_string, character_count )  )
								return
							end
							character_count = character_count + 1
							if character_count == ( end_of_file + 1 ) then
								break
							end
						end	
					addr_low	=	addr_low + 32
					if addr_low == 0x100 then
						addr_low = 0
						addr_high = addr_high + 1
						io.write( " " .. ( addr_high * 2 ).. "\r" )
					end
				until
					addr_high == 0x100 or character_count >= end_of_file
			print( "\n EEprom verified successfully." )
end

function	write_propeller_program( file_in_a_string )
-- The VGA EEprom is 64KByte. If the selected file is too large send an error 
-- through the console and return 
			if	#file_in_a_string >= 65535 then		
				print( "\n The file " ..filename.. " is too large. Select anothr file.")
				return
			end
			addr_low, addr_high = 0, 0
			character_count = 1
			end_of_file = #file_in_a_string
			io.write( "\n 0   EEprom pages write.\r")
			Propeller_in_stand_by()
			repeat
				test_i2c_address( VGA_addr )
				eeprom_missed()
				i2c.start( id )
				acked = i2c.address( id, VGA_addr, i2c.TRANSMITTER )
				i2c.write( id, addr_high, addr_low )
				for loop = 1, 32 do
					i2c.write( id, string.byte( file_in_a_string, character_count ) )
					character_count = character_count + 1
					if	character_count == ( end_of_file + 1 ) then
						end_of_byte = loop
						break 
					end
				end
				i2c.stop( id )
				addr_low = addr_low + 32
					if	addr_low == 0x100 then
						addr_low = 0x00
						addr_high = addr_high + 1
						io.write( " " .. ( addr_high * 2 ) .. "\r" )
					end
			until
				character_count == ( end_of_file + 1 ) or addr_high == 0x100
			
			print( "\n Programmed " .. end_of_file .. " byte in VGA EEprom." )
			verify_eeprom( VGA_addr, file_in_a_string )
end

function	led_on()
			pio.pin.setlow( led )
end

function	write_command_list()
		inputfile = "PropTerm_for_Mizar32.binary"
		local filename = "/mmc/" .. inputfile
		search_file( filename )
		print( "\n Select an option." )
		print( " 1-- Erase EEprom." )
		print( " 2-- EEprom blank check." )		
		print( " 3-- Select a file and program EEprom." )
		print( " 4-- Select a file and verify EEprom." )
		if	PropTermFile then
			print( " 5-- Programming PropTerm_for_Mizar32.binary on EEprom." )
			print( " 6-- Verify PropTerm_for_Mizar32.binary on EEprom." )
		end
		print( " L-- Rewrite this command list." )
		print( " Q-- Quit." )
		return	get_menu_select()
end

function	get_menu_select()
	menu_option = uart.getchar( uartid, uart.INF_TIMEOUT )
	decode_key()
end

function	decode_key()
		if	menu_option == "1" then		-- erase the memory
				erase_eeprom( VGA_addr )
				print	( "\n Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		elseif
				menu_option == "2" then		-- blank check
				blank_check( VGA_addr )
				print	( "\n Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		elseif
				menu_option == "3" then		-- Select a file and program EEprom
				io.write( "\n File name: " )
				inputfile = io.read()			-- Type your file to program
	local filename = "/mmc/" .. inputfile
				get_file_contents( filename )
				write_propeller_program( s )
				reset_VGA()
				print	( " Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		elseif
				menu_option == "4" then		-- Select a file and verify EEprom
				io.write( "\n File name: " )
				inputfile = io.read()			-- Type your file to program
	local filename = "/mmc/" .. inputfile
				get_file_contents( filename )
				verify_eeprom( VGA_addr, s )
				reset_VGA()
				print	( " Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		elseif
				menu_option == "l" then
				write_command_list()
		elseif
				menu_option == "q" then
				print( "\n Propeller programmer end." )
				return
		elseif
				PropTermFile == false then
				return get_menu_select()
		elseif
				menu_option == "5" then			-- Program the Propeller chip with PropTrem.binary
					if	not	PropTermFile then
						return	get_menu_select()
					end
				inputfile = "PropTerm_for_Mizar32.binary"
	local filename = "/mmc/" .. inputfile
				get_file_contents( filename )
				write_propeller_program( s )
				reset_VGA()
				print	( "\n Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		elseif
				menu_option == "6" then			-- Verify PropTerm.binary on EEprom
					if	not	PropTermFile then
						return	get_menu_select()
					end
				inputfile = "PropTerm_for_Mizar32.binary"
	local filename = "/mmc/" .. inputfile
				get_file_contents( filename )
				verify_eeprom( VGA_addr, s )
				reset_VGA()
				print	( " Select a new command or type L to rewrite the command list." )
				return	get_menu_select()
		else	
				return	get_menu_select()
		end
end

pio.pin.setpull( pio.NOPULL, button )   
pio.pin.setdir( pio.INPUT, button ) -- put switch in input mode
pio.pin.sethigh( led )
pio.pin.setlow( pin_reset_VGA )
pio.pin.setdir( pio.OUTPUT, pin_reset_VGA, led )
pio.pin.setpull( pio.PULLUP, pin_reset_VGA, pin_sda, pin_scl )  

speed = i2c.setup( id, 100000 ) -- Enable I2C
print( "\n Try to connect to VGA EEprom." )
io.write( " Wait please." )

repeat
			Propeller_in_stand_by()
			test_i2c_address( VGA_addr )
			if not acked then
				write_punto = write_punto + 1
			end
			io.write( "." )
until	acked == true or write_punto == 10

if not acked then
						print( "\n Unable to comunicate with the VGA EEprom." )
						print( " Occurred any of these problem:" )
						print( " 1- The VGA shield is not connected whit Mizar32 board." )
						print( " 2- The EEprom on VGA shield is broken." )
						print( " 3- The jumper G54 and G55 in VGA shield are not welded." )
						print( " Turn off the Mizar32 board and solve the problem." )
						while	true do			-- turn on the led and do nothing else
								led_on()
						end
end
print( "\n VGA EEprom found." )
write_command_list()
