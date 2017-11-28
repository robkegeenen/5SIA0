/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module Address_Isolator
#
(
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,

	parameter RANGE_PERIPHERALS = "9.0",
	parameter STRING_SIZE = 3,
	parameter NUM_PERIPHERALS = 1,
	parameter PERIPHERAL_NUM = 0,
	
	parameter NUM_LSU = 1
)
(	
	//input port
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iWriteAddress,
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iReadAddress,
	input [NUM_LSU*(INTERFACE_WIDTH / 8)-1:0] iWriteEnable,
	input [NUM_LSU*INTERFACE_WIDTH-1:0] iWriteData,
	input [NUM_LSU-1:0] iReadRequest,
	input [NUM_LSU-1:0] iWriteRequest,	
	

	output [NUM_LSU*INTERFACE_WIDTH-1:0] oReadData,
	output [NUM_LSU-1:0] oReadDataValid,
	output [NUM_LSU-1:0] oWriteAccept,

	output [NUM_LSU-1:0] oReadGrantNextCycle,
	output [NUM_LSU-1:0] oWriteGrantNextCycle,

	
	//output port
	output [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] oWriteAddress,
	output [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] oReadAddress,
	output [NUM_LSU*(INTERFACE_WIDTH / 8)-1:0] oWriteEnable,
	output [NUM_LSU*INTERFACE_WIDTH-1:0] oWriteData,	
	output [NUM_LSU-1:0] oReadRequest,
	output [NUM_LSU-1:0] oWriteRequest,
	
	input [NUM_LSU-1:0] iReadGrantNextCycle,
	input [NUM_LSU-1:0] iWriteGrantNextCycle,

	input [NUM_LSU*INTERFACE_WIDTH-1:0] iReadData,
	input [NUM_LSU-1:0] iReadDataValid,
	input [NUM_LSU-1:0] iWriteAccept

);

	localparam range = FindRange(0);
	localparam Address_Low = range[2*INTERFACE_ADDR_WIDTH-1:INTERFACE_ADDR_WIDTH];
	localparam Address_High = range[INTERFACE_ADDR_WIDTH-1:0];

	function [2*INTERFACE_ADDR_WIDTH-1:0] FindRange;
		input A;
		integer AddressRange[(NUM_PERIPHERALS*2)-1:0];
		integer d;
		integer charnum;
		integer accumulate;
		integer m;
		integer significance;
		integer Address_L;
		integer Address_H;
		begin
			accumulate = 0;
			m = 0;
			significance = 1;
			for(d=0;d<STRING_SIZE;d=d+1) begin
				charnum = RANGE_PERIPHERALS[d*8 +:8];
				if(charnum != ".") begin
					charnum = charnum - 48;
					accumulate = accumulate + charnum * significance;
					significance = significance * 10;
				end
				else begin
					AddressRange[m] = accumulate;
					m = m+1;
					significance = 1;
					accumulate = 0;
				end			
			end
			AddressRange[m] = accumulate;
		
			Address_L = AddressRange[PERIPHERAL_NUM*2];

			Address_H = AddressRange[(PERIPHERAL_NUM*2)+1];

			FindRange = {Address_L,Address_H};
		end
	endfunction	


	// initial begin		
	//  	$display("NUMBER:");
	//  	$display("%d", PERIPHERAL_NUM);
	//  	$display("%d", Address_Low);
	//  	$display("%d", Address_High);
	// end

	wire [INTERFACE_ADDR_WIDTH-1:0] wWriteAddress[NUM_LSU-1:0];
	wire [INTERFACE_ADDR_WIDTH-1:0] wReadAddress[NUM_LSU-1:0];

	wire wInRangeWrite[NUM_LSU-1:0];
	wire wInRangeRead[NUM_LSU-1:0];

	assign oWriteEnable = iWriteEnable;	
	assign oWriteData = iWriteData;

	assign oReadData = oReadData;
	assign oReadDataValid = iReadDataValid;

	assign oWriteAccept = iWriteAccept;

	assign oReadGrantNextCycle = iReadGrantNextCycle;
	assign oWriteGrantNextCycle = iWriteGrantNextCycle;


	genvar gCurrPort;

	generate

		for (gCurrPort=0; gCurrPort < NUM_LSU; gCurrPort = gCurrPort + 1)
			begin : Map_Ports

				assign wWriteAddress[gCurrPort] = iWriteAddress[(gCurrPort*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 : gCurrPort*INTERFACE_ADDR_WIDTH];
				assign wReadAddress[gCurrPort] = iReadAddress[(gCurrPort*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 : gCurrPort*INTERFACE_ADDR_WIDTH];

				assign wInRangeWrite[gCurrPort]	= (wWriteAddress[gCurrPort] >= Address_Low) & (wWriteAddress[gCurrPort] <= Address_High);
				assign wInRangeRead[gCurrPort] = (wReadAddress[gCurrPort] >= Address_Low) & (wReadAddress[gCurrPort] <= Address_High);

				assign oWriteRequest[gCurrPort] = iWriteRequest[gCurrPort] & wInRangeWrite[gCurrPort];
				assign oReadRequest[gCurrPort] = iReadRequest[gCurrPort] & wInRangeRead[gCurrPort];	

				assign oWriteAddress[(gCurrPort*INTERFACE_WIDTH)+INTERFACE_WIDTH-1 : gCurrPort*INTERFACE_WIDTH] = wWriteAddress[gCurrPort] - Address_Low;
				assign oReadAddress[(gCurrPort*INTERFACE_WIDTH)+INTERFACE_WIDTH-1 : gCurrPort*INTERFACE_WIDTH] = wReadAddress[gCurrPort] - Address_Low;		

			end
	endgenerate		

endmodule
