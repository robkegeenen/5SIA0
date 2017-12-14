/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module CORE_FIFO
#
(
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32
)
(	
	input iClk,
	input iReset,
	
	input [INTERFACE_ADDR_WIDTH-1:0] iWriteAddress,
	input [INTERFACE_ADDR_WIDTH-1:0] iReadAddress,
	input [(INTERFACE_WIDTH / 8)-1:0] iWriteEnable,
	input [INTERFACE_WIDTH-1:0] iWriteData,
	input iReadRequest,
	input iWriteRequest,
	

	output [INTERFACE_WIDTH-1:0] oReadData,
	output oReadDataValid,
	output oWriteAccept
);

	// initial begin		
	//  	$display("NUMBER:");
	//  	$display("%d", PERIPHERAL_NUM);
	//  	$display("%d", Address_Low);
	//  	$display("%d", Address_High);
	// end


	assign oReadData = 10;
	assign oReadDataValid = 1;

endmodule
