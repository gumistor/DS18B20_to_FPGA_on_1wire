`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CAPACTIVE TOUCH BUTTON demo for iCEblink40 board, VQ100 version
//
// Version 1.1
// Date:  1-MAR-2012
// ===============================================================================
// Description:
//
// When board powers on, the green LEDs along the right edge scroll upward.
// If any button is pressed, the LEDs instead display the current toggle state of
// the buttons.  If no button is pressed in five seconds, then the LEDs return to
// displaying the upward-scrolling pattern.
//////////////////////////////////////////////////////////////////////////////////

module my_first(
     input  CLK_3P3_MHZ,					  // 3.3 MHz clock from LTC1799 oscillator (pin 13)
     inout  BTN1,							  // Connection to cap-sense button BTN1 (pin 60)
	 inout  BTN2,							  // Connection to cap-sense button BTN1 (pin 60)
	 inout  BTN3,							  // Connection to cap-sense button BTN1 (pin 60)
	 inout  BTN4,							  // Connection to cap-sense button BTN1 (pin 60)
     output LED1,           					// Drives LED LD2 (pin 53)
	 output CLK_WIRE,
	 inout  ONE_WIRE,
     // -- Digilent ADEPT 2 I/O Expander Debug Interface
     input  ASTB ,                            // Address strobe
     input  DSTB ,                            // Data strobe
     input  WRITE ,                           // Read/Write control
     inout [7:0] DB ,                         // Data bus, byte-wide
     output WAIT ,                            // Wait signal
     output SS_B,							  // SPI slave-select output
	 // -- LCD
	output reg LCD_RS = 1'b0,
	output reg LCD_RW = 1'b0,
	output reg LCD_E = 1'b0,
	output reg [3:0] LCD_DB = 4'h0
);
	 
	 reg [7:0] one_wire_machine = 8'h00;
	 reg [7:0] last_one_wire_machine = 8'h00;
	 reg [7:0] next_one_wire_machine = 8'h00;
	 
	 // -- Digilent ADEPT 2 I/O Expander Debug Graphical Interface (GUI) connections 
     wire [31:0] ToFPGA ;                     // 32-bit value written to the FPGA, specified via a textbox on the graphical interface (GUI)
     wire [31:0] FromFPGA ;                   // 32-bit value provided by the FPGA and displayed in a textbox on the graphical interface (GUI)
                                              // ... Green = [23:16], Yellow = [15:8], Red = [7:0]

	 reg LED1_STATUS = 1'b0;
	 wire UPDATE_COUNTER = 1'b0;
	 wire ONE_WIRE_READY;
	
	 reg ONE_WIRE_ENABLE = 1'b0;
	 reg ONE_WIRE_RW = 1'b0;
	 reg ONE_WIRE_INIT = 1'b0;
	 	 
	 reg [79:0] DATA_TO_SEND;
	 wire [79:0] DATA_RECEIVED;
	 reg [7:0] ONE_WIRE_DATA_SIZE;
	 
	 reg [15:0] ONE_WIRE_COUNTER = 16'h0000;
	 reg [15:0] TIMEOUT_COUNTER = 16'h0000;

	 wire READ_OUT_TIMER;
	 
	wire test_pin;//
	reg test_pin1= 1'b0;
	 
	 wire BTN_CHANGED;
	 
	 wire BTN2_TOGGLE_STATUS;
	 wire BTN3_TOGGLE_STATUS;
	 
	 
	 reg [3:0] lcd_state_machine = 0;
	 reg lcd_send_hl = 0;
	 reg [7:0] lcd_data_size = 8'd80;
	 reg [79:0] lcd_data_to_send = 80'h4a757374796e61203a2a;
	 //reg [79:0] lcd_data_to_send = 80'h017601320176013201F8;
	 reg LCD_E_reg = 0;
	 reg [7:0] LCD_TIMEOUT = 8'h05;
	 reg [87:0] TEMP_READ_DATA = 88'h2B3030302C30303030DF43;
	 reg [3:0] set = 0;
	 reg [3:0] dzi = 0;
	 reg [3:0] jed = 0;
	 reg BTN_SAMPLE_old = 0;
	 reg hex_to_dec_machine = 0;
	 
	 reg [15:0] TEMP_FROM_DS=0;
	 reg [15:0] TEMP_FROM_DS_old=0;
	 reg [15:0] TEMP_FROM_DS_cal=0;

	 parameter idle=0, send_init=1, read_rom_command=2, read_rom_data=10, write_scratch_data=3, send_init2=4, skip_rom_command2=5, request_scratch_data=6, read_scratch_data=7, write_rom_command=8, calculate_temperature=9, timeout=13;
	 parameter LED_ON = 1, LED_OFF = 0;
	 parameter lcd_idle=0, lcd_init1=1, lcd_init2=2, lcd_init3=3, lcd_init4=4, lcd_init5=5, lcd_entry_mode=6, lcd_on=7, lcd_send_position=8, lcd_send_data=9, lcd_off=10, lcd_clear=11, start_next_line_data=12, send_temp=13, gotohome_data=14;
	 
     assign SS_B = 1'b1 ;					  // Disable SPI Flash after configuration
	
		 
	//assign FromFPGA = (BTN2_TOGGLE_STATUS)? DATA_RECEIVED[63:32]: DATA_RECEIVED[31:0];
	assign FromFPGA[31:16] = 8'd0;
	//assign FromFPGA[31:0]=  DATA_RECEIVED[31:0];
	//assign FromFPGA[31:0] =  TEMP_READ_DATA[87:56];
	assign FromFPGA[15:0] =TEMP_FROM_DS;
	assign LED1 = (BTN2_TOGGLE_STATUS)? LED_ON: LED_OFF;

	//assign LED1 = LED1_STATUS;
	
	assign CLK_WIRE = test_pin; //BTN_CHANGED;//ONE_WIRE_READY;
	
	always @(posedge CLK_3P3_MHZ)
	begin
	//TEMP_FROM_DS_old <= TEMP_FROM_DS;
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		case(hex_to_dec_machine)
		1'b0:
		begin
			TEMP_FROM_DS <= DATA_RECEIVED[15:0] >> 4;
			TEMP_FROM_DS_old <= TEMP_FROM_DS;
			TEMP_FROM_DS_cal <= DATA_RECEIVED[15:0];
			if(TEMP_FROM_DS_old != TEMP_FROM_DS) 
			begin
				hex_to_dec_machine <= 1'b1;
				set <= 0;
				dzi <= 0;
				jed <= 0;
			end
		end
		1'b1:
		begin
			if(TEMP_FROM_DS > 16'h0063)
			begin
				set <= set + 4'h1;
				TEMP_FROM_DS <= TEMP_FROM_DS - 16'h0064;
			end
			else if(TEMP_FROM_DS > 16'h0009)
			begin
				dzi <= dzi + 4'h1;
				TEMP_FROM_DS <= TEMP_FROM_DS - 16'h000A;
			end 
			else if(TEMP_FROM_DS > 16'h0000)
			begin
				jed <= jed + 4'h1;
				TEMP_FROM_DS <= TEMP_FROM_DS - 16'h0001;
			end
			else
			begin
			 if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h39333735;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h38373530;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h38313235;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h37353030;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h36383735;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h36323530;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h35363235;
			 else if(TEMP_FROM_DS_cal[3] == 1'b1 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h35303030;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h34333735;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h33373530;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h33313235;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b1 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h32353030;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h31383735;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b1 && TEMP_FROM_DS_cal[0] == 1'b0) TEMP_READ_DATA[47:16] <= 32'h31323530;
			 else if(TEMP_FROM_DS_cal[3] == 1'b0 && TEMP_FROM_DS_cal[2] == 1'b0 && TEMP_FROM_DS_cal[1] == 1'b0 && TEMP_FROM_DS_cal[0] == 1'b1) TEMP_READ_DATA[47:16] <= 32'h30363235;
			 else TEMP_READ_DATA[47:16] <= 32'h30303030;
			 
			 hex_to_dec_machine <= 1'b0;
			 
			 TEMP_READ_DATA[59:56] <= jed;
			 if(set == 0 && dzi == 0)
			 begin
				TEMP_READ_DATA[71:64] <= 8'h20;
				TEMP_READ_DATA[79:72] <= 8'h20;
			 end
			 else if(set == 0 && dzi != 0)
			 begin			 
				TEMP_READ_DATA[79:72] <= 8'h20;
				TEMP_READ_DATA[71:68] <= 4'h3;
				TEMP_READ_DATA[67:64] <= dzi;
			 end
			 else
			 begin
				TEMP_READ_DATA[79:76] <= 4'h3;
				TEMP_READ_DATA[75:72] <= set;
				TEMP_READ_DATA[71:68] <= 4'h3;
				TEMP_READ_DATA[67:64] <= dzi;
			 end
			end
		end
		default:
		begin
		end
		endcase
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		LCD_E <= LCD_E_reg;
	end
	
	always @(posedge READ_OUT_TIMER)
	begin
		case(lcd_state_machine)
		lcd_idle:
		begin
			if(LCD_TIMEOUT > 0)
			begin
				LCD_TIMEOUT <= LCD_TIMEOUT - 1;
				lcd_state_machine <= lcd_idle;
			end
			else
			begin
				LCD_RW <= 1'b0;
				LCD_RS <= 1'b0;
				lcd_send_hl <= 1'b1;
				lcd_state_machine <= lcd_init1;
				LCD_E_reg <= 1'b0;
			end
		end
		lcd_init1:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				LCD_DB <= 4'b0011;
				lcd_state_machine <= lcd_init2;
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_init2:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				LCD_DB <= 4'b0011;
				lcd_state_machine <= lcd_init3;
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_init3:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				LCD_DB <= 4'b0011;
				lcd_state_machine <= lcd_init4;
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_init4:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				LCD_DB <= 4'b0010;
				lcd_state_machine <= lcd_init5;
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_init5:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'b0010;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_init5;
				end
				else
				begin
					LCD_DB <= 4'b1000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_off;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_off:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'b0000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_off;
				end
				else
				begin
					LCD_DB <= 4'b1000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_clear;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_clear:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'b0000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_clear;
				end
				else
				begin
					LCD_DB <= 4'b0001;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_entry_mode;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_entry_mode:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'b0000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_entry_mode;
				end
				else
				begin
					LCD_DB <= 4'b0000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_on;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_on:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'b0000;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_on;
				end
				else
				begin
					LCD_DB <= 4'b1100;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_send_position;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_send_position:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'h0;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_send_position;
				end
				else
				begin
					LCD_DB <= 4'h2;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_send_data;
					lcd_data_size <= 8'd80;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		lcd_send_data:
		begin
			if(lcd_data_size > 0)
			begin
				if(!LCD_E_reg)
				begin
					LCD_RS <= 1'b1;
					LCD_RW <= 1'b0;
					LCD_E_reg <= 1'b1;
					if(lcd_send_hl)
					begin
						LCD_DB[3] <= lcd_data_to_send[lcd_data_size-1];
						LCD_DB[2] <= lcd_data_to_send[lcd_data_size-2];
						LCD_DB[1] <= lcd_data_to_send[lcd_data_size-3];
						LCD_DB[0] <= lcd_data_to_send[lcd_data_size-4];
						lcd_send_hl <= ~lcd_send_hl;
						lcd_state_machine <= lcd_send_data;
						lcd_data_size <= lcd_data_size - 4;
					end
					else
					begin
						LCD_DB[3] <= lcd_data_to_send[lcd_data_size-1];
						LCD_DB[2] <= lcd_data_to_send[lcd_data_size-2];
						LCD_DB[1] <= lcd_data_to_send[lcd_data_size-3];
						LCD_DB[0] <= lcd_data_to_send[lcd_data_size-4];
						lcd_send_hl <= ~lcd_send_hl;
						lcd_state_machine <= lcd_send_data;
						lcd_data_size <= lcd_data_size - 4;
					end
				end
				else
					LCD_E_reg <= 1'b0;
			end
			else
			begin
				lcd_state_machine <= start_next_line_data;
				lcd_data_size <= 8'd88;
			end
				
		end
		start_next_line_data:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 4'hC;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= start_next_line_data;
				end
				else
				begin
					LCD_DB <= 4'h0;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= send_temp;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		send_temp:
		begin
			if(lcd_data_size > 0)
			begin
				if(!LCD_E_reg)
				begin
					LCD_RS <= 1'b1;
					LCD_RW <= 1'b0;
					LCD_E_reg <= 1'b1;
					if(lcd_send_hl)
					begin
						LCD_DB[3] <= TEMP_READ_DATA[lcd_data_size-1];
						LCD_DB[2] <= TEMP_READ_DATA[lcd_data_size-2];
						LCD_DB[1] <= TEMP_READ_DATA[lcd_data_size-3];
						LCD_DB[0] <= TEMP_READ_DATA[lcd_data_size-4];
						lcd_send_hl <= ~lcd_send_hl;
						lcd_state_machine <= send_temp;
						lcd_data_size <= lcd_data_size - 4;
					end
					else
					begin
						LCD_DB[3] <= TEMP_READ_DATA[lcd_data_size-1];
						LCD_DB[2] <= TEMP_READ_DATA[lcd_data_size-2];
						LCD_DB[1] <= TEMP_READ_DATA[lcd_data_size-3];
						LCD_DB[0] <= TEMP_READ_DATA[lcd_data_size-4];
						lcd_send_hl <= ~lcd_send_hl;
						lcd_state_machine <= send_temp;
						lcd_data_size <= lcd_data_size - 4;
					end
				end
				else
					LCD_E_reg <= 1'b0;
			end
			else
			begin
					lcd_state_machine <= start_next_line_data;
					lcd_data_size <= 8'd88;
			end	
		end
		gotohome_data:
		begin
			if(!LCD_E_reg)
			begin
				LCD_RS <= 1'b0;
				LCD_RW <= 1'b0;
				LCD_E_reg <= 1'b1;
				if(lcd_send_hl)
				begin
					LCD_DB <= 1'h0;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_send_position;
				end
				else
				begin
					LCD_DB <= 1'h2;
					lcd_send_hl <= ~lcd_send_hl;
					lcd_state_machine <= lcd_send_data;
				end
			end
			else
				LCD_E_reg <= 1'b0;
		end
		default:
		begin
		 
		end
		endcase
	end
	
	always @(posedge UPDATE_COUNTER)
	begin
		BTN_SAMPLE_old <= BTN_SAMPLE;
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		case(one_wire_machine)
		 idle: //idle
		 begin
			LED1_STATUS = LED_OFF;
			if( BTN_SAMPLE_old != BTN_SAMPLE ) 
			begin
				ONE_WIRE_COUNTER = 10;
				one_wire_machine = send_init;
				next_one_wire_machine = send_init;
			end
			else
				ONE_WIRE_ENABLE = 0;
		 end
		 send_init:
		 begin
			if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				DATA_TO_SEND = 80'd0; 
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 1;
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = read_rom_command;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		read_rom_command:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'h000000000000000000CC;
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = write_scratch_data;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		read_rom_data:	   
		begin
		test_pin1 = 1'b1;
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'd0;
				ONE_WIRE_DATA_SIZE = 8'd64;
				ONE_WIRE_RW = 1;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 12000;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = idle;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		write_scratch_data:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				//DATA_TO_SEND = 80'h0000000000005555554E;
				//ONE_WIRE_DATA_SIZE = 8'd32;
				DATA_TO_SEND = 80'h00000000000000000044;
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 16000;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = send_init2;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		send_init2:
		 begin
			test_pin1 = 1'b1;
			if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				DATA_TO_SEND = 80'd0; 
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 1;
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = skip_rom_command2;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		skip_rom_command2:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'h000000000000000000CC;
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = request_scratch_data;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		request_scratch_data:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'h000000000000000000BE;
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = read_scratch_data;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		read_scratch_data:	   
		begin
		test_pin1 = 1'b0;
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'd0;
				ONE_WIRE_DATA_SIZE = 8'd80;
				ONE_WIRE_RW = 1;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 12000;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = idle;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		calculate_temperature:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE = 1;
				DATA_TO_SEND = 80'h00000000000000000044;
				ONE_WIRE_DATA_SIZE = 8'd8;
				ONE_WIRE_RW = 0;
				ONE_WIRE_INIT = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = idle;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		timeout:
		begin
			ONE_WIRE_ENABLE = 0;
			if(TIMEOUT_COUNTER > 0)
				TIMEOUT_COUNTER--;
			else
				one_wire_machine = next_one_wire_machine;
		end
		 default:
		 begin
			one_wire_machine = idle;
		end
		endcase
	end
		
   CAPSENSEBUTTONS BUTTONS (
      .CLK(CLK_3P3_MHZ) ,
      .BTN1(BTN1) ,
      .BTN2(BTN2) ,
      .BTN3(BTN3) ,
      .BTN4(BTN4) ,
      .BTN_SAMPLE(BTN_SAMPLE),
      .ANY_BTN_CHANGED(BTN_CHANGED),
      .BTN1_TOGGLE_STATUS(BTN1_TOGGLE_STATUS) ,
      .BTN2_TOGGLE_STATUS(BTN2_TOGGLE_STATUS) ,
      .BTN3_TOGGLE_STATUS(BTN3_TOGGLE_STATUS) ,
      .BTN4_TOGGLE_STATUS(BTN4_TOGGLE_STATUS)
   );
		
	CLK_DIVIDER_3P3MHz CLK_MANAGER(
	.CLK_3P3MHz(CLK_3P3_MHZ),
	.UPDATE_COUNTER(UPDATE_COUNTER),
	.BTN_SAMPLE(BTN_SAMPLE),
	.ONE_WIRE_CLK(ONE_WIRE_CLK),
	.READ_OUT_TIMER(READ_OUT_TIMER)
);

	RW_DATA_MODULE ONE_WIRE_MOD(
	.CLK(ONE_WIRE_CLK),
	.RW(ONE_WIRE_RW),
	.DATA_TO_SEND(DATA_TO_SEND),
	.COUNTER(ONE_WIRE_DATA_SIZE),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(ONE_WIRE_INIT),
	.ONE_WIRE_LINE(ONE_WIRE),
	.DATA_RECEIVED(DATA_RECEIVED),
	.READY(ONE_WIRE_READY),
	.test_pin(test_pin)
);

    Digilent_IOX USB_DEBUG (
    .ASTB(ASTB) ,      // Address strobe
    .DSTB(DSTB) ,      // Data strobe
    .WRITE(WRITE) ,    // Read/Write control
    .DB(DB),           // Data bus, byte-wide
    .WAIT(WAIT) ,      // Wait control
    // --- Virtual I/O signals
    .FromFPGA(FromFPGA) ,   // 32-bit value (From FPGA on GUI)
    .ToFPGA(ToFPGA)         // 32-bit value (To FPGA on GUI)
);

endmodule
/*
module ONE_WIRE_DRIVER (
	input CLK,
	input RW,
	input DATA_IN,
	input ENABLE,
	input INIT,
	inout ONE_WIRE_LINE,
	output READY,
	output reg DATA_OUT = 0,
	output reg test_pin
);

reg [3:0] machine_state=0;
reg [3:0] next_machine_state=0;
reg [15:0] ONE_EVENT_TIMER=0;
reg [8:0] LOW_LEVEL_COUNTER=0;
reg LOW_TO_HIGH_DETECTED=0;
reg ONE_WIRE=0;
reg WORKING_reg;

parameter ready_state = 0, init_1wire = 1, wait_init_1wire = 2, write_low = 3, write_high = 4, read_line = 5;

localparam init_low_timer = 450;
localparam init_high_timer = 12;
localparam read_low_timer = 1;
localparam read_high_timer = 89;
localparam read_sample_time = 3;
localparam write_high_init_timer = 1;
localparam write_high_end_timer = 89;
localparam write_low_init_timer = 89;
localparam write_low_end_timer = 1;

assign ONE_WIRE_LINE = ONE_WIRE;
assign READY = !(WORKING_reg | ENABLE); 

always @(ONE_EVENT_TIMER)
begin
	if(ONE_EVENT_TIMER == 0 && machine_state!=init_1wire) WORKING_reg = 1'b0;
	else WORKING_reg = 1'b1;
end

always @(posedge CLK)
begin
		case(machine_state)
		ready_state:
		begin
			ONE_WIRE <= 1'bz;
			if(ENABLE == 1)
			begin
				if(INIT == 1)
				begin
					ONE_EVENT_TIMER <= init_low_timer + init_high_timer;
				end
				else
				begin
					if(RW == 1)
					begin
						ONE_EVENT_TIMER <= 1 + read_low_timer + read_high_timer;
					end
					else
					begin
						if(DATA_IN == 1)
						begin
							ONE_EVENT_TIMER <= 1 + write_high_init_timer + write_high_end_timer;
						end
						else
						begin
							ONE_EVENT_TIMER <= 1 + write_low_init_timer + write_low_end_timer;
						end
					end
				end
			end
			else
			begin
				 ONE_EVENT_TIMER <= 0;
			end
		end
		init_1wire:
		begin
			LOW_LEVEL_COUNTER <= 8'h00;
			LOW_TO_HIGH_DETECTED <= 0;
			if(ONE_EVENT_TIMER > init_high_timer) ONE_WIRE <= 1'b0;
			else ONE_WIRE <= 1'bz;
			if(ONE_EVENT_TIMER == 0) ONE_EVENT_TIMER <= init_low_timer + init_high_timer;
		end
		wait_init_1wire:
		begin
			ONE_WIRE <= 1'bz;
			if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 0 && LOW_TO_HIGH_DETECTED == 0)
				LOW_LEVEL_COUNTER <= LOW_LEVEL_COUNTER + 1;
			else if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 1 && LOW_LEVEL_COUNTER > 0)
				LOW_TO_HIGH_DETECTED <= 1;
		end
		write_high:
		begin
			//ONE_WIRE = 1'b0;
			if(ONE_EVENT_TIMER > write_high_end_timer) ONE_WIRE <= 1'b0;
			else if(ONE_EVENT_TIMER  <= write_high_end_timer && ONE_EVENT_TIMER > 0) ONE_WIRE <= 1'bz;
		end
		write_low:
		begin
			//ONE_WIRE = 1'b1;
			if(ONE_EVENT_TIMER > write_low_end_timer) ONE_WIRE <= 1'b0;
			else if(ONE_EVENT_TIMER  <= write_low_end_timer && ONE_EVENT_TIMER > 0) ONE_WIRE <= 1'bz;
		end
		read_line:
		begin
			if(ONE_EVENT_TIMER > read_high_timer) ONE_WIRE <= 1'b0;
			else if(ONE_EVENT_TIMER  <= read_high_timer && ONE_EVENT_TIMER > 0) ONE_WIRE <= 1'bz;
			
			if(ONE_EVENT_TIMER == 1 + read_low_timer + read_high_timer - read_sample_time) 
			begin
				DATA_OUT <= ONE_WIRE_LINE;
				test_pin <= ONE_WIRE_LINE;
			end
			else
				;//test_pin <= 1'b0;
		end
		default:
		begin
			ONE_WIRE <= 1'bz;
		end
		endcase
		if(ONE_EVENT_TIMER > 0) 
		begin
			ONE_EVENT_TIMER <= ONE_EVENT_TIMER - 1;
		end
		else 
		begin
			ONE_WIRE <= 1'bz;
		end
end

always @(machine_state, ENABLE, ONE_EVENT_TIMER)//(posedge CLK)
begin
	case(machine_state)
	ready_state:
	begin
		if(ENABLE == 1)
		begin
			if(INIT == 1)
			begin
				next_machine_state = init_1wire;
			end
			else
			begin
				if(RW == 1)
				begin
					next_machine_state = read_line;
				end
				else
				begin
					if(DATA_IN == 1)
					begin
						next_machine_state = write_high;
					end
					else
					begin
						next_machine_state = write_low;
					end
				end
			end
		end
		else
		begin
			next_machine_state = ready_state;
		end
	end
	init_1wire:		if(ONE_EVENT_TIMER == 0) next_machine_state = wait_init_1wire; 	else next_machine_state = machine_state;
	wait_init_1wire:if(ONE_EVENT_TIMER == 0) next_machine_state = ready_state; 		else next_machine_state = machine_state;
	write_low:		if(ONE_EVENT_TIMER == 0) next_machine_state = ready_state; 		else next_machine_state = machine_state;
	write_high: 	if(ONE_EVENT_TIMER == 0) next_machine_state = ready_state; 		else next_machine_state = machine_state;
	read_line: 		if(ONE_EVENT_TIMER == 0) next_machine_state = ready_state; 		else next_machine_state = machine_state;
	default: 		next_machine_state = ready_state;
	endcase
end

always @(posedge CLK)
begin
	machine_state <= next_machine_state;
end

endmodule

module RW_DATA_MODULE (
	input CLK,
	input RW,
	input [79:0] DATA_TO_SEND,
	input [7:0] COUNTER,
	input ENABLE,
	input INIT,
	inout ONE_WIRE_LINE,
	output reg [79:0] DATA_RECEIVED,
	output READY,
	output reg test_pin
);

wire ONE_WIRE_ENABLE;

reg DATA_TO_DRIVER = 0;
reg ONE_WIRE_ENABLE_reg = 0;
wire ONE_WIRE_READY;

reg [7:0] DATA_LENGTH = 0;
reg WORKING_reg = 0;

reg [3:0] machine_state = 0;
reg [3:0] next_machine_state = 0;

parameter ready_state = 0, write_data = 2, read_data = 3, read_data_catch = 4;
   
 assign ONE_WIRE_RW = RW;
 assign READY = (INIT) ? ONE_WIRE_READY : !(WORKING_reg | ENABLE); 

 assign ONE_WIRE_ENABLE = (INIT) ? ENABLE : ONE_WIRE_ENABLE_reg; 
 
// always @(DATA_LENGTH)
// begin
//	if(DATA_LENGTH == 0) WORKING_reg = 1'b0;
//	else WORKING_reg = 1'b1;
 //end
 
 always @(ENABLE, DATA_LENGTH)
 begin
	if(ENABLE) WORKING_reg = 1'b1;
	else if(DATA_LENGTH == 0) WORKING_reg = 1'b0;
 end
 
always @(posedge CLK)
begin
		case(machine_state)
		ready_state: 
		begin
			if(ENABLE) 
			begin
				DATA_LENGTH <= 0;
				test_pin <= 1'b1;
			end
		end
		write_data:
		begin
			if(DATA_LENGTH < COUNTER)
			begin
				if(ONE_WIRE_READY)
				begin
						DATA_TO_DRIVER <= DATA_TO_SEND[DATA_LENGTH];
						ONE_WIRE_ENABLE_reg <= 1'b1;
						DATA_LENGTH <= DATA_LENGTH + 1;
				end
				else
				begin
					ONE_WIRE_ENABLE_reg <= 1'b0;
				end
			end
			else
			begin
				ONE_WIRE_ENABLE_reg <= 1'b0;
				DATA_LENGTH <= 0;
			end
		end
		read_data: 
		begin
			if(DATA_LENGTH < COUNTER)
			begin
				if(ONE_WIRE_READY)
				begin
					if(DATA_LENGTH > 0)	DATA_RECEIVED[DATA_LENGTH-1] <= DATA_FROM_DRIVER;
					ONE_WIRE_ENABLE_reg <= 1'b1;
					DATA_LENGTH <= DATA_LENGTH + 1;
				end
				else
				begin
					ONE_WIRE_ENABLE_reg <= 1'b0;
				end
			end
			else
			begin
				if(ONE_WIRE_READY) DATA_RECEIVED[DATA_LENGTH-1] <= DATA_FROM_DRIVER;
				ONE_WIRE_ENABLE_reg <= 1'b0;
				DATA_LENGTH <= 0;
			end
		end
		read_data_catch:
		begin
			if(ONE_WIRE_READY)
				begin
					//DATA_RECEIVED[DATA_LENGTH] <= DATA_FROM_DRIVER;
					//DATA_LENGTH++;
				end
		end
		default: ;
		
		endcase
end
  
always @(machine_state, INIT, RW, ENABLE, DATA_LENGTH)
begin
	case(machine_state)
	ready_state:
	begin
		if(INIT == 0 && ENABLE == 1)
		begin			
			if(RW == 1)
			begin
				next_machine_state <= read_data;
			end
			else
			begin
				next_machine_state <= write_data;
			end
		end
		else
		begin
			next_machine_state <= ready_state;
		end
	end
	write_data:	if(DATA_LENGTH == COUNTER) next_machine_state <= ready_state;
	read_data: if(DATA_LENGTH == COUNTER) next_machine_state <= ready_state;
	default: next_machine_state <= ready_state;
	endcase
end

always @(posedge CLK)
begin
	machine_state <= next_machine_state;
end
   
ONE_WIRE_DRIVER ONE_WIRE_MOD(
	.CLK(CLK),
	.RW(ONE_WIRE_RW),
	.DATA_IN(DATA_TO_DRIVER),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(INIT),
	.ONE_WIRE_LINE(ONE_WIRE_LINE),
	.DATA_OUT(DATA_FROM_DRIVER),
	.READY(ONE_WIRE_READY),
	.test_pin()
); 
   
endmodule
*/
module CAPSENSEBUTTONS (
    inout BTN1 ,
    inout BTN2 ,
    inout BTN3 ,
    inout BTN4 ,
    input BTN_SAMPLE ,
    input CLK ,
    output ANY_BTN_CHANGED ,
    output reg BTN1_TOGGLE_STATUS ,
    output reg BTN2_TOGGLE_STATUS ,
    output reg BTN3_TOGGLE_STATUS ,
    output reg BTN4_TOGGLE_STATUS
);

	 reg STATUS_ALL_BUTTONS = 1'b0 ;          // Indicates the status of all four buttons
	 reg STATUS_ALL_BUTTONS_LAST = 1'b0 ;     // Indicates the status during the last clock cycle
	 reg SAMPLE_BTN1 = 1'b0 ;				  // Captures the value on BTN1 
	 reg SAMPLE_BTN2 = 1'b0 ;				  // Captures the value on BTN2
	 reg SAMPLE_BTN3 = 1'b0 ;				  // Captures the value on BTN3
	 reg SAMPLE_BTN4 = 1'b0 ;				  // Captures the value on BTN4
	 reg SAMPLE_BTN1_LAST = 1'b0 ;            // Hold the previous value of BNT1
	 reg SAMPLE_BTN2_LAST = 1'b0 ;            // Hold the previous value of BNT2
	 reg SAMPLE_BTN3_LAST = 1'b0 ;            // Hold the previous value of BNT3
	 reg SAMPLE_BTN4_LAST = 1'b0 ;            // Hold the previous value of BNT4
	 //reg BTN1_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN1
	 //reg BTN2_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN2
	 //reg BTN3_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN3
	 //reg BTN4_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN4

	 wire BTN1_CHANGED ;                      // Indicates that the value on BTN1 changed from the previous sample
	 wire BTN2_CHANGED ;                      // Indicates that the value on BTN2 changed from the previous sample
	 wire BTN3_CHANGED ;                      // Indicates that the value on BTN3 changed from the previous sample
	 wire BTN4_CHANGED ;                      // Indicates that the value on BTN4 changed from the previous sample

	 // Capacitive buttons are driven to a steady Low value to bleed off any charge, 
	 // then allowed to float High.  An external resistor pulls each button pad High.
	 assign BTN1 = ( (BTN_SAMPLE) ? 1'bZ : 1'b0 ) ;
     assign BTN2 = ( (BTN_SAMPLE) ? 1'bZ : 1'b0 ) ;
     assign BTN3 = ( (BTN_SAMPLE) ? 1'bZ : 1'b0 ) ;
     assign BTN4 = ( (BTN_SAMPLE) ? 1'bZ : 1'b0 ) ;
	 
	 // Indicates when ANY of the four buttons goes High
	 always @(posedge CLK)
	     if (~BTN_SAMPLE) // Clear status when buttons driven low
		     STATUS_ALL_BUTTONS <= 1'b0 ;
		  else
		     // Trigger whenever any button goes High, but only during first incident
	         STATUS_ALL_BUTTONS <= (BTN1 | BTN2 | BTN3 | BTN4) & ~STATUS_ALL_BUTTONS_LAST ;
	        
	 // Indicates the last status of all four buttons
	 always @(posedge CLK)
	     if (~BTN_SAMPLE) // Clear status when buttons driven low
		     STATUS_ALL_BUTTONS_LAST <= 1'b0 ;
        else if (STATUS_ALL_BUTTONS)
			  STATUS_ALL_BUTTONS_LAST <= STATUS_ALL_BUTTONS ;

	 always @(posedge CLK)
		  if (STATUS_ALL_BUTTONS) // If any button went High after driving it low ...
		  begin                   //    ... wait one clock cycle before re-sampling the pin value
		     SAMPLE_BTN1 <= ~BTN1 ; // Invert polarity to make buttons active-High
		     SAMPLE_BTN2 <= ~BTN2 ;
		     SAMPLE_BTN3 <= ~BTN3 ;
		     SAMPLE_BTN4 <= ~BTN4 ;
			 SAMPLE_BTN1_LAST <= SAMPLE_BTN1 ; // Save last sample to see if the value changed
			 SAMPLE_BTN2_LAST <= SAMPLE_BTN2 ;
			 SAMPLE_BTN3_LAST <= SAMPLE_BTN3 ;
			 SAMPLE_BTN4_LAST <= SAMPLE_BTN4 ;
		  end

     // Toggle switch effect		  
	 assign BTN1_CHANGED = ( SAMPLE_BTN1 & !SAMPLE_BTN1_LAST ) ; // Sampled pin value changed  
	 assign BTN2_CHANGED = ( SAMPLE_BTN2 & !SAMPLE_BTN2_LAST ) ;	  
	 assign BTN3_CHANGED = ( SAMPLE_BTN3 & !SAMPLE_BTN3_LAST ) ;	  
	 assign BTN4_CHANGED = ( SAMPLE_BTN4 & !SAMPLE_BTN4_LAST ) ;	  

     // Indicates that one of the buttons was pressed
     assign ANY_BTN_CHANGED = ( BTN1_CHANGED | BTN2_CHANGED | BTN3_CHANGED | BTN4_CHANGED ) ;
 
     // If any button is pressed, toggle the button's current value    	 
	 always @(posedge CLK)
	 begin
	    if (BTN1_CHANGED)
		    BTN1_TOGGLE_STATUS <= ~(BTN1_TOGGLE_STATUS) ;
	    if (BTN2_CHANGED)
		    BTN2_TOGGLE_STATUS <= ~(BTN2_TOGGLE_STATUS) ;
	    if (BTN3_CHANGED)
		    BTN3_TOGGLE_STATUS <= ~(BTN3_TOGGLE_STATUS) ;
	    if (BTN4_CHANGED)
		    BTN4_TOGGLE_STATUS <= ~(BTN4_TOGGLE_STATUS) ;
   end
   
endmodule

module CLK_DIVIDER_3P3MHz (
   input        CLK_3P3MHz,
   output		UPDATE_COUNTER,
   output       BTN_SAMPLE,
   output		ONE_WIRE_CLK,
   output		READ_OUT_TIMER
);

   reg [19:0] COUNTER = 20'b0 ;

   always @(posedge CLK_3P3MHz)
      COUNTER <= COUNTER + 1;
	  assign UPDATE_COUNTER = COUNTER[19];
	  assign READ_OUT_TIMER = COUNTER[13];
	  assign BTN_SAMPLE = COUNTER[17] ;
	  assign ONE_WIRE_CLK = COUNTER[1];
endmodule

module Digilent_IOX (
    // -- Connections to Digilent Parallel Port (DPP) interface
    // -- Controlled by Digilent ADEPT 2 software and USB controller
    input ASTB ,      // Address strobe
    input DSTB ,      // Data strobe
    input WRITE ,     // Read/Write control
    inout [7:0] DB,   // Data bus, byte-wide
    output WAIT ,     // Wait control
    // --- Virtual I/O signals
    input [31:0] FromFPGA ,       // 32-bit value (From FPGA on GUI)
    output reg [31:0] ToFPGA      // 32-bit value (To FPGA on GUI)
);

   reg [7:0] AddressRegister ; // Epp address
   reg [7:0] CommValidRegister ;  // Communitation link confirmed by reading complement of value written to FPGA
   reg [7:0] busIOXinternal ; // Internal data bus
   
   // Assert WAIT signal whenever ASTB or DSTB are Low.  Maximum port speed. 
   assign WAIT = ( !ASTB | !DSTB ) ;

   // Control data direction to/from IOX interface
   // If WRITE = 1, then read value on busIOXinternal.  If WRITE = 0, set outputs to three-state (Hi-Z)
   assign DB = ( (WRITE) ? busIOXinternal : 8'bZZZZZZZZ ) ;

   // Read values from inside FPGA application and display on GUI
   always @(*)
   begin
      if (!ASTB)                               // When ASTB is Low
         busIOXinternal <= AddressRegister ;   // ... Read address register
      else if (AddressRegister == 8'h00)       // When address is 0x00
         busIOXinternal <= CommValidRegister ; // ... return the complement value written value to CommValidRegister
      else if (AddressRegister == 8'h0d)       // When address is 0x0D
         busIOXinternal <= FromFPGA[7:0] ;     // ... read value to be presented in "From FPGA" text box, bits 7:0 
      else if (AddressRegister == 8'h0e)       // When address is 0x0E
         busIOXinternal <= FromFPGA[15:8] ;    // ... read value to be presented in "From FPGA" text box, bits 15:8 
      else if (AddressRegister == 8'h0f)       // When address is 0x0F
         busIOXinternal <= FromFPGA[23:16] ;   // ... read value to be presented in "From FPGA" text box, bits 23:16
      else if (AddressRegister == 8'h10)       // When address is 0x10
         busIOXinternal <= FromFPGA[31:24] ;   // ... read value to be presented in "From FPGA" text box, bits 31:24
     else
         busIOXinternal <= 8'b11111111 ;       // Otherwise, read all ones (or any value that looks like non data)
   end

   // EPP Address Register
   // If WRITE = 0, load Address Register at rising-edge of ASTB
   always @(posedge ASTB)
      if (!WRITE)
         AddressRegister <= DB; 

   // Write Various Registers based on settings from GUI controls
   // If WRITE = 0, load register selected by Address Register at rising-edge of DSTB
   always @(posedge DSTB)
      if (!WRITE)
      begin
         if (AddressRegister == 8'h00)         // When address is 0x00
            CommValidRegister <= ~DB ;         // ... Load Verification register with complement of value written
                                               // ... The GUI writes to this register to verify proper communication with target
         else if (AddressRegister == 8'h09)    // When address is 0x09
            ToFPGA[7:0]  <= DB ;               // ... Load value from "To FPGA"  in GUI, bits 7:0
         else if (AddressRegister == 8'h0a)    // When address is 0x0A
            ToFPGA[15:8]  <= DB ;              // ... Load value from "To FPGA"  in GUI, bits 15:8
         else if (AddressRegister == 8'h0b)    // When address is 0x0B
            ToFPGA[23:16]  <= DB ;             // ... Load value from "To FPGA"  in GUI, bits 23:16
         else if (AddressRegister == 8'h0c)    // When address is 0x0C
            ToFPGA[31:24]  <= DB ;             // ... Load value from "To FPGA"  in GUI, bits 31:24
      end

endmodule