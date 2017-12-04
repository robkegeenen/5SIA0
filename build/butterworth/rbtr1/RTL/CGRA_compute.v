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
	
	parameter NUM_ID = 10,
	parameter NUM_IMM = 3,
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

	wire [IM_ADDR_WIDTH-1:0] wIM_ID_ReadAddress[9:0];
	wire [I_WIDTH-1:0] wIM_ID_ReadData[9:0];
	wire wIM_ID_ReadEnable[9:0];
	wire [I_WIDTH-1:0] wIM_ID_Instruction[9:0];
	wire [I_DECODED_WIDTH-1:0] wIM_ID_DecodedInstruction[9:0];

	wire [IM_ADDR_WIDTH-1:0] wIM_IU_ReadAddress[2:0];
	wire [I_IMM_WIDTH-1:0] wIM_IU_ReadData[2:0];
	wire wIM_IU_ReadEnable[2:0];
	wire [I_IMM_WIDTH-1:0] wIM_IU_Instruction[2:0];

	//data wires 
	wire [D_WIDTH-1:0] wData_mul_y_0;
	wire [D_WIDTH-1:0] wData_mul_y_1;
	wire [D_WIDTH-1:0] wData_alu_0;
	wire [D_WIDTH-1:0] wData_alu_1;
	wire [D_WIDTH-1:0] wData_abu_0;
	wire [D_WIDTH-1:0] wData_abu_1;
	wire [D_WIDTH-1:0] wData_abu_x_0;
	wire [D_WIDTH-1:0] wData_abu_x_1;
	wire [D_WIDTH-1:0] wData_abu_y_0;
	wire [D_WIDTH-1:0] wData_abu_y_1;
	wire [D_WIDTH-1:0] wData_imm_y_0;
	wire [D_WIDTH-1:0] wData_imm_x_0;
	wire [D_WIDTH-1:0] wData_rf_y_0;
	wire [D_WIDTH-1:0] wData_rf_y_1;
	wire [D_WIDTH-1:0] wData_rf_x_0;
	wire [D_WIDTH-1:0] wData_rf_x_1;
	wire [D_WIDTH-1:0] wData_imm_stor_0;
	wire [D_WIDTH-1:0] wData_mul_x_0;
	wire [D_WIDTH-1:0] wData_mul_x_1;
	wire [D_WIDTH-1:0] wData_abu_stor_0;
	wire [D_WIDTH-1:0] wData_abu_stor_1;
	wire [D_WIDTH-1:0] wData_lsu_stor_0;
	wire [D_WIDTH-1:0] wData_lsu_stor_1;
	

	//control wires 
	
	
	//configuration wires
	wire wConfig_id_abu_x_TO_imm_stor;
	wire wConfig_imm_y_TO_imm_x;
	wire wConfig_imm_x_TO_id_abu_stor;
	wire wConfig_abu_stor_TO_lsu_stor;
	wire wConfig_id_abu_stor_TO_id_abu_y;
	wire wConfig_id_alu_TO_abu_x;
	wire wConfig_abu_x_TO_abu_y;
	wire wConfig_alu_TO_id_rf_x;
	wire wConfig_id_rf_x_TO_id_rf_y;
	wire wConfig_id_abu_y_TO_id_abu_x;
	wire wConfig_id_abu_TO_id_alu;
	wire wConfig_imm_stor_TO_abu_stor;
	wire wConfig_id_rf_y_TO_abu;
	wire wConfig_abu_TO_id_abu;
	wire wConfig_id_mul_x_TO_alu;
	wire wConfig_id_lsu_stor_TO_id_mul_y;
	wire wConfig_id_mul_y_TO_id_mul_x;
	wire wConfig_abu_y_TO_imm_y;
	

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
	assign oIM_ReadAddress = {wIM_IU_ReadAddress[2], wIM_IU_ReadAddress[1], wIM_IU_ReadAddress[0], wIM_ID_ReadAddress[9], wIM_ID_ReadAddress[8], wIM_ID_ReadAddress[7], wIM_ID_ReadAddress[6], wIM_ID_ReadAddress[5], wIM_ID_ReadAddress[4], wIM_ID_ReadAddress[3], wIM_ID_ReadAddress[2], wIM_ID_ReadAddress[1], wIM_ID_ReadAddress[0]};
	assign oIM_ReadEnable = {wIM_IU_ReadEnable[2], wIM_IU_ReadEnable[1], wIM_IU_ReadEnable[0], wIM_ID_ReadEnable[9], wIM_ID_ReadEnable[8], wIM_ID_ReadEnable[7], wIM_ID_ReadEnable[6], wIM_ID_ReadEnable[5], wIM_ID_ReadEnable[4], wIM_ID_ReadEnable[3], wIM_ID_ReadEnable[2], wIM_ID_ReadEnable[1], wIM_ID_ReadEnable[0]};
	assign {wIM_IU_ReadData[2], wIM_IU_ReadData[1], wIM_IU_ReadData[0], wIM_ID_ReadData[9], wIM_ID_ReadData[8], wIM_ID_ReadData[7], wIM_ID_ReadData[6], wIM_ID_ReadData[5], wIM_ID_ReadData[4], wIM_ID_ReadData[3], wIM_ID_ReadData[2], wIM_ID_ReadData[1], wIM_ID_ReadData[0]} = iIM_ReadData;	

	//assign for halting
	assign oHalted = wHalted;
	assign oStall = wStall;
	
	//----------------------------------
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled					
		//state chain wires
		wire wState_id_lsu_stor_TO_mul_y;
		wire wState_mul_y_TO_id_mul_y;
		wire wState_id_mul_y_TO_id_mul_x;
		wire wState_id_mul_x_TO_alu;
		wire wState_alu_TO_id_rf_x;
		wire wState_id_rf_x_TO_id_rf_y;
		wire wState_id_rf_y_TO_abu;
		wire wState_abu_TO_id_abu;
		wire wState_id_abu_TO_id_alu;
		wire wState_id_alu_TO_abu_x;
		wire wState_abu_x_TO_abu_y;
		wire wState_abu_y_TO_imm_y;
		wire wState_imm_y_TO_imm_x;
		wire wState_imm_x_TO_rf_y;
		wire wState_rf_y_TO_rf_x;
		wire wState_rf_x_TO_id_abu_stor;
		wire wState_id_abu_stor_TO_id_abu_y;
		wire wState_id_abu_y_TO_id_abu_x;
		wire wState_id_abu_x_TO_imm_stor;
		wire wState_imm_stor_TO_mul_x;
		wire wState_mul_x_TO_abu_stor;
		wire wState_abu_stor_TO_lsu_stor;

	`else
		wire iStateSwitchHalt = 0;
	`endif	

    //instruction decode units
	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_lsu_stor_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[7]),
		.iInstruction(wIM_ID_ReadData[7]),

		.oInstruction(wIM_ID_Instruction[7]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[7])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_lsu_stor"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_lsu_stor_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(iConfigDataIn),
		.oConfigDataOut(wConfig_id_lsu_stor_TO_id_mul_y),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(iStateDataIn),
			.oStateDataOut(wState_id_lsu_stor_TO_mul_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[7]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[7])			
	);	

	MUL
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH (D_WIDTH),
		
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),
		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.TEST_ID("mul_y")
	)
	mul_y_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_lsu_stor_TO_mul_y),
			.oStateDataOut(wState_mul_y_TO_id_mul_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_imm_y_0, wData_rf_y_1}), 
		.oOutputs({wData_mul_y_1, wData_mul_y_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[8])
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_mul_y_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[8]),
		.iInstruction(wIM_ID_ReadData[8]),

		.oInstruction(wIM_ID_Instruction[8]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[8])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_mul_y"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_mul_y_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_lsu_stor_TO_id_mul_y),
		.oConfigDataOut(wConfig_id_mul_y_TO_id_mul_x),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_mul_y_TO_id_mul_y),
			.oStateDataOut(wState_id_mul_y_TO_id_mul_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[8]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[8])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_mul_x_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_ID_ReadAddress[9]),
		.iInstruction(wIM_ID_ReadData[9]),

		.oInstruction(wIM_ID_Instruction[9]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[9])
	);

	ID //instruction decoding
	#(
		.I_WIDTH(I_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.TEST_ID("id_mul_x"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_mul_x_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_mul_y_TO_id_mul_x),
		.oConfigDataOut(wConfig_id_mul_x_TO_alu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_mul_y_TO_id_mul_x),
			.oStateDataOut(wState_id_mul_x_TO_alu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[9]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[9])			
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
		.iConfigDataIn(wConfig_id_mul_x_TO_alu),
		.oConfigDataOut(wConfig_alu_TO_id_rf_x),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_mul_x_TO_alu),
			.oStateDataOut(wState_alu_TO_id_rf_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
		
		.iCarryIn(1'b0),
		.oCarryOut(),

		.iInputs({wData_abu_y_0, wData_abu_x_0, wData_lsu_stor_1, wData_abu_stor_0}), 
		.oOutputs({wData_alu_1, wData_alu_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[5])
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_rf_x_inst
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
		.TEST_ID("id_rf_x"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_rf_x_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_alu_TO_id_rf_x),
		.oConfigDataOut(wConfig_id_rf_x_TO_id_rf_y),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_alu_TO_id_rf_x),
			.oStateDataOut(wState_id_rf_x_TO_id_rf_y),	
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
	IF_id_rf_y_inst
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
		.TEST_ID("id_rf_y"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_rf_y_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_rf_x_TO_id_rf_y),
		.oConfigDataOut(wConfig_id_rf_y_TO_abu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_rf_x_TO_id_rf_y),
			.oStateDataOut(wState_id_rf_y_TO_abu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[3]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[3])			
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
		.iConfigDataIn(wConfig_id_rf_y_TO_abu),
		.oConfigDataOut(wConfig_abu_TO_id_abu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_rf_y_TO_abu),
			.oStateDataOut(wState_abu_TO_id_abu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif		
		
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_abu_stor_1}),
		.oOutputs({wData_abu_1, wData_abu_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[6])	
	);

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
	
		.oInstructionAddress(wIM_ID_ReadAddress[6]),
		.iInstruction(wIM_ID_ReadData[6]),

		.oInstruction(wIM_ID_Instruction[6]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[6])
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
		.iConfigDataIn(wConfig_abu_TO_id_abu),
		.oConfigDataOut(wConfig_id_abu_TO_id_alu),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_abu_TO_id_abu),
			.oStateDataOut(wState_id_abu_TO_id_alu),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[6]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[6])			
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
	
		.oInstructionAddress(wIM_ID_ReadAddress[5]),
		.iInstruction(wIM_ID_ReadData[5]),

		.oInstruction(wIM_ID_Instruction[5]),
		.oInstructionReadEnable(wIM_ID_ReadEnable[5])
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
		.iConfigDataIn(wConfig_id_abu_TO_id_alu),
		.oConfigDataOut(wConfig_id_alu_TO_abu_x),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_abu_TO_id_alu),
			.oStateDataOut(wState_id_alu_TO_abu_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[5]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[5])			
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
	
		.TEST_ID("abu_x"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
		
	)
	abu_x_inst
	(	//inputs and outputs
		.iClk(iClk),
		.iReset(iReset),
		.oHalted(wHalted),
		.iStall(wStall | iStateSwitchHalt),
	
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_alu_TO_abu_x),
		.oConfigDataOut(wConfig_abu_x_TO_abu_y),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_alu_TO_abu_x),
			.oStateDataOut(wState_abu_x_TO_abu_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif		
		
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_imm_stor_0, wData_mul_x_0}),
		.oOutputs({wData_abu_x_1, wData_abu_x_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[4])	
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
	
		.TEST_ID("abu_y"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
		
	)
	abu_y_inst
	(	//inputs and outputs
		.iClk(iClk),
		.iReset(iReset),
		.oHalted(wHalted),
		.iStall(wStall | iStateSwitchHalt),
	
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_abu_x_TO_abu_y),
		.oConfigDataOut(wConfig_abu_y_TO_imm_y),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_abu_x_TO_abu_y),
			.oStateDataOut(wState_abu_y_TO_imm_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif		
		
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_imm_stor_0, wData_mul_y_0}),
		.oOutputs({wData_abu_y_1, wData_abu_y_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[1])	
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_imm_y_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_IU_ReadAddress[1]),
		.iInstruction(wIM_IU_ReadData[1]),

		.oInstruction(wIM_IU_Instruction[1]),
		.oInstructionReadEnable(wIM_IU_ReadEnable[1])
	);

	IU
	#(	
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.D_WIDTH(D_WIDTH),
	
		.INSERT_BUBBLE(1),
	
		.TEST_ID("imm_y"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	imm_y_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_abu_y_TO_imm_y),
		.oConfigDataOut(wConfig_imm_y_TO_imm_x),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_abu_y_TO_imm_y),
			.oStateDataOut(wState_imm_y_TO_imm_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInstruction(wIM_IU_Instruction[1]),
		.oImmediateOut(wData_imm_y_0)	
	);

	IF //instruction fetching
	#(
		.I_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_imm_x_inst
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(wData_abu_1[IM_ADDR_WIDTH-1:0]),
	
		.oInstructionAddress(wIM_IU_ReadAddress[2]),
		.iInstruction(wIM_IU_ReadData[2]),

		.oInstruction(wIM_IU_Instruction[2]),
		.oInstructionReadEnable(wIM_IU_ReadEnable[2])
	);

	IU
	#(	
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.D_WIDTH(D_WIDTH),
	
		.INSERT_BUBBLE(1),
	
		.TEST_ID("imm_x"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	imm_x_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_imm_y_TO_imm_x),
		.oConfigDataOut(wConfig_imm_x_TO_id_abu_stor),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_imm_y_TO_imm_x),
			.oStateDataOut(wState_imm_x_TO_rf_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInstruction(wIM_IU_Instruction[2]),
		.oImmediateOut(wData_imm_x_0)	
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
	rf_y_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_imm_x_TO_rf_y),
			.oStateDataOut(wState_rf_y_TO_rf_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
		
		.iInputs({wData_imm_stor_0, wData_alu_0, wData_abu_stor_1, wData_alu_1}),
		.oOutputs({wData_rf_y_1, wData_rf_y_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[3])	
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
	rf_x_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_rf_y_TO_rf_x),
			.oStateDataOut(wState_rf_x_TO_id_abu_stor),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
		
		.iInputs({wData_imm_stor_0, wData_alu_0, wData_abu_stor_1, wData_lsu_stor_0}),
		.oOutputs({wData_rf_x_1, wData_rf_x_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[2])	
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_abu_stor_inst
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
		.TEST_ID("id_abu_stor"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_abu_stor_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_imm_x_TO_id_abu_stor),
		.oConfigDataOut(wConfig_id_abu_stor_TO_id_abu_y),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_rf_x_TO_id_abu_stor),
			.oStateDataOut(wState_id_abu_stor_TO_id_abu_y),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[0]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[0])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_abu_y_inst
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
		.TEST_ID("id_abu_y"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_abu_y_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_abu_stor_TO_id_abu_y),
		.oConfigDataOut(wConfig_id_abu_y_TO_id_abu_x),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_abu_stor_TO_id_abu_y),
			.oStateDataOut(wState_id_abu_y_TO_id_abu_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[1]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[1])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_id_abu_x_inst
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
		.TEST_ID("id_abu_x"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	id_abu_x_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),
		
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_abu_y_TO_id_abu_x),
		.oConfigDataOut(wConfig_id_abu_x_TO_imm_stor),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_abu_y_TO_id_abu_x),
			.oStateDataOut(wState_id_abu_x_TO_imm_stor),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			

		.iInstruction(wIM_ID_Instruction[4]),	
		.oDecodedInstruction(wIM_ID_DecodedInstruction[4])			
	);	

	IF //instruction fetching
	#(
		.I_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_imm_stor_inst
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
	
		.TEST_ID("imm_stor"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	imm_stor_inst
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_id_abu_x_TO_imm_stor),
		.oConfigDataOut(wConfig_imm_stor_TO_abu_stor),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_id_abu_x_TO_imm_stor),
			.oStateDataOut(wState_imm_stor_TO_mul_x),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInstruction(wIM_IU_Instruction[0]),
		.oImmediateOut(wData_imm_stor_0)	
	);

	MUL
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH (D_WIDTH),
		
		.NUM_INPUTS(4),
		.NUM_OUTPUTS(2),
		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.TEST_ID("mul_x")
	)
	mul_x_inst
	(	
		.iClk(iClk),
		.iReset(iReset),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_imm_stor_TO_mul_x),
			.oStateDataOut(wState_mul_x_TO_abu_stor),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_imm_x_0, wData_rf_x_1}), 
		.oOutputs({wData_mul_x_1, wData_mul_x_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[9])
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
	
		.TEST_ID("abu_stor"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
		
	)
	abu_stor_inst
	(	//inputs and outputs
		.iClk(iClk),
		.iReset(iReset),
		.oHalted(wHalted),
		.iStall(wStall | iStateSwitchHalt),
	
		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_imm_stor_TO_abu_stor),
		.oConfigDataOut(wConfig_abu_stor_TO_lsu_stor),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_mul_x_TO_abu_stor),
			.oStateDataOut(wState_abu_stor_TO_lsu_stor),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif		
		
		.iInputs({{D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, {D_WIDTH{1'b0}}, wData_imm_stor_0}),
		.oOutputs({wData_abu_stor_1, wData_abu_stor_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[0])	
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

		.TEST_ID("lsu_stor"),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	) 
	lsu_stor_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.oStall(wStall_0), 

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(wConfig_abu_stor_TO_lsu_stor),
		.oConfigDataOut(oConfigDataOut),	

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(wState_abu_stor_TO_lsu_stor),
			.oStateDataOut(oStateDataOut),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif				

		.iInputs({{D_WIDTH{1'b0}}, wData_imm_y_0, wData_alu_1, wData_abu_stor_1}),
		.oOutputs({wData_lsu_stor_1, wData_lsu_stor_0}),
		
		.iDecodedInstruction(wIM_ID_DecodedInstruction[7]),
				
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


			
endmodule


