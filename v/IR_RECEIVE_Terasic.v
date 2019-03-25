//NEC IR transfer protocol:
//1. 9ms leading high
//2. 4.5ms leading low
//Logical '0': 562.5us high + 562.5us low
//Logical '1': 562.5us high + 1.6875ms low
//Note: the signal received by the IR receiver is inverted!!
module IR_RECEIVE(
					input 					clk,			//clk 50MHz
					input					rst_n,			//reset					
					input					data_in,        //IR code input
					output 	reg				data_ready,		//data ready
					output	reg[31:0]		data_out		//decode data output
					);

//=======================================================
//  PARAMETER declarations
//=======================================================
parameter LEAD_LOW				= 2'b00;    //data_in is deasserted for 9ms
parameter LEAD_HIGH				= 2'b01;    //data_in is asserted for 4.5ms
parameter DATA_TRANSFER			= 2'b10;    //data_in transfers 32bits in this state

parameter MAX_DATA_TRANSFER		=  262143;	// data_count    262143*0.02us = 5.24ms, maximum length for DATA_TRANSFER-----> LEAD_LOW
parameter LEAD_LOW_DUR			=  230000;	// lead_low_count    230000*0.02us = 4.60ms, threshold for LEAD_LOW--------->LEAD_HIGH
parameter LEAD_HIGH_DUR			=  210000;	// lead_high_count   210000*0.02us = 4.20ms, 4.5-4.2 = 0.3ms < MIN_BIT_VALID = 0.4ms,threshold for LEAD_HIGH------->DATA_TRANSFER
parameter DATA_HIGH_DUR			=  41500;	// data_count    41500 *0.02us = 0.83ms, logical "1" is >= 0.83ms
parameter MIN_BIT_VALID			=  20000;	// data_count    20000 *0.02us = 0.4ms, it's a new valid bit

//=======================================================
//  Signal Declarations
//=======================================================
reg    [17:0] lead_low_count;            //lead_low_count counter works under data_read state
reg    [17:0] lead_high_count;           //lead_high_count counter works under guide state
reg    [17:0] data_count;            //data_count counter works under data_read state
reg     [5:0] bitcount;              //sample bit pointer
reg     [1:0] state;                 //state reg
reg    [31:0] data_buf;              //data buf

//=======================================================
//  Structural coding
//=======================================================
//state change between LEAD_LOW,GUIDE,DATA_READ according to irda edge or counter
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)	     
		state <= LEAD_LOW;
	else
	begin
		case (state)
			LEAD_LOW 	:
				if (lead_low_count > LEAD_LOW_DUR)  // state chang from LEAD_LOW to Guidance when detect the negedge and the low voltage last for > 4.6ms
					state <= LEAD_HIGH; 
			LEAD_HIGH 	:	
				if (lead_high_count > LEAD_HIGH_DUR)//state change from LEAD_HIGH to DATA_TRANSFER when detect the posedge and the high voltage last for > 4.2ms
					state <= DATA_TRANSFER;
			DATA_TRANSFER	:
				if ((data_count >= MAX_DATA_TRANSFER) || (bitcount >= 33))
					state <= LEAD_LOW;
	        default		:	
				state <= LEAD_LOW; //default
		endcase
	end
end

//Leading low phase
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		lead_low_count <= 0;
	else if ((state == LEAD_LOW) && !data_in)
		lead_low_count <= lead_low_count + 1'b1;
	else                           
		lead_low_count <= 0;	     		 	
end

//Leading high phase, 4.5ms
always @(posedge clk or negedge rst_n)
begin	
	if (!rst_n)
		lead_high_count <= 0;
	else if ((state == LEAD_HIGH) && data_in)    //the counter works when the flag is 1
		lead_high_count <= lead_high_count + 1'b1;
	else  
		lead_high_count <= 0;	        //the counter resets when the flag is 0		      		 	
end

//Sampling data by bits, counting asserted length to identify logical "0" and "1"
always @(posedge clk or negedge rst_n)
begin	
	if (!rst_n)
		data_count <= 1'b0;
	else if((state == DATA_TRANSFER) && data_in)      //the counter works when the flag is 1
		data_count <= data_count + 1'b1;
	else 
		data_count <= 1'b0;        //the counter resets when the flag is 0
end

//Check bit status and value base on length of asserted data_in
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		bitcount <= 6'b0;
		data_buf <= 0;
	end
	else if (state == DATA_TRANSFER)
	begin
		if (data_count == MIN_BIT_VALID)
			bitcount <= bitcount + 1'b1; //add 1 when data_in posedge
		
		if (data_count >= DATA_HIGH_DUR) //2^15 = 32767*0.02us = 0.64us
			data_buf[bitcount - 1'b1] <= 1'b1;  //>0.52ms  sample the bit 1
	end   
	else
	begin
		bitcount <= 6'b0;
		data_buf <= 0;
	end
end

//set the data_ready flag 
always @(posedge clk or negedge rst_n)
begin 
	if (!rst_n)
		data_ready <= 1'b0;
    else if (bitcount == 32)   
	begin
		if (data_buf[31:24] == ~data_buf[23:16])	//command match
			data_ready <= 1'b1;   //set the data ready flag
		else
			data_ready <= 1'b0 ;  //data error
	end
	else
		data_ready <= 1'b0 ;
end

//data has been read
always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		data_out <= 32'b0000;
	else if (data_ready)
		data_out <= data_buf;  //output
end
		
endmodule