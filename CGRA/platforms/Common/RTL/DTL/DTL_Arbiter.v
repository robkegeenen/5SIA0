/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

module DTL_ARBITER
#
(
	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter INTERFACE_BLOCK_WIDTH = 5,
	parameter NUM_PORTS = 2,
	
	parameter INTERFACE_NUM_ENABLES = INTERFACE_WIDTH/8
)
(
	input iClk,
	input iReset,
	
	//input (SLAVE) DTL ports
	input  [NUM_PORTS-1:0]								iDTL_IN_CommandValid,
	output [NUM_PORTS-1:0]								oDTL_IN_CommandAccept,
	input  [NUM_PORTS*INTERFACE_ADDR_WIDTH-1:0]  iDTL_IN_Address,
	input  [NUM_PORTS-1:0]								iDTL_IN_CommandReadWrite,
	input  [NUM_PORTS*INTERFACE_BLOCK_WIDTH-1:0] iDTL_IN_BlockSize,

	output [NUM_PORTS-1:0]								oDTL_IN_ReadValid,
	output [NUM_PORTS-1:0]								oDTL_IN_ReadLast,	
	input  [NUM_PORTS-1:0]								iDTL_IN_ReadAccept,
	output [NUM_PORTS*INTERFACE_WIDTH-1:0] 		oDTL_IN_ReadData,
	
	input  [NUM_PORTS-1:0]								iDTL_IN_WriteValid,		
	input  [NUM_PORTS-1:0]								iDTL_IN_WriteLast,
	output [NUM_PORTS-1:0]								oDTL_IN_WriteAccept,	
	input  [NUM_PORTS*INTERFACE_NUM_ENABLES-1:0] iDTL_IN_WriteEnable,	
	input  [NUM_PORTS*INTERFACE_WIDTH-1:0] 		iDTL_IN_WriteData,
	
	//output (MASTER) DTL port
	input 										iDTL_OUT_CommandAccept,
	input 										iDTL_OUT_WriteAccept,
	input 										iDTL_OUT_ReadValid,
	input 										iDTL_OUT_ReadLast,
	input [INTERFACE_WIDTH-1:0] 			iDTL_OUT_ReadData,
		
	output 										oDTL_OUT_CommandValid,
	output 										oDTL_OUT_WriteValid,	
	output 										oDTL_OUT_CommandReadWrite,
	output [INTERFACE_NUM_ENABLES-1:0] 	oDTL_OUT_WriteEnable,	
	output [INTERFACE_ADDR_WIDTH-1:0] 	oDTL_OUT_Address,
	output [INTERFACE_WIDTH-1:0] 			oDTL_OUT_WriteData,
	
	output [INTERFACE_BLOCK_WIDTH-1:0] 	oDTL_OUT_BlockSize,
	output 										oDTL_OUT_WriteLast,
	output 										oDTL_OUT_ReadAccept	
);

	function integer CLogB2;
		input [31:0] Depth;
		integer i;
		begin
			i = Depth;		
			for(CLogB2 = 0; i > 0; CLogB2 = CLogB2 + 1)
				i = i >> 1;
		end
	endfunction	

	function [NUM_PORTS-1:0] FindBE;
		input [NUM_PORTS*(INTERFACE_WIDTH / 8)-1:0] inputBE;
		integer i;
		reg [(INTERFACE_WIDTH / 8)-1:0] foundBE;
		reg [(INTERFACE_WIDTH / 8)-1:0] currBE;
		begin
			foundBE=0;
			FindBE=0;			

			for(i=0; i < NUM_PORTS; i=i+1)
				begin
					currBE=inputBE[(i+1)*(INTERFACE_WIDTH / 8)-1-:(INTERFACE_WIDTH / 8)];
					if ( !( |(foundBE & currBE) ) )
						begin
							foundBE = foundBE | currBE;
							FindBE[i] = 1'b1;
						end
				end			
		end
	endfunction				
	
	localparam NUM_PORTS_WIDTH = CLogB2(NUM_PORTS-1);
	
	wire 										wDTL_IN_CommandValid[NUM_PORTS-1:0];
	wire 										wDTL_IN_CommandAccept[NUM_PORTS-1:0];
	wire [INTERFACE_ADDR_WIDTH-1:0]  wDTL_IN_Address[NUM_PORTS-1:0];
	wire 										wDTL_IN_CommandReadWrite[NUM_PORTS-1:0];
	wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_IN_BlockSize[NUM_PORTS-1:0];

	wire 										wDTL_IN_ReadValid[NUM_PORTS-1:0];
	wire 										wDTL_IN_ReadLast[NUM_PORTS-1:0];
	wire 										wDTL_IN_ReadAccept[NUM_PORTS-1:0];
	wire [INTERFACE_WIDTH-1:0] 		wDTL_IN_ReadData[NUM_PORTS-1:0];
	
	wire 										wDTL_IN_WriteValid[NUM_PORTS-1:0];
	wire 										wDTL_IN_WriteLast[NUM_PORTS-1:0];
	wire 										wDTL_IN_WriteAccept[NUM_PORTS-1:0];
	wire [INTERFACE_NUM_ENABLES-1:0] wDTL_IN_WriteEnable[NUM_PORTS-1:0];	
	wire [INTERFACE_WIDTH-1:0] 		wDTL_IN_WriteData[NUM_PORTS-1:0];
	
	wire [NUM_PORTS_WIDTH-1:0] wSelected;
	wire [NUM_PORTS-1:0] wGrant;
	wire wActive;
				
	wire [INTERFACE_ADDR_WIDTH-1:0] wSelectedAddress = wDTL_IN_Address[wSelected];
	wire [NUM_PORTS-1:0]  wGrantParallel;

	wire [NUM_PORTS-1:0] wNonConflictingEnable_WRITE;
	wire [NUM_PORTS*(INTERFACE_ADDR_WIDTH / 8)-1:0] wDTL_IN_WriteValid_wide;
	wire [NUM_PORTS-1:0] wMaskRequest_WRITE;
	wire [NUM_PORTS*(INTERFACE_ADDR_WIDTH / 8)-1:0] wMaskRequest_WRITE_wide;

	wor [INTERFACE_NUM_ENABLES-1:0] wEnableOut_WRITE;
	wor [INTERFACE_WIDTH-1:0] wDataOut_WRITE;

	reg rPortBusy;

	genvar gCurrPort;
				
	generate
		for (gCurrPort=0; gCurrPort < NUM_PORTS; gCurrPort = gCurrPort + 1)
			begin : CheckAddresses	
				//Added support for coalesced writes
				//need to catch the fact that if we have 2 channels the read will always be granted if address = 0	
				//(wSelectedAddress == wDTL_IN_Address[gCurrPort] & !wDTL_IN_CommandReadWrite[gCurrPort] & wActive & wNonConflictingEnable_WRITE[gCurrPort] & wDTL_IN_WriteValid[gCurrPort])		
				assign wGrantParallel[gCurrPort] = (wSelectedAddress == wDTL_IN_Address[gCurrPort] & wDTL_IN_CommandReadWrite[gCurrPort] & wActive) | (wSelectedAddress == wDTL_IN_Address[gCurrPort] & !wDTL_IN_CommandReadWrite[gCurrPort] & wActive & wNonConflictingEnable_WRITE[gCurrPort] & wDTL_IN_WriteValid[gCurrPort]) | wGrant[gCurrPort]; //if it has the same address for reading or writing without conflict
			end
	endgenerate
	
	generate
		for (gCurrPort=0; gCurrPort < NUM_PORTS; gCurrPort = gCurrPort + 1)
			begin : ArbiterPorts						
				assign oDTL_IN_ReadData[(gCurrPort+1)*INTERFACE_WIDTH-1 : gCurrPort*INTERFACE_WIDTH] = wDTL_IN_ReadData[gCurrPort][INTERFACE_WIDTH-1:0];
					
				assign wDTL_IN_Address[gCurrPort] = iDTL_IN_Address[(gCurrPort*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 : gCurrPort*INTERFACE_ADDR_WIDTH];
				assign wDTL_IN_BlockSize[gCurrPort] = iDTL_IN_BlockSize[(gCurrPort*INTERFACE_BLOCK_WIDTH)+INTERFACE_BLOCK_WIDTH-1 : gCurrPort*INTERFACE_BLOCK_WIDTH];
				assign wDTL_IN_WriteEnable[gCurrPort] = iDTL_IN_WriteEnable[(gCurrPort*INTERFACE_NUM_ENABLES)+INTERFACE_NUM_ENABLES-1 : gCurrPort*INTERFACE_NUM_ENABLES];
				assign wDTL_IN_WriteData[gCurrPort] = iDTL_IN_WriteData[(gCurrPort*INTERFACE_WIDTH)+INTERFACE_WIDTH-1 : gCurrPort*INTERFACE_WIDTH];
				
				assign oDTL_IN_CommandAccept[gCurrPort] = wDTL_IN_CommandAccept[gCurrPort];
				assign oDTL_IN_ReadValid[gCurrPort] = wDTL_IN_ReadValid[gCurrPort];
				assign oDTL_IN_ReadLast[gCurrPort] = wDTL_IN_ReadLast[gCurrPort];
				assign oDTL_IN_WriteAccept[gCurrPort] = wDTL_IN_WriteAccept[gCurrPort];
				
				assign wDTL_IN_CommandValid[gCurrPort] = iDTL_IN_CommandValid[gCurrPort];
				assign wDTL_IN_CommandReadWrite[gCurrPort] = iDTL_IN_CommandReadWrite[gCurrPort];
				assign wDTL_IN_ReadAccept[gCurrPort] = iDTL_IN_ReadAccept[gCurrPort];
				assign wDTL_IN_WriteValid[gCurrPort] = iDTL_IN_WriteValid[gCurrPort];
				assign wDTL_IN_WriteValid_wide[(gCurrPort+1)*(INTERFACE_WIDTH / 8)-1:(gCurrPort)*(INTERFACE_WIDTH / 8)] = {(INTERFACE_WIDTH / 8){wDTL_IN_WriteValid[gCurrPort]}};
				assign wDTL_IN_WriteLast[gCurrPort] = iDTL_IN_WriteLast[gCurrPort];

				//Need the mask to prevent other adresses to interfere with coalesced writes
				assign wMaskRequest_WRITE[gCurrPort] = (wSelectedAddress == wDTL_IN_Address[gCurrPort]);
				assign wMaskRequest_WRITE_wide[(gCurrPort+1)*(INTERFACE_WIDTH / 8)-1:(gCurrPort)*(INTERFACE_WIDTH / 8)] = {(INTERFACE_WIDTH / 8){wMaskRequest_WRITE[gCurrPort]}};		
					
				assign wDTL_IN_CommandAccept[gCurrPort] = iDTL_OUT_CommandAccept & (wGrantParallel[gCurrPort] | !wActive);
				assign wDTL_IN_ReadValid[gCurrPort] = iDTL_OUT_ReadValid & (wGrantParallel[gCurrPort]);
				assign wDTL_IN_ReadLast[gCurrPort] = iDTL_OUT_ReadLast & (wGrantParallel[gCurrPort]);
				assign wDTL_IN_WriteAccept[gCurrPort] = iDTL_OUT_WriteAccept & (wGrantParallel[gCurrPort]);
				assign wDTL_IN_ReadData[gCurrPort] = (wGrantParallel[gCurrPort]) ? iDTL_OUT_ReadData : {(INTERFACE_WIDTH){1'b0}};

				//If we have a coaslesced write construct new enable and data, NOTE: WOR wires
				assign wEnableOut_WRITE = wDTL_IN_WriteEnable[gCurrPort] & {(INTERFACE_NUM_ENABLES){wGrantParallel[gCurrPort]}};
				assign wDataOut_WRITE = wDTL_IN_WriteData[gCurrPort] & {(INTERFACE_WIDTH){wGrantParallel[gCurrPort]}};	

			end
		
			assign oDTL_OUT_CommandValid = /*wActive ?*/ wDTL_IN_CommandValid[wSelected] /*: 1'b0*/;
			assign oDTL_OUT_WriteValid =  /*wActive ?*/  wDTL_IN_WriteValid[wSelected] /*: 1'b0*/;			
			assign oDTL_OUT_CommandReadWrite =  /*wActive ?*/  wDTL_IN_CommandReadWrite[wSelected] /*: 1'b1*/;						
			assign oDTL_OUT_BlockSize = /*wActive ?*/ wDTL_IN_BlockSize[wSelected] /*: {(INTERFACE_BLOCK_WIDTH){1'b0}}*/;
			assign oDTL_OUT_WriteLast = /*wActive ?*/ wDTL_IN_WriteLast[wSelected] /*: 1'b1*/;
			assign oDTL_OUT_ReadAccept = /*wActive ?*/ wDTL_IN_ReadAccept[wSelected] /*: 1'b1*/;
			assign oDTL_OUT_Address = /*wActive ?*/  wDTL_IN_Address[wSelected] /*: {(INTERFACE_ADDR_WIDTH){1'b0}} */;	

			if(NUM_PORTS > 1)
				begin
					//Writeenable is NUM_PORTS*interfacewidth/4
					assign wNonConflictingEnable_WRITE = FindBE(iDTL_IN_WriteEnable & wDTL_IN_WriteValid_wide & wMaskRequest_WRITE_wide);
					assign oDTL_OUT_WriteEnable =  wActive ? wEnableOut_WRITE : {(INTERFACE_NUM_ENABLES){1'b0}} ;
					assign oDTL_OUT_WriteData = wActive ?  wDataOut_WRITE : {(INTERFACE_ADDR_WIDTH){1'b0}} ;					
				end
			else
				begin
					assign wNonConflictingEnable_WRITE[0] = 1'b1;
					assign oDTL_OUT_WriteEnable =  wActive ? wDTL_IN_WriteEnable[wSelected] : {(INTERFACE_NUM_ENABLES){1'b0}} ;
					assign oDTL_OUT_WriteData = wActive ? wDTL_IN_WriteData[wSelected] : {(INTERFACE_WIDTH){1'b0}};
				end		
	endgenerate	
	
	always @(posedge iClk)
	begin		
		if (iReset )
			rPortBusy <= 1'b0;
		else
			begin				
				if (oDTL_OUT_CommandValid)
					rPortBusy <= 1'b1;
					
				if (iDTL_OUT_ReadValid | iDTL_OUT_WriteAccept)
					rPortBusy <= 1'b0;
			end				
	end
		
	generate	
		if (NUM_PORTS > 1)
			begin				
				ARBITER_RR 
				#(
						.NUM_PORTS(NUM_PORTS),
						.NUM_PORTS_WIDTH(NUM_PORTS_WIDTH)
				)
				arbiter_inst	
				(
					.iClk(iClk),
					.iReset(iReset),
					
					.iRequest(iDTL_IN_CommandValid),
					.oGrant(wGrant),
					.oSelected(wSelected),
					
					.oActive(wActive),
					.iPortBusy(/*oDTL_OUT_CommandValid | oDTL_OUT_WriteValid |*/ (rPortBusy & !(iDTL_OUT_ReadValid | iDTL_OUT_WriteAccept)))
				);
			end
		else //if there is just one port then dont use the arbiter, just grant everything to port 0
			begin
				assign wGrant = 1'b1;
				assign wSelected = 1'd0;
				assign wActive = 1'b1;
			end
	endgenerate
	
endmodule
