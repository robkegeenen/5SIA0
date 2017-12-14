`include "config.vh"

module ARBITER
#
(	
	parameter D_WIDTH = 32,	
	parameter INTERFACE_ADDR_WIDTH = 32,	
	parameter INTERFACE_MEM_WIDTH = 32,
	parameter NUM_LSU = 1
)
(
	input iClk,
	input iReset,
	
	//output oLastCycle,

	//input ports
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iWriteAddress,
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iReadAddress,
	input [NUM_LSU*(INTERFACE_MEM_WIDTH / 8)-1:0] iWriteEnable,
	output oReadEnable,
	input [NUM_LSU*D_WIDTH-1:0] iWriteData,
	input [NUM_LSU-1:0] iReadRequest,
	input [NUM_LSU-1:0] iWriteRequest,

	output [NUM_LSU*D_WIDTH-1:0] oReadData,
	output [NUM_LSU-1:0] oReadDataValid,
	output [NUM_LSU-1:0] oWriteAccept,

	output [NUM_LSU-1:0] oReadGrantNextCycle,
	output [NUM_LSU-1:0] oWriteGrantNextCycle,

	
	//output port
	output [INTERFACE_ADDR_WIDTH-1:0] oWriteAddress,
	output [INTERFACE_ADDR_WIDTH-1:0] oReadAddress,
	output [(INTERFACE_MEM_WIDTH / 8)-1:0] oWriteEnable,
	output [D_WIDTH-1:0] oWriteData,

	output oReadRequest,
	output oWriteRequest,
	input  iWriteAccept,
	input  iReadDataValid,

	input [D_WIDTH-1:0] iReadData
);

	READARB
	#(	
		.D_WIDTH(D_WIDTH),	
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),	
		.INTERFACE_MEM_WIDTH(INTERFACE_MEM_WIDTH),
		.NUM_LSU(NUM_LSU)
	)
	readarb_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		.iReadAddress(iReadAddress),
		.iReadRequest(iReadRequest),
		.oReadData(oReadData),
		.oReadDataValid(oReadDataValid),
		.oReadGrantNextCycle(oReadGrantNextCycle),
		.oReadAddress(oReadAddress),
		.oReadRequest(oReadRequest),
		.iReadDataValid(iReadDataValid),
		.oReadEnable(oReadEnable),
		.iReadData(iReadData)
	);

	WRITEARB
	#(	
		.D_WIDTH(D_WIDTH),	
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),	
		.INTERFACE_MEM_WIDTH(INTERFACE_MEM_WIDTH),
		.NUM_LSU(NUM_LSU)
	)
	writearb_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		.iWriteAddress(iWriteAddress),
		.iWriteEnable(iWriteEnable),
		.iWriteData(iWriteData),
		.iWriteRequest(iWriteRequest),
		.oWriteAccept(oWriteAccept),
		.oWriteGrantNextCycle(oWriteGrantNextCycle),
		.oWriteAddress(oWriteAddress),
		.oWriteEnable(oWriteEnable),
		.oWriteData(oWriteData),
		.oWriteRequest(oWriteRequest),
		.iWriteAccept(iWriteAccept)
	);
	
endmodule

module READARB
#
(	
	parameter D_WIDTH = 32,	
	parameter INTERFACE_ADDR_WIDTH = 32,	
	parameter INTERFACE_MEM_WIDTH = 32,
	parameter NUM_LSU = 1
)
(
	input iClk,
	input iReset,
	
	//input ports
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iReadAddress,

	input [NUM_LSU-1:0] iReadRequest,

	output [NUM_LSU*D_WIDTH-1:0] oReadData,
	output [NUM_LSU-1:0] oReadDataValid,

	output [NUM_LSU-1:0] oReadGrantNextCycle,
	
	//output port
	output [INTERFACE_ADDR_WIDTH-1:0] oReadAddress,

	output oReadRequest,
	input  iReadDataValid,
	output oReadEnable,

	input [D_WIDTH-1:0] iReadData
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
	
	localparam NUM_LSU_WIDTH = CLogB2(NUM_LSU-1);	

	wire [NUM_LSU-1:0] wGrant_unbuffered;
	wire [NUM_LSU-1:0] wGrant_buffered;	

	wire [NUM_LSU_WIDTH-1:0] wSelected_unbuffered;	
	wire [NUM_LSU_WIDTH-1:0] wSelected_buffered;	

	reg [NUM_LSU-1:0] rSameAddress;
	wire [NUM_LSU-1:0] wSameAddress;	

	integer i;
	always @(posedge iClk)
	begin
		if (iReset)
			begin
				rSameAddress <= 0;
			end
		else 
			begin
				rSameAddress <= wSameAddress;
			end
	end
	
	genvar gCurrPort;
	generate	
		if (NUM_LSU > 1)
			begin			

				for (gCurrPort=0; gCurrPort < NUM_LSU; gCurrPort = gCurrPort + 1)
					begin : check_same_addr
						assign wSameAddress[gCurrPort] = (oReadAddress == iReadAddress[(gCurrPort*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 -: INTERFACE_ADDR_WIDTH]);
					end	

				ARBITER_GEN_RR
				#(
						.NUM_PORTS(NUM_LSU),
						.NUM_PORTS_WIDTH(NUM_LSU_WIDTH)
				)
				arbiter_read_inst	
				(
					.iClk(iClk),
					.iReset(iReset),
					
					.iRequest(iReadRequest),
					.oGrant(wGrant_buffered),
					.oGrant_unbuffered(wGrant_unbuffered),
					.oSelected(wSelected_buffered),
					.oSelected_unbuffered(wSelected_unbuffered),
					
					.oActive(),
					.iPortBusy(|iReadRequest & !iReadDataValid)					
				);			

				assign oReadRequest = |iReadRequest;
				assign oReadAddress = iReadAddress[(wSelected_unbuffered*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 -: INTERFACE_ADDR_WIDTH];
				assign oReadData = {(NUM_LSU){iReadData}} & {(NUM_LSU*D_WIDTH){iReadDataValid}};				
				assign oReadGrantNextCycle = {(NUM_LSU){iReadDataValid}} & wSameAddress & {NUM_LSU{|wGrant_unbuffered}};					
				assign oReadEnable = |wGrant_unbuffered;

				`ifdef NATIVE_GM_INTERFACE
					assign oReadDataValid = {(NUM_LSU){iReadDataValid}} & rSameAddress & {NUM_LSU{|wGrant_buffered}};
				`else					
					assign oReadDataValid = {(NUM_LSU){iReadDataValid}} & wSameAddress & {NUM_LSU{|wGrant_unbuffered}};
				`endif				
			end
		else //if there is just one port then dont use the arbiter, just grant everything to port 0
			begin				
				assign oReadAddress = iReadAddress;
				assign oReadData = iReadData & {(D_WIDTH){iReadDataValid}};
				assign oReadDataValid = iReadDataValid;

				`ifdef NATIVE_GM_INTERFACE
					assign oReadGrantNextCycle = iReadRequest;
				`else
					assign oReadGrantNextCycle = iReadDataValid;
				`endif

				assign oReadRequest = iReadRequest;						
				assign oReadEnable = iReadRequest;
			end
	endgenerate	
endmodule

module WRITEARB
#
(	
	parameter D_WIDTH = 32,	
	parameter INTERFACE_ADDR_WIDTH = 32,	
	parameter INTERFACE_MEM_WIDTH = 32,
	parameter NUM_LSU = 1
)
(
	input iClk,
	input iReset,
	
	//input ports
	input [NUM_LSU*INTERFACE_ADDR_WIDTH-1:0] iWriteAddress,
	input [NUM_LSU*(INTERFACE_MEM_WIDTH / 8)-1:0] iWriteEnable,
	input [NUM_LSU*D_WIDTH-1:0] iWriteData,
	input [NUM_LSU-1:0] iWriteRequest,

	output [NUM_LSU-1:0] oWriteAccept,

	output [NUM_LSU-1:0] oWriteGrantNextCycle,

	
	//output port
	output [INTERFACE_ADDR_WIDTH-1:0] oWriteAddress,
	output [(INTERFACE_MEM_WIDTH / 8)-1:0] oWriteEnable,
	output [D_WIDTH-1:0] oWriteData,

	output oWriteRequest,
	input  iWriteAccept
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
	
	localparam NUM_LSU_WIDTH = CLogB2(NUM_LSU-1);	

	wire [NUM_LSU-1:0] wGrant_unbuffered;
	wire [NUM_LSU-1:0] wGrant_buffered;
	wire [NUM_LSU-1:0] wGrant_nonConflicting;

	wire [NUM_LSU_WIDTH-1:0] wSelected_unbuffered;	
	wire [NUM_LSU_WIDTH-1:0] wSelected_buffered;	

	wire [NUM_LSU*(INTERFACE_MEM_WIDTH / 8)-1:0] wWriteEnablesMasked;
	wire [NUM_LSU-1:0] wWriteEnablesMaskedRepacked[(INTERFACE_MEM_WIDTH / 8)-1:0];
	wire [NUM_LSU-1:0] wWriteDataRepacked[D_WIDTH-1:0];
	wire [(INTERFACE_MEM_WIDTH / 8)-1:0] wWriteEnablesOut;
	wire [D_WIDTH-1:0] wWriteDataOut;

	reg [NUM_LSU-1:0] rSameAddress;
	wire [NUM_LSU-1:0] wSameAddress;	

	function [NUM_LSU-1:0] FindBE;
		input [NUM_LSU*(INTERFACE_MEM_WIDTH / 8)-1:0] inputBE;
		integer i;
		reg [(INTERFACE_MEM_WIDTH / 8)-1:0] foundBE;
		reg [(INTERFACE_MEM_WIDTH / 8)-1:0] currBE;
		begin
			foundBE=0;
			FindBE=0;			

			for(i=0; i < NUM_LSU; i=i+1)
				begin
					currBE=inputBE[(i+1)*(INTERFACE_MEM_WIDTH / 8)-1-:(INTERFACE_MEM_WIDTH / 8)];
					if ( !( |(foundBE & currBE) ) )
						begin
							foundBE = foundBE | currBE;
							FindBE[i] = 1'b1;
						end
				end			
		end
	endfunction		
	
	always @(posedge iClk)
	begin
		if (iReset)
			begin				
				rSameAddress <= 0;
			end
		else 
			begin
				rSameAddress <= wSameAddress;
			end	
	end

	genvar gCurrPort;
	genvar gCurrByte;	
	genvar gCurrBit;
	generate	
		if (NUM_LSU > 1)
			begin			

				for (gCurrPort=0; gCurrPort < NUM_LSU; gCurrPort = gCurrPort + 1)
					begin : check_same_addr
						assign wSameAddress[gCurrPort] = (oWriteAddress == iWriteAddress[(gCurrPort*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 -: INTERFACE_ADDR_WIDTH]);
						assign wWriteEnablesMasked[(gCurrPort*(INTERFACE_MEM_WIDTH / 8))+(INTERFACE_MEM_WIDTH / 8)-1 -: (INTERFACE_MEM_WIDTH / 8)] = {(INTERFACE_MEM_WIDTH / 8){wSameAddress[gCurrPort]}} & iWriteEnable[(gCurrPort*(INTERFACE_MEM_WIDTH / 8))+(INTERFACE_MEM_WIDTH / 8)-1 -: (INTERFACE_MEM_WIDTH / 8)] & {(INTERFACE_MEM_WIDTH / 8){iWriteRequest[gCurrPort]}};

						for (gCurrByte=0; gCurrByte < (INTERFACE_MEM_WIDTH / 8); gCurrByte = gCurrByte +1)						
							begin : repack_byte
								assign wWriteEnablesMaskedRepacked[gCurrByte][gCurrPort] = wWriteEnablesMasked[gCurrPort*(INTERFACE_MEM_WIDTH / 8) + gCurrByte] & wGrant_nonConflicting[gCurrPort];
								assign wWriteEnablesOut[gCurrByte] = |wWriteEnablesMaskedRepacked[gCurrByte];				

								for (gCurrBit=0; gCurrBit < 8; gCurrBit = gCurrBit +1)						
									begin: repack_bit
										assign wWriteDataRepacked[(gCurrByte*8)+gCurrBit][gCurrPort] = iWriteData[(gCurrPort*D_WIDTH)+(gCurrByte*8)+gCurrBit] & wGrant_nonConflicting[gCurrPort];
										assign wWriteDataOut[(gCurrByte*8)+gCurrBit] = |wWriteDataRepacked[(gCurrByte*8)+gCurrBit];
									end
							end
					end					

				ARBITER_GEN_RR
				#(
						.NUM_PORTS(NUM_LSU),
						.NUM_PORTS_WIDTH(NUM_LSU_WIDTH)
				)
				arbiter_read_inst	
				(
					.iClk(iClk),
					.iReset(iReset),
					
					.iRequest(iWriteRequest),
					.oGrant(wGrant_buffered),
					.oGrant_unbuffered(wGrant_unbuffered),
					.oSelected(wSelected_buffered),
					.oSelected_unbuffered(wSelected_unbuffered),
					
					.oActive(),
					.iPortBusy(|iWriteRequest & !iWriteAccept)					
				);			

				assign oWriteRequest = |iWriteRequest;
				assign oWriteAddress = iWriteAddress[(wSelected_unbuffered*INTERFACE_ADDR_WIDTH)+INTERFACE_ADDR_WIDTH-1 -: INTERFACE_ADDR_WIDTH];
				assign oWriteData = wWriteDataOut;
				assign oWriteEnable = wWriteEnablesOut;

				assign oWriteAccept = {(NUM_LSU){iWriteAccept}} & wGrant_nonConflicting; 
				assign oWriteGrantNextCycle = {(NUM_LSU){iWriteAccept}} & wGrant_nonConflicting;				

				assign wGrant_nonConflicting = FindBE(wWriteEnablesMasked) & wSameAddress & iWriteRequest;
			end
		else //if there is just one port then dont use the arbiter, just grant everything to port 0
			begin				
				assign oWriteAddress = iWriteAddress;
				assign oWriteData = iWriteData;
				assign oWriteEnable = iWriteEnable;
				assign oWriteAccept = iWriteAccept;
				`ifdef NATIVE_GM_INTERFACE
					assign oWriteGrantNextCycle = 1'b1;					
				`else
					assign oWriteGrantNextCycle = iWriteAccept;				
				`endif

				assign oWriteRequest = iWriteRequest;				
			end
	endgenerate	
endmodule
