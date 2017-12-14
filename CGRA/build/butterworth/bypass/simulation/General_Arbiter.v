module General_ARBITER
#
(	
	parameter D_WIDTH = 32,	
	parameter GM_ADDR_WIDTH = 32,	
	parameter GM_MEM_WIDTH = 32,
	parameter NUM_GLOBAL_DMEM = 1,
	parameter NUM_PERIPHERALS = 1,
	parameter RANGE_PERIPHERALS = "9.0",
	parameter STRING_SIZE = 3
)
(
	input iClk,
	input iReset,
	
	//output oLastCycle,

	//input ports
	input [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] iGen_Arb_WriteAddress,
	input [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] iGen_Arb_ReadAddress,
	input [NUM_GLOBAL_DMEM*(GM_MEM_WIDTH / 8)-1:0] iGen_Arb_WriteEnable,
	input [NUM_GLOBAL_DMEM*D_WIDTH-1:0] iGen_Arb_WriteData,
	input [NUM_GLOBAL_DMEM-1:0] iGen_Arb_ReadRequest,
	input [NUM_GLOBAL_DMEM-1:0] iGen_Arb_WriteRequest,
	

	output wor [NUM_GLOBAL_DMEM*D_WIDTH-1:0] oGen_Arb_ReadData,
	output wor [NUM_GLOBAL_DMEM-1:0] oGen_Arb_ReadDataValid,
	output wor [NUM_GLOBAL_DMEM-1:0] oGen_Arb_WriteAccept,

	output wor [NUM_GLOBAL_DMEM-1:0] oGen_Arb_ReadGrantNextCycle,
	output wor [NUM_GLOBAL_DMEM-1:0] oGen_Arb_WriteGrantNextCycle,
	
	//output port
	output [NUM_PERIPHERALS*GM_ADDR_WIDTH-1:0] oGen_Arb_WriteAddress,
	output [NUM_PERIPHERALS*GM_ADDR_WIDTH-1:0] oGen_Arb_ReadAddress,
	output [NUM_PERIPHERALS*(GM_MEM_WIDTH / 8)-1:0] oGen_Arb_WriteEnable,
	output [NUM_PERIPHERALS-1:0] oGen_Arb_ReadEnable,
	output [NUM_PERIPHERALS*D_WIDTH-1:0] oGen_Arb_WriteData,

	output [NUM_PERIPHERALS-1:0] oGen_Arb_ReadRequest,
	output [NUM_PERIPHERALS-1:0] oGen_Arb_WriteRequest,
	input  [NUM_PERIPHERALS-1:0] iGen_Arb_WriteAccept,
	input  [NUM_PERIPHERALS-1:0] iGen_Arb_ReadDataValid,

	input [NUM_PERIPHERALS*D_WIDTH-1:0] iGen_Arb_ReadData

); 

	//Wires between isolator and arbiter
	wire [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] wWriteAddress[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] wReadAddress[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM*(GM_MEM_WIDTH / 8)-1:0] wWriteEnable[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM*D_WIDTH-1:0] wWriteData[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM-1:0] wReadRequest[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM-1:0] wWriteRequest[NUM_PERIPHERALS-1:0];
	wire wReadEnable[NUM_PERIPHERALS-1:0];	

	wire [NUM_GLOBAL_DMEM*D_WIDTH-1:0] wReadData[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM-1:0] wReadDataValid[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM-1:0] wWriteAccept[NUM_PERIPHERALS-1:0];

	wire [NUM_GLOBAL_DMEM-1:0] wReadGrantNextCycle[NUM_PERIPHERALS-1:0];
	wire [NUM_GLOBAL_DMEM-1:0] wWriteGrantNextCycle[NUM_PERIPHERALS-1:0];

	//Wires from arbiters to peripherals
	wire [GM_ADDR_WIDTH-1:0] wArb_WriteAddress[NUM_PERIPHERALS-1:0];
	wire [GM_ADDR_WIDTH-1:0] wArb_ReadAddress[NUM_PERIPHERALS-1:0];
	wire [(GM_MEM_WIDTH / 8)-1:0] wArb_WriteEnable[NUM_PERIPHERALS-1:0];
	wire [D_WIDTH-1:0] wArb_WriteData[NUM_PERIPHERALS-1:0];

	wire [D_WIDTH-1:0] wArb_ReadData[NUM_PERIPHERALS-1:0];

	wire wArb_ReadRequest[NUM_PERIPHERALS-1:0];
	wire wArb_WriteRequest[NUM_PERIPHERALS-1:0];
	wire wArb_ReadDataValid[NUM_PERIPHERALS-1:0];
	wire wArb_WriteAccept[NUM_PERIPHERALS-1:0];

	genvar gCurrPort;
	generate
		for (gCurrPort=0; gCurrPort < NUM_PERIPHERALS; gCurrPort = gCurrPort + 1)
			begin : Assign_wires
				//output port
				assign oGen_Arb_WriteAddress[(gCurrPort*GM_ADDR_WIDTH)+GM_ADDR_WIDTH-1 : gCurrPort*GM_ADDR_WIDTH] = wArb_WriteAddress[gCurrPort];
				assign oGen_Arb_ReadAddress[(gCurrPort*GM_ADDR_WIDTH)+GM_ADDR_WIDTH-1 : gCurrPort*GM_ADDR_WIDTH] = wArb_ReadAddress[gCurrPort];
				assign oGen_Arb_WriteEnable[(gCurrPort*(GM_MEM_WIDTH / 8))+(GM_MEM_WIDTH / 8)-1 : gCurrPort*(GM_MEM_WIDTH / 8)] = wArb_WriteEnable[gCurrPort];
				assign oGen_Arb_WriteData[(gCurrPort*D_WIDTH)+D_WIDTH-1 : gCurrPort*D_WIDTH]  = wArb_WriteData[gCurrPort];
				
				assign oGen_Arb_ReadRequest[gCurrPort] = wArb_ReadRequest[gCurrPort]; 
				assign oGen_Arb_WriteRequest[gCurrPort] = wArb_WriteRequest[gCurrPort];
				assign wArb_WriteAccept[gCurrPort] = iGen_Arb_WriteAccept[gCurrPort];
				assign wArb_ReadDataValid[gCurrPort] = iGen_Arb_ReadDataValid[gCurrPort];

				assign wArb_ReadData[gCurrPort] = iGen_Arb_ReadData[(gCurrPort*D_WIDTH)+D_WIDTH-1 : gCurrPort*D_WIDTH];

				//input port outputs WORs
				assign oGen_Arb_ReadData = wReadData[gCurrPort];
				assign oGen_Arb_ReadDataValid = wReadDataValid[gCurrPort];
				assign oGen_Arb_WriteAccept = wWriteAccept[gCurrPort];
				assign oGen_Arb_ReadGrantNextCycle = wReadGrantNextCycle[gCurrPort];
				assign oGen_Arb_WriteGrantNextCycle = wWriteGrantNextCycle[gCurrPort];
			end
	endgenerate

	genvar i;
	generate 
		for (i = 0; i < NUM_PERIPHERALS; i = i + 1) 
			begin : Peripheral_Arbiters
				Address_Isolator
				#(
					.INTERFACE_WIDTH(GM_MEM_WIDTH),
					.INTERFACE_ADDR_WIDTH(GM_ADDR_WIDTH),

					.RANGE_PERIPHERALS(RANGE_PERIPHERALS),
					.STRING_SIZE(STRING_SIZE),
					.NUM_PERIPHERALS(NUM_PERIPHERALS),
					.PERIPHERAL_NUM(i),
					
					.NUM_LSU(NUM_GLOBAL_DMEM)
				)
				Address_Isolator_Inst
				(
					//input port
					.iWriteAddress(iGen_Arb_WriteAddress),
					.iReadAddress(iGen_Arb_ReadAddress),
					.iWriteEnable(iGen_Arb_WriteEnable),
					.iWriteData(iGen_Arb_WriteData),
					.iReadRequest(iGen_Arb_ReadRequest),
					.iWriteRequest(iGen_Arb_WriteRequest),		
					.oReadData(),
					.oReadDataValid(),
					.oWriteAccept(),
					
					.oReadGrantNextCycle(),
					.oWriteGrantNextCycle(),					
				
					//output port
					.oWriteAddress(wWriteAddress[i]),
					.oReadAddress(wReadAddress[i]),
					.oWriteEnable(wWriteEnable[i]),
					.oWriteData(wWriteData[i]),
					.oReadRequest(wReadRequest[i]),
					.oWriteRequest(wWriteRequest[i]),		
					.iReadData(wReadData[i]),
					.iReadDataValid(wReadDataValid[i]),

					.iReadGrantNextCycle(wReadGrantNextCycle[i]),
					.iWriteGrantNextCycle(wWriteGrantNextCycle[i]),


					.iWriteAccept(wWriteAccept[i])			
				);

				ARBITER
				#(
					.D_WIDTH(D_WIDTH),	
					.INTERFACE_ADDR_WIDTH(GM_ADDR_WIDTH),	
					.INTERFACE_MEM_WIDTH(GM_MEM_WIDTH),
					.NUM_LSU(NUM_GLOBAL_DMEM)		
				)
				ARBITER_Inst
				(
					.iClk(iClk),
					.iReset(iReset),

					//input ports					
					.oReadGrantNextCycle(wReadGrantNextCycle[i]),
					.oWriteGrantNextCycle(wWriteGrantNextCycle[i]),
								
					.iWriteAddress(wWriteAddress[i]),
					.iReadAddress(wReadAddress[i]),
					.iWriteEnable(wWriteEnable[i]),
					.oReadEnable(oGen_Arb_ReadEnable[i]),
					.iWriteData(wWriteData[i]),
					.iReadRequest(wReadRequest[i]),
					.iWriteRequest(wWriteRequest[i]),		
					.oReadData(wReadData[i]),
					.oReadDataValid(wReadDataValid[i]),
					.oWriteAccept(wWriteAccept[i]),
					
					//output port to GM arbiter interface
					.oReadRequest(wArb_ReadRequest[i]),
					.oWriteRequest(wArb_WriteRequest[i]),

					.iWriteAccept(wArb_WriteAccept[i]),
					.iReadDataValid(wArb_ReadDataValid[i]),

					.oWriteAddress(wArb_WriteAddress[i]),
					.oReadAddress(wArb_ReadAddress[i]),
					.oWriteEnable(wArb_WriteEnable[i]),
					.oWriteData(wArb_WriteData[i]),
					.iReadData(wArb_ReadData[i])		
				);
			end
	endgenerate

endmodule
