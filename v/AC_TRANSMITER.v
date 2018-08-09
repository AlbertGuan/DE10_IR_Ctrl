module AC_TRANSMITER(
	input					clk,
	input		[63:0]		data_to_send,
	input		[6:0]		data_len,
	output		reg			data_out
)