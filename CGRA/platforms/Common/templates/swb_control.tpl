module <<MODULE_NAME>>
#
(
	parameter WIDTH = <<WIDTH>>,
	parameter FU_INPUTS = <<NUM_INPUTS>>,
	parameter FU_OUTPUTS = <<NUM_OUTPUTS>>
)
(
	<<WIRES>>

	<<CONTROL_WIRES>>
	//config chain
	input iClk,
	input iReset,
	input iConfigEnable,
	input iConfigDataIn,
	output oConfigDataOut
);

	localparam CONFIG_LENGTH = <<CONFIG_LENGTH>>;

	<<OUTPUT_REGISTERS>>
	<<OUTPUT_WIRES>>
	<<OUTPUT_BUFFERS>>
	<<ENABLE_WIRES>>

	reg [CONFIG_LENGTH-1:0] rConfig;
	wire [CONFIG_LENGTH-1:0] wConfig = (iReset) ? 1'b0 : rConfig;

	<<CONTROL_ASSIGNMENT>>
	<<OUTPUT_ASSIGNMENT>>

	//----------------------------------------
	//	SCAN CHAIN CONFIG CODE
	//----------------------------------------
			
	integer gCurrBit;
	always @(posedge iClk)
	begin
		if (iConfigEnable)
			begin
				rConfig[CONFIG_LENGTH-1] <= iConfigDataIn;
				
				for (gCurrBit=0; gCurrBit < CONFIG_LENGTH-1; gCurrBit = gCurrBit + 1)		
					rConfig[gCurrBit] <= rConfig[gCurrBit+1];
			end
	end
	
	assign oConfigDataOut = rConfig[0];
	//----------------------------------------

<<CONNECTIONS>>
endmodule

