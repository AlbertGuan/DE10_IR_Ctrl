module AC_RECEIVER(
		input					clk,
		input					rst_n,
		input					data_in,
		output		reg			data_ready,
		output		reg[127:0]	data_out,
		output		reg[32:0]	data_len
	);
parameter	LEAD						= 2'b00;
parameter	DATA_TRANSFER				= 2'b01;

parameter	MAX_DATA_TRANSER			= 150000;
parameter	LEAD_DUR					= 230000;	//230000 * 0.02us = 4.6ms
parameter	MIN_BIT_VALID				= 20000;
parameter	LOGICAL_ONE					= 40000;	//Logical "1" is longer than this, Logical "0" is between 20000 and 35000

reg		[17:0]					lead_count;
reg		[17:0]					data_count;
reg		[32:0]					bit_ptr;
reg		[127:0]					data_buf;
reg		[1:0]					state;

always @ (posedge clk or negedge rst_n)
begin
	if (0 == rst_n)
		state <= LEAD;
	else
	begin
		case (state)
			LEAD			:
				if (lead_count > LEAD_DUR)
					state <= DATA_TRANSFER;
			DATA_TRANSFER	:
				if (data_count >= MAX_DATA_TRANSER || bit_ptr >= 128)
				begin
					data_ready <= 1'b1;
					data_len <= bit_ptr;
					data_out <= data_buf;
					state <= LEAD;
				end
			default			:
				state <= LEAD;
		endcase
	end
end

always @ (posedge clk or negedge rst_n)
begin
	if (0 == rst_n)
		lead_count <= 0;
	else if ((LEAD == state) && 0 == data_in)
		lead_count <= lead_count + 1'b1;
	else
		lead_count <= 0;
end

always @ (posedge clk or negedge rst_n)
begin
	if (0 == rst_n)
		data_count <= 0;
	else if ((DATA_TRANSFER == state) && data_in)
		data_count <= data_count + 1'b1;
	else
		data_count <= 0;
end

always @ (posedge clk or negedge rst_n)
begin
	if (0 == rst_n)
	begin
		bit_ptr <= 0;
		data_buf <= 0;
	end
	else if (DATA_TRANSFER == state)
	begin
		if (data_count == MIN_BIT_VALID)
			bit_ptr <= bit_ptr + 1'b1;
			
		if (data_count >= LOGICAL_ONE)
			data_buf[bit_ptr - 1'b1] <= 1'b1;
	end
	else
	begin
		bit_ptr <= 0;
		data_buf <= 0;
	end
end

endmodule