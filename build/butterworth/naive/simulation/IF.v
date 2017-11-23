/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module IF
#( //parameters that can be externally configured
	parameter I_WIDTH = 16,
	parameter IM_ADDR_WIDTH = 16
)
(  //inputs and outputs
	input iClk,
	input iReset,
	
	input [IM_ADDR_WIDTH-1:0] iProgramCounter,
		
	output [IM_ADDR_WIDTH-1:0] oInstructionAddress,
	input [I_WIDTH-1:0] iInstruction,
	
	output [I_WIDTH-1:0] oInstruction,

	output oInstructionReadEnable
);

	//reg [I_WIDTH-1:0] rInstruction;
	
	assign oInstructionAddress = iProgramCounter;
	assign oInstructionReadEnable = (iProgramCounter != 0);
	
	/*
	always @(posedge iClk)
	begin
		if (iReset)
			rInstruction <= 'b0;
		else
			rInstruction <= iInstruction;
	end
	*/
	
	//assign oInstruction = rInstruction;
	assign oInstruction = iInstruction;
	
endmodule
