/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module RAM_SDP_BE
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8,
	parameter DATAFILE = "",
	parameter DO_INIT = 1,
	parameter ADDRESSABLE_SIZE = 8
)
(
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	rden,
	q);

	
	localparam NUM_MEMS = DATA_WIDTH / ADDRESSABLE_SIZE;

	input	  clock;
	input	[DATA_WIDTH-1:0]  data;
	input	[ADDR_WIDTH-1:0]  rdaddress;
	input	[ADDR_WIDTH-1:0]  wraddress;
	input	  [NUM_MEMS-1:0] wren;
	input	  rden;
	output	[DATA_WIDTH-1:0]  q;
		
	reg [ADDR_WIDTH-1:0] rReadAddress;
	reg [ADDR_WIDTH-1:0] rWriteAddress;
	reg [DATA_WIDTH-1:0] rWriteData;
	
	reg [DATA_WIDTH-1:0] rRAM [2**ADDR_WIDTH-1:0];
	reg  [NUM_MEMS-1:0] rWriteEnable;
	
	initial begin
		if (DO_INIT & DATAFILE!="")
			$readmemb(DATAFILE, rRAM, 0, 2**ADDR_WIDTH-1);
	end
	
	integer x;
	
	always @(posedge clock)
	begin
		//if (!(|wren))
			rReadAddress <= rdaddress;
		//else begin
			rWriteAddress <= wraddress;
			rWriteEnable <= wren;
			rWriteData <= data;			
		//end
			
		for (x=0; x<NUM_MEMS; x=x+1)
			if (rWriteEnable[x])
				rRAM[rWriteAddress][x*ADDRESSABLE_SIZE+:ADDRESSABLE_SIZE] <= rWriteData[x*ADDRESSABLE_SIZE+:ADDRESSABLE_SIZE];
	end
	
	genvar currMem;

	generate
		for (currMem=0; currMem<NUM_MEMS; currMem=currMem+1)
			begin : forwarding
				assign q[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE] = (rReadAddress == rWriteAddress & rWriteEnable[currMem]) ? rWriteData[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE] : rRAM[rReadAddress][(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE];
			end
	endgenerate
	
endmodule
