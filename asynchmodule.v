`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Asynchronous driver
//////////////////////////////////////////////////////////////////////////////////

module ASYNCH_DRIVER (
	input ASYNCH_CLK,
	input [7:0] ASYNCH_BYTE_TO_SEND,
	input ASYNCH_ENABLE,
	input ASYNCH_TX_LINE,
	output reg ASYNCH_RX_LINE = 1'b1,
	output reg ASYNCH_READY = 1'b1,
	output [7:0] ASYNCH_BYTE_RECEIVED,
	output reg ASYNCH_DATA_OK = 1'b0,
	output reg ASYNCH_TEST_PIN = 1'b0
);

reg [3:0] ASYNCH_RX_TIMER = 4'hA;
reg [10:0] ASYNCH_RX_BUFFER = 11'b11000000000;

always @(ASYNCH_TX_TIMER or ASYNCH_RX_TIMER)
begin
	ASYNCH_READY <= (ASYNCH_RX_TIMER == 4'hA)? ((ASYNCH_TX_TIMER == 4'hA)? 1'b1 : 1'b0) : 1'b0;
end

//
//Tick generator
//
localparam timier_value = 8'd52;//8'd47;
reg [14:0] TickAcc = 15'd0;
reg ASYNCH_TIC_ENABLE = 1'b1;  
reg TickAcc10_old = 1'b1;
wire BAUD_GEN_tick;
wire BAUD_OVER_tick;
wire BAUD_SYNCH_tick;
reg BAUD_SYNCH_tick_reg = 1'b0;
reg BAUD_OVER_counter_synch = 1'b0;
reg [3:0] BAUD_OVER_counter = 4'h0;

always @(BAUD_SYNCH_tick)ASYNCH_TEST_PIN <= BAUD_SYNCH_tick;

assign BAUD_SYNCH_tick = BAUD_SYNCH_tick_reg & BAUD_OVER_tick;

always @(BAUD_OVER_counter)
begin
	if(BAUD_OVER_counter == 4'hF)	BAUD_SYNCH_tick_reg <= #1 1'b1;
	else BAUD_SYNCH_tick_reg <= #1 1'b0;
end	

always @(posedge ASYNCH_CLK)
begin
	if(BAUD_OVER_counter_synch == 1'b1)
	begin
		BAUD_OVER_counter <= #1 4'hF;
	end
	else
	begin
		if(BAUD_OVER_tick == 1'b1)
		begin
			BAUD_OVER_counter <= #1 BAUD_OVER_counter + 4'h1;
		end
		else
		begin
			BAUD_OVER_counter <= #1 BAUD_OVER_counter;
		end
	end
end

always @(posedge ASYNCH_CLK)
begin
  if(ASYNCH_TIC_ENABLE) 	TickAcc <= TickAcc[13:0] + timier_value; 
  else 						TickAcc <= timier_value;
end

always @(posedge ASYNCH_CLK) TickAcc10_old <= TickAcc[10];

assign BAUD_GEN_tick = TickAcc[14];
assign BAUD_OVER_tick = TickAcc10_old^TickAcc[10];

//
//Transmiter
//	
always @(posedge ASYNCH_CLK)
begin
if((ASYNCH_RX_TIMER < 4'hA) && (BAUD_GEN_tick == 1'b1)) 		ASYNCH_RX_TIMER <= #1 ASYNCH_RX_TIMER + 1;
else if((ASYNCH_ENABLE == 1'b1) && (BAUD_GEN_tick == 1'b1)) 	ASYNCH_RX_TIMER <= #1 4'h0;
else 							ASYNCH_RX_TIMER <= #1 ASYNCH_RX_TIMER;
end

always @(ASYNCH_BYTE_TO_SEND or ASYNCH_RX_TIMER)
begin
if(ASYNCH_RX_TIMER == 4'hA)	ASYNCH_RX_BUFFER[8:1] <= #1 ASYNCH_BYTE_TO_SEND;
else						ASYNCH_RX_BUFFER <= #1 ASYNCH_RX_BUFFER;
end

always @(ASYNCH_RX_TIMER) ASYNCH_RX_LINE = ASYNCH_RX_BUFFER[ASYNCH_RX_TIMER];
//
//Receiver
//
reg [7:0] TX_DATA_SAMPLES = 8'h55;
reg [3:0] ASYNCH_TX_TIMER = 4'hA;
reg [10:0] ASYNCH_TX_BUFFER = 11'b00000000000;

always @(posedge ASYNCH_CLK) if(BAUD_OVER_tick) TX_DATA_SAMPLES <= {TX_DATA_SAMPLES[6:0], ASYNCH_TX_LINE}; else TX_DATA_SAMPLES <= TX_DATA_SAMPLES;

always @(posedge ASYNCH_CLK)
begin
	if(ASYNCH_TX_TIMER < 4'hA)
	begin
		BAUD_OVER_counter_synch <= #1 1'b0;
		if(BAUD_SYNCH_tick == 1'b1) 		ASYNCH_TX_TIMER <= #1 ASYNCH_TX_TIMER + 1;
	end
	else
	begin
		if(TX_DATA_SAMPLES == 8'h00) 
		begin
			ASYNCH_TX_TIMER <= #1 4'h0;
			BAUD_OVER_counter_synch <= #1 1'b1;
		end
	end
end
	
always @(posedge ASYNCH_CLK) 
if(BAUD_SYNCH_tick == 1'b1 && ASYNCH_TX_TIMER < 4'hA) begin ASYNCH_TX_BUFFER[ASYNCH_TX_TIMER] <= #1 TX_DATA_SAMPLES[0]; end 
//else ASYNCH_TEST_PIN <= #1 1'b0;

assign ASYNCH_BYTE_RECEIVED = ASYNCH_TX_BUFFER[8:1];

endmodule

//
//
//
//
//
//
//
module RTC_MODULE (
	input RTC_CLK,
	input RTC_RESET,
	input RTC_READ_ID,
	input RTC_READ_STATUS,
	input RTC_SET_CLOCK,
	input wire [7:0] RTC_DATA_FROM_DRIVER,
	input RTC_DATA_OK,
	output reg [47:0] RTC_ID = 48'h000000000000,
	output reg RTC_READY = 1'b1,
	output reg RTC_TEST_PIN = 1'b0,
	//asnych driver
	input RTC_ASYNCH_READY,
	output reg [7:0] RTC_ASYNCH_BYTE_TO_SEND = 8'h00,
	//output [7:0] RTC_ASYNCH_BYTE_TO_SEND,
	output reg [7:0] RTC_SECOND = 8'hFF,
	output reg [7:0] RTC_MINUTE = 8'hFF,
	output reg [7:0] RTC_HOUR = 8'hFF,
	output reg [7:0] RTC_WEEKDAY = 8'hFF,
	output reg [7:0] RTC_DAY = 8'hFF,
	output reg [7:0] RTC_MONTH = 8'hFF,
	output reg [7:0] RTC_YEAR = 8'hFF,
	output reg RTC_ASYNCH_ENABLE = 1'b0
	
);

//reg [63:0] RTC_ID = 64'h0000000000000000;

reg [7:0] rtc_state = 8'h00;
reg [7:0] rtc_state_next = 8'h00;

reg [7:0] rtc_data_length = 8'h00;
reg [7:0] rtc_receive_length = 8'h00;

reg [15:0] rtc_timeout = 16'h0FFF;


parameter rtc_idle = 8'h00, rtc_request_id = 8'h01, rtc_request_id_count = 8'h02, rtc_request_id_wait = 8'h03, rtc_request_id_wait_response = 8'h04, rtc_request_id_wait_response_data = 8'h05, rtc_request_id_wait_response_store = 8'h06, rtc_empty = 8'h07, 
			rtc_request_status = 8'h08, rtc_write_clock = 8'h09, rtc_request_status_count = 8'h0A, rtc_write_clock_count = 8'h0B, rtc_request_status_wait = 8'h0C, 
			rtc_write_clock_wait = 8'h0D , rtc_request_status_response = 8'h0E, rtc_request_status_response_data = 8'h0F, rtc_request_status_response_store = 8'h10;

always @(rtc_state or rtc_data_length)
				//
				if(rtc_state == rtc_request_id && rtc_data_length == 8'h00) 		RTC_ASYNCH_BYTE_TO_SEND = 8'h33;
				else if(rtc_state == rtc_request_id && rtc_data_length == 8'h01)	RTC_ASYNCH_BYTE_TO_SEND = 8'h02;
				else if(rtc_state == rtc_request_id && rtc_data_length == 8'h02)	RTC_ASYNCH_BYTE_TO_SEND = 8'h18;
				//
				else if(rtc_state == rtc_request_status && rtc_data_length == 8'd0) RTC_ASYNCH_BYTE_TO_SEND = 8'h33;
				else if(rtc_state == rtc_request_status && rtc_data_length == 8'd1) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				else if(rtc_state == rtc_request_status && rtc_data_length == 8'd2) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd0) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd1) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd2) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd3) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd4) RTC_ASYNCH_BYTE_TO_SEND = 8'h01;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd5) RTC_ASYNCH_BYTE_TO_SEND = 8'h25;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd6) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd7) RTC_ASYNCH_BYTE_TO_SEND = 8'h02;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd8) RTC_ASYNCH_BYTE_TO_SEND = 8'h23;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd9) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd10) RTC_ASYNCH_BYTE_TO_SEND = 8'h03;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd11) RTC_ASYNCH_BYTE_TO_SEND = 8'h06;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd12) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd13) RTC_ASYNCH_BYTE_TO_SEND = 8'h04;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd14) RTC_ASYNCH_BYTE_TO_SEND = 8'h02;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd15) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd16) RTC_ASYNCH_BYTE_TO_SEND = 8'h05;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd17) RTC_ASYNCH_BYTE_TO_SEND = 8'h11;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd18) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd19) RTC_ASYNCH_BYTE_TO_SEND = 8'h06;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd20) RTC_ASYNCH_BYTE_TO_SEND = 8'h13;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd21) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd22) RTC_ASYNCH_BYTE_TO_SEND = 8'h07;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd23) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd24) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd25) RTC_ASYNCH_BYTE_TO_SEND = 8'h08;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd26) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd27) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd28) RTC_ASYNCH_BYTE_TO_SEND = 8'h09;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd29) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd30) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd31) RTC_ASYNCH_BYTE_TO_SEND = 8'h0A;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd32) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd33) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd34) RTC_ASYNCH_BYTE_TO_SEND = 8'h0B;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd35) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd36) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd37) RTC_ASYNCH_BYTE_TO_SEND = 8'h0C;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd38) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd39) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd40) RTC_ASYNCH_BYTE_TO_SEND = 8'h0D;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd41) RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				//
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd42) RTC_ASYNCH_BYTE_TO_SEND = 8'h22;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd43) RTC_ASYNCH_BYTE_TO_SEND = 8'h0E;
				else if(rtc_state == rtc_write_clock && rtc_data_length == 8'd44) RTC_ASYNCH_BYTE_TO_SEND = 8'h10;
				//
				else RTC_ASYNCH_BYTE_TO_SEND = 8'h00;
				
always @(posedge RTC_CLK)
begin
	if(RTC_RESET) 	begin
						RTC_ID <= #1 64'h0000000000000000;
					//	RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
						RTC_SECOND <= #1 8'hFF;
						RTC_MINUTE <= #1 8'hFF;
						RTC_HOUR <= #1 8'hFF;
						RTC_WEEKDAY <= #1 8'hFF;
						RTC_DAY <= #1 8'hFF;
						RTC_MONTH <= #1 8'hFF;
						RTC_YEAR <= #1 8'hFF;
						RTC_READY <= #1 1'b1;
						rtc_data_length <= #1 8'h00;
						RTC_ASYNCH_ENABLE <= #1 1'b0;
						rtc_receive_length <= #1 8'h00;
						rtc_timeout <= #1 16'h0FFF;
					end
	else
	case(rtc_state)
	rtc_idle:
	begin
		RTC_READY <= #1 1'b1;
		rtc_data_length <= #1 8'h00;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		rtc_receive_length <= #1 8'h00;
		rtc_timeout <= #1 16'h1FFF;
	end
	rtc_request_id:
	begin
		RTC_READY <= #1 1'b0;
		//if(rtc_data_length == 8'h00) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h33;
		//else if(rtc_data_length == 8'h01) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h02;
		//else if(rtc_data_length == 8'h02) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h18;
		//else RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		RTC_ASYNCH_ENABLE <= #1 1'b1;
	end
	rtc_request_status:
	begin
		RTC_READY <= #1 1'b0;
		//if(rtc_data_length == 8'h00) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h33;
		//else if(rtc_data_length == 8'h01) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		//else if(rtc_data_length == 8'h02) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		//else RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		RTC_ASYNCH_ENABLE <= #1 1'b1;
	end
	rtc_write_clock:
	begin
		RTC_READY <= #1 1'b0;
		/*if(rtc_data_length == 8'h00) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h01) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		else if(rtc_data_length == 8'h02) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //seconds
		else if(rtc_data_length == 8'h03) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h04) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h01;
		else if(rtc_data_length == 8'h05) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h25; //minutes
		else if(rtc_data_length == 8'h06) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h07) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h02;
		else if(rtc_data_length == 8'h08) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h23; //hours
		else if(rtc_data_length == 8'h09) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h0A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h03;
		else if(rtc_data_length == 8'h0B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h06; //day of week
		else if(rtc_data_length == 8'h0C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h0D) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h04;
		else if(rtc_data_length == 8'h0E) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h02; //day
		else if(rtc_data_length == 8'h0F) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h10) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h05;
		else if(rtc_data_length == 8'h11) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h11; //month
		else if(rtc_data_length == 8'h12) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h13) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h06;
		else if(rtc_data_length == 8'h14) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h13; //year
		else if(rtc_data_length == 8'h15) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h16) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h07;
		else if(rtc_data_length == 8'h17) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm second
		else if(rtc_data_length == 8'h18) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h19) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h08;
		else if(rtc_data_length == 8'h1A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm minutes
		else if(rtc_data_length == 8'h1B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h1C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h09;
		else if(rtc_data_length == 8'h1D) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm hours
		else if(rtc_data_length == 8'h1E) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h1F) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0A;
		else if(rtc_data_length == 8'h20) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm day of week
		else if(rtc_data_length == 8'h21) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h22) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0B;
		else if(rtc_data_length == 8'h23) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm low temperature
		else if(rtc_data_length == 8'h24) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h25) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0C;
		else if(rtc_data_length == 8'h26) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //alarm high temperature
		else if(rtc_data_length == 8'h27) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h28) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0D;
		else if(rtc_data_length == 8'h29) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00; //sample rate
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0E;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h0F;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h11;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h12;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h13;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h14;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h15;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h16;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h17;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h18;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h19;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1A;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1B;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1C;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1D;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1E;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register
		else if(rtc_data_length == 8'h2A) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h22;
		else if(rtc_data_length == 8'h2B) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h1F;
		else if(rtc_data_length == 8'h2C) RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h10; //control register*/
		//else RTC_ASYNCH_BYTE_TO_SEND <= #1 8'h00;
		RTC_ASYNCH_ENABLE <= #1 1'b1;
	end
	rtc_request_id_count:
	begin
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		rtc_data_length <= #1 rtc_data_length + 1;
	end
	rtc_request_status_count:
	begin
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		rtc_data_length <= #1 rtc_data_length + 1;
	end
	rtc_write_clock_count:
	begin
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		rtc_data_length <= #1 rtc_data_length + 1;
	end
	rtc_request_id_wait:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
	end
	rtc_request_status_wait:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
	end
	rtc_write_clock_wait:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
	end
	rtc_request_id_wait_response:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b0;
	end
	rtc_request_status_response:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b0;
	end
	rtc_request_id_wait_response_data:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b1;
	end
	rtc_request_status_response_data:
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b1;
	end
	rtc_request_id_wait_response_store:
	begin
		RTC_READY <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		if(rtc_receive_length == 8'h00) RTC_SECOND <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h01) RTC_MINUTE <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h02) RTC_HOUR <= #1 RTC_DATA_FROM_DRIVER;
		else ;
		rtc_receive_length <= #1 rtc_receive_length + 8'h01;
	end
	rtc_request_status_response_store:
	begin
		RTC_READY <= #1 1'b0;
		RTC_TEST_PIN <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
		if(rtc_receive_length == 8'h00) RTC_SECOND <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h01) RTC_MINUTE <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h02) RTC_HOUR <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h03) RTC_WEEKDAY <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h04) RTC_DAY <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h05) RTC_MONTH <= #1 RTC_DATA_FROM_DRIVER;
		else if(rtc_receive_length == 8'h06) RTC_YEAR <= #1 RTC_DATA_FROM_DRIVER;
		else ;
		rtc_receive_length <= #1 rtc_receive_length + 8'h01;
	end
	rtc_empty:
	begin
		rtc_timeout <= #1 rtc_timeout - 1;
	end
	default: 
	begin
		RTC_READY <= #1 1'b0;
		RTC_ASYNCH_ENABLE <= #1 1'b0;
	end
	endcase
end

always @(rtc_state or rtc_data_length or rtc_timeout or rtc_receive_length or RTC_READ_ID or RTC_READ_STATUS or RTC_SET_CLOCK or RTC_ASYNCH_READY)
begin
	if(RTC_RESET) rtc_state_next = rtc_idle;
	else
	case(rtc_state)
	rtc_idle:
	begin
		if(RTC_READ_ID == 1'b1 && RTC_ASYNCH_READY == 1'b1) rtc_state_next = rtc_request_id;
		else if(RTC_READ_STATUS == 1'b1 && RTC_ASYNCH_READY == 1'b1) rtc_state_next = rtc_request_status;
		else if(RTC_SET_CLOCK == 1'b1 && RTC_ASYNCH_READY == 1'b1) rtc_state_next = rtc_write_clock;
		else rtc_state_next = rtc_idle;
	end
	rtc_request_id: 
		if(RTC_ASYNCH_READY == 1'b0) rtc_state_next = rtc_request_id_count;
		else rtc_state_next = rtc_request_id;
	rtc_request_status:
		if(RTC_ASYNCH_READY == 1'b0) rtc_state_next = rtc_request_status_count;
		else rtc_state_next = rtc_request_status;
	rtc_write_clock:
		if(RTC_ASYNCH_READY == 1'b0) rtc_state_next = rtc_write_clock_count;
		else rtc_state_next = rtc_write_clock;
	rtc_request_id_count: rtc_state_next = rtc_request_id_wait;
	rtc_request_status_count: rtc_state_next = rtc_request_status_wait;
	rtc_write_clock_count: rtc_state_next = rtc_write_clock_wait;
	rtc_request_id_wait: 
		if(RTC_ASYNCH_READY == 1'b1) 
			if(rtc_data_length < 8'h03) rtc_state_next = rtc_request_id;
			else	rtc_state_next = rtc_request_id_wait_response;
		else
			rtc_state_next = rtc_request_id_wait;
	rtc_request_status_wait: 
		if(RTC_ASYNCH_READY == 1'b1) 
			if(rtc_data_length < 8'h3) rtc_state_next = rtc_request_status;
			else	rtc_state_next = rtc_request_status_response;
		else
			rtc_state_next = rtc_request_status_wait;
	rtc_write_clock_wait: 
		if(RTC_ASYNCH_READY == 1'b1) 
			if(rtc_data_length < 8'h2D) rtc_state_next = rtc_write_clock;
			else	rtc_state_next = rtc_empty;
		else
			rtc_state_next = rtc_write_clock_wait;
	rtc_request_status_response: if(RTC_ASYNCH_READY == 1'b0) rtc_state_next = rtc_request_status_response_data; else rtc_state_next = rtc_request_status_response;
	rtc_request_id_wait_response: if(RTC_ASYNCH_READY == 1'b0) rtc_state_next = rtc_request_id_wait_response_data; else rtc_state_next = rtc_request_id_wait_response;
	rtc_request_id_wait_response_data: if(RTC_ASYNCH_READY == 1'b1) rtc_state_next = rtc_request_id_wait_response_store; else rtc_state_next = rtc_request_id_wait_response_data;
	rtc_request_status_response_data: if(RTC_ASYNCH_READY == 1'b1) rtc_state_next = rtc_request_status_response_store; else rtc_state_next = rtc_request_status_response_data;
	rtc_request_id_wait_response_store: if(rtc_receive_length > 8'h02) rtc_state_next = rtc_empty; else rtc_state_next = rtc_request_id_wait_response;
	rtc_request_status_response_store: if(rtc_receive_length > 8'h20) rtc_state_next = rtc_empty; else rtc_state_next = rtc_request_status_response;
	rtc_empty: if(rtc_timeout != 0) rtc_state_next = rtc_empty; else rtc_state_next = rtc_idle;
	default:
		rtc_state_next = rtc_idle;
	endcase
end

always @(posedge RTC_CLK)
begin
if(RTC_RESET) 	rtc_state <= #1 rtc_idle;
	else	rtc_state <= #1 rtc_state_next;
end

endmodule