`timescale 1 ns / 1 ns

`include "config.vh"

module CGRA_Compute
#
(
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
	
	parameter NUM_ID = 5,
	parameter NUM_IMM = 1,
	parameter NUM_LOCAL_DMEM = 1,
	parameter NUM_GLOBAL_DMEM = 1,

	parameter NUM_STALL_GROUPS = 1	
)
(
	input iClk,
	input iReset,
	output oHalted,
	output oStall,
	
	input iConfigEnable,
	input iConfigDataIn,
	output oConfigDataOut,

	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled							
		output oStateDataOut,
		input iStateDataIn,		
		input iStateSwitchHalt,			
		input iStateShift,
		input iStateNewIn,
		input iStateOldOut,		
	`endif	
	
	//global memory interfaces
	output [(NUM_GLOBAL_DMEM*(GM_MEM_WIDTH / 8))-1:0] oGM_WriteEnable,
	output [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] oGM_WriteAddress,
	output [NUM_GLOBAL_DMEM*D_WIDTH-1:0] oGM_WriteData,
	output [NUM_GLOBAL_DMEM*GM_ADDR_WIDTH-1:0] oGM_ReadAddress,
	input  [NUM_GLOBAL_DMEM*D_WIDTH-1:0] iGM_ReadData,
	input  [NUM_GLOBAL_DMEM-1:0] iGM_ReadDataValid,
	output [NUM_GLOBAL_DMEM-1:0] oGM_ReadRequest,	
	output [NUM_GLOBAL_DMEM-1:0] oGM_WriteRequest,
	input  [NUM_GLOBAL_DMEM-1:0] iGM_WriteAccept,	
	//`ifdef NATIVE_GM_INTERFACE
		input [NUM_GLOBAL_DMEM-1:0]	iGM_ReadGrantNextCycle,
		input [NUM_GLOBAL_DMEM-1:0]	iGM_WriteGrantNextCycle,
	//`endif	

	//local memory interfaces
	output [(NUM_LOCAL_DMEM*(LM_MEM_WIDTH / 8))-1:0] oLM_WriteEnable,
	output [NUM_LOCAL_DMEM-1:0] oLM_ReadEnable,
	output [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] oLM_WriteAddress,
	output [NUM_LOCAL_DMEM*D_WIDTH-1:0] oLM_WriteData,
	output [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] oLM_ReadAddress,
	input  [NUM_LOCAL_DMEM*D_WIDTH-1:0] iLM_ReadData,	
	
	//instruction memory interfaces
	output [(NUM_IMM+NUM_ID)*IM_ADDR_WIDTH-1:0] oIM_ReadAddress,
	output [(NUM_IMM+NUM_ID)-1:0] oIM_ReadEnable,
	input  [NUM_IMM*I_IMM_WIDTH+NUM_ID*I_WIDTH-1:0] iIM_ReadData	
);
	
	localparam SRC_WIDTH = 2;
	localparam DEST_WIDTH = 1;	
	localparam REG_ADDR_WIDTH = 4;
		
	wire [D_WIDTH-1:0] 			wLM_ReadData[NUM_LOCAL_DMEM-1:0];
	wire [LM_ADDR_WIDTH-1:0] 	wLM_ReadAddress[NUM_LOCAL_DMEM-1:0];
	wire [D_WIDTH-1:0] 			wLM_WriteData[NUM_LOCAL_DMEM-1:0];
	wire [LM_ADDR_WIDTH-1:0]	wLM_WriteAddress[NUM_LOCAL_DMEM-1:0];
	wire [(LM_MEM_WIDTH / 8)-1:0]	wLM_WriteEnable[NUM_LOCAL_DMEM-1:0];
	wire 						wLM_ReadEnable[NUM_LOCAL_DMEM-1:0];
	
	wire			 			wGM_ReadDataValid[NUM_GLOBAL_DMEM-1:0];
	wire			 			wGM_ReadRequest[NUM_GLOBAL_DMEM-1:0];
	wire [D_WIDTH-1:0] 			wGM_ReadData[NUM_GLOBAL_DMEM-1:0];
	wire [GM_ADDR_WIDTH-1:0] 	wGM_ReadAddress[NUM_GLOBAL_DMEM-1:0];
	wire [GM_ADDR_WIDTH-1:0] 	wGM_WriteAddress[NUM_GLOBAL_DMEM-1:0];
	wire [D_WIDTH-1:0] 			wGM_WriteData[NUM_GLOBAL_DMEM-1:0];
	wire [(GM_MEM_WIDTH / 8)-1:0]	wGM_WriteEnable[NUM_GLOBAL_DMEM-1:0];	
	wire 					 	wGM_WriteRequest[NUM_GLOBAL_DMEM-1:0];
	wire 					 	wGM_WriteAccept[NUM_GLOBAL_DMEM-1:0];

	//`ifdef NATIVE_GM_INTERFACE
	wire 					 	wGM_ReadGrantNextCycle[NUM_GLOBAL_DMEM-1:0];
	wire 					 	wGM_WriteGrantNextCycle[NUM_GLOBAL_DMEM-1:0];
	//`endif

	wand wHalted;
	wire [NUM_STALL_GROUPS-1:0] wStall;

	wire [NUM_STALL_GROUPS-1:0] wStall_0;

	genvar gCurrStall;
	generate
		for (gCurrStall=0; gCurrStall < NUM_STALL_GROUPS; gCurrStall = gCurrStall + 1)
			begin : stallGroups
				assign wStall[gCurrStall] = wStall_0[gCurrStall];

			end
	endgenerate

	wire [IM_ADDR_WIDTH-1:0] wIM_ID_ReadAddress[4:0];
	wire [I_WIDTH-1:0] wIM_ID_ReadData[4:0];
	wire wIM_ID_ReadEnable[4:0];
	wire [I_WIDTH-1:0] wIM_ID_Instruction[4:0];
	wire [I_DECODED_WIDTH-1:0] wIM_ID_DecodedInstruction[4:0];

	wire [IM_ADDR_WIDTH-1:0] wIM_IU_ReadAddress[0:0];
	wire [I_IMM_WIDTH-1:0] wIM_IU_ReadData[0:0];
	wire wIM_IU_ReadEnable[0:0];
	wire [I_IMM_WIDTH-1:0] wIM_IU_Instruction[0:0];

	//data wires 
	wire [D_WIDTH-1:0] wData_imm_0;
	wire [D_WIDTH-1:0] wData_rf_0;
	wire [D_WIDTH-1:0] wData_rf_1;
	wire [D_WIDTH-1:0] wData_lsu_0;
	wire [D_WIDTH-1:0] wData_lsu_1;
	wire [D_WIDTH-1:0] wData_abu_0;
	wire [D_WIDTH-1:0] wData_abu_1;
	wire [D_WIDTH-1:0] wData_mul_0;
	wire [D_WIDTH-1:0] wData_mul_1;
	wire [D_WIDTH-1:0] wData_alu_0;
	wire [D_WIDTH-1:0] wData_alu_1;
	

	//control wires 
	
	
	//configuration wires
	wire wConfig_abu_TO_id_mul;
	wire wConfig_id_abu_TO_imm;
	wire wConfig_imm_TO_lsu;
	wire wConfig_lsu_TO_id_lsu;
	wire wConfig_id_lsu_TO_abu;
	wire wConfig_id_mul_TO_id_alu;
	wire wConfig_id_alu_TO_alu;
	wire wConfig_alu_TO_id_rf;
	

	//Carrychain wires
	

	//assigns for global memories
	assign oGM_WriteEnable = {wGM_WriteEnable[0]};
	assign oGM_WriteAddress = {wGM_WriteAddress[0]};
	assign oGM_WriteData = {wGM_WriteData[0]};	
	assign oGM_ReadAddress = {wGM_ReadAddress[0]};
	assign oGM_ReadRequest = {wGM_ReadRequest[0]};
	assign oGM_WriteRequest = {wGM_WriteRequest[0]};
	assign {wGM_ReadData[0]} = iGM_ReadData;
	assign {wGM_ReadDataValid[0]} = iGM_ReadDataValid;
	assign {wGM_WriteAccept[0]} = iGM_WriteAccept;
	//`ifdef NATIVE_GM_INTERFACE
		assign {wGM_ReadGrantNextCycle[0]} = iGM_ReadGrantNextCycle;
		assign {wGM_WriteGrantNextCycle[0]} = iGM_WriteGrantNextCycle;
	//`endif
	
	//assigns for local memories
	assign oLM_WriteEnable = {wLM_WriteEnable[0]};
	assign oLM_ReadEnable = {wLM_ReadEnable[0]};
	assign oLM_WriteAddress = {wLM_WriteAddress[0]};
	assign oLM_WriteData = {wLM_WriteData[0]};	
	assign oLM_ReadAddress = {wLM_ReadAddress[0]};
	assign {wLM_ReadData[0]} = iLM_ReadData;

	//assigns for instruction memories
	assign oIM_ReadAddress = {wIM_IU_ReadAddress[0], wIM_ID_ReadAddress[4], wIM_ID_ReadAddress[3], wIM_ID_ReadAddress[2], wIM_ID_ReadAddress[1], wIM_ID_ReadAddress[0]};
	assign oIM_ReadEnable = {wIM_IU_ReadEnable[0], wIM_ID_ReadEnable[4], wIM_ID_ReadEnable[3], wIM_ID_ReadEnable[2], wIM_ID_ReadEnable[1], wIM_ID_ReadEnable[0]};
	assign {wIM_IU_ReadData[0], wIM_ID_ReadData[4], wIM_ID_ReadData[3], wIM_ID_ReadData[2], wIM_ID_ReadData[1], wIM_ID_ReadData[0]} = iIM_ReadData;	

	//assign for halting
	assign oHalted = wHalted;
	assign oStall = wStall;
	
	//----------------------------------
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled					
		//state chain wires
		wire wState_id_abu_TO_imm;
		wire wState_imm_TO_rf;
		wire wState_rf_TO_lsu;
		wire wState_lsu_TO_id_lsu;
		wire wState_id_lsu_TO_abu;
		wire wState_abu_TO_id_mul;
		wire wState_id_mul_TO_id_alu;
		wire wState_id_alu_TO_mul;
		wire wState_mul_TO_alu;
		wire wState_alu_TO_id_rf;

	`else
		wire iStateSwitchHalt = 0;
	`endif	

    //instruction decode units
	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_abu_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[0]),
		.iInstruction(wIM_ID_ReadData[0]),

		.oInstruction(wIM_ID_Instruction[0]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[0])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_abu"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_abu_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(iConfigDataIn),
		.oConfigDataOut(wConfig_id_abu_TO_imm),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(iStateDataIn),
			.oStateDataOut(wState_id_abu_TO_imm),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[0]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[0])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_imm_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_IU_ReadAddress[0]),
		.iInstruction(wIM_IU_ReadData[0]),

		.oInstruction(wIM_IU_Instruction[0]),
		.oInstructionReadEnable(wIM_IU_ReadEnable[0])
	);

	IU
	#(	
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.D_WIDTH(D_WIDTH),
	
		.INSERT_BUBBLE(1),
	
		.TEST_ID("imm"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	imm_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_abu_TO_imm),
		.oConfigDataOut(wConfig_imm_TO_lsu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_abu_TO_imm),
			.oStateDataOut(wState_imm_TO_rf),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInstruction(wIM_IU_Instruction[0]),
		.oImmediateOut(wData_imm_0)	
	);

	RF
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),		
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),		
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH)
	)
	rf_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_imm_TO_rf),
			.oStateDataOut(wState_rf_TO_lsu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
		
		.iInputs({wData_mul_0, wData_alu_1, wData_lsu_1, wData_imm_0}),
		.oOutputs({wData_rf_1, wData_rf_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[4])	
	);	

	LSU 
	#(		
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),	
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),	
		.LM_ADDR_WIDTH(LM_ADDR_WIDTH),
		.GM_ADDR_WIDTH(GM_ADDR_WIDTH),

		.LM_MEM_ADDR_WIDTH(LM_MEM_ADDR_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),

		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),

		.TEST_ID("lsu"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	) 
	lsu_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.oStall(wStall_0), 

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_imm_TO_lsu),
		.oConfigDataOut(wConfig_lsu_TO_id_lsu),	

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_rf_TO_lsu),
			.oStateDataOut(wState_lsu_TO_id_lsu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif				

		.iInputs({{D_WIDTH{1'b0}}, wData_rf_0, wData_rf_1, wData_imm_0}),
		.oOutputs({wData_lsu_1, wData_lsu_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[1]),
				
		.iLM_ReadData(wLM_ReadData[0]),
		.oLM_ReadAddress(wLM_ReadAddress[0]),		
		.oLM_WriteData(wLM_WriteData[0]),
		.oLM_WriteAddress(wLM_WriteAddress[0]),
		.oLM_WriteEnable(wLM_WriteEnable[0]),	
		.oLM_ReadEnable(wLM_ReadEnable[0]),
		
		//`ifdef NATIVE_GM_INTERFACE
			.iGM_ReadGrantNextCycle(wGM_ReadGrantNextCycle[0]),
			.iGM_WriteGrantNextCycle(wGM_WriteGrantNextCycle[0]),
		//`endif				

		.iGM_ReadData(wGM_ReadData[0]),
		.iGM_ReadDataValid(wGM_ReadDataValid[0]),
		.oGM_ReadRequest(wGM_ReadRequest[0]),		
		.oGM_ReadAddress(wGM_ReadAddress[0]),	
		.oGM_WriteAddress(wGM_WriteAddress[0]),	
		.oGM_WriteData(wGM_WriteData[0]),
		.oGM_WriteEnable(wGM_WriteEnable[0]),	
		.oGM_WriteRequest(wGM_WriteRequest[0]),
		.iGM_WriteAccept(wGM_WriteAccept[0])		

	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_lsu_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[1]),
		.iInstruction(wIM_ID_ReadData[1]),

		.oInstruction(wIM_ID_Instruction[1]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[1])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_lsu"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_lsu_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_lsu_TO_id_lsu),
		.oConfigDataOut(wConfig_id_lsu_TO_abu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_lsu_TO_id_lsu),
			.oStateDataOut(wState_id_lsu_TO_abu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[1]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[1])			
	);	


	ABU
	#(  //parameters that can be externally configured
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH),
	
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),
	
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
	
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
	
		.TEST_ID("abu"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
		
	)
	abu_inst
	(	//inputs and outputs
		.iClk(iClk),
		.iReset(iReset),
		.oHalted(wHalted),
		.iStall(wStall | iStateSwitchHalt),
	
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_lsu_TO_abu),
		.oConfigDataOut(wConfig_abu_TO_id_mul),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_lsu_TO_abu),
			.oStateDataOut(wState_abu_TO_id_mul),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif		
		
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_rf_1, wData_alu_1}),
		.oOutputs({wData_abu_1, wData_abu_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[0])	
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_mul_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[2]),
		.iInstruction(wIM_ID_ReadData[2]),

		.oInstruction(wIM_ID_Instruction[2]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[2])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_mul"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_mul_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_abu_TO_id_mul),
		.oConfigDataOut(wConfig_id_mul_TO_id_alu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_abu_TO_id_mul),
			.oStateDataOut(wState_id_mul_TO_id_alu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[2]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[2])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_alu_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[3]),
		.iInstruction(wIM_ID_ReadData[3]),

		.oInstruction(wIM_ID_Instruction[3]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[3])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_alu"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_alu_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_mul_TO_id_alu),
		.oConfigDataOut(wConfig_id_alu_TO_alu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_mul_TO_id_alu),
			.oStateDataOut(wState_id_alu_TO_mul),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[3]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[3])			
	);	

	MUL
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH (D_WIDTH),
		
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),
		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.TEST_ID("mul")
	)
	mul_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_alu_TO_mul),
			.oStateDataOut(wState_mul_TO_alu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInputs({{D_WIDTH{1'b0}}, wData_alu_1, wData_rf_1, wData_rf_0}), 
		.oOutputs({wData_mul_1, wData_mul_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[2])
	);

	ALU
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH (D_WIDTH),
		
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),
		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.TEST_ID("alu")
	)
	alu_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_alu_TO_alu),
		.oConfigDataOut(wConfig_alu_TO_id_rf),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_mul_TO_alu),
			.oStateDataOut(wState_alu_TO_id_rf),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
		
		.iCarryIn(1'b0),
		.oCarryOut(),

		.iInputs({{D_WIDTH{1'b0}}, wData_mul_0, wData_rf_1, wData_rf_0}), 
		.oOutputs({wData_alu_1, wData_alu_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[3])
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_rf_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[4]),
		.iInstruction(wIM_ID_ReadData[4]),

		.oInstruction(wIM_ID_Instruction[4]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[4])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_rf"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_rf_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_alu_TO_id_rf),
		.oConfigDataOut(oConfigDataOut),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_alu_TO_id_rf),
			.oStateDataOut(oStateDataOut),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[4]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[4])			
	);	


			
endmodule


