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
	 //reg rBTN1_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN1
	 //reg rBTN2_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN2
	 //reg rBTN3_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN3
	 //reg rBTN4_TOGGLE_STATUS = 1'b0 ;          // Holds current toggle status of BTN4

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