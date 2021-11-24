`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// DS18B20 driver
//////////////////////////////////////////////////////////////////////////////////

module DS18B20_DRIVER (
	input DS18B20_CLK,
	input DS18B20_RESET,
	input [1:0] DS18B20_RESOLUTION,
	input [7:0] DS18B20_T_HIGH,
	input [7:0] DS18B20_T_LOW,
	input [47:0] DS18B20_ID,
	input DS18B20_GET_TEMP,
	input DS18B20_READ_DATA,
	input DS18B20_WRITE_DATA,
	input DS18B20_STORE_IN_EE,
	input DS18B20_RECALL_FROM_EE,
	output reg [11:0] DS18B20_TEMPERATURE =12'h228,
	output reg [1:0] DS18B20_RESOLUTION_OUT =2'b00,
	output reg [7:0] DS18B20_T_HIGH_OUT =8'h00,
	output reg [7:0] DS18B20_T_LOW_OUT =8'h00,
	output reg DS18B20_CRC = 1'b0,
	output reg DS18B20_ERROR = 1'b0,
	output reg DS18B20_READY = 1'b0,
	//output reg [7:0] DS18B20_ACTUAL_STATE = 8'h00, 
	//one wire interface
	input [79:0] DS18B20_DATA_RECEIVED,
	input DS18B20_ONE_WIRE_READY,
	
	output reg DS18B20_ONE_WIRE_RW = 1'b0,
	output reg [79:0] DS18B20_DATA_TO_SEND = 80'h00000000000000000000,
	output reg [7:0] DS18B20_ONE_WIRE_DATA_SIZE = 8'd0,
	output reg DS18B20_ONE_WIRE_ENABLE = 1'b0,
	output reg DS18B20_ONE_WIRE_INIT = 1'b0,
	output reg DS18B20_TEST_PIN = 1'b0
);

parameter 	ds12b20_idle = 8'h00, ds12b20_init = 8'h01, ds12b20_read_data_request = 8'h03, ds12b20_get_temp = 8'h02, ds12b20_write_data = 8'h06, 
			ds12b20_store_ee = 8'h07, ds12b20_recall_ee = 8'h05, ds12b20_ROMcomm = 8'h04, ds12b20_searchALARM = 8'h0C, ds12b20_init_wait = 8'h0D, 
			ds12b20_ROMcomm_wait = 8'h0F, ds12b20_read_data_request_wait = 8'h0E, ds12b20_read_data_response = 8'h0A, ds12b20_read_data_response_wait = 8'h0B,
			ds12b20_read_data_response_store = 8'h09, ds12b20_get_temp_wait = 8'h08;

reg [7:0] ds12b20_state = 8'h00;
reg [7:0] next_ds12b20_state = 8'h00;
reg [7:0] ds12b20_stored_state = 8'h00;

//always @(posedge DS18B20_CLK)
//begin
//	DS18B20_ACTUAL_STATE <= ds12b20_state;
//end

always @(posedge DS18B20_CLK)
begin
	if(DS18B20_RESET == 1'b1)
	begin
		DS18B20_TEST_PIN <= #1 1'b0;
		DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		DS18B20_DATA_TO_SEND <= #1 80'd0; 
		DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd0;
		DS18B20_ONE_WIRE_RW <= #1 1'b0;
		DS18B20_ONE_WIRE_INIT <= #1 1'b0;
	end
	else
	begin
		case(ds12b20_state)
		ds12b20_idle:
		begin
			DS18B20_TEST_PIN <= #1 1'b0;
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
			DS18B20_DATA_TO_SEND <= #1 80'd0; 
			DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd0;
			DS18B20_ONE_WIRE_RW <= #1 1'b0;
			DS18B20_ONE_WIRE_INIT <= #1 1'b0;
		end
		//-----------------------
		ds12b20_init:
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
			DS18B20_DATA_TO_SEND <= #1 80'd0; 
			DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd100;
			DS18B20_ONE_WIRE_RW <= #1 1'b0;
			DS18B20_ONE_WIRE_INIT <= #1 1'b1;
			DS18B20_TEST_PIN <= #1 1'b1;
		end
		ds12b20_init_wait: 
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		end	
		//-----------------------
		ds12b20_ROMcomm:
		begin
			if(DS18B20_ID == 48'h000000000000)
			begin
				DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
				DS18B20_DATA_TO_SEND <= #1 80'h000000000000000000CC;
				DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'h08;
				DS18B20_ONE_WIRE_RW <= #1 1'b0;
				DS18B20_ONE_WIRE_INIT <= #1 1'b0;
			end
			else
			begin
				DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
				DS18B20_DATA_TO_SEND <= #1 80'h000000000000000000CD;
				DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'h08;
				DS18B20_ONE_WIRE_RW <= #1 1'b0;
				DS18B20_ONE_WIRE_INIT <= #1 1'b0;
			end
		end
		ds12b20_ROMcomm_wait: 
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		end
		//-----------------------
		ds12b20_read_data_request:
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
			DS18B20_DATA_TO_SEND <= #1 80'h000000000000000000BE;
			DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd8;
			DS18B20_ONE_WIRE_RW <= #1 1'b0;
			DS18B20_ONE_WIRE_INIT <= #1 1'b0;
		end
		ds12b20_read_data_request_wait:	
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		end
		//-----------------------
		ds12b20_read_data_response:
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
			DS18B20_DATA_TO_SEND <= #1 80'h00000000000000000000;
			DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd72;
			DS18B20_ONE_WIRE_RW <= #1 1'b1;
			DS18B20_ONE_WIRE_INIT <= #1 1'b0;
		end
		ds12b20_read_data_response_wait: DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		ds12b20_read_data_response_store:
		begin
			DS18B20_TEMPERATURE <= #1 DS18B20_DATA_RECEIVED[11:0];
			DS18B20_T_HIGH_OUT <= #1 DS18B20_DATA_RECEIVED[31:16];
			DS18B20_T_LOW_OUT <= #1 DS18B20_DATA_RECEIVED[39:32];
			DS18B20_RESOLUTION_OUT <= #1 DS18B20_DATA_RECEIVED[46:45];
		end
		//-----------------------
		ds12b20_get_temp:
		begin
			DS18B20_ONE_WIRE_ENABLE <= #1 1'b1;
			DS18B20_DATA_TO_SEND <= #1 80'h00000000000000000044;
			DS18B20_ONE_WIRE_DATA_SIZE <= #1 8'd8;
			DS18B20_ONE_WIRE_RW <= #1 1'b0;
			DS18B20_ONE_WIRE_INIT <= #1 1'b0;
		end
		ds12b20_get_temp_wait: DS18B20_ONE_WIRE_ENABLE <= #1 1'b0;
		//-----------------------
		ds12b20_write_data:
		begin
		end
		ds12b20_store_ee:
		begin
		end
		ds12b20_recall_ee:
		begin
		end
		default:
		begin
		end
		endcase
	end
end

always @(ds12b20_state or DS18B20_GET_TEMP or DS18B20_READ_DATA or DS18B20_WRITE_DATA or DS18B20_STORE_IN_EE or DS18B20_RECALL_FROM_EE)
begin
	if(ds12b20_state == ds12b20_idle)
	begin
		if(DS18B20_READ_DATA) ds12b20_stored_state = ds12b20_read_data_request;
		else if(DS18B20_GET_TEMP) ds12b20_stored_state = ds12b20_get_temp;
		else if(DS18B20_WRITE_DATA) ds12b20_stored_state = ds12b20_write_data;
		else if(DS18B20_STORE_IN_EE) ds12b20_stored_state = ds12b20_store_ee;
		else if(DS18B20_RECALL_FROM_EE) ds12b20_stored_state = ds12b20_recall_ee;
		else ds12b20_stored_state = ds12b20_idle;
	end
	else if(ds12b20_state == ds12b20_get_temp_wait)
	begin
		ds12b20_stored_state = ds12b20_read_data_request;
	end
	else ds12b20_stored_state = ds12b20_stored_state;
end

always @(ds12b20_state or ds12b20_stored_state or DS18B20_GET_TEMP or DS18B20_READ_DATA or DS18B20_WRITE_DATA or DS18B20_STORE_IN_EE or DS18B20_RECALL_FROM_EE or DS18B20_ONE_WIRE_READY)
begin
	case(ds12b20_state)
		ds12b20_idle:
		begin	
			if (DS18B20_READ_DATA || DS18B20_GET_TEMP || DS18B20_WRITE_DATA || DS18B20_STORE_IN_EE || DS18B20_RECALL_FROM_EE)
				next_ds12b20_state = ds12b20_init;
			else next_ds12b20_state = ds12b20_idle;
		end
		ds12b20_init:
		begin
			if (DS18B20_ONE_WIRE_READY == 1'b0)
				next_ds12b20_state = ds12b20_init_wait;	
			else next_ds12b20_state = ds12b20_init;
		end
		ds12b20_init_wait:
		begin
			if (DS18B20_ONE_WIRE_READY == 1'b1) 
				next_ds12b20_state = ds12b20_ROMcomm;	
			else next_ds12b20_state = ds12b20_init_wait;
		end
		ds12b20_ROMcomm:
		begin
			if(DS18B20_ONE_WIRE_READY == 1'b0) next_ds12b20_state = ds12b20_ROMcomm_wait;
			else next_ds12b20_state = ds12b20_ROMcomm;
		end
		ds12b20_ROMcomm_wait:
		begin
			if (DS18B20_ONE_WIRE_READY == 1'b1)
			begin
				next_ds12b20_state = ds12b20_stored_state;
			end
			else next_ds12b20_state = ds12b20_ROMcomm_wait;
		end
		ds12b20_read_data_request: if (DS18B20_ONE_WIRE_READY == 1'b0) next_ds12b20_state = ds12b20_read_data_request_wait; else next_ds12b20_state = ds12b20_read_data_request;
		ds12b20_read_data_request_wait: if (DS18B20_ONE_WIRE_READY == 1'b1) next_ds12b20_state = ds12b20_read_data_response; else next_ds12b20_state = ds12b20_read_data_request_wait;
		ds12b20_read_data_response: if (DS18B20_ONE_WIRE_READY == 1'b0) next_ds12b20_state = ds12b20_read_data_response_wait; else next_ds12b20_state = ds12b20_read_data_response;
		ds12b20_read_data_response_wait: if (DS18B20_ONE_WIRE_READY == 1'b1) next_ds12b20_state = ds12b20_read_data_response_store; else next_ds12b20_state = ds12b20_read_data_response_wait;
		ds12b20_read_data_response_store: next_ds12b20_state = ds12b20_idle;
		ds12b20_get_temp: if (DS18B20_ONE_WIRE_READY == 1'b0) next_ds12b20_state = ds12b20_get_temp_wait; else next_ds12b20_state = ds12b20_get_temp;
		ds12b20_get_temp_wait: if (DS18B20_ONE_WIRE_READY == 1'b1) next_ds12b20_state = ds12b20_init; else next_ds12b20_state = ds12b20_get_temp_wait;
		default:
			next_ds12b20_state = ds12b20_idle;
	endcase
end

always @(posedge DS18B20_CLK)
begin
	if(DS18B20_RESET == 1'b1)	ds12b20_state <= #1 ds12b20_idle;
	else						ds12b20_state <= #1 next_ds12b20_state;
end

endmodule