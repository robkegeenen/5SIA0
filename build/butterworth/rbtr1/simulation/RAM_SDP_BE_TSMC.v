/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module RAM_SDP_BE_TSMC
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8,
	parameter DATAFILE = "",
	parameter DO_INIT = 0,
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
	input	   rden;
	output	[DATA_WIDTH-1:0]  q;
		
	parameter TSMC_ADDR_WIDTH = ADDR_WIDTH;
	parameter TSMC_DATA_WIDTH = DATA_WIDTH;

	wire [DATA_WIDTH-1:0]  q_tmp;
	wire wCLKR;
	assign wCLKR = clock;
	wire wCLKW;
	assign wCLKW = clock;
	wire wWEB;
	assign wWEB = !(|wren);
	wire wREB = !rden;

	wire wBIST = 1'b0;
	wire wPD = 1'b0;
	wire wREBM = 1'b1;
	wire wWEBM = 1'b1;
	wire [TSMC_ADDR_WIDTH-1:0] wAMA = {TSMC_ADDR_WIDTH{1'b0}};
	wire [TSMC_ADDR_WIDTH-1:0] wAMB = {TSMC_ADDR_WIDTH{1'b0}};
	wire [TSMC_DATA_WIDTH-1:0] wDM = {TSMC_DATA_WIDTH{1'b0}};
	wire [TSMC_DATA_WIDTH-1:0] wBWEBM = {TSMC_DATA_WIDTH{1'b1}};


	wire [TSMC_ADDR_WIDTH-1:0] wAA; //Address on port A (write)
	wire [TSMC_ADDR_WIDTH-1:0] wAB; //Address on port B (read) 

	wire [TSMC_DATA_WIDTH-1:0] wD; 
	wire [TSMC_DATA_WIDTH-1:0] wQ; 

	wire [TSMC_DATA_WIDTH-1:0] wBWEB; 

	assign wAA = (wraddress >= 2**TSMC_ADDR_WIDTH) ? (2**TSMC_ADDR_WIDTH)-1 : wraddress; //Address on port A (write)
	assign wAB = rdaddress; //Address on port B (read) 

	assign wD = data; 		

	TS6N40LPA256X32M4S mem_inst
	  (
	  	.AA(wAA),
	  	.D(wD),
	  	.BWEB(wBWEB),
	  	.WEB(wWEB),
	  	.CLKW(wCLKW),
	  	.AB(wAB),
	  	.REB(wREB),
	  	.CLKR(wCLKR),
	  	.PD(wPD),

	  	.AMA(wAMA),
	  	.DM(wDM),
	  	.BWEBM(wBWEBM),
	  	.WEBM(wWEBM),
	  	.AMB(wAMB),
	  	.REBM(wREBM),
	  	.BIST(wBIST),
	  	.Q(wQ)
	  );

	genvar currMem;	

	generate
		for (currMem=0; currMem<NUM_MEMS; currMem=currMem+1)
			begin : forwarding
				assign wBWEB[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE] = {ADDRESSABLE_SIZE{~wren[currMem]}};				
				//assign q[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE] = (rdaddress == wraddress & wren[currMem]) ? wQ[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE] : wQ[(currMem+1)*ADDRESSABLE_SIZE-1:(currMem+0)*ADDRESSABLE_SIZE];
			end
	endgenerate
	
	assign q = wQ;

endmodule
