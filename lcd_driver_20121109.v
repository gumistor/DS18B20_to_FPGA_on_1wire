module LCD_MAIN (
	input				LCD_MAIN_CLK,				//LCD main clock
	input				LCD_MAIN_RESET,				//LCD global reset
	input				LCD_MAIN_SENDING_ENABLE,	//LCD enable state machine
	//To configuration status
	input		[1:0]	LCD_MAIN_START_ADDRESS,		//LCD start address, where pointer to first line in memory
	//To memory
	input		[7:0]	LCD_MAIN_DATA_IN,			//LCD data from memory, addressed by LCD_MAIN_MEMORY_ADDRESS
	input				LCD_MAIN_DATA_ENABLED,		//LCD data from memory ready
	output	reg			LCD_MAIN_MEMORY_REQUEST = 1'b0,	//LCD request access to memory
	output		[8:0]	LCD_MAIN_MEMORY_ADDRESS,	//LCD set memory address
	//To LCD driver
	input				LCD_BUSY,					//LCD busy flag
	output	reg	[7:0]	LCD_DATA = 8'h00,					//Data to send
	output	reg			LCD_DATA_ENABLE = 1'b0,		//Write data into LCD
	output		[3:0]		lcd_main_state,
	output				LCD_MAIN_TEST_PIN
);

reg [3:0] LCD_MAIN_MEMORY_lower_address = 4'b0000;
reg LCD_MAIN_START_line = 1'b0;

assign LCD_MAIN_MEMORY_ADDRESS = {5'b00011 & (LCD_MAIN_START_ADDRESS + LCD_MAIN_START_line) , LCD_MAIN_MEMORY_lower_address};

//assign LCD_DATA = 8'h30 + LCD_MAIN_MEMORY_lower_address[3:0]; //LCD_MAIN_DATA_IN;

assign LCD_MAIN_TEST_PIN = LCD_DATA_ENABLE;

parameter lcd_idle = 4'h0, lcd_request_data = 4'h1, lcd_send_data = 4'h2, lcd_send_wait = 4'h3, lcd_next_byte = 4'h4, lcd_send_null = 4'h5, lcd_null_wait = 4'h6, lcd_send_chng = 4'h7, lcd_chng_wait = 4'h8, lcd_next_byte_ = 4'h9;
reg [3:0] lcd_main_state = 4'h0;
reg [3:0] lcd_main_state_next = 4'h0;

always @(posedge LCD_MAIN_CLK)
begin
	if(LCD_MAIN_RESET)	lcd_main_state <= #1 lcd_idle;
	else				lcd_main_state <= #1 lcd_main_state_next;
end

always @(lcd_main_state or LCD_MAIN_SENDING_ENABLE or LCD_BUSY or LCD_MAIN_DATA_ENABLED or LCD_MAIN_MEMORY_lower_address)
begin
	case(lcd_main_state)
		lcd_idle: if(LCD_MAIN_SENDING_ENABLE) lcd_main_state_next = lcd_request_data; else lcd_main_state_next = lcd_main_state;
		lcd_request_data: if(LCD_MAIN_SENDING_ENABLE && LCD_MAIN_DATA_ENABLED && !LCD_BUSY) lcd_main_state_next = lcd_send_data; else lcd_main_state_next = lcd_main_state;
		lcd_send_data: if(LCD_BUSY) lcd_main_state_next = lcd_send_wait; else lcd_main_state_next = lcd_main_state;
		lcd_send_wait: if(!LCD_BUSY) lcd_main_state_next = lcd_next_byte; else lcd_main_state_next = lcd_main_state;
		lcd_next_byte: if(LCD_MAIN_MEMORY_lower_address == 4'hF) lcd_main_state_next = lcd_send_null; else lcd_main_state_next = lcd_request_data;
		lcd_send_null:	if(!LCD_BUSY) lcd_main_state_next = lcd_null_wait; else lcd_main_state_next = lcd_main_state;
		lcd_null_wait:	if(!LCD_BUSY) lcd_main_state_next = lcd_send_chng; else lcd_main_state_next = lcd_main_state;
		lcd_send_chng:	if(LCD_BUSY) lcd_main_state_next = lcd_chng_wait; else lcd_main_state_next = lcd_main_state;
		lcd_chng_wait:	if(!LCD_BUSY) lcd_main_state_next = lcd_next_byte_; else lcd_main_state_next = lcd_main_state;
		lcd_next_byte_: lcd_main_state_next = lcd_idle;
		default: lcd_main_state_next = lcd_idle;
	endcase
	
end

always @(posedge LCD_MAIN_CLK)
begin
	if(LCD_MAIN_RESET)	begin
									LCD_DATA <= #1 8'h00;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 4'h0;
									LCD_DATA_ENABLE <= #1 1'b0;
									LCD_MAIN_START_line <= #1 1'b0;
						end
	else
	begin
		case(lcd_main_state)
			lcd_idle:			begin
									LCD_DATA <= #1 8'h00;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 4'h0;
									LCD_DATA_ENABLE <= #1 1'b0;
								end
			lcd_request_data:	begin
									LCD_DATA <= #1 8'h00;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b1;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b0;
								end
			lcd_send_data: 		begin
									LCD_DATA <= #1 LCD_MAIN_DATA_IN;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b1;
								end
			lcd_send_wait: 		begin
									LCD_DATA <= #1 LCD_DATA;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b0;
								end					
			lcd_next_byte:		begin
									LCD_DATA <= #1 8'h00;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address + 1;
									LCD_DATA_ENABLE <= #1 1'b0;
								end
			lcd_send_null:		begin
									LCD_DATA <= #1 8'h00;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b1;
								end
			lcd_null_wait: 		begin
									LCD_DATA <= #1 LCD_DATA;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b0;
								end
			lcd_send_chng:		begin
									if(LCD_MAIN_START_line) LCD_DATA <= #1 8'h80; 
									else LCD_DATA <= #1 8'hC0;
									LCD_MAIN_START_line <= #1 ~LCD_MAIN_START_line;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b1;
								end
			lcd_chng_wait: 		begin
									LCD_DATA <= #1 LCD_DATA;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 LCD_MAIN_MEMORY_lower_address;
									LCD_DATA_ENABLE <= #1 1'b0;
								end		
			lcd_next_byte_:		begin
									LCD_DATA <= #1 LCD_DATA;
									LCD_MAIN_MEMORY_REQUEST <= #1 1'b0;
									LCD_MAIN_MEMORY_lower_address <= #1 4'h0;
									LCD_DATA_ENABLE <= #1 1'b0;
								end								
			default: ;
		endcase
	end
end
endmodule

module LCD_DRIVER (
	input LCD_CLK,
	input LCD_RESET,
	input [7:0] LCD_DATA_ext,
	input LCD_DATA_ENABLE_ext,
	input LCD_COMMAND,
	output reg LCD_RS = 1'b0, 
	output reg LCD_E = 1'b0,
	output [3:0] LCD_DataBus,
	output LCD_BUSY,
	output  LCD_SENDING_ENABLE,// = 1'b0,
	output	[4:0]			lcd_counter_test,
	output LCD_TEST_PIN
	//output reg [15:0] lcd_step_count
);

reg [15:0] lcd_step_count =  16'h0000;
reg LCD_INIT_latch = 1'b0;

reg LCD_DATA_ENABLE_int = 1'b0;
wire [7:0] LCD_DATA_int;// = 8'h00;

wire [7:0] LCD_DATA = (LCD_SENDING_ENABLE) ? LCD_DATA_ext : LCD_DATA_int;
wire LCD_DATA_ENABLE = (LCD_SENDING_ENABLE) ? LCD_DATA_ENABLE_ext : LCD_DATA_ENABLE_int;

wire LCD_Start_Function = LCD_DATA_ENABLE & (LCD_DATA==0);
wire LCD_Start_Data = ((LCD_DATA_ENABLE & (LCD_DATA!=0)) | LCD_INIT_latch);
wire [15:0] LCD_wait_length =(LCD_DATA == 8'h01 || LCD_DATA == 8'h02) ? 16'd5467 : 16'd146;

assign LCD_BUSY = (lcd_step_count != 16'h0000);

assign LCD_DataBus = (LCD_INIT_latch == 1'b0) ? ((lcd_step_count > 16'd4) ? LCD_DATA[3:0] : LCD_DATA[7:4]) : ((lcd_step_count > 16'd14008) ? 4'b0010 : 4'b0011);

assign LCD_TEST_PIN = LCD_INIT_latch;

always @(posedge LCD_CLK) 
	if(LCD_RESET)	lcd_step_count <= #1 16'h0000;
	else
	begin
		if(LCD_Start_Data || (lcd_step_count!= 16'h0000)) 
			begin
				if((LCD_INIT_latch && (lcd_step_count < 16'd14274)) || (!LCD_INIT_latch && (lcd_step_count < LCD_wait_length))) 
				begin
					if(LCD_Start_Function) lcd_step_count <= #1 16'h0000; else lcd_step_count <= #1 lcd_step_count + 16'd1;
				end 
				else 
				begin
					lcd_step_count <= #1 16'h0000;
				end
			end
		else 
			begin
				lcd_step_count <= #1 lcd_step_count;
			end
	end

always @(posedge LCD_CLK)
	if(LCD_RESET)	LCD_E <= #1 1'b0;
	else
		if((lcd_step_count == 16'd2) || ((lcd_step_count == 16'd5) && (LCD_INIT_latch == 1'b0)) || ((lcd_step_count == 16'd13672) && (LCD_INIT_latch == 1'b1)) || ((lcd_step_count == 16'd14006) && (LCD_INIT_latch == 1'b1)) || ((lcd_step_count == 16'd14140) && (LCD_INIT_latch == 1'b1)))  
			LCD_E <= #1 1'b1;
		else LCD_E <= #1 1'b0;

always @(posedge LCD_CLK)
	if(LCD_RESET)	LCD_INIT_latch <= #1 1'b1;
	else
		if(LCD_INIT_latch == 1)
			LCD_INIT_latch <= #1 ~(((LCD_INIT_latch == 1'b1) & (lcd_step_count == 16'd14274)) | ((LCD_INIT_latch == 1'b0) & (lcd_step_count == LCD_wait_length)));
		else LCD_INIT_latch <= #1 LCD_INIT_latch;
	
always @(posedge LCD_CLK)
	if(LCD_RESET)	LCD_RS <= #1 1'b0;
	else
		if(LCD_RS == 1)
			LCD_RS <= #1 ~LCD_Start_Function;
		else
			LCD_RS <= #1 ~(((LCD_INIT_latch == 1'b1) & (lcd_step_count != 16'd14274)) | ((LCD_INIT_latch == 1'b0) & (lcd_step_count != LCD_wait_length)));
		
reg [4:0] lcd_counter_test = 5'd0;
	/*
always @(posedge LCD_CLK)
	if (LCD_RESET)	LCD_SENDING_ENABLE <= 1'b0; 
	else 			LCD_SENDING_ENABLE <= (lcd_counter_test == 5'd21) ? 1'b1 : 1'b0;	
*/
	
	assign LCD_SENDING_ENABLE = (lcd_counter_test == 5'd29) ? 1'b1 : 1'b0;
	
	
	assign LCD_DATA_int = 	((lcd_counter_test > 21) ? LCD_DATA_ext :
							((lcd_counter_test > 18) ? 8'h0F :
							((lcd_counter_test > 17) ? 8'h00 :
							((lcd_counter_test > 14) ? 8'h01 :
							((lcd_counter_test > 13) ? 8'h00 :
							((lcd_counter_test > 10) ? 8'h08 :
							((lcd_counter_test > 9) ? 8'h00 :
							((lcd_counter_test > 6) ? 8'h28 :
							((lcd_counter_test > 5) ? 8'h00 :
							((lcd_counter_test > 2) ? 8'h28 : 8'h00))))))))));
							
							
	/*
	assign LCD_DATA_int = 	((lcd_counter_test == 3) ? 8'h28 :
							((lcd_counter_test == 7) ? 8'h28 :
							((lcd_counter_test == 11) ? 8'h28 :
							((lcd_counter_test == 15) ? 8'h28 :
							((lcd_counter_test == 19) ? 8'h28 :
							((lcd_counter_test == 21) ? LCD_DATA_ext : 8'h00))))));
							*/
/*always @(posedge LCD_CLK)
begin
	if (LCD_RESET) LCD_DATA_int <= 8'h00;
	case(lcd_counter_test)
	5'd1:	LCD_DATA_int <= 8'h00;
	5'd3:	LCD_DATA_int <= 8'h28;
	5'd5:	LCD_DATA_int <= 8'h00;
	5'd7:	LCD_DATA_int <= 8'h28;
	5'd9:	LCD_DATA_int <= 8'h00;
	5'd11:	LCD_DATA_int <= 8'h08;
	5'd13:	LCD_DATA_int <= 8'h00;
	5'd15:	LCD_DATA_int <= 8'h01;
	5'd17:	LCD_DATA_int <= 8'h00;
	5'd19:	LCD_DATA_int <= 8'h0F;
	5'd22:	LCD_DATA_int <= 8'h00;//LCD_DATA_ext;
	default: LCD_DATA_int <= LCD_DATA_int;
	endcase
end
	*/
	
	//assign LCD_DATA_ENABLE_int <= lcd_counter_test[0] & ~LCD_BUSY;
	
always @(posedge LCD_CLK)
begin
	if (LCD_RESET) 	LCD_DATA_ENABLE_int <= 1'b0;
	else			if(!LCD_INIT_latch && lcd_counter_test < 5'd21) LCD_DATA_ENABLE_int <= lcd_counter_test[0];// & ~LCD_BUSY;
					else LCD_DATA_ENABLE_int <= 1'b0;
end
	
always @(posedge LCD_CLK)
begin
if (LCD_RESET) 	lcd_counter_test <= 5'd0;	
else if(lcd_counter_test < 5'd29)	begin
										if(!LCD_INIT_latch && !LCD_BUSY) lcd_counter_test <= lcd_counter_test + 1;
										else if(LCD_INIT_latch) lcd_counter_test <= 5'd0;
										else lcd_counter_test <= lcd_counter_test;
									end
else 	lcd_counter_test <= 5'd29;
end 

endmodule