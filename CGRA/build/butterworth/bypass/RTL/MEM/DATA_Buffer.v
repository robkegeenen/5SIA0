module DATA_Buffer
#
(
	parameter WIDTH = 1
)
(
	input [WIDTH-1:0] iData,
	output [WIDTH-1:0] oData
);

	genvar x;

	generate
		for (x=0; x < WIDTH; x = x + 1)
			begin : assign_buffer_bits				
				BUFFXD12BWP12T40M1P bitbuf (.I(iData[x]), .Z(oData[x]));
			end
	endgenerate

endmodule
	
 // cadence translate_off
module BUFFXD12BWP12T40M1P
(
	input I,
	output Z
);

	assign Z = I;
endmodule
// cadence translate_on