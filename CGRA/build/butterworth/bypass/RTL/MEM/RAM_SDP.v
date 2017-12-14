/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module RAM_SDP 
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8,
	parameter DATAFILE = "../../DATA/DMEM_8.hex",
	parameter DO_INIT = 1
)
(
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	rden,
	q);

	input	  clock;
	input	[DATA_WIDTH-1:0]  data;
	input	[ADDR_WIDTH-1:0]  rdaddress;
	input	[ADDR_WIDTH-1:0]  wraddress;
	input	  wren;
	input	  rden;
	output	[DATA_WIDTH-1:0]  q;
		
	reg [ADDR_WIDTH-1:0] rReadAddress;
	reg [ADDR_WIDTH-1:0] rWriteAddress;
	reg [DATA_WIDTH-1:0] rWriteData;
		
	reg [DATA_WIDTH-1:0] rRAM [2**ADDR_WIDTH-1:0];
	reg rWriteEnable;
	
	initial begin
		if (DO_INIT)
			$readmemb(DATAFILE, rRAM, 0, 2**ADDR_WIDTH-1);
	end
	
	always @(posedge clock)
	begin
		rReadAddress <= rdaddress;
		rWriteAddress <= wraddress;
		rWriteEnable <= wren;
		rWriteData <= data;
			
		if (rWriteEnable)
			rRAM[rWriteAddress] <= rWriteData;
	end
	
	assign q = (rReadAddress == rWriteAddress & rWriteEnable) ? rWriteData : rRAM[rReadAddress];
	
endmodule
