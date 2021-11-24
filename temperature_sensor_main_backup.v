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

module iceblink40_demo(
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
     output SS_B							  // SPI slave-select output
);
	 wire BTN_SAMPLE;
	 wire ONE_WIRE_CLK;
	 
	 reg [7:0] one_wire_machine = 8'h00;
	 reg [7:0] last_one_wire_machine = 8'h00;
	 reg [7:0] next_one_wire_machine = 8'h00;
	 
	 // -- Digilent ADEPT 2 I/O Expander Debug Graphical Interface (GUI) connections 
     wire [31:0] ToFPGA ;                     // 32-bit value written to the FPGA, specified via a textbox on the graphical interface (GUI)
     wire [31:0] FromFPGA ;                   // 32-bit value provided by the FPGA and displayed in a textbox on the graphical interface (GUI)
                                              // ... Green = [23:16], Yellow = [15:8], Red = [7:0]

     wire BTN1_TOGGLE_STATUS;    
	 reg BTN1_TOGGLE_STATUS_reg;
	 reg BTN1_STATUS = 1'b0;
	 reg LED1_STATUS = 1'b0;
	 reg ONE_WIRE_reg;
	 reg ONE_WIRE_start;
	 
	 wire ONE_WIRE_READY;
	 wire ONE_WIRE_OK;
	 wire ONE_WIRE_ENABLE;
	 wire ONE_WIRE_DATA;
	 wire ONE_WIRE_RW;
	 wire ONE_WIRE_INIT;

	 reg ONE_WIRE_ENABLE_reg;
	 reg ONE_WIRE_DATA_reg;
	 reg ONE_WIRE_RW_reg;
	 reg ONE_WIRE_INIT_reg;
	 
	 reg [7:0] BUFFER_COUNTER = 8;
	 
	 reg [7:0] ONE_WIRE_ROM_COMMAND = 8'hCC;
	 reg [7:0] ONE_WIRE_FUNCTION_COMMAND = 8'h44;
	 reg [7:0] ONE_READ_FUNCTION_COMMAND = 8'hBE;
	 reg [71:0] READ_DATA;
	 
	 reg [15:0] ONE_WIRE_COUNTER = 16'h0000;
	 reg [15:0] TIMEOUT_COUNTER = 16'h0000;

	 wire [71:0] ONE_WIRE_DATA_WORD;
	 wire [7:0] ONE_WIRE_DATA_SIZE;
	 
	 reg [71:0] ONE_WIRE_DATA_WORD_reg;
	 reg [7:0] ONE_WIRE_DATA_SIZE_reg;
	 
	 reg TEMPERATURE=1;
	 
	 wire BTN_CHANGED;
	 
	 parameter idle=0, send_init=1, wait_init=2, xxx=3, write_rom_command=4, write_function_command=5, read_function_command=6, read_function_data=7, send_low=15, send_high=14, timeout=13;
	 parameter LED_ON = 1, LED_OFF = 0;
	 
     assign SS_B = 1'b1 ;					  // Disable SPI Flash after configuration
	 
	 //assign FromFPGA[15:0] = ONE_WIRE_COUNTER;
	 //assign FromFPGA[23:16] = 8'hFF;
	 //assign FromFPGA[31:24] = one_wire_machine;
	 
	 assign FromFPGA = ONE_WIRE_DATA_WORD_reg[71:40];
   
	assign LED1 = LED1_STATUS;
	
	assign CLK_WIRE = BTN_CHANGED;//ONE_WIRE_READY;
	//assign ONE_WIRE = ONE_WIRE_reg;
	
	//assign ONE_WIRE_READY;
	assign ONE_WIRE_ENABLE = ONE_WIRE_ENABLE_reg;
	assign ONE_WIRE_DATA = ONE_WIRE_DATA_reg;
	//assign ONE_WIRE_DATA_WORD = (one_wire_machine == read_function_command)? ONE_WIRE_DATA_WORD_reg : 1'hzzzzzzzzzzzzzzzzzz;
	assign ONE_WIRE_DATA_SIZE = ONE_WIRE_DATA_SIZE_reg;
	assign ONE_WIRE_RW = ONE_WIRE_RW_reg;
	assign ONE_WIRE_INIT = ONE_WIRE_INIT_reg;
	 
	always @(posedge CLK_3P3_MHZ)
		if( BTN1_TOGGLE_STATUS ) BTN1_TOGGLE_STATUS_reg = BTN1_TOGGLE_STATUS;
	
	always @(posedge CLK_3P3_MHZ)
	begin
		case(one_wire_machine)
		 idle: //idle
		 begin
			LED1_STATUS = LED_OFF;
			if( BTN_CHANGED ) 
			begin
				ONE_WIRE_COUNTER = 10;
				one_wire_machine = send_init;
				next_one_wire_machine = send_init;
			end
			else
				ONE_WIRE_ENABLE_reg = 0;
		 end
		 send_init:
		 begin
			if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_DATA_WORD_reg = 71'd0; 
				ONE_WIRE_DATA_SIZE_reg = 8'd8;
				ONE_WIRE_RW_reg = 0;
				ONE_WIRE_INIT_reg = 1;
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE_reg = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = write_rom_command;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		write_rom_command:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_DATA_WORD_reg = 71'h0000000000000000CC;
				ONE_WIRE_DATA_SIZE_reg = 8'd8;
				ONE_WIRE_RW_reg = 0;
				ONE_WIRE_INIT_reg = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE_reg = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = read_function_command;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		write_function_command:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_DATA_WORD_reg = 71'h000000000000000044;
				ONE_WIRE_DATA_SIZE_reg = 8'd8;
				ONE_WIRE_RW_reg = 0;
				ONE_WIRE_INIT_reg = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE_reg = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = idle;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		read_function_command:
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_DATA_WORD_reg = 71'h0000000000000000BE;
				ONE_WIRE_DATA_SIZE_reg = 8'd8;
				ONE_WIRE_RW_reg = 0;
				ONE_WIRE_INIT_reg = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE_reg = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = read_function_data;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		read_function_data:	   
		begin
		if(ONE_WIRE_COUNTER > 0 && ONE_WIRE_READY == 1)
			begin
				LED1_STATUS = LED_ON;
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_DATA_WORD_reg = 71'hzzzzzzzzzzzzzzzzzz;
				ONE_WIRE_DATA_SIZE_reg = 8'd72;
				ONE_WIRE_RW_reg = 1;
				ONE_WIRE_INIT_reg = 0;
				TIMEOUT_COUNTER--;
			end	
			else if(ONE_WIRE_COUNTER == 0)
			begin
				ONE_WIRE_ENABLE_reg = 0;
				TIMEOUT_COUNTER = 4500;
				ONE_WIRE_COUNTER = 10;
				next_one_wire_machine = idle;
				one_wire_machine = timeout;
			end
			else if(ONE_WIRE_COUNTER > 0)
			begin
				ONE_WIRE_ENABLE_reg = 1;
				ONE_WIRE_COUNTER--;
			end
			else
				one_wire_machine = idle;
		end
		timeout:
		begin
			ONE_WIRE_ENABLE_reg = 0;
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
	.BTN_SAMPLE(BTN_SAMPLE),
	.ONE_WIRE_CLK(ONE_WIRE_CLK)
);
/*
ONE_WIRE_DRIVER ONE_WIRE_MOD(
	.CLK(ONE_WIRE_CLK),
	.RW(ONE_WIRE_RW),
	.DATA(ONE_WIRE_DATA),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(ONE_WIRE_INIT),
	.ONE_WIRE_LINE(ONE_WIRE),
	.READY(ONE_WIRE_READY),
	.OK(ONE_WIRE_OK)
);
*/	 
	RW_DATA_MODULE ONE_WIRE_MOD(
	.CLK(ONE_WIRE_CLK),
	.RW(ONE_WIRE_RW),
	.DATA(ONE_WIRE_DATA_WORD),
	.COUNTER(ONE_WIRE_DATA_SIZE),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(ONE_WIRE_INIT),
	.ONE_WIRE_LINE(ONE_WIRE),
	.READY(ONE_WIRE_READY),
	.OK(ONE_WIRE_OK)
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

module ONE_WIRE_DRIVER (
	input CLK,
	input RW,
	inout DATA,
	input ENABLE,
	input INIT,
	inout ONE_WIRE_LINE,
	output READY,
	output reg OK = 1
);

reg [3:0] machine_state=0;
reg [3:0] next_machine_state=0;
reg [15:0] ONE_EVENT_TIMER=0;
reg [8:0] LOW_LEVEL_COUNTER=0;
reg LOW_TO_HIGH_DETECTED=0;
reg ONE_WIRE=0;
reg READY_reg;
reg WORKING_reg;
reg DATA_reg;

parameter ready_state = 0, init_1wire = 1, wait_init_1wire = 2, write_low = 3, write_high = 4, read_line = 5;

localparam init_low_timer = 450;
localparam init_high_timer = 12;
localparam wait_init_timer = 450;
//localparam wait_init_low_timer = 
localparam read_low_timer = 1;
localparam read_high_timer = 89;
localparam read_sample_time = 8;
//localparam write_high_timer = 10;
localparam write_high_init_timer = 1;
localparam write_high_end_timer = 89;
//localparam write_low_timer = 10;
localparam write_low_init_timer = 89;
localparam write_low_end_timer = 1;

assign ONE_WIRE_LINE = ONE_WIRE;
//assign ONE_WIRE_LINE = (~RW)? ONE_WIRE : 1'bz;
assign READY = !(WORKING_reg | ENABLE); //READY_reg;
assign DATA = (~RW)? 1'bz : DATA_reg;
//always @(ENABLE)
//begin
//	if(ENABLE) READY_reg = 1'b0;
	//if(ONE_EVENT_TIMER == 0) READY_reg = 1'b1;
//end

always @(ONE_EVENT_TIMER)
begin
	if(ONE_EVENT_TIMER == 0 && machine_state!=init_1wire) WORKING_reg = 1'b0;
	else WORKING_reg = 1'b1;
end

 //READY_reg = !(WORKING_reg | ENABLE);

always @(posedge CLK)
begin
		case(machine_state)
		ready_state:
		begin
			ONE_WIRE = 1'bz;
			if(ENABLE == 1)
			begin
				OK = 1'b0;
				if(INIT == 1)
				begin
					ONE_EVENT_TIMER = init_low_timer + init_high_timer;
				end
				else
				begin
					if(RW == 1)
					begin
						ONE_EVENT_TIMER = 1 + read_low_timer + read_high_timer;
					end
					else
					begin
						if(DATA == 1)
						begin
							ONE_EVENT_TIMER = 1 + write_high_init_timer + write_high_end_timer;
						end
						else
						begin
							ONE_EVENT_TIMER = 1 + write_low_init_timer + write_low_end_timer;
						end
					end
				end
			end
			else
			begin
				 ONE_EVENT_TIMER = 0;
			end
		end
		init_1wire:
		begin
			LOW_LEVEL_COUNTER = 8'h00;
			LOW_TO_HIGH_DETECTED = 0;
			if(ONE_EVENT_TIMER > init_high_timer) ONE_WIRE = 1'b0;
			else ONE_WIRE = 1'bz;
			if(ONE_EVENT_TIMER == 0) ONE_EVENT_TIMER = init_low_timer + init_high_timer;
		end
		wait_init_1wire:
		begin
			ONE_WIRE = 1'bz;
			if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 0 && LOW_TO_HIGH_DETECTED == 0)
				LOW_LEVEL_COUNTER++;
			else if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 0 && LOW_TO_HIGH_DETECTED == 1)
				OK = 1'b0;
			else if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 1 && LOW_LEVEL_COUNTER > 50 && LOW_LEVEL_COUNTER < 200)
				OK = 1'b0;
			else if(ONE_EVENT_TIMER > 0 && ONE_WIRE == 1 && LOW_LEVEL_COUNTER > 0)
				LOW_TO_HIGH_DETECTED = 1;
			if(ONE_EVENT_TIMER == 0 && LOW_LEVEL_COUNTER > 50 && LOW_LEVEL_COUNTER < 200 && LOW_TO_HIGH_DETECTED == 1)
				OK = 1'b1;
		end
		write_high:
		begin
			//ONE_WIRE = 1'b0;
			if(ONE_EVENT_TIMER > write_high_end_timer) ONE_WIRE = 1'b0;
			else if(ONE_EVENT_TIMER  <= write_high_end_timer && ONE_EVENT_TIMER > 0) ONE_WIRE = 1'bz;
			else if(ONE_EVENT_TIMER == 0) OK = 1'b1;
		end
		write_low:
		begin
			//ONE_WIRE = 1'b1;
			if(ONE_EVENT_TIMER > write_low_end_timer) ONE_WIRE = 1'b0;
			else if(ONE_EVENT_TIMER  <= write_low_end_timer && ONE_EVENT_TIMER > 0) ONE_WIRE = 1'bz;
			else if(ONE_EVENT_TIMER == 0) OK = 1'b1;
		end
		read_line:
		begin
			if(ONE_EVENT_TIMER > read_high_timer) ONE_WIRE = 1'b0;
			else if(ONE_EVENT_TIMER  <= read_high_timer && ONE_EVENT_TIMER > 0) ONE_WIRE = 1'bz;
			else if(ONE_EVENT_TIMER == 0) OK = 1'b1;
			else if(ONE_EVENT_TIMER == read_sample_time) DATA_reg = ONE_WIRE_LINE;
		end
		default:
		begin
			OK = 1'b0;
			ONE_WIRE = 1'bz;
		end
		endcase
		if(ONE_EVENT_TIMER > 0) 
		begin
			ONE_EVENT_TIMER --;
		end
		else 
		begin
			ONE_WIRE = 1'bz;
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
					if(DATA == 1)
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
	inout [71:0] DATA,
	inout [7:0] COUNTER,
	input ENABLE,
	input INIT,
	inout ONE_WIRE_LINE,
	output READY,
	output OK
);

wire ONE_WIRE_DATA;
wire ONE_WIRE_ENABLE;

reg ONE_WIRE_DATA_reg = 0;
reg ONE_WIRE_ENABLE_reg = 0;
wire ONE_WIRE_READY;
wire ONE_WIRE_OK;

reg ONE_WIRE_READY_reg=1;
reg ONE_WIRE_OK_reg = 1;

reg [7:0] DATA_LENGTH = 0;
reg WORKING_reg;

reg [3:0] machine_state = 0;
reg [3:0] next_machine_state = 0;
reg [8:0] BIT_TIMEOUT = 0;

reg [71:0] DATA_reg;

parameter ready_state = 0, write_data = 2, read_data = 3;

localparam init_low_timer = 450;
   
 assign ONE_WIRE_RW = RW;
// assign READY = !(WORKING_reg | ENABLE);//ONE_WIRE_READY;//
 assign READY = (INIT) ? ONE_WIRE_READY : !(WORKING_reg | ENABLE); 
 assign OK = (INIT) ? ONE_WIRE_OK : ONE_WIRE_OK_reg; 
 assign ONE_WIRE_DATA = (RW) ? 1'bz : ONE_WIRE_DATA_reg; 
 assign ONE_WIRE_ENABLE = (INIT) ? ENABLE : ONE_WIRE_ENABLE_reg; 
 assign DATA = (RW) ? DATA_reg : 1'hzzzzzzzzzzzzzzzzzz;
 
 always @(DATA_LENGTH)
 begin
	if(DATA_LENGTH == 0) WORKING_reg = 1'b0;
	else WORKING_reg = 1'b1;
 end
 
//assign ONE_WIRE_READY_reg = WORKING_reg | ENABLE;
 
always @(posedge CLK)
begin
		case(machine_state)
		ready_state: 
		begin
			if(ENABLE == 1) DATA_LENGTH = COUNTER;
		end
		write_data:
		begin
			if(DATA_LENGTH > 0)
			begin
				if(ONE_WIRE_READY)
				begin
						ONE_WIRE_DATA_reg = DATA[DATA_LENGTH-1];
						ONE_WIRE_ENABLE_reg = 1'b1;
						DATA_LENGTH--;
				end
				else
				begin
					ONE_WIRE_ENABLE_reg = 1'b0;
				end
			end
			else
			begin
				//ONE_WIRE_READY_reg = 1'b1;
				ONE_WIRE_ENABLE_reg = 1'b0;
			end
		end
		read_data: 
		begin
			if(DATA_LENGTH > 0)
			begin
				if(ONE_WIRE_READY)
				begin
						DATA_reg[DATA_LENGTH-1] = 1'b1;//DATA_LENGTH[0];
						//ONE_WIRE_DATA_reg = DATA[DATA_LENGTH-1];
						ONE_WIRE_ENABLE_reg = 1'b1;
						DATA_LENGTH--;
				end
				else
				begin
					ONE_WIRE_ENABLE_reg = 1'b0;
				end
			end
			else
			begin
				//ONE_WIRE_READY_reg = 1'b1;
				ONE_WIRE_ENABLE_reg = 1'b0;
			end
		end
		default: ;
		
		endcase
end
  
always @(machine_state, ENABLE, DATA_LENGTH)
begin
	case(machine_state)
	ready_state:
	begin
		if(INIT == 0 && ENABLE == 1)
		begin			
			if(RW == 1)
			begin
				next_machine_state = read_data;
			end
			else
			begin
				next_machine_state = write_data;
			end
		end
		else
		begin
			next_machine_state = ready_state;
		end
	end
	write_data:	if(DATA_LENGTH == 0) next_machine_state = ready_state;
	read_data: if(DATA_LENGTH == 0) next_machine_state = ready_state;
	default: next_machine_state = ready_state;
	endcase
end

always @(posedge CLK)
begin
	machine_state <= #1 next_machine_state;
end
   
ONE_WIRE_DRIVER ONE_WIRE_MOD(
	.CLK(CLK),
	.RW(ONE_WIRE_RW),
	.DATA(ONE_WIRE_DATA),
	.ENABLE(ONE_WIRE_ENABLE),
	.INIT(INIT),
	.ONE_WIRE_LINE(ONE_WIRE_LINE),
	.READY(ONE_WIRE_READY),
	.OK(ONE_WIRE_OK)
); 
   
endmodule

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
   output       BTN_SAMPLE,
   output		ONE_WIRE_CLK
);

   reg [19:0] COUNTER = 20'b0 ;

   always @(posedge CLK_3P3MHz)
      COUNTER <= COUNTER + 1;

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