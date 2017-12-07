`timescale 1 ns / 1 ns

`include "config.vh"

module CGRA_Compute_Wrapper
#
(  //parameters that can be externally configured
	parameter LOADER_OFFSET = 32'hC0000,

	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter INTERFACE_BLOCK_WIDTH = 5,
	
	parameter D_WIDTH = 32,	
	parameter I_WIDTH = 12,
	parameter I_IMM_WIDTH = 33,
	parameter I_DECODED_WIDTH = 16,
		
	parameter LM_ADDR_WIDTH = 16,
	parameter GM_ADDR_WIDTH = 32,	
	parameter IM_ADDR_WIDTH = 16,
	
	parameter IM_MEM_ADDR_WIDTH = 8,	
	parameter LM_MEM_ADDR_WIDTH = 8,	
	
	parameter LM_MEM_WIDTH = 32,
	parameter GM_MEM_WIDTH = 32,
	
	parameter NUM_ID = 6,
	parameter NUM_IMM = 3,
	parameter NUM_LOCAL_DMEM = 1,
	parameter NUM_GLOBAL_DMEM = 1,
	parameter NUM_PERIPHERALS = 1
)
(
	//inputs and outputs
	input iClk,
	input iReset,
	output oReset,
	output oHalted,
	output oConfigDone,

	output debug_0,
	output debug_1,

	//WIP TO DO CONNECT OUTSIDE OF WRAPPER
	//inputs and outputs for peripherals
	

	//DTL interface for control by the host (SLAVE)
	output oDTL_Loader_CommandAccept,
	output oDTL_Loader_WriteAccept,
	output oDTL_Loader_ReadValid,
	output oDTL_Loader_ReadLast,
	output [INTERFACE_WIDTH-1:0] oDTL_Loader_ReadData,
		
	input iDTL_Loader_CommandValid,
	input iDTL_Loader_WriteValid,		
	input iDTL_Loader_CommandReadWrite,
	input [(INTERFACE_WIDTH/8)-1:0] iDTL_Loader_WriteEnable,
	input [INTERFACE_ADDR_WIDTH-1:0] iDTL_Loader_Address,	
	input [INTERFACE_WIDTH-1:0] iDTL_Loader_WriteData,
		
	input [INTERFACE_BLOCK_WIDTH-1:0] iDTL_Loader_BlockSize,
	input iDTL_Loader_WriteLast,
	input iDTL_Loader_ReadAccept,				
		
	//DTL interface for the shared memory with the host (MASTER)
	input iDTL_SMEM_CommandAccept,
	input iDTL_SMEM_WriteAccept,
	input iDTL_SMEM_ReadValid,
	input iDTL_SMEM_ReadLast,
	input [INTERFACE_WIDTH-1:0] iDTL_SMEM_ReadData,
			
	output oDTL_SMEM_CommandValid,
	output oDTL_SMEM_WriteValid,		
	output oDTL_SMEM_CommandReadWrite,
	output [(INTERFACE_WIDTH/8)-1:0] oDTL_SMEM_WriteEnable,
	output [INTERFACE_ADDR_WIDTH-1:0] oDTL_SMEM_Address,	
	output [INTERFACE_WIDTH-1:0] oDTL_SMEM_WriteData,
		
	output [INTERFACE_BLOCK_WIDTH-1:0] oDTL_SMEM_BlockSize,
	output oDTL_SMEM_WriteLast,
	output oDTL_SMEM_ReadAccept,	
	
	`ifndef NATIVE_GM_INTERFACE			
		//DTL interface for the global memory (MASTER)
		//I/O DTL master interface
		input iDTL_DMEM_CommandAccept,
		input iDTL_DMEM_WriteAccept,
		input iDTL_DMEM_ReadValid,
		input iDTL_DMEM_ReadLast,
		input [INTERFACE_WIDTH-1:0] iDTL_DMEM_ReadData,
			
		output oDTL_DMEM_CommandValid,
		output oDTL_DMEM_WriteValid,	
		output oDTL_DMEM_CommandReadWrite,
		output [(INTERFACE_WIDTH/8)-1:0] oDTL_DMEM_WriteEnable,	
		output [INTERFACE_ADDR_WIDTH-1:0] oDTL_DMEM_Address,
		output [INTERFACE_WIDTH-1:0] oDTL_DMEM_WriteData,
		
		output [INTERFACE_BLOCK_WIDTH-1:0] oDTL_DMEM_BlockSize,
		output oDTL_DMEM_WriteLast,
		output oDTL_DMEM_ReadAccept,		
	`else
		output [GM_ADDR_WIDTH-1:0] oGM_WriteAddress,
		output [GM_ADDR_WIDTH-1:0] oGM_ReadAddress,
		output [(GM_MEM_WIDTH / 8)-1:0] oGM_WriteEnable,
		output oGM_ReadEnable,
		output [D_WIDTH-1:0] oGM_WriteData,
		input [D_WIDTH-1:0] iGM_ReadData,
	`endif

	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
		//DTL interface for the state memory (MASTER)
		input iDTL_STATE_CommandAccept,
		input iDTL_STATE_WriteAccept,
		input iDTL_STATE_ReadValid,
		input iDTL_STATE_ReadLast,
		input [INTERFACE_WIDTH-1:0] iDTL_STATE_ReadData,
			
		output oDTL_STATE_CommandValid,
		output oDTL_STATE_WriteValid,	
		output oDTL_STATE_CommandReadWrite,
		output [(INTERFACE_WIDTH/8)-1:0] oDTL_STATE_WriteEnable,	
		output [INTERFACE_ADDR_WIDTH-1:0] oDTL_STATE_Address,
		output [INTERFACE_WIDTH-1:0] oDTL_STATE_WriteData,
		
		output [INTERFACE_BLOCK_WIDTH-1:0] oDTL_STATE_BlockSize,
		output oDTL_STATE_WriteLast,
		output oDTL_STATE_ReadAccept,			
	`endif	

	//local memory interfaces
	output [NUM_LOCAL_DMEM*(LM_MEM_WIDTH / 8)-1:0] oLM_WriteEnable,
	output [NUM_LOCAL_DMEM-1:0] oLM_ReadEnable,
	output [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] oLM_WriteAddress,
	output [NUM_LOCAL_DMEM*D_WIDTH-1:0] oLM_WriteData,
	output [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] oLM_ReadAddress,
	input  [NUM_LOCAL_DMEM*D_WIDTH-1:0] iLM_ReadData,	
	
	//instruction memory interfaces
	output [(NUM_IMM+NUM_ID)*IM_ADDR_WIDTH-1:0] oIM_ReadAddress,
	output [(NUM_IMM+NUM_ID)-1:0] oIM_ReadEnable,
	input  [NUM_IMM*I_IMM_WIDTH+NUM_ID*I_WIDTH-1:0] iIM_ReadData,
	output [NUM_IMM+NUM_ID-1:0] oIM_WriteEnable,
	output [IM_MEM_ADDR_WIDTH-1:0] oIM_WriteAddress,
	output [I_WIDTH-1:0] oIM_WriteData,
	output [I_IMM_WIDTH-1:0] oIM_WriteData_IMM	
	
);

	localparam INTERFACE_NUM_ENABLES = (INTERFACE_WIDTH / 8);

	wire wConfigEnable;
	wire wConfigDataIn;
	wire wReset;
	wire wResetFromLoader;
	
	assign oReset = wReset;

	wire wLoader_WriteReq;
	wire [INTERFACE_WIDTH-1:0] wLoader_WriteData;
	
	wire wLoader_ReadReq;
	wire [INTERFACE_ADDR_WIDTH-1:0] wLoader_ReadAddress;
	wire [INTERFACE_WIDTH-1:0] wLoader_ReadData;
	wire wLoader_ReadDataValid;	
			
	wire [NUM_GLOBAL_DMEM*(GM_MEM_WIDTH / 8)-1:0] wGM_WriteEnable_packed;
	wire [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] wGM_WriteAddress_packed;
	wire [NUM_GLOBAL_DMEM*D_WIDTH-1:0] wGM_WriteData_packed;
	wire [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] wGM_ReadAddress_packed;
	wire [NUM_GLOBAL_DMEM*D_WIDTH-1:0] wGM_ReadData_packed;
	wire [NUM_GLOBAL_DMEM-1:0] wGM_ReadDataValid_packed;
	wire [NUM_GLOBAL_DMEM-1:0] wGM_ReadRequest_packed;
	wire [NUM_GLOBAL_DMEM-1:0] wGM_WriteRequest_packed;
	wire [NUM_GLOBAL_DMEM-1:0] wGM_WriteAccept_packed;	

	wire [NUM_GLOBAL_DMEM-1:0] wGM_ReadGrantNextCycle_packed;
	wire [NUM_GLOBAL_DMEM-1:0] wGM_WriteGrantNextCycle_packed;

	//bus Wires from arbiters to peripherals
	wire [NUM_PERIPHERALS*GM_ADDR_WIDTH-1:0] wGen_Arb_WriteAddressP;
	wire [NUM_PERIPHERALS*GM_ADDR_WIDTH-1:0] wGen_Arb_ReadAddressP;
	wire [NUM_PERIPHERALS*(GM_MEM_WIDTH / 8)-1:0] wGen_Arb_WriteEnableP;
	wire [NUM_PERIPHERALS-1:0] wGen_Arb_ReadEnableP;
	wire [NUM_PERIPHERALS*D_WIDTH-1:0] wGen_Arb_WriteDataP;

	wire [NUM_PERIPHERALS*D_WIDTH-1:0] wGen_Arb_ReadDataP;

	wire [NUM_PERIPHERALS-1:0] wGen_Arb_ReadRequestP;
	wire [NUM_PERIPHERALS-1:0] wGen_Arb_WriteRequestP;
	wire [NUM_PERIPHERALS-1:0] wGen_Arb_ReadDataValidP;
	wire [NUM_PERIPHERALS-1:0] wGen_Arb_WriteAcceptP;
	
	//unpacked
	wire [GM_ADDR_WIDTH-1:0] wGen_Arb_WriteAddress [NUM_PERIPHERALS-1:0];
	wire [GM_ADDR_WIDTH-1:0] wGen_Arb_ReadAddress [NUM_PERIPHERALS-1:0];
	wire [(GM_MEM_WIDTH / 8)-1:0] wGen_Arb_WriteEnable [NUM_PERIPHERALS-1:0];
	wire wGen_Arb_ReadEnable [NUM_PERIPHERALS-1:0];
	wire [D_WIDTH-1:0] wGen_Arb_WriteData [NUM_PERIPHERALS-1:0];

	wire [D_WIDTH-1:0] wGen_Arb_ReadData [NUM_PERIPHERALS-1:0];

	wire wGen_Arb_ReadRequest [NUM_PERIPHERALS-1:0];
	wire wGen_Arb_WriteRequest [NUM_PERIPHERALS-1:0];
	wire wGen_Arb_ReadDataValid [NUM_PERIPHERALS-1:0];
	wire wGen_Arb_WriteAccept [NUM_PERIPHERALS-1:0];

	genvar k;
	generate
		for (k=0; k < NUM_PERIPHERALS; k = k + 1)
			begin : Assign_wires
				assign wGen_Arb_WriteAddress[k] = wGen_Arb_WriteAddressP[(k*GM_ADDR_WIDTH)+GM_ADDR_WIDTH-1 : k*GM_ADDR_WIDTH];
				assign wGen_Arb_ReadAddress[k] = wGen_Arb_ReadAddressP[(k*GM_ADDR_WIDTH)+GM_ADDR_WIDTH-1 : k*GM_ADDR_WIDTH];
				assign wGen_Arb_WriteEnable[k] = wGen_Arb_WriteEnableP[(k*(GM_MEM_WIDTH / 8))+(GM_MEM_WIDTH / 8)-1 : k*(GM_MEM_WIDTH / 8)];

				assign wGen_Arb_ReadEnable[k] = wGen_Arb_ReadEnableP[k];

				assign wGen_Arb_WriteData[k] = wGen_Arb_WriteDataP[(k*D_WIDTH)+D_WIDTH-1 : k*D_WIDTH];
				assign wGen_Arb_ReadDataP[(k*D_WIDTH)+D_WIDTH-1 : k*D_WIDTH] = wGen_Arb_ReadData[k];
				
				assign wGen_Arb_ReadRequest[k] = wGen_Arb_ReadRequestP[k] ; 
				assign wGen_Arb_WriteRequest[k] = wGen_Arb_WriteRequestP[k];
				assign wGen_Arb_WriteAcceptP[k] = wGen_Arb_WriteAccept[k];
				assign wGen_Arb_ReadDataValidP[k] = wGen_Arb_ReadDataValid[k];			
			end
	endgenerate
	
	wire wWriteValid;
	wire [INTERFACE_ADDR_WIDTH-1:0] wAddress;
	reg [INTERFACE_WIDTH-1:0] wReadData; //becomes a wire during synthesis

	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
		wire wStateDataOut;
		wire wStateDataIn;	
		wire wStateSwitchHalt;
		wire wStateShift;
		wire wStateNewIn;
		wire wStateOldOut;
		
		wire wState_ReadRequest;
		wire wState_WriteRequest;
		wire [INTERFACE_ADDR_WIDTH-1:0] wState_Address;
		wire [INTERFACE_WIDTH-1:0] wState_WriteData;
		wire [INTERFACE_WIDTH-1:0] wState_ReadData;		
				
		wire wState_ReadDataValid;
		wire wState_WriteAccept;

		reg [INTERFACE_WIDTH-1:0] rStateRegs [2:0];				
	`endif	
	
	wire [(NUM_IMM+NUM_ID)-1:0] wIM_ReadEnable;
	wire wStateControlBusy;	
	wire wStall;	
	reg rCGRA_Reset;

	assign oIM_ReadEnable = wIM_ReadEnable | {(NUM_IMM+NUM_ID){wReset & oConfigDone}};

	`ifdef INCLUDE_PERF_COUNTERS
		reg [INTERFACE_WIDTH-1:0] rCycleCounter;
		reg [INTERFACE_WIDTH-1:0] rStallCounter;

		always @(posedge iClk)
			begin
				if (!wReset & !oHalted)
					rCycleCounter <= rCycleCounter + 1'd1;

				if (!wReset & !oHalted & wStall)
					rStallCounter <= rStallCounter + 1'd1;

				if (wReset)
					begin
						rCycleCounter <= 0;
						rStallCounter <= 0;
					end
			end
	`endif
	
	assign wLoader_WriteReq = wWriteValid & (wAddress == LOADER_OFFSET);
	assign wReset = wResetFromLoader | rCGRA_Reset;
	
	`ifdef INCLUDE_STATE_CONTROL
		always @(wAddress or wStall or oReset or oHalted or oConfigDone or wStateControlBusy)
	`else
		always @(wAddress or wStall or oReset or oHalted or oConfigDone)
	`endif
	begin
		case (wAddress)	
			0+LOADER_OFFSET: 
				begin
					`ifdef INCLUDE_STATE_CONTROL
						wReadData = {{(INTERFACE_WIDTH-5){1'b0}},wStateControlBusy,wStall,oReset,oHalted,oConfigDone};
					`else
						wReadData = {{(INTERFACE_WIDTH-5){1'b0}},1'b0,wStall,oReset,oHalted,oConfigDone};
					`endif			
			   	end
			`ifdef INCLUDE_PERF_COUNTERS
				4+LOADER_OFFSET:
					begin
						wReadData = rCycleCounter;						
					end
				8+LOADER_OFFSET:
					begin
						wReadData = rStallCounter;						
					end
			`endif
			default:
			 	begin
			 		wReadData = {(INTERFACE_WIDTH){1'b0}};
			 	end
		endcase
	end

	always @(posedge iClk)
	begin
		if (iReset)
			begin
				rCGRA_Reset <= 1'b1;
				`ifdef INCLUDE_STATE_CONTROL
					rStateRegs[0] <= 32'b0;
					rStateRegs[1] <= 32'b0;
					rStateRegs[2] <= 32'b0;
				`endif				
			end
			
		if (wAddress != LOADER_OFFSET & wWriteValid)
			begin
				if (wAddress == 4+LOADER_OFFSET) 
					begin
						rCGRA_Reset <= wLoader_WriteData[0];
					end	

				`ifdef INCLUDE_STATE_CONTROL
					if (wAddress == 8+LOADER_OFFSET)
						begin
							rStateRegs[0] <= wLoader_WriteData;
						end	
					
					if (wAddress == 12+LOADER_OFFSET)
						begin
							rStateRegs[1] <= wLoader_WriteData;
						end	

					if (wAddress == 16+LOADER_OFFSET)
						begin
							rStateRegs[2] <= wLoader_WriteData;
						end	

				`endif					
			end
	end	
	
	LOADER
	#(
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
		
		.I_WIDTH(I_WIDTH),
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH),	
		.IM_MEM_ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		
		.NUM_ID(NUM_ID),
		.NUM_IMM(NUM_IMM)	
	)
	LOADER_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		.oReset(wResetFromLoader),
		.oConfigDone(oConfigDone),

		//loader interface (to outside world)
		.iLoaderWriteReq(wLoader_WriteReq),
		.oLoaderReadReq(wLoader_ReadReq),
		.iLoaderWriteData(wLoader_WriteData),
		.oLoaderReadAddress(wLoader_ReadAddress),
		.iLoaderReadData(wLoader_ReadData),
		.iLoaderReadDataValid(wLoader_ReadDataValid),
		
		//interfaces to instruction memories
		.oIM_WriteEnable(oIM_WriteEnable),
		.oIM_WriteAddress(oIM_WriteAddress),
		.oIM_WriteData(oIM_WriteData),
		.oIM_WriteData_IMM(oIM_WriteData_IMM),	
		
		//configuration scan-chain interface
		.oConfigEnable(wConfigEnable),
		.oConfigDataIn(wConfigDataIn)				
	);

	assign debug_0 = wConfigEnable;
	assign debug_1 = wConfigDataIn;
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				

		STATE_CONTROLLER 
		#(
			.INTERFACE_WIDTH(INTERFACE_WIDTH),
			.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),			
			.STATE_BITS(3328)
		)
		SC_inst
		(
			.iClk(iClk),
			.iReset(iReset),
			.iStall(wStall),
			.oBusy(wStateControlBusy),
			
			.iReadAddress(rStateRegs[1]),
			.iWriteAddress(rStateRegs[2]),			
			
			//SC control signals
			.iStateReadRequest(rStateRegs[0][0]),
			.iStateWriteRequest(rStateRegs[0][1]),
			.iStateSwapRequest(rStateRegs[0][2]),	
			
			.iDisableShiftIn(rStateRegs[0][3]),
			.iDisableShiftOut(rStateRegs[0][4]),
			.iDisableExec(rStateRegs[0][5]),
	
			//control signals for the state scan chain	
			.oStateSwitchHalt(wStateSwitchHalt),					
			.iStateDataOut(wStateDataOut),
			.oStateDataIn(wStateDataIn),			
			.oStateShift(wStateShift),
			.oStateNewIn(wStateNewIn),
			.oStateOldOut(wStateOldOut),

			//memory control signals
			.oStateMemReadRequest(wState_ReadRequest),
			.oStateMemWriteRequest(wState_WriteRequest),
			.oStateMemAddress(wState_Address),
			.oStateMemWriteData(wState_WriteData),
			.iStateMemReadData(wState_ReadData),
			.iWriteAccept(wState_WriteAccept),
			.iReadValid(wState_ReadDataValid)							
		);	
	`endif

	CGRA_Compute
	#(
		.D_WIDTH(D_WIDTH),	
		.I_WIDTH(I_WIDTH),
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
	
		.LM_ADDR_WIDTH(LM_ADDR_WIDTH),
		.GM_ADDR_WIDTH(GM_ADDR_WIDTH),	
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH),

		.IM_MEM_ADDR_WIDTH(IM_MEM_ADDR_WIDTH),	
		.LM_MEM_ADDR_WIDTH(LM_MEM_ADDR_WIDTH),		

		.LM_MEM_WIDTH(LM_MEM_WIDTH),
		.GM_MEM_WIDTH(GM_MEM_WIDTH),
		
		.NUM_ID(NUM_ID),
		.NUM_LOCAL_DMEM(NUM_LOCAL_DMEM),
		.NUM_GLOBAL_DMEM(NUM_GLOBAL_DMEM)		
	)
	CGRA_Compute_inst
	(
		.iClk(iClk),
		.iReset(wReset),
		.oHalted(oHalted),
		.oStall(wStall),
			
		.iConfigEnable(wConfigEnable),
		.iConfigDataIn(wConfigDataIn),
		.oConfigDataOut(),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled						
			.oStateDataOut(wStateDataOut),
			.iStateDataIn(wStateDataIn),		
			.iStateSwitchHalt(wStateSwitchHalt),			
			.iStateShift(wStateShift),
			.iStateNewIn(wStateNewIn),
			.iStateOldOut(wStateOldOut),		
		`endif		
		
		//global memory wires
		.oGM_WriteEnable(wGM_WriteEnable_packed),
		.oGM_WriteAddress(wGM_WriteAddress_packed),
		.oGM_WriteData(wGM_WriteData_packed),
		.oGM_ReadAddress(wGM_ReadAddress_packed),
		.iGM_ReadData(wGM_ReadData_packed),	
		.iGM_ReadDataValid(wGM_ReadDataValid_packed),
		.oGM_ReadRequest(wGM_ReadRequest_packed),	 
		.oGM_WriteRequest(wGM_WriteRequest_packed), 
		.iGM_WriteAccept(wGM_WriteAccept_packed),	
		//`ifdef NATIVE_GM_INTERFACE
			.iGM_ReadGrantNextCycle(wGM_ReadGrantNextCycle_packed),
			.iGM_WriteGrantNextCycle(wGM_WriteGrantNextCycle_packed),
		//`endif			
		
		//local memory wires
		.oLM_WriteEnable(oLM_WriteEnable),
		.oLM_ReadEnable(oLM_ReadEnable),
		.oLM_WriteAddress(oLM_WriteAddress),
		.oLM_WriteData(oLM_WriteData),
		.oLM_ReadAddress(oLM_ReadAddress),
		.iLM_ReadData(iLM_ReadData),
		
		//instruction memory wires
		.oIM_ReadAddress(oIM_ReadAddress),
		.oIM_ReadEnable(wIM_ReadEnable),
		.iIM_ReadData(iIM_ReadData)		
	);
			
	//DTL slave for control	
	DTL_SlaveInterface
	#(			
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH)		
	)
	DTL_LOADER_SLAVE_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.iDTL_CommandValid(iDTL_Loader_CommandValid),
		.oDTL_CommandAccept(oDTL_Loader_CommandAccept),
		.iDTL_Address(iDTL_Loader_Address),
		.iDTL_CommandReadWrite(iDTL_Loader_CommandReadWrite),
		.iDTL_BlockSize(iDTL_Loader_BlockSize),

		.oDTL_ReadValid(oDTL_Loader_ReadValid),
		.oDTL_ReadLast(oDTL_Loader_ReadLast),	
		.iDTL_ReadAccept(iDTL_Loader_ReadAccept),
		.oDTL_ReadData(oDTL_Loader_ReadData),
		
		.iDTL_WriteValid(iDTL_Loader_WriteValid),		
		.iDTL_WriteLast(iDTL_Loader_WriteLast),
		.oDTL_WriteAccept(oDTL_Loader_WriteAccept),	
		.iDTL_WriteEnable(iDTL_Loader_WriteEnable),	
		.iDTL_WriteData(iDTL_Loader_WriteData),
		
		.oWriteValid(wWriteValid),
		.oWriteData(wLoader_WriteData),
		.oWriteEnable(),
		.oAddress(wAddress),
		.iReadData(wReadData)
	);		
	
	//DTL master for accessing the shared memory
	DTL_MasterInterface
	#(
		.D_WIDTH(INTERFACE_WIDTH),	
		.ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
		.MEM_WIDTH(INTERFACE_WIDTH),	
		
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH)
	)
	DTL_SMEM_MASTER_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.iReadRequest(wLoader_ReadReq),
		.iWriteRequest(1'b0),
		
		.iWriteAddress({(INTERFACE_ADDR_WIDTH){1'b0}}),
		.iReadAddress(wLoader_ReadAddress),
		.iWriteEnable({(INTERFACE_WIDTH/8){1'b0}}),
		.iWriteData({(INTERFACE_WIDTH){1'b0}}),
		
		.oReadDataValid(wLoader_ReadDataValid),
		.oWriteAccept(),
		.oReadData(wLoader_ReadData),
		
		.iDTL_CommandAccept(iDTL_SMEM_CommandAccept),
		.iDTL_WriteAccept(iDTL_SMEM_WriteAccept),
		.iDTL_ReadValid(iDTL_SMEM_ReadValid),
		.iDTL_ReadLast(iDTL_SMEM_ReadLast),
		.iDTL_ReadData(iDTL_SMEM_ReadData),
			
		.oDTL_CommandValid(oDTL_SMEM_CommandValid),
		.oDTL_WriteValid(oDTL_SMEM_WriteValid),		
		.oDTL_CommandReadWrite(oDTL_SMEM_CommandReadWrite),
		.oDTL_WriteEnable(oDTL_SMEM_WriteEnable),
		.oDTL_Address(oDTL_SMEM_Address),	
		.oDTL_WriteData(oDTL_SMEM_WriteData),
		
		.oDTL_BlockSize(oDTL_SMEM_BlockSize),
		.oDTL_WriteLast(oDTL_SMEM_WriteLast),
		.oDTL_ReadAccept(oDTL_SMEM_ReadAccept)
	);

	General_ARBITER
	#
	(	
		.D_WIDTH(D_WIDTH),	
		.GM_ADDR_WIDTH(GM_ADDR_WIDTH),	
		.GM_MEM_WIDTH(GM_MEM_WIDTH),
		.NUM_GLOBAL_DMEM(NUM_GLOBAL_DMEM),
		.NUM_PERIPHERALS(1),
		.RANGE_PERIPHERALS("32767.0"),
		.STRING_SIZE(7)
	)
	General_ARBITER_inst
	(
		.iClk(iClk),
		.iReset(iReset),
				
		//input ports
		.iGen_Arb_WriteAddress(wGM_WriteAddress_packed),
		.iGen_Arb_ReadAddress(wGM_ReadAddress_packed),
		.iGen_Arb_WriteEnable(wGM_WriteEnable_packed),
		.iGen_Arb_WriteData(wGM_WriteData_packed),
		.iGen_Arb_ReadRequest(wGM_ReadRequest_packed),
		.iGen_Arb_WriteRequest(wGM_WriteRequest_packed),		

		.oGen_Arb_ReadData(wGM_ReadData_packed),
		.oGen_Arb_ReadDataValid(wGM_ReadDataValid_packed),
		.oGen_Arb_WriteAccept(wGM_WriteAccept_packed),
		.oGen_Arb_ReadGrantNextCycle(wGM_ReadGrantNextCycle_packed),
		.oGen_Arb_WriteGrantNextCycle(wGM_WriteGrantNextCycle_packed),
		
		//output port to master interface			
		.oGen_Arb_WriteAddress(wGen_Arb_WriteAddressP),
		.oGen_Arb_ReadAddress(wGen_Arb_ReadAddressP),
		.oGen_Arb_WriteEnable(wGen_Arb_WriteEnableP),
		.oGen_Arb_ReadEnable(wGen_Arb_ReadEnableP),
		.oGen_Arb_WriteData(wGen_Arb_WriteDataP),
		.iGen_Arb_ReadData(wGen_Arb_ReadDataP),

		.oGen_Arb_ReadRequest(wGen_Arb_ReadRequestP),
		.oGen_Arb_WriteRequest(wGen_Arb_WriteRequestP),
		.iGen_Arb_WriteAccept(wGen_Arb_WriteAcceptP),
		.iGen_Arb_ReadDataValid(wGen_Arb_ReadDataValidP)
	);	


	`ifndef NATIVE_GM_INTERFACE
		DTL_MasterInterface
		#(
			.D_WIDTH(D_WIDTH),	
			.ADDR_WIDTH(GM_ADDR_WIDTH),
			.MEM_WIDTH(GM_MEM_WIDTH),	
			
			.INTERFACE_WIDTH(INTERFACE_WIDTH),
			.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
			.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH)
		)
		DTL_DMEM_MASTER_inst
		(
			.iClk(iClk),
			.iReset(iReset),
			
			.iReadRequest(wGen_Arb_ReadRequest[0]),
			.iWriteRequest(wGen_Arb_WriteRequest[0]),
			
			.iWriteAddress(wGen_Arb_WriteAddress[0]),
			.iReadAddress(wGen_Arb_ReadAddress[0]),
			.iWriteEnable(wGen_Arb_WriteEnable[0]),
			.iWriteData(wGen_Arb_WriteData[0]),
			.oReadData(wGen_Arb_ReadData[0]),
			
			.oReadDataValid(wGen_Arb_ReadDataValid[0]),
			.oWriteAccept(wGen_Arb_WriteAccept[0]),			
			
			.iDTL_CommandAccept(iDTL_DMEM_CommandAccept),
			.iDTL_WriteAccept(iDTL_DMEM_WriteAccept),
			.iDTL_ReadValid(iDTL_DMEM_ReadValid),
			.iDTL_ReadLast(iDTL_DMEM_ReadLast),
			.iDTL_ReadData(iDTL_DMEM_ReadData),
			
			.oDTL_CommandValid(oDTL_DMEM_CommandValid),
			.oDTL_WriteValid(oDTL_DMEM_WriteValid),		
			.oDTL_CommandReadWrite(oDTL_DMEM_CommandReadWrite),
			.oDTL_WriteEnable(oDTL_DMEM_WriteEnable),
			.oDTL_Address(oDTL_DMEM_Address),	
			.oDTL_WriteData(oDTL_DMEM_WriteData),
			
			.oDTL_BlockSize(oDTL_DMEM_BlockSize),
			.oDTL_WriteLast(oDTL_DMEM_WriteLast),
			.oDTL_ReadAccept(oDTL_DMEM_ReadAccept)
		);	
	`else		
			//direct global memory connection
			assign oGM_WriteAddress = wGen_Arb_WriteAddress[0];
			assign oGM_ReadAddress = wGen_Arb_ReadAddress[0];
			assign oGM_WriteEnable = wGen_Arb_WriteEnable[0];
			assign oGM_ReadEnable = wGen_Arb_ReadEnable[0];
			assign oGM_WriteData = wGen_Arb_WriteData[0];
			assign wGen_Arb_ReadData[0] = iGM_ReadData;

			assign wGen_Arb_WriteAccept[0] = 'b1;
			assign wGen_Arb_ReadDataValid[0] = 'b1;	
	`endif

	//Core peripheral instantiations

				
		
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
		DTL_MasterInterface
		#(
			.D_WIDTH(D_WIDTH),	
			.ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
			.MEM_WIDTH(D_WIDTH),	
			
			.INTERFACE_WIDTH(INTERFACE_WIDTH),
			.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),		
			.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH)
		)
		DTL_STATE_MASTER_inst
		(
			.iClk(iClk),
			.iReset(iReset),
			
			.iReadRequest(wState_ReadRequest),
			.iWriteRequest(wState_WriteRequest),
			
			.iWriteAddress(wState_Address),
			.iReadAddress(wState_Address),
			.iWriteEnable({(INTERFACE_NUM_ENABLES){1'b1}}),
			.iWriteData(wState_WriteData),
			
			.oReadDataValid(wState_ReadDataValid),
			.oWriteAccept(wState_WriteAccept),
			.oReadData(wState_ReadData),
			
			.iDTL_CommandAccept(iDTL_STATE_CommandAccept),
			.iDTL_WriteAccept(iDTL_STATE_WriteAccept),
			.iDTL_ReadValid(iDTL_STATE_ReadValid),
			.iDTL_ReadLast(iDTL_STATE_ReadLast),
			.iDTL_ReadData(iDTL_STATE_ReadData),
				
			.oDTL_CommandValid(oDTL_STATE_CommandValid),
			.oDTL_WriteValid(oDTL_STATE_WriteValid),		
			.oDTL_CommandReadWrite(oDTL_STATE_CommandReadWrite),
			.oDTL_WriteEnable(oDTL_STATE_WriteEnable),
			.oDTL_Address(oDTL_STATE_Address),	
			.oDTL_WriteData(oDTL_STATE_WriteData),
			
			.oDTL_BlockSize(oDTL_STATE_BlockSize),
			.oDTL_WriteLast(oDTL_STATE_WriteLast),
			.oDTL_ReadAccept(oDTL_STATE_ReadAccept)
		);	
	`endif		
endmodule

