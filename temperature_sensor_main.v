`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////////////////////
// Aquarium control module on iCEblink40 board, VQ100 version
//
// Version 1.1
// Date:  1-NOV-2013
// ===============================================================================
// Description:
// 1-NOV-2013:KHO:LCD module (PARALEL), RTC module (UART), TEMPERATURE module(1WIRE) are created
/////////////////////////////////////////////////////////////////////////////////////////////////

module my_first(
	// -- Clock generator
	input  				CLK_3P3_MHZ,		// 3.3 MHz clock from LTC1799 oscillator (pin 13)
	// -- Buttons
	inout  				BTN1,			  	// Connection to cap-sense button BTN1 (pin 60)
	inout  				BTN2,			  	// Connection to cap-sense button BTN1 (pin 60)
	inout  				BTN3,			  	// Connection to cap-sense button BTN1 (pin 60)
	inout  				BTN4,			  	// Connection to cap-sense button BTN1 (pin 60)
	// -- Leds
	output 				LED1, 				// Drives LED LD2 (pin 53)
	output 				LED2,
	output 				LED3,
	output 				LED4,
	// -- Test pins
	output 				CLK_WIRE0,			//PIN 21
	output 				CLK_WIRE1,			//PIN 24
	output 				CLK_WIRE2,			//PIN 25
	// -- One Wire
	inout 				ONE_WIRE,			// 1Wire line
	// -- Encoder
	input  	wire		ENCODER_A,			// Encoder input B
	input 	wire		ENCODER_B,			// Encoder input A
	input 	wire		ENCODER_BUTTON,		// Encoder button pressed strobe
	// -- Digilent ADEPT 2 I/O Expander Debug Interface
	input  				ASTB ,              // Address strobe
	input  				DSTB ,              // Data strobe
	input  				WRITE ,             // Read/Write control
	inout 		[7:0] 	DB ,            	// Data bus, byte-wide
	output 				WAIT ,              // Wait signal
	// -- SPI prgraming
	output 				SS_B,	 			// SPI slave-select output
	// -- LCD
	output 				LCD_RS,				// LCD command/data input
	output	reg 		LCD_RW = 1'b0,		// LCD read/write input
	output				LCD_E,				// LCD data enable
	output		[3:0]	LCD_DB,				// LCD data bus
	// -- ASYNCH RTC
	output				RTC_RX,				// UART transmit line
	input				RTC_TX				// UART receive line
);
	 
	 
assign SS_B = 1'b1 ;					  // Disable SPI Flash after configuration
//
// -- global reset management
//
wire	GLOBAL_RESET_local = GLOBAL_RESET_TIME[3];
reg [3:0] GLOBAL_RESET_TIME = 4'b0000;

always @(posedge CLK_3P3_MHZ, posedge ENC_BUTTON_PRESSED)
begin
	if(ENC_BUTTON_PRESSED) GLOBAL_RESET_TIME <= 4'b0000;
	else 	begin
				GLOBAL_RESET_TIME[0] <= 1'b1;
				GLOBAL_RESET_TIME[1] <= GLOBAL_RESET_TIME[0];
				GLOBAL_RESET_TIME[2] <= GLOBAL_RESET_TIME[1];
				GLOBAL_RESET_TIME[3] <= GLOBAL_RESET_TIME[2];
			end
end
//
// -- Digilent ADEPT 2 I/O Expander Debug Graphical Interface (GUI) connections 
//
wire 	[31:0]	ToFPGA ;                // 32-bit value written to the FPGA, specified via a textbox on the graphical interface (GUI)
wire 	[31:0]	FromFPGA ;              // 32-bit value provided by the FPGA and displayed in a textbox on the graphical interface (GUI)
//
// -- CLOCKS
//
wire 			UPDATE_COUNTER;			//slow counter to enable readout
//
// -- RAM driver - block ram from ice40
//
wire	[7:0]	din;					//data to write
wire			write_en; 				//write enable
wire	[8:0]	waddr; 					//write address
wire	[8:0]	raddr; 					//data address
wire	[7:0]	dout;					//data read
//
// -- LCD driver PVC160205Q
//
wire 	[7:0] 	LCD_DATA;				//data to send
wire 			LCD_DATA_ENABLE;		//enable strobe
wire 			LCD_BUSY;				//busy flag
//
// -- 1Wire DS18B20
//
wire 	[11:0] 	TEMPERATURE;			//temperature from sensor
reg		[20:0]	TEMPERATURE_BCD = {1'b0,4'h3,4'h4,4'h5,4'h6,4'h7};		//temperature in BCD
reg		[20:0]	TEMPERATURE_BCD_temp = {1'b0,4'h3,4'h4,4'h5,4'h6,4'h7};		//temperature in BCD temporaty to calculate
reg 			DS18B20_ENABLE = 1'b0;	//temperature read enable
//machine 
wire 			ONE_WIRE_READY;			//1wire ready state
wire 	[7:0] 	ONE_WIRE_DATA_SIZE;		//1wire data size
wire 	[79:0] 	ONEWIRE_DATA_TO_SEND;	//1wire data to send
wire 	[79:0] 	DATA_RECEIVED;			//1wire data received
//
// -- UART RTC DS1615
//
wire 	[7:0] 	RTC_DATA_FROM_DRIVER;	//data from driver



	 
	wire LINE_1WIRE_TEST_PIN;
	wire DS18B20_TEST_PIN;
	wire RW_DATA_TEST_PIN;
	wire ASYNCH_TEST_PIN;
	wire RTC_TEST_PIN;
	wire [7:0] RTC_HOUR;
	wire [7:0] RTC_MINUTE;
	wire [7:0] RTC_SECOND;
	
	reg RTC_READ_ID = 1'b0;
	
	wire [47:0] RTC_ID;
	wire ASYNCH_READY;
	wire [7:0] ASYNCH_BYTE_TO_SEND;
	wire ASYNCH_ENABLE;
	
	 wire BTN_CHANGED;
	 wire BTN2_TOGGLE_STATUS;
	 wire BTN3_TOGGLE_STATUS;
	
	wire LCD_TEST_PIN;
	wire [3:0] lcd_main_state;

	 reg hex_to_dec_machine = 0;
	 
	 reg [15:0] TEMP_FROM_DS=0;
	 reg [15:0] TEMP_FROM_DS_old=0;

	 reg ENC_RIGHT = 1'b0;
	 reg ENC_LEFT = 1'b0;
	 reg ENC_BUTTON_DOWN = 1'b0;
	 reg ENC_BUTTON_UP = 1'b0;
	 reg ENC_BUTTON_PRESSED = 1'b0;
	 
	 reg [15:0] ENC_state = 16'h0000;
	 reg ENC_counter = 4'h0;
	 
	 parameter LED_ON = 1, LED_OFF = 0;
		 
	//assign FromFPGA = (BTN2_TOGGLE_STATUS)? DATA_RECEIVED[63:32]: DATA_RECEIVED[31:0];
	//assign FromFPGA[19:16] = LINE_DRIVER_ACTUAL_STATE;
	//assign FromFPGA[15:0] =	 TEMP_FROM_DS;
	//assign FromFPGA[31:0]=  DATA_RECEIVED[31:0];
	//assign FromFPGA[31:0] = RTC_ID[47:32];
	//assign FromFPGA[31:0] = {4'h00, RTC_HOUR, RTC_MINUTE, RTC_SECOND};
	assign FromFPGA[31:0] = {28'b0,lcd_main_state};
	//assign FromFPGA[15:0] = GLOBAL_RESET_TIME;//test_counter;
	//wire [15:0] lcd_step_count;
	assign CLK_WIRE0 = LCD_E;//LINE_1WIRE_TEST_PIN;
	assign CLK_WIRE1 = RTC_RX; //ENC_RIGHT;//DS18B20_TEST_PIN;
	//assign CLK_WIRE2 = RW_DATA_TEST_PIN;
	assign CLK_WIRE2 = LCD_TEST_PIN; //ENC_LEFT;//ASYNCH_TEST_PIN;
	wire [4:0] lcd_counter_test;
	reg [7:0] addr_to_write = 0;
	reg [7:0] data_to_send = 0;
	reg [8:0] addr_to_send = 0;
	reg write_enable = 0;
	
	assign din = data_to_send;
	assign write_en = write_enable;
	assign waddr = addr_to_send;
	
	always @(posedge CLK_3P3_MHZ)
	begin
		if(GLOBAL_RESET) 	begin
								data_to_send <= 0;
								addr_to_send <= 0;
								write_enable <= 0;
								addr_to_write <= 0;
							end
		else
		case(addr_to_write)
			0: 	begin
					data_to_send <= 8'h30 + RTC_SECOND[3:0];
					addr_to_send <= 9'h0F;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			1: 	begin
					data_to_send <= 8'h30 + RTC_SECOND[3:0];
					addr_to_send <= 9'h0F;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			2: 	begin
					data_to_send <= 8'h30 + RTC_SECOND[7:4];
					addr_to_send <= 9'h0E;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			3: 	begin
					data_to_send <= 8'h30 + RTC_SECOND[7:4];
					addr_to_send <= 9'h0E;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			4: 	begin
					data_to_send <= 8'h30 + RTC_MINUTE[3:0];
					addr_to_send <= 9'h0C;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			5: 	begin
					data_to_send <= 8'h30 + RTC_MINUTE[3:0];
					addr_to_send <= 9'h0C;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			6: 	begin
					data_to_send <= 8'h30 + RTC_MINUTE[7:4];
					addr_to_send <= 9'h0B;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			7: 	begin
					data_to_send <= 8'h30 + RTC_MINUTE[7:4];
					addr_to_send <= 9'h0B;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			8: 	begin
					data_to_send <= 8'h30 + RTC_HOUR[3:0];
					addr_to_send <= 9'h09;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			9: 	begin
					data_to_send <= 8'h30 + RTC_HOUR[3:0];
					addr_to_send <= 9'h09;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			10: 	begin
					data_to_send <= 8'h30 + RTC_HOUR[7:4];
					addr_to_send <= 9'h08;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			11: 	begin
					data_to_send <= 8'h30 + RTC_HOUR[7:4];
					addr_to_send <= 9'h08;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
				
			
			12: 	begin
					data_to_send <= (TEMPERATURE_BCD[20])? 8'h2D : 8'h2B;
					addr_to_send <= 9'h10;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			13: 	begin
					data_to_send <= (TEMPERATURE_BCD[20])? 8'h2D : 8'h2B;
					addr_to_send <= 9'h10;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			14: 	begin
					data_to_send <= (TEMPERATURE_BCD[19:16] == 4'h0) ? 8'h20 : 8'h30 + TEMPERATURE_BCD[19:16];
					addr_to_send <= 9'h11;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			15: 	begin
					data_to_send <= (TEMPERATURE_BCD[19:16] == 4'h0) ? 8'h20 : 8'h30 + TEMPERATURE_BCD[19:16];
					addr_to_send <= 9'h11;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			16: 	begin
					data_to_send <= (TEMPERATURE_BCD[19:12] == 8'h00) ? 8'h20 : 8'h30 + TEMPERATURE_BCD[15:12];
					addr_to_send <= 9'h12;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			17: 	begin
					data_to_send <= (TEMPERATURE_BCD[19:12] == 8'h00) ? 8'h20 : 8'h30 + TEMPERATURE_BCD[15:12];
					addr_to_send <= 9'h12;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			18: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[11:8];
					addr_to_send <= 9'h13;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			19: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[11:8];
					addr_to_send <= 9'h13;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			20: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[7:4];
					addr_to_send <= 9'h15;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			21: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[7:4];
					addr_to_send <= 9'h15;
					write_enable <= 1'b0;
					addr_to_write <= addr_to_write + 1;
				end	
			22: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[3:0];
					addr_to_send <= 9'h16;
					write_enable <= 1'b1;
					addr_to_write <= addr_to_write + 1;
				end
			23: 	begin
					data_to_send <= 8'h30 + TEMPERATURE_BCD[3:0];
					addr_to_send <= 9'h16;
					write_enable <= 1'b0;
					addr_to_write <= 0;
				end	
		endcase
	end

	reg OLD_ENCODER_A = 1'b0;
	reg OLD_ENCODER_BUTTON = 1'b0;
	
	reg [7:0] test_counter = 1'b0;
	
	always @(posedge CLK_3P3_MHZ)
	begin
		OLD_ENCODER_A <= #1 ENCODER_A;
		OLD_ENCODER_BUTTON <= #1 ENCODER_BUTTON;
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		if(ENC_BUTTON_DOWN == 1'b1) test_counter <= 8'h00;
		else if(ENC_RIGHT) if(ENC_BUTTON_PRESSED) test_counter <= test_counter + 10; else test_counter <= test_counter + 1;
		else if(ENC_LEFT) if(ENC_BUTTON_PRESSED) test_counter <= test_counter - 10; else test_counter <= test_counter - 1;
		else test_counter <= test_counter;
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		case(ENC_state)
			16'h0000: 	begin
						ENC_RIGHT <= 1'b0;
						ENC_LEFT <= 1'b0;
						ENC_BUTTON_DOWN <= 1'b0;
						ENC_BUTTON_UP <= 1'b0;
						if(OLD_ENCODER_BUTTON == 1'b1 && ENCODER_BUTTON == 1'b0) ENC_state <= 16'h00FE;
						else if(OLD_ENCODER_BUTTON == 1'b0 && ENCODER_BUTTON == 1'b1) ENC_state <= 16'h00FC;
						else if(OLD_ENCODER_A == 1'b0 && ENCODER_A == 1'b1) ENC_state <= 16'h0001;
						else if(OLD_ENCODER_A == 1'b1 && ENCODER_A == 1'b0) ENC_state <= 16'h0002;
						else ENC_state <= 16'h0000;
					end
			16'h0001:	begin
						if(ENCODER_B)
						begin
							ENC_RIGHT <= 1'b1;
							ENC_LEFT <= 1'b0;
						end
						else
						begin
							ENC_RIGHT <= 1'b0;
							ENC_LEFT <= 1'b1;
						end
						ENC_state <= 16'h0100;
					end
			16'h0002:  begin
						if(ENCODER_B)
						begin
							ENC_RIGHT <= 1'b0;
							ENC_LEFT <= 1'b1;
						end
						else
						begin
							ENC_RIGHT <= 1'b1;
							ENC_LEFT <= 1'b0;
						end
						ENC_state <= 16'h0100;
					end
			16'h00FC:  	begin
							if(ENCODER_BUTTON == 1'b1) ENC_state <= 16'h00FD;
							else ENC_state <= 16'h1000;
						end
			16'h00FD:  	begin
							if(ENCODER_BUTTON == 1'b1) begin
															ENC_BUTTON_PRESSED <= 1'b0;
															ENC_BUTTON_UP <= 1'b1;
														end 
							ENC_state <= 16'h0100;
						end
			16'h00FE:  	begin
							if(ENCODER_BUTTON == 1'b0) ENC_state <= 16'h00FF;
							else ENC_state <= 16'h1000;
						end
			16'h00FF:  	begin
							if(ENCODER_BUTTON == 1'b0) begin
															ENC_BUTTON_PRESSED <= 1'b1;
															ENC_BUTTON_DOWN <= 1'b1;
														end
							ENC_state <= 16'h0100;
						end
			default: begin
						if(ENC_state == 16'hFFFF) ENC_state <= 16'h0000; else ENC_state <= ENC_state + 1;
						ENC_BUTTON_DOWN <= 1'b0;
						ENC_BUTTON_UP <= 1'b0;
						ENC_RIGHT <= 1'b0;
						ENC_LEFT <= 1'b0;
					 end
		endcase
	end
	
	always @(posedge CLK_3P3_MHZ)
	begin
		case(hex_to_dec_machine)
		1'b0:
		begin
			TEMP_FROM_DS <= TEMPERATURE;
			TEMP_FROM_DS_old <= TEMP_FROM_DS;
			TEMPERATURE_BCD <= TEMPERATURE_BCD_temp;
			if(TEMPERATURE != TEMP_FROM_DS) 
			begin
				hex_to_dec_machine <= 1'b1;
				TEMPERATURE_BCD_temp <= 21'b0;
			end
		end
		1'b1:
		begin
			if(TEMP_FROM_DS[11] == 1'b1)
			begin
				TEMPERATURE_BCD_temp[20] <= 1'b1;
				TEMP_FROM_DS <= ~TEMP_FROM_DS - 1;
			end
			else if(TEMP_FROM_DS[11:4] > 16'h0063)
			begin
				TEMPERATURE_BCD_temp[19:16] <= TEMPERATURE_BCD_temp[19:16] + 4'h1;
				TEMP_FROM_DS[11:4] <= TEMP_FROM_DS[11:4] - 8'h64;
			end
			else if(TEMP_FROM_DS[11:4] > 16'h0009)
			begin
				TEMPERATURE_BCD_temp[15:12] <= TEMPERATURE_BCD_temp[15:12] + 4'h1;
				TEMP_FROM_DS[11:4] <= TEMP_FROM_DS[11:4] - 8'h0A;
			end 
			else if(TEMP_FROM_DS[11:4] > 16'h0000)
			begin
				TEMPERATURE_BCD_temp[11:8] <= TEMPERATURE_BCD_temp[11:8] +  4'h1;
				TEMP_FROM_DS[11:4] <= TEMP_FROM_DS[11:4] - 8'h01;
			end
			else
			begin 
			 if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h94; 
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h87;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h81;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h75;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h69;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h62;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h56;
			 else if(TEMP_FROM_DS[3] == 1'b1 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h50;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h44;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h38;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h31;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b1 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h25;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h19;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b1 && TEMP_FROM_DS[0] == 1'b0) TEMPERATURE_BCD_temp[7:0] <= 8'h13;
			 else if(TEMP_FROM_DS[3] == 1'b0 && TEMP_FROM_DS[2] == 1'b0 && TEMP_FROM_DS[1] == 1'b0 && TEMP_FROM_DS[0] == 1'b1) TEMPERATURE_BCD_temp[7:0] <= 8'h06;
			 else TEMPERATURE_BCD_temp[7:0] <= 8'h00;
			 
			 hex_to_dec_machine <= 1'b0;
			end
		end
		default:
		begin
		end
		endcase
	end
	
	always @(posedge UPDATE_COUNTER)
	begin
		DS18B20_ENABLE <= ~DS18B20_ENABLE;
		RTC_READ_ID <= ~RTC_READ_ID;
	end
	
	DS18B20_DRIVER DS18B20(
	.DS18B20_CLK(CLK_3P3_MHZ),
	.DS18B20_RESET(GLOBAL_RESET),
	.DS18B20_RESOLUTION(2'b00),
	.DS18B20_T_HIGH(8'd0),
	.DS18B20_T_LOW(8'd0),
	.DS18B20_ID(48'd0),
	.DS18B20_GET_TEMP(DS18B20_ENABLE),
	.DS18B20_READ_DATA(1'b0),
	.DS18B20_WRITE_DATA(1'b0),
	.DS18B20_STORE_IN_EE(1'b0),
	.DS18B20_RECALL_FROM_EE(1'b0),
	.DS18B20_TEMPERATURE(TEMPERATURE),
	.DS18B20_RESOLUTION_OUT(),
	.DS18B20_T_HIGH_OUT(),
	.DS18B20_T_LOW_OUT(),
	.DS18B20_CRC(),
	.DS18B20_ERROR(),
	.DS18B20_READY(),
	//.DS18B20_ACTUAL_STATE(DS18B20_ACTUAL_STATE),
	//one wire interface
	.DS18B20_DATA_RECEIVED(DATA_RECEIVED),
	.DS18B20_ONE_WIRE_READY(ONE_WIRE_READY),
	.DS18B20_ONE_WIRE_RW(ONE_WIRE_RW),
	.DS18B20_DATA_TO_SEND(ONEWIRE_DATA_TO_SEND),
	.DS18B20_ONE_WIRE_DATA_SIZE(ONE_WIRE_DATA_SIZE),
	.DS18B20_ONE_WIRE_ENABLE(ONE_WIRE_ENABLE),
	.DS18B20_ONE_WIRE_INIT(ONE_WIRE_INIT),
	.DS18B20_TEST_PIN(DS18B20_TEST_PIN)
	);
	
	RW_DATA_MODULE ONE_WIRE_MODULE(
	.RW_DATA_CLK(CLK_3P3_MHZ),
	.RW(ONE_WIRE_RW),
	.DATA_TO_SEND(ONEWIRE_DATA_TO_SEND),
	.COUNTER(ONE_WIRE_DATA_SIZE),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(ONE_WIRE_INIT),
	.DATA_RECEIVED(DATA_RECEIVED),
	.ONE_WIRE_READY(ONE_WIRE_READY),
	//.ACTUAL_STATE(RW_DATA_ACTUAL_STATE),
	.test_pin(RW_DATA_TEST_PIN),
	//connect to 1wire module
	.RW_DATA_DATA_FROM_DRIVER(DRIVER_TO_RW_DATA),
	.RW_DATA_DRIVER_READY(LINE_1WIRE_DRIVER_READY),
	.RW_DATA_DRIVER_OK(LINE_1WIRE_LINE_OK),
	.RW_DATA_RW_DRIVER(LINE_1WIRE_DRIVER_RW),
	.RW_DATA_DATA_TO_DRIVER(RW_TO_DRIVER_DATA),
	.RW_DATA_DRIVER_ENABLE(LINE_1WIRE_DRIVER_ENABLE),
	.RW_DATA_INIT_DRIVER(LINE_1WIRE_INIT_DRIVER)
);
	
	ONE_WIRE_DRIVER ONE_WIRE_DRIVER(
	.LINE_1WIRE_CLK(CLK_3P3_MHZ),
	.LINE_1WIRE_RW(LINE_1WIRE_DRIVER_RW),
	.LINE_1WIRE_DATA_IN(RW_TO_DRIVER_DATA),
	.LINE_1WIRE_ENABLE(LINE_1WIRE_DRIVER_ENABLE),
	.LINE_1WIRE_INIT(LINE_1WIRE_INIT_DRIVER),
	.LINE_1WIRE_ONE_WIRE_LINE(ONE_WIRE),
	.LINE_1WIRE_DATA_OUT(DRIVER_TO_RW_DATA),
	.LINE_1WIRE_READY(LINE_1WIRE_DRIVER_READY),
	.LINE_1WIRE_LINE_OK(LINE_1WIRE_LINE_OK),
	.LINE_1WIRE_test_pin(LINE_1WIRE_TEST_PIN)
); 
	
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
	.READ_OUT_TIMER()
);

	ASYNCH_DRIVER ASYNCH_DRIVER(
	.ASYNCH_CLK(CLK_3P3_MHZ),
	.ASYNCH_BYTE_TO_SEND(ASYNCH_BYTE_TO_SEND),
	.ASYNCH_ENABLE(ASYNCH_ENABLE),
	.ASYNCH_TX_LINE(RTC_TX),
	.ASYNCH_RX_LINE(RTC_RX),
	.ASYNCH_READY(ASYNCH_READY),
	.ASYNCH_BYTE_RECEIVED(RTC_DATA_FROM_DRIVER),
	.ASYNCH_DATA_OK(ASYNCH_DATA_OK),
	.ASYNCH_TEST_PIN(ASYNCH_TEST_PIN)
);

RTC_MODULE RTC_MODULE(
	.RTC_CLK(CLK_3P3_MHZ),
	.RTC_RESET(GLOBAL_RESET),
	.RTC_READ_ID(1'b0),
	.RTC_READ_STATUS(RTC_READ_ID),
	.RTC_SET_CLOCK(1'b0),//RTC_READ_ID),
	.RTC_DATA_FROM_DRIVER(RTC_DATA_FROM_DRIVER),
	.RTC_DATA_OK(ASYNCH_DATA_OK),
	.RTC_ID(RTC_ID),
	.RTC_READY(),
	.RTC_TEST_PIN(RTC_TEST_PIN),
	.RTC_SECOND(RTC_SECOND),
	.RTC_MINUTE(RTC_MINUTE),
	.RTC_HOUR(RTC_HOUR),
	.RTC_WEEKDAY(),
	.RTC_DAY(),
	.RTC_MONTH(),
	.RTC_YEAR(),
	//asnych driver
	.RTC_ASYNCH_READY(ASYNCH_READY),
	.RTC_ASYNCH_BYTE_TO_SEND(ASYNCH_BYTE_TO_SEND),
	.RTC_ASYNCH_ENABLE(ASYNCH_ENABLE)
	
);

ram RAM(
	.reset(GLOBAL_RESET),
	.din(din), 
	.write_en(write_en), 
	.waddr(waddr), 
	.wclk(CLK_3P3_MHZ), 
	.raddr(raddr), 
	.rclk(CLK_3P3_MHZ), 
	.dout(dout)
);

LCD_DRIVER lcd_module (
	.LCD_CLK(CLK_3P3_MHZ),
	.LCD_RESET(GLOBAL_RESET),
	.LCD_DATA_ext(LCD_DATA),
	.LCD_DATA_ENABLE_ext(LCD_DATA_ENABLE),
	.LCD_COMMAND(LCD_COMMAND),
	.LCD_RS(LCD_RS), 
	.LCD_E(LCD_E),
	.LCD_DataBus(LCD_DB),
	.LCD_BUSY(LCD_BUSY),
	.LCD_SENDING_ENABLE(LCD_SENDING_ENABLE),
	.lcd_counter_test(lcd_counter_test),
	.LCD_TEST_PIN(LCD_TEST_PIN)
	//.lcd_step_count(lcd_step_count)
);

LCD_MAIN lcd_main_loop (
	.LCD_MAIN_CLK(CLK_3P3_MHZ),						//LCD main clock
	.LCD_MAIN_RESET(GLOBAL_RESET),					//LCD global reset
	.LCD_MAIN_SENDING_ENABLE(LCD_SENDING_ENABLE),	//LCD enable state machine
	//To configuration status
	.LCD_MAIN_START_ADDRESS(test_counter[1:0]),					//LCD start address, where pointer to first line in memory
	//To memory
	.LCD_MAIN_DATA_IN(dout),						//LCD data from memory, addressed by LCD_MAIN_MEMORY_ADDRESS
	.LCD_MAIN_DATA_ENABLED(1'b1),					//LCD data from memory ready
	.LCD_MAIN_MEMORY_REQUEST(),						//LCD request access to memory
	.LCD_MAIN_MEMORY_ADDRESS(raddr),				//LCD set memory address
	//To LCD driver
	.LCD_BUSY(LCD_BUSY),							//LCD busy flag
	.LCD_DATA(LCD_DATA),							//Data to send
	.LCD_DATA_ENABLE(LCD_DATA_ENABLE),				//Write data into LCD
	.LCD_COMMAND(LCD_COMMAND),
	.lcd_main_state(lcd_main_state),
	.LCD_MAIN_TEST_PIN(LCD_MAIN_TEST_PIN)
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

SB_GB Reset_global_buffer (
.USER_SIGNAL_TO_GLOBAL_BUFFER (~GLOBAL_RESET_local),
.GLOBAL_BUFFER_OUTPUT (GLOBAL_RESET) 
);

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