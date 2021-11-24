`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 1Wire driver
//////////////////////////////////////////////////////////////////////////////////

module ONE_WIRE_DRIVER (
	input LINE_1WIRE_CLK,
	input LINE_1WIRE_RW,
	input LINE_1WIRE_DATA_IN,
	input LINE_1WIRE_ENABLE,
	input LINE_1WIRE_INIT,
	inout LINE_1WIRE_ONE_WIRE_LINE,
	output reg LINE_1WIRE_READY = 1'b1,
	output reg LINE_1WIRE_LINE_OK = 1'b0,
	output reg LINE_1WIRE_DATA_OUT = 1'b0,
	output reg LINE_1WIRE_test_pin = 1'b0
);

reg [3:0] line_1wire_machine_state=0;
reg [3:0] line_1wire_next_machine_state=0;

reg [15:0] LINE_1WIRE_ONE_EVENT_TIMER=0;
reg [15:0] LINE_1WIRE_LOW_LEVEL_COUNTER=0;
reg LINE_1WIRE_LOW_TO_HIGH_DETECTED=0;
reg LINE_1WIRE_ONE_WIRE=0;

parameter ready_state = 4'h0, init_1wire = 4'h1, wait_init_1wire = 4'h2, write_low = 4'h3, write_high = 4'h4, read_line = 4'h5, init_ok = 4'h6, init_not_ok = 4'h7;

localparam init_low_timer = 16'd1800;//450;
localparam init_high_timer = 16'd48;//12;
localparam read_low_timer = 16'd4;//1;
localparam read_high_timer = 16'd356;//89;
localparam read_sample_time = 16'd12;//3;
localparam write_high_init_timer = 16'd4;//1;
localparam write_high_end_timer = 16'd356;//89;
localparam write_low_init_timer = 16'd356;//89;
localparam write_low_end_timer = 16'd4;//1;

assign LINE_1WIRE_ONE_WIRE_LINE = LINE_1WIRE_ONE_WIRE;

//always @(line_1wire_machine_state)
//begin
//	LINE_1WIRE_READY <= #1 (line_1wire_machine_state == ready_state)? 1'b1 : 1'b0;
//end

always @(posedge LINE_1WIRE_CLK)
begin
		case(line_1wire_machine_state)
		ready_state:
		begin
			LINE_1WIRE_READY <= #1 1'b1;
			LINE_1WIRE_ONE_WIRE <= #1 1'bz;
			if(LINE_1WIRE_ENABLE == 1)
			begin
				if(LINE_1WIRE_INIT == 1)
				begin
					LINE_1WIRE_ONE_EVENT_TIMER <= #1 init_low_timer + init_high_timer;
				end
				else
				begin
					if(LINE_1WIRE_RW == 1)
					begin
						LINE_1WIRE_ONE_EVENT_TIMER <= #1 4 + read_low_timer + read_high_timer;
					end
					else
					begin
						if(LINE_1WIRE_DATA_IN == 1)
						begin
							LINE_1WIRE_ONE_EVENT_TIMER <= #1 4 + write_high_init_timer + write_high_end_timer;
						end
						else
						begin
							LINE_1WIRE_ONE_EVENT_TIMER <= #1 4 + write_low_init_timer + write_low_end_timer;
						end
					end
				end
			end
			else
			begin
				 LINE_1WIRE_ONE_EVENT_TIMER <= #1 16'h0000;
			end
		end
		init_1wire:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			LINE_1WIRE_LOW_LEVEL_COUNTER <= #1 16'h0000;
			LINE_1WIRE_LOW_TO_HIGH_DETECTED <= #1 0;
			if(LINE_1WIRE_ONE_EVENT_TIMER > init_high_timer) LINE_1WIRE_ONE_WIRE <= #1 1'b0;
			else LINE_1WIRE_ONE_WIRE <= #1 1'bz;
			if(LINE_1WIRE_ONE_EVENT_TIMER == 0) LINE_1WIRE_ONE_EVENT_TIMER <= #1 init_low_timer + init_high_timer;
		end
		wait_init_1wire:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			LINE_1WIRE_ONE_WIRE <= #1 1'bz;
			if(LINE_1WIRE_ONE_EVENT_TIMER > 0 && LINE_1WIRE_ONE_WIRE == 0 && LINE_1WIRE_LOW_TO_HIGH_DETECTED == 0)
				LINE_1WIRE_LOW_LEVEL_COUNTER <= #1 LINE_1WIRE_LOW_LEVEL_COUNTER + 1;
			else if(LINE_1WIRE_ONE_EVENT_TIMER > 0 && LINE_1WIRE_ONE_WIRE == 1 && LINE_1WIRE_LOW_LEVEL_COUNTER > 0)
				LINE_1WIRE_LOW_TO_HIGH_DETECTED <= #1 1;
		end
		init_ok:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			LINE_1WIRE_LINE_OK = 1'b1;
		end
		init_not_ok:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			LINE_1WIRE_LINE_OK = 1'b0;
		end
		write_high:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			if(LINE_1WIRE_ONE_EVENT_TIMER > write_high_end_timer) LINE_1WIRE_ONE_WIRE <= #1 1'b0;
			else if(LINE_1WIRE_ONE_EVENT_TIMER  <= write_high_end_timer && LINE_1WIRE_ONE_EVENT_TIMER > 0) LINE_1WIRE_ONE_WIRE <= #1 1'bz;
		end
		write_low:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			if(LINE_1WIRE_ONE_EVENT_TIMER > write_low_end_timer) LINE_1WIRE_ONE_WIRE <= #1 1'b0;
			else if(LINE_1WIRE_ONE_EVENT_TIMER  <= write_low_end_timer && LINE_1WIRE_ONE_EVENT_TIMER > 0) LINE_1WIRE_ONE_WIRE <= #1 1'bz;
		end
		read_line:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			if(LINE_1WIRE_ONE_EVENT_TIMER > read_high_timer) LINE_1WIRE_ONE_WIRE <= #1 1'b0;
			else if(LINE_1WIRE_ONE_EVENT_TIMER  <= read_high_timer && LINE_1WIRE_ONE_EVENT_TIMER > 0) LINE_1WIRE_ONE_WIRE <= #1 1'bz;
			
			if(LINE_1WIRE_ONE_EVENT_TIMER == 4 + read_low_timer + read_high_timer - read_sample_time) 
			begin
				if(LINE_1WIRE_ONE_WIRE_LINE == 1'b1)
					LINE_1WIRE_DATA_OUT <= #1 1'b1;
				else
					LINE_1WIRE_DATA_OUT <= #1 1'b0;
			end
		end
		default:
		begin
			LINE_1WIRE_READY <= #1 1'b0;
			LINE_1WIRE_ONE_WIRE <= #1 1'bz;
		end
		endcase
		
		if(LINE_1WIRE_ONE_EVENT_TIMER > 0) 
		begin
			LINE_1WIRE_ONE_EVENT_TIMER <= #1 LINE_1WIRE_ONE_EVENT_TIMER - 1;
		end
		else 
		begin
			LINE_1WIRE_ONE_WIRE <= #1 1'bz;
		end
end

always @(line_1wire_machine_state or LINE_1WIRE_ENABLE or LINE_1WIRE_INIT or LINE_1WIRE_RW or LINE_1WIRE_DATA_IN or LINE_1WIRE_ONE_EVENT_TIMER or LINE_1WIRE_LOW_LEVEL_COUNTER)
begin
	//line_1wire_next_machine_state = 4'h0;
	case(line_1wire_machine_state)
	ready_state:
	begin
		if(LINE_1WIRE_ENABLE == 1)
		begin
			if(LINE_1WIRE_INIT == 1)
			begin
				line_1wire_next_machine_state = init_1wire;
			end
			else
			begin
				if(LINE_1WIRE_RW == 1)
				begin
					line_1wire_next_machine_state = read_line;
				end
				else
				begin
					if(LINE_1WIRE_DATA_IN == 1)
					begin
						line_1wire_next_machine_state = write_high;
					end
					else
					begin
						line_1wire_next_machine_state = write_low;
					end
				end
			end
		end
		else
		begin
			line_1wire_next_machine_state = ready_state;
		end
	end
	init_1wire:		if(LINE_1WIRE_ONE_EVENT_TIMER == 0) line_1wire_next_machine_state = wait_init_1wire; else line_1wire_next_machine_state = init_1wire;
	wait_init_1wire:
	begin
		if(LINE_1WIRE_ONE_EVENT_TIMER == 0)
			if(LINE_1WIRE_LOW_LEVEL_COUNTER > 0 && LINE_1WIRE_LOW_LEVEL_COUNTER < 200) line_1wire_next_machine_state = init_ok;
			else line_1wire_next_machine_state = init_not_ok;
		else
			line_1wire_next_machine_state =  line_1wire_machine_state;
	end
	init_ok: 		line_1wire_next_machine_state = ready_state;//	else line_1wire_next_machine_state = init_ok;
	init_not_ok: 	line_1wire_next_machine_state = ready_state;//	else line_1wire_next_machine_state<= init_not_ok;
	write_low:		if(LINE_1WIRE_ONE_EVENT_TIMER == 0) line_1wire_next_machine_state = ready_state; 	else line_1wire_next_machine_state = write_low;
	write_high: 	if(LINE_1WIRE_ONE_EVENT_TIMER == 0) line_1wire_next_machine_state = ready_state; 	else line_1wire_next_machine_state = write_high;
	read_line: 		if(LINE_1WIRE_ONE_EVENT_TIMER == 0) line_1wire_next_machine_state = ready_state; 	else line_1wire_next_machine_state = read_line;
	default: 		line_1wire_next_machine_state = ready_state;
	endcase
end

always @(posedge LINE_1WIRE_CLK)
begin
	line_1wire_machine_state <= #1 line_1wire_next_machine_state;
end

endmodule

////////////////////////////////////////////////////////////////////
// To use with devices
////////////////////////////////////////////////////////////////////

module RW_DATA_MODULE (
	input RW_DATA_CLK,
	input RW,
	input [79:0] DATA_TO_SEND,
	input [7:0] COUNTER,
	input ENABLE,
	input INIT,
	output reg [79:0] DATA_RECEIVED = 80'h00000000000000000000,
	output reg ONE_WIRE_READY = 1'b1,
	//output reg [3:0] ACTUAL_STATE = 4'h0,
	output reg test_pin = 1'b0,
		
	//one wire line	
	input RW_DATA_DATA_FROM_DRIVER,
	input RW_DATA_DRIVER_READY,
	input RW_DATA_DRIVER_OK,
	
	output reg RW_DATA_RW_DRIVER = 1'b1,
	output reg RW_DATA_DATA_TO_DRIVER = 1'b1,
	output reg RW_DATA_DRIVER_ENABLE = 1'b0,
	output reg RW_DATA_INIT_DRIVER = 1'b0
);

reg [7:0] data_length = 8'h00;

reg [3:0] machine_state = 4'h0;
reg [3:0] next_machine_state = 4'h0;

parameter ready_state = 4'h0, write_data = 4'h2, read_data = 4'h3, read_store = 4'h4, init_line_start = 4'h5, wait_for_init = 4'h6, read_wait = 4'h7, write_wait = 4'h8, write_start = 4'h9;
 
//always @(posedge RW_DATA_CLK)
//begin
//	ACTUAL_STATE <= machine_state;
//end
  
always @(posedge RW_DATA_CLK)
begin
		case(machine_state)
		ready_state: 
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b1;
			test_pin <= #1 1'b0;
			data_length <= #1 8'h00;
		end
		init_line_start:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b1;
			RW_DATA_INIT_DRIVER <= #1 1'b1;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
			test_pin <= #1 1'b1;
		end
		wait_for_init:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
		end
		write_start:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b1;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
			RW_DATA_DATA_TO_DRIVER <= #1 DATA_TO_SEND[data_length];
		end
		write_data:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
			data_length <= #1 data_length + 8'h01;
		end
		write_wait:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
		end
		read_data: 
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b1;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b1;
			ONE_WIRE_READY <= #1 1'b0;
		end
		read_wait:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b1;
			ONE_WIRE_READY <= #1 1'b0;
		end
		read_store:
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b1;
			ONE_WIRE_READY <= #1 1'b0;
			DATA_RECEIVED[data_length] <= #1 RW_DATA_DATA_FROM_DRIVER;
			data_length <= #1 data_length + 8'h01;
		end
		default: 
		begin
			RW_DATA_DRIVER_ENABLE <= #1 1'b0;
			RW_DATA_INIT_DRIVER <= #1 1'b0;
			RW_DATA_RW_DRIVER <= #1 1'b0;
			ONE_WIRE_READY <= #1 1'b0;
		end
		
		endcase
end
  
always @(machine_state or INIT or RW or COUNTER or ENABLE or data_length or RW_DATA_DRIVER_READY)
begin
	//next_machine_state = 4'h0;
	case(machine_state)
	ready_state:
	begin
		if(INIT == 1'b1 && ENABLE == 1'b1)
		begin
			next_machine_state = init_line_start;
		end
		else if(INIT == 1'b0 && ENABLE == 1'b1)
		begin			
			if(RW == 1'b1)
			begin
				next_machine_state = read_data;
			end
			else
			begin
				next_machine_state = write_start;
			end
		end
		else
		begin
			next_machine_state = ready_state;
		end
	end
	init_line_start: if(RW_DATA_DRIVER_READY == 1'b0) next_machine_state = wait_for_init; else next_machine_state = init_line_start;
	wait_for_init: if(RW_DATA_DRIVER_READY == 1'b1) next_machine_state = ready_state; else next_machine_state = wait_for_init;
	write_start: if(RW_DATA_DRIVER_READY == 1'b0) next_machine_state = write_data; else next_machine_state = write_start;
	write_data:	next_machine_state = write_wait;
	write_wait:
	begin	
		if(RW_DATA_DRIVER_READY)
		begin
			if(data_length == COUNTER) next_machine_state = ready_state;
			else next_machine_state = write_start;
		end
		else next_machine_state = write_wait;
			
	end
	read_data: if(RW_DATA_DRIVER_READY == 1'b0) next_machine_state = read_wait; else next_machine_state = read_data;
	read_wait: if(RW_DATA_DRIVER_READY == 1'b1) next_machine_state = read_store; else next_machine_state = read_wait;
	read_store: if(data_length == COUNTER-1) next_machine_state = ready_state; else next_machine_state = read_data;
	default: next_machine_state = ready_state;
	endcase
end

always @(posedge RW_DATA_CLK)
begin
	machine_state <= #1 next_machine_state;
end

endmodule