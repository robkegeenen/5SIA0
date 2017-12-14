module RAM_SDP_TSMC 
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8,
	parameter DATAFILE = "", //dummy for compatibility
	parameter DO_INIT = 0 //dummy for compatibility
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
			
	parameter TSMC_ADDR_WIDTH = ADDR_WIDTH;
	parameter TSMC_DATA_WIDTH = DATA_WIDTH;

	wire wCLKR;
	assign wCLKR = clock;
	wire wCLKW;
	assign wCLKW = clock;
	wire wWEB = !wren;
	wire wREB = !rden;

	wire wBIST = 1'b0;
	wire wPD = 1'b0;
	wire wREBM = 1'b1;
	wire wWEBM = 1'b1;
	wire [TSMC_ADDR_WIDTH-1:0] wAMA = {TSMC_ADDR_WIDTH{1'b0}};
	wire [TSMC_ADDR_WIDTH-1:0] wAMB = {TSMC_ADDR_WIDTH{1'b0}};
	wire [TSMC_DATA_WIDTH-1:0] wDM = {TSMC_DATA_WIDTH{1'b0}};
	wire [TSMC_DATA_WIDTH-1:0] wBWEBM = {TSMC_DATA_WIDTH{1'b1}};


	wire [TSMC_ADDR_WIDTH-1:0] wAA = (wraddress >= 2**TSMC_ADDR_WIDTH) ? (2**TSMC_ADDR_WIDTH)-1 : wraddress; //Address on port A (write)
	wire [TSMC_ADDR_WIDTH-1:0] wAB = rdaddress; //Address on port B (read) 

	wire [TSMC_DATA_WIDTH-1:0] wD = data; //Input data
	wire [TSMC_DATA_WIDTH-1:0] wQ; //Input data

	wire [TSMC_DATA_WIDTH-1:0] wBWEB = {TSMC_DATA_WIDTH{wWEB}}; //Input data

	generate
		if (DATA_WIDTH == 12)
			begin	
				TS6N40LPA256X12M4S mem_inst
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
			end
		else begin
				TS6N40LPA256X33M2F mem_inst
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
		end	  
	endgenerate

	assign q = wQ;
		
endmodule