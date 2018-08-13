
/*
Code for making a IR transmitter & receiver follow NEC protocol based on Terasic demo
More details on NEC protocol can be found at:
https://techdocs.altium.com/display/FPGA/NEC+Infrared+Transmission+Protocol
*/

module DE10_Standard_IR(

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,
	input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// Seg7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	output		     [6:0]		HEX4,
	output		     [6:0]		HEX5,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N,

	//////////// Video-In //////////
	input 		          		TD_CLK27,
	input 		     [7:0]		TD_DATA,
	input 		          		TD_HS,
	output		          		TD_RESET_N,
	input 		          		TD_VS,

	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B,
	output		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,
	output		     [7:0]		VGA_R,
	output		          		VGA_SYNC_N,
	output		          		VGA_VS,

	//////////// Audio //////////
	input 		          		AUD_ADCDAT,
	inout 		          		AUD_ADCLRCK,
	inout 		          		AUD_BCLK,
	output		          		AUD_DACDAT,
	inout 		          		AUD_DACLRCK,
	output		          		AUD_XCK,

	//////////// PS2 //////////
	inout 		          		PS2_CLK,
	inout 		          		PS2_CLK2,
	inout 		          		PS2_DAT,
	inout 		          		PS2_DAT2,

	//////////// ADC //////////
	output		          		ADC_CONVST,
	output		          		ADC_DIN,
	input 		          		ADC_DOUT,
	output		          		ADC_SCLK,

	//////////// I2C for Audio and Video-In //////////
	output		          		FPGA_I2C_SCLK,
	inout 		          		FPGA_I2C_SDAT,

	//////////// IR //////////
	input 		          		IRDA_RXD,
	output		          		IRDA_TXD
);



//=======================================================
//  REG/WIRE declarations
//=======================================================
wire reset_n;

//=======================================================
//  Structural coding
//=======================================================
assign reset_n = 1'b1;
///////////////////////////////////////////


assign  LEDR = SW;

///////////////////////////////////////////////////////////////////
//=============================================================================
// REG/WIRE declarations
//=============================================================================

wire  data_ready;        //IR data_ready flag
wire  [31:0] hex_data;   //seg data input

//---IR Receiver module---//			  
IR_RECEIVE u1(
				///clk 50MHz////
				.clk(CLOCK_50), 
				//reset          
				.rst_n(1'b1),        
				//IRDA code input
				.data_in(IRDA_RXD), 
				//read command
				.data_ready(data_ready),
				//decoded data 32bit
				.data_out(hex_data)        
);
//   hex_data
//   invert data 8bits + data 8bits + invert address 8bits + address_8bits
//   [31:24]             [23:16]    + [15:8]               + [7:0]

// 6 HEXs
// HEX1-0  data    8bits     [23:16] 
// HEX3-2  address 8bits     [7:0]
// HEX5-4  invert data 8bits [31:24]
// so HEX3-0 shows  the  16bits send data (8bits addr + 8bits data)

SEG_HEX hex0( //display the HEX on HEX0                               
			  .iDIG(hex_data[19:16]),         
			  .oHEX_D(HEX0)
		     );  
SEG_HEX hex1( //display the HEX on HEX1                                
           .iDIG(hex_data[23:20]),
           .oHEX_D(HEX1)
           );
SEG_HEX hex2(//display the HEX on HEX2                                
           .iDIG(hex_data[3:0]),
           .oHEX_D(HEX2)
           );
SEG_HEX hex3(//display the HEX on HEX3                                 
           .iDIG(hex_data[7:4]),
           .oHEX_D(HEX3)
           );
SEG_HEX hex4(//display the HEX on HEX4                                 
           .iDIG(4'hf),
           .oHEX_D(HEX4)
           );
SEG_HEX hex5(//display the HEX on HEX5                                 
           .iDIG(4'hf), 
           .oHEX_D(HEX5)
           );

parameter signalTap_count = 1200;
reg	[11:0] 	us_count;
reg				clk_38;
always @(posedge CLOCK_50)
begin
	if (us_count <= signalTap_count)
		us_count <= us_count + 1'b1;
	else
		us_count <= 1'b1;
end

always @(posedge CLOCK_50)
begin
	if (us_count == signalTap_count)
		clk_38 = ~clk_38;
end

/////////////////////////////////////////////////////////
//  TX test pattern . (Simple) 
/////////////////////////////////////////////////////////

reg [15:0] test_data;
reg        data_send;
wire       tx_busy;
always @(posedge CLOCK_50)
  begin
      if(KEY[0]) begin
	        	test_data <= 16'd0;
	         data_send <= 1'b0;
		end else begin
			  if ( (!tx_busy) ) begin
			    data_send <= 1'b1;
				 test_data <= test_data + 1'b1;
			  end else begin
			  	 data_send <= 1'b0;
			  end
     end
end


IR_TRANSMITTER_Terasic  u_tx(
        .clk(CLOCK_50),
        .rst_n(1'b1),
		.clk_38(clk_38),
        .addr(8'h86), // 8bits Address 
        .cmd(8'h12),  // 8bits Command
		.send(!KEY[1]),
        .busy(tx_busy),
        .data_out(IRDA_TXD)		
);

/*
wire				ac_data_ready;
wire	[127:0]		ac_data_out;
wire	[32:0]		ac_data_len;
AC_RECEIVER		ac_receiver_inst(
		.clk(CLOCK_50),
		.rst_n(1'b1),
		.data_in(IRDA_RXD),
		.data_ready(ac_data_ready),
		.data_out(ac_data_out),
		.data_len(ac_data_len)
);
*/
endmodule
