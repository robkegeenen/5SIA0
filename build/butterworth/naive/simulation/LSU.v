`include "config.vh"

`define LOWLATENCY

module LSU
#
(	//parameters that can be externally configured
	parameter I_DECODED_WIDTH = 16,
	parameter D_WIDTH = 8,
	
	parameter NUM_INPUTS = 4,
	parameter NUM_OUTPUTS = 2,
	
	parameter LM_ADDR_WIDTH = 16,
	parameter GM_ADDR_WIDTH = 32,
	
	parameter LM_MEM_ADDR_WIDTH = 8,
		
	parameter LM_MEM_WIDTH = D_WIDTH,
	parameter GM_MEM_WIDTH = D_WIDTH,
		
	parameter SRC_WIDTH = 2,
	parameter DEST_WIDTH = 1,
	
	parameter REG_ADDR_WIDTH = 4,
	
	parameter NUM_STALL_GROUPS = 1,	
	
	parameter TEST_ID = "0"
)
(  //inputs and outputs
	input iClk,
	input iReset,
		
	output [NUM_STALL_GROUPS-1:0] oStall,
	
	input iConfigEnable,
	input iConfigDataIn,
	output oConfigDataOut,
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		//state chain	
		input iStateDataIn,
		output oStateDataOut,	
		input iStateShift,
		input iNewStateIn,
		input iOldStateOut,	
	`endif
	
	input [NUM_INPUTS*D_WIDTH-1:0] iInputs,
	output [NUM_OUTPUTS*D_WIDTH-1:0] oOutputs,
	
	input [I_DECODED_WIDTH-1:0] iDecodedInstruction,
			
	//--------------- LOCAL MEMORY INTERFACE ----------------	
	input  [LM_MEM_WIDTH-1:0] 			iLM_ReadData,
	output [LM_ADDR_WIDTH-1:0] 		oLM_ReadAddress,	
	output [LM_MEM_WIDTH-1:0] 			oLM_WriteData,
	output [LM_ADDR_WIDTH-1:0]			oLM_WriteAddress,
	output [(LM_MEM_WIDTH / 8)-1:0]	oLM_WriteEnable,	
	output oLM_ReadEnable,
	
	//--------------- GLOBAL MEMORY INTERFACE ----------------		
	input iGM_ReadGrantNextCycle,
	input iGM_WriteGrantNextCycle,
	
	input  [GM_MEM_WIDTH-1:0] 			iGM_ReadData,
	input 									iGM_ReadDataValid,
	output 									oGM_ReadRequest,
	output [GM_ADDR_WIDTH-1:0] 		oGM_ReadAddress,	
	output [GM_ADDR_WIDTH-1:0] 		oGM_WriteAddress,	
	output [GM_MEM_WIDTH-1:0] 			oGM_WriteData,
	output [(GM_MEM_WIDTH / 8)-1:0]	oGM_WriteEnable,		
	output 									oGM_WriteRequest,
	input										iGM_WriteAccept
);

	function integer MIN;
		input [31:0] A;		
		input [31:0] B;		
		begin
			if (A < B)
				MIN = A;
			else
				MIN = B;
		end
	endfunction	
	
	function integer MAX;
		input [31:0] A;		
		input [31:0] B;		
		begin
			if (A > B)
				MAX = A;
			else
				MAX = B;
		end
	endfunction		
	
	function integer CLogB2;
		input [31:0] Depth;
		integer i;
		begin
			i = Depth;		
			for(CLogB2 = 0; i > 0; CLogB2 = CLogB2 + 1)
				i = i >> 1;
		end
	endfunction		
	
	//local parameters, these depend on the actual implementation of the module and therefore are not configurable
	//from outside the module.
	
	localparam NUM_REGS = 16;
	localparam NUM_REGS_LM_ADDR = 2;
	localparam NUM_REGS_GM_ADDR = 4;
	
			
	localparam GM_ADDR_REGS_REQ = (GM_ADDR_WIDTH > D_WIDTH) ? (GM_ADDR_WIDTH / D_WIDTH) : 1; //make sure that GM_ADDR_WIDTH % D_WIDTH = 0	
	localparam GM_ADDR_REGS_OFFSET = 6;
	
	localparam LM_ADDR_REGS_REQ = (LM_ADDR_WIDTH > D_WIDTH) ? (LM_ADDR_WIDTH / D_WIDTH) -1 : 0; //make sure that LM_ADDR_WIDTH % D_WIDTH = 0
	localparam LM_ADDR_REGS_OFFSET = 14;
		
	localparam CONFIG_LOAD_IMPLICIT_OFFSET = 0;
	localparam CONFIG_STORE_IMPLICIT_OFFSET = 3;
	
	localparam CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET = 6;
	localparam CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET = 10;
	
	localparam LSU_DECODED_WIDTH = 16;
	
	localparam LM_WRITE_WIDTH = MIN(D_WIDTH, LM_ADDR_WIDTH);
	localparam GM_WRITE_WIDTH = MIN(D_WIDTH, GM_ADDR_WIDTH);
	
	localparam LM_BYTE_ENABLES = (LM_MEM_WIDTH / 8);
	localparam LM_BYTE_ENABLES_WIDTH = CLogB2(LM_BYTE_ENABLES-1);
		
	localparam GM_BYTE_ENABLES = (GM_MEM_WIDTH / 8);
	localparam GM_BYTE_ENABLES_WIDTH = CLogB2(GM_BYTE_ENABLES-1);

	localparam TYPE_WIDTH = 2;
	
	localparam STALL_GROUP_WIDTH = MAX(CLogB2(NUM_STALL_GROUPS-1),1);
	localparam CONFIG_WIDTH = 0+STALL_GROUP_WIDTH;	
	
	localparam STATE_OUTPUTS_OFFSET = 7+GM_BYTE_ENABLES_WIDTH-TYPE_WIDTH;
	localparam STATE_REGS_OFFSET = 7+GM_BYTE_ENABLES_WIDTH-TYPE_WIDTH+D_WIDTH*NUM_OUTPUTS;
	
	
	//--------------- LOCAL MEMORY INTERFACE ----------------	
	reg  [LM_MEM_WIDTH-1:0] 	wLM_ReadData;
	wire  [LM_MEM_WIDTH-1:0] 	wLM_ReadData_Buffered;
	wire [LM_ADDR_WIDTH-1:0] 	wLM_ReadAddress;
	reg  [LM_MEM_WIDTH-1:0] 	wLM_WriteData;
	wire [LM_ADDR_WIDTH-1:0]	wLM_WriteAddress;
		
	//--------------- GLOBAL MEMORY INTERFACE ----------------	
	reg  [GM_MEM_WIDTH-1:0] 	wGM_ReadData;
	wire  [GM_MEM_WIDTH-1:0] 	wGM_ReadData_Buffered;
	wire [GM_ADDR_WIDTH-1:0] 	wGM_ReadAddress;
	reg  [GM_MEM_WIDTH-1:0] 	wGM_WriteData;
	wire [GM_ADDR_WIDTH-1:0] 	wGM_WriteAddress;
			
	wire [LM_MEM_ADDR_WIDTH-1:0] wLM_ReadAddress_MEM = wLM_ReadAddress[LM_MEM_ADDR_WIDTH+LM_BYTE_ENABLES_WIDTH-1:LM_BYTE_ENABLES_WIDTH];
	wire [LM_MEM_ADDR_WIDTH-1:0] wLM_WriteAddress_MEM = wLM_WriteAddress[LM_MEM_ADDR_WIDTH+LM_BYTE_ENABLES_WIDTH-1:LM_BYTE_ENABLES_WIDTH];	
	wire [GM_ADDR_WIDTH-1:0] wGM_ReadAddress_MEM = {wGM_ReadAddress[GM_ADDR_WIDTH-1: GM_BYTE_ENABLES_WIDTH],{(GM_BYTE_ENABLES_WIDTH){1'b0}}};
	wire [GM_ADDR_WIDTH-1:0] wGM_WriteAddress_MEM = {wGM_WriteAddress[GM_ADDR_WIDTH-1: GM_BYTE_ENABLES_WIDTH],{(GM_BYTE_ENABLES_WIDTH){1'b0}}};
	wire [LM_BYTE_ENABLES_WIDTH-1:0] wLM_ReadAddressOffset;
	wire [LM_BYTE_ENABLES_WIDTH-1:0] wLM_WriteAddressOffset;				
	wire [GM_BYTE_ENABLES_WIDTH-1:0] wGM_ReadAddressOffset;
	wire [GM_BYTE_ENABLES_WIDTH-1:0] wGM_WriteAddressOffset;		
	reg [LM_BYTE_ENABLES-1:0] wLM_WriteEnable;
	reg [GM_BYTE_ENABLES-1:0] wGM_WriteEnable;
	
	reg [GM_BYTE_ENABLES_WIDTH-1:0] rGM_ReadAddressOffset;
	reg [LM_BYTE_ENABLES_WIDTH-1:0] rLM_ReadAddressOffset;
	
	wire [D_WIDTH-1:0] wInputs [NUM_INPUTS -1:0];
	wire [D_WIDTH-1:0] wOutputs [NUM_OUTPUTS-1:0];
	
	wire wRegisterOrPassOperation;

	wire wStore;
	wire wStoreImplicit;
	wire wLoadMemOrReg;
	wire wLoad;
	wire wLoadImplicit;
	
	wire wLoadGlobal;
	wire wStoreGlobal;
	wire wLoadGlobalImplicit;
	wire wStoreGlobalImplicit;
	
	wire wRegisterWrite;
	wire wRegisterRead;
	wire wPass;
		
	wire [REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:0] wRegFromOpcodeA;
	wire wTypeMSB;
	wire [DEST_WIDTH-1:0] wDest;
	wire [SRC_WIDTH-1:0]  wSrcA; //datasrc (with the exception of registers)
	wire [SRC_WIDTH-1:0]  wSrcB; //addrsrc		
	wire [REG_ADDR_WIDTH-1:0] wRegisterAddr;		
	wire [TYPE_WIDTH-1:0] wDataType;	
	wire wStall;

	reg [D_WIDTH-1:0] rConfigurationRegister [NUM_REGS-1:0];
	reg [TYPE_WIDTH-1:0] rDataType;

	wire wWriteGranted;
	wire wReadGranted;	
	
	// There are be several configuration registers:
	// 0  - Start_H					 \
	// 1  - Start_L					  | Register Set for the 
	// 2  - Stride			   		 /  Load implicit instructions
	
	// 3  - Start_H					 \
	// 4  - Start_L					  | Register Set for the 
	// 5  - Stride			   		 /  Store implicit instructions

	// 6:6+(GM_ADDR_WIDTH/D_WIDTH)-2 - Register for global Load address
	// 10:10+(GM_ADDR_WIDTH/D_WIDTH)-2 - Register for global Store address
	// 14: Local address High (Load)
	// 15: Local address High (Store)
		
	reg [D_WIDTH-1:0] rOutputs [NUM_OUTPUTS-1:0];
		
	reg rLoad;
	reg rLoadGlobal;
	reg rLoadImplicit;
	reg rLoadGlobalImplicit;
	
	reg rWaitForLoad;
	reg rWaitForStore;

	
	reg rStallForLoad;
	reg rStallForStore;

	reg rLoadGlobal_buffered;
	reg rLoadGlobalImplicit_buffered;

	reg rStoreGlobal_buffered;
	reg rStoreGlobalImplicit_buffered;


	`ifdef LOWLATENCY
		wire wLoadGlobal_buffered = (rLoadGlobal_buffered | wLoadGlobal);
		wire wLoadGlobalImplicit_buffered = (rLoadGlobalImplicit_buffered | wLoadGlobalImplicit);

		wire wStoreGlobal_buffered = (rStoreGlobal_buffered | wStoreGlobal);
		wire wStoreGlobalImplicit_buffered = (rStoreGlobalImplicit_buffered | wStoreGlobalImplicit);	
	`else
		wire wLoadGlobal_buffered = rLoadGlobal_buffered;
		wire wLoadGlobalImplicit_buffered = rLoadGlobalImplicit_buffered;

		wire wStoreGlobal_buffered = rStoreGlobal_buffered;
		wire wStoreGlobalImplicit_buffered = rStoreGlobalImplicit_buffered;		
	`endif

	reg [D_WIDTH-1:0] rGM_WriteData;
	reg [D_WIDTH-1:0] rGM_WriteAddress;
	reg [D_WIDTH-1:0] rGM_ReadAddress;

	reg rWriteGranted;
	reg rReadGranted;	
			
	reg rDest;	
		
	reg [CONFIG_WIDTH-1:0] rConfig;	
	
	//----------------------------------------
	//	SCAN CHAIN CONFIG CODE
	//----------------------------------------
			
	integer gCurrBit;
	always @(posedge iClk)
	begin
		if (iConfigEnable)
			begin
				rConfig[CONFIG_WIDTH-1] <= iConfigDataIn;
				
				for (gCurrBit=0; gCurrBit < CONFIG_WIDTH-1; gCurrBit = gCurrBit + 1)		
					rConfig[gCurrBit] <= rConfig[gCurrBit+1];
			end
	end
	
	assign oConfigDataOut = rConfig[0];
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------
		
		localparam STATE_LENGTH = D_WIDTH*NUM_OUTPUTS + GM_BYTE_ENABLES_WIDTH+D_WIDTH*NUM_REGS+TYPE_WIDTH+7;
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];
		//-----------------------------------------	
	`endif
	
	wire [STALL_GROUP_WIDTH-1:0] wStallGroup = rConfig[CONFIG_WIDTH-1:CONFIG_WIDTH-STALL_GROUP_WIDTH];	
	
	generate
		if (D_WIDTH == 8)
			begin
				assign wLM_ReadAddressOffset = 1'b0;
				assign wLM_WriteAddressOffset = 1'b0;				
				assign wGM_ReadAddressOffset = 1'b0;
				assign wGM_WriteAddressOffset = 1'b0;				
			end
		else
			begin
				assign wLM_ReadAddressOffset = wLM_ReadAddress[LM_BYTE_ENABLES_WIDTH-1:0];
				assign wLM_WriteAddressOffset = wLM_WriteAddress[LM_BYTE_ENABLES_WIDTH-1:0];				
				assign wGM_ReadAddressOffset = wGM_ReadAddress[GM_BYTE_ENABLES_WIDTH-1:0];
				assign wGM_WriteAddressOffset = wGM_WriteAddress[GM_BYTE_ENABLES_WIDTH-1:0];				
			end
	endgenerate
		
	//for global memory
	always @(iGM_ReadData or wInputs[wSrcA] or wGM_WriteAddressOffset or wDataType or wStoreGlobal or wStoreGlobalImplicit or wSrcA or rDataType or rGM_ReadAddressOffset)
	begin
		//these individual cases can be calculated (using CLogB2(x/8))for the datatype index but then Verilog complains				
		if (((wDataType==2'b00 & (wStoreGlobal | wStoreGlobalImplicit)) | (rDataType==2'b00  & !(wStoreGlobal | wStoreGlobalImplicit))) &  D_WIDTH >= 8) //byte
			begin
				wGM_WriteData = ((wStoreGlobal | wStoreGlobalImplicit) ? wInputs[wSrcA][MIN(8,D_WIDTH)-1:0] : rGM_WriteData[MIN(8,D_WIDTH)-1:0]) << {wGM_WriteAddressOffset,3'b0};
				wGM_WriteEnable = (1'b1 << wGM_WriteAddressOffset) & {GM_BYTE_ENABLES{(wStoreGlobal_buffered | wStoreGlobalImplicit_buffered)}};
			end				
		else if (((wDataType==2'b01 & (wStoreGlobal | wStoreGlobalImplicit)) | (rDataType==2'b01  & !(wStoreGlobal | wStoreGlobalImplicit))) &  D_WIDTH >= 16) //hword
			begin
				wGM_WriteData = ((wStoreGlobal | wStoreGlobalImplicit) ? wInputs[wSrcA][MIN(16,D_WIDTH)-1:0] : rGM_WriteData[MIN(16,D_WIDTH)-1:0]) << {wGM_WriteAddressOffset,3'b0};
				wGM_WriteEnable = (2'b11 << wGM_WriteAddressOffset) & {GM_BYTE_ENABLES{(wStoreGlobal_buffered | wStoreGlobalImplicit_buffered)}};
			end				
		else if (((wDataType==2'b10 & (wStoreGlobal | wStoreGlobalImplicit)) | (rDataType==2'b10  & !(wStoreGlobal | wStoreGlobalImplicit))) &  D_WIDTH >= 32) //word
			begin
				wGM_WriteData = ((wStoreGlobal | wStoreGlobalImplicit) ? wInputs[wSrcA][MIN(32,D_WIDTH)-1:0] : rGM_WriteData[MIN(32,D_WIDTH)-1:0]) << {wGM_WriteAddressOffset,3'b0};
				wGM_WriteEnable = (4'b1111 << wGM_WriteAddressOffset) & {GM_BYTE_ENABLES{(wStoreGlobal_buffered | wStoreGlobalImplicit_buffered)}};
			end			
		else if (((wDataType==2'b11 & (wStoreGlobal | wStoreGlobalImplicit)) | (rDataType==2'b1  & !(wStoreGlobal | wStoreGlobalImplicit))) & D_WIDTH >= 64) //dword
			begin
				wGM_WriteData = ((wStoreGlobal | wStoreGlobalImplicit) ? wInputs[wSrcA][MIN(64,D_WIDTH)-1:0] : rGM_WriteData[MIN(64,D_WIDTH)-1:0]) << {wGM_WriteAddressOffset,3'b0};
				wGM_WriteEnable = (8'b1111_1111 << wGM_WriteAddressOffset) & {GM_BYTE_ENABLES{(wStoreGlobal_buffered | wStoreGlobalImplicit_buffered)}};
			end
		else
			begin
				wGM_WriteData = {(GM_MEM_WIDTH){1'b0}};
				wGM_WriteEnable = {(GM_BYTE_ENABLES){1'b0}};
			end
			
		//these individual cases can be calculated (using CLogB2(x/8))for the datatype index but then Verilog complains				
		if (rDataType==2'b00 &  D_WIDTH >= 8) //byte
			begin
				wGM_ReadData = {{(MIN(GM_MEM_WIDTH-8,1)){1'b0}},iGM_ReadData[rGM_ReadAddressOffset*(GM_MEM_WIDTH/GM_BYTE_ENABLES)+:8]};																					
			end				
		else if (rDataType==2'b01 &  D_WIDTH >= 16) //hword
			begin
				wGM_ReadData = {{(MIN(GM_MEM_WIDTH-16,1)){1'b0}},iGM_ReadData[rGM_ReadAddressOffset*(GM_MEM_WIDTH/GM_BYTE_ENABLES)+:16]};
			end				
		else if (rDataType==2'b10 &  D_WIDTH >= 32) //word
			begin
				wGM_ReadData = {{(MIN(GM_MEM_WIDTH-32,1)){1'b0}},iGM_ReadData[rGM_ReadAddressOffset*(GM_MEM_WIDTH/GM_BYTE_ENABLES)+:32]};
			end			
		else if (rDataType==2'b11 & D_WIDTH >= 64) //dword
			begin
				wGM_ReadData = {{(MIN(GM_MEM_WIDTH-64,1)){1'b0}},iGM_ReadData[rGM_ReadAddressOffset*(GM_MEM_WIDTH/GM_BYTE_ENABLES)+:64]};							
			end
		else
			begin
				wGM_ReadData = {(GM_MEM_WIDTH){1'b0}};
			end			
	end
	
	//for global memory
	always @(iLM_ReadData or wInputs[wSrcA] or wLM_WriteAddressOffset or wDataType or wStore or wStoreImplicit or wSrcA or rDataType or rLM_ReadAddressOffset)
	begin
		//these individual cases can be calculated (using CLogB2(x/8))for the datatype index but then Verilog complains
		if (wDataType==2'b00 & D_WIDTH >= 8) //byte
			begin
				wLM_WriteData = wInputs[wSrcA][MIN(8,D_WIDTH)-1:0] << {wLM_WriteAddressOffset,3'b0};
				wLM_WriteEnable = (1'b1 << wLM_WriteAddressOffset) & {LM_BYTE_ENABLES{(wStore | wStoreImplicit)}};
			end
		else if (wDataType==2'b01 & D_WIDTH >= 16) //hword
			begin
				wLM_WriteData = wInputs[wSrcA][MIN(16,D_WIDTH)-1:0] << {wLM_WriteAddressOffset,3'b0};
				wLM_WriteEnable = (2'b11 << wLM_WriteAddressOffset) & {LM_BYTE_ENABLES{(wStore | wStoreImplicit)}};
			end
		else if (wDataType==2'b10 & D_WIDTH >= 32) //word
			begin
				wLM_WriteData = wInputs[wSrcA][MIN(32,D_WIDTH)-1:0] << {wLM_WriteAddressOffset,3'b0};
				wLM_WriteEnable = (4'b1111 << wLM_WriteAddressOffset) & {LM_BYTE_ENABLES{(wStore | wStoreImplicit)}};
			end				
		else if (wDataType==2'b11 & D_WIDTH >= 64) //dword
			begin
				wLM_WriteData = wInputs[wSrcA][MIN(64,D_WIDTH)-1:0] << {wLM_WriteAddressOffset,3'b0};
				wLM_WriteEnable = (8'b1111_1111 << wLM_WriteAddressOffset) & {LM_BYTE_ENABLES{(wStore | wStoreGlobal)}};
			end
		else
			begin
				wLM_WriteData = {(LM_MEM_WIDTH){1'b0}};
				wLM_WriteEnable = {(LM_BYTE_ENABLES){1'b0}};
			end						
			
		//these individual cases can be calculated (using CLogB2(x/8))for the datatype index but then Verilog complains
		if (rDataType==2'b00 & D_WIDTH >= 8) //byte
			begin
				wLM_ReadData = {{(MIN(LM_MEM_WIDTH-8,1)){1'b0}},iLM_ReadData[rLM_ReadAddressOffset*(LM_MEM_WIDTH/LM_BYTE_ENABLES)+:8]};																					
			end
		else if (rDataType==2'b01 & D_WIDTH >= 16) //hword
			begin
				wLM_ReadData = {{(MIN(LM_MEM_WIDTH-16,1)){1'b0}},iLM_ReadData[rLM_ReadAddressOffset*(LM_MEM_WIDTH/LM_BYTE_ENABLES)+:16]};
			end
		else if (rDataType==2'b10 & D_WIDTH >= 32) //word
			begin
				wLM_ReadData = {{(MIN(LM_MEM_WIDTH-32,1)){1'b0}},iLM_ReadData[rLM_ReadAddressOffset*(LM_MEM_WIDTH/LM_BYTE_ENABLES)+:32]};
			end				
		else if (rDataType==2'b11 & D_WIDTH >= 64) //dword
			begin
				wLM_ReadData = {{(MIN(LM_MEM_WIDTH-64,1)){1'b0}},iLM_ReadData[rLM_ReadAddressOffset*(LM_MEM_WIDTH/LM_BYTE_ENABLES)+:64]};							
			end
		else
			begin
				wLM_ReadData = {(LM_MEM_WIDTH){1'b0}};
			end					
	end
		
	assign oLM_ReadAddress = wLM_ReadAddress_MEM;
	assign oLM_WriteAddress = wLM_WriteAddress_MEM;
	assign oGM_ReadAddress = wGM_ReadAddress_MEM;
	assign oGM_WriteAddress = wGM_WriteAddress_MEM;
	
	assign oLM_WriteData = wLM_WriteData;
	assign oGM_WriteData = wGM_WriteData;

	assign oLM_WriteEnable = wLM_WriteEnable;
	assign oLM_ReadEnable = (wLoad | wLoadImplicit);
	assign oGM_WriteEnable = wGM_WriteEnable;
		
	assign oGM_ReadRequest = wLoadGlobal_buffered | wLoadGlobalImplicit_buffered;
	assign oGM_WriteRequest = wStoreGlobal_buffered | wStoreGlobalImplicit_buffered;

	assign wWriteGranted = (rWriteGranted & !(wStoreGlobal | wStoreGlobalImplicit)) | iGM_WriteGrantNextCycle;
	assign wReadGranted = (rReadGranted & !(wLoadGlobal | wLoadGlobalImplicit)) | iGM_ReadGrantNextCycle;

	assign wStall = (((rStallForLoad | wLoadGlobal | wLoadGlobalImplicit) & !wReadGranted) | ((rStallForStore | wStoreGlobal | wStoreGlobalImplicit) & !wWriteGranted)); 	
	
	assign oStall = (wStall) << wStallGroup;

	//assign decoded instruction input to the control wires
	assign wRegisterAddr = {wRegFromOpcodeA,wDest,wSrcB};
	assign wDataType = {wTypeMSB, wRegFromOpcodeA[0]}; //REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:0
	assign {wTypeMSB, wRegFromOpcodeA, wRegisterOrPassOperation, wLoadGlobalImplicit, wLoadGlobal, wLoadImplicit, wLoadMemOrReg, wStoreGlobalImplicit, wStoreGlobal, wStoreImplicit,wStore, wDest, wSrcB, wSrcA} = iDecodedInstruction[LSU_DECODED_WIDTH-1:0];
		
	assign wLoad = wLoadMemOrReg & !wRegisterOrPassOperation;	
	assign wPass = wRegisterOrPassOperation & wDataType[1];
	assign wRegisterWrite = wRegisterOrPassOperation & !wDataType[1] & !wLoadMemOrReg;
	assign wRegisterRead = wRegisterOrPassOperation & !wDataType[1] & wLoadMemOrReg;						
	
	//construct the addresses out of registers and addresses on the input (for lower datapath widths) or use input directly
	genvar gBuildAddress;
	generate
		//for local addresses
		if (LM_ADDR_REGS_REQ == 0) //datapath is wide enough for direct addressing
			begin
				assign wLM_ReadAddress[LM_ADDR_WIDTH-1:0] = (wLoad) ? wInputs[wSrcB][LM_WRITE_WIDTH-1:0] : ((wLoadImplicit) ? rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+1][LM_WRITE_WIDTH-1:0] : 1'b0);	
				assign wLM_WriteAddress[LM_ADDR_WIDTH-1:0] = (wStore) ? wInputs[wSrcB][LM_WRITE_WIDTH-1:0] : ((wStoreImplicit) ? rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+1][LM_WRITE_WIDTH-1:0] : 1'b0);	
			end
		else //needs concatenating with registers for addressing
			begin							
				for (gBuildAddress=0; gBuildAddress < LM_ADDR_REGS_REQ; gBuildAddress=gBuildAddress+1)
				begin : BuildAddress
					assign wLM_ReadAddress[LM_ADDR_WIDTH-gBuildAddress*D_WIDTH-1:LM_ADDR_WIDTH-(gBuildAddress+1)*D_WIDTH] = (wLoad) ? (rConfigurationRegister[gBuildAddress+LM_ADDR_REGS_OFFSET]) : ((wLoadImplicit) ? rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+NUM_REGS_LM_ADDR-LM_ADDR_REGS_REQ+gBuildAddress-1] : {(D_WIDTH){1'b0}});
					assign wLM_WriteAddress[LM_ADDR_WIDTH-gBuildAddress*D_WIDTH-1:LM_ADDR_WIDTH-(gBuildAddress+1)*D_WIDTH] = (wStore) ? (rConfigurationRegister[gBuildAddress+LM_ADDR_REGS_REQ+LM_ADDR_REGS_OFFSET]) : ((wStoreImplicit) ? rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+NUM_REGS_LM_ADDR-LM_ADDR_REGS_REQ+gBuildAddress-1] :{(D_WIDTH){1'b0}});
				end
				
				//for implicit loads use the lowest register, for direct loads use an input
				assign wLM_ReadAddress[LM_WRITE_WIDTH-1:0] = (wLoad) ? wInputs[wSrcB] : ((wLoadImplicit) ? rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+NUM_REGS_LM_ADDR-1][LM_WRITE_WIDTH-1:0] : {(D_WIDTH){1'b0}});
				assign wLM_WriteAddress[LM_WRITE_WIDTH-1:0] = (wStore) ? wInputs[wSrcB] : ((wStoreImplicit) ? rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+NUM_REGS_LM_ADDR-1][LM_WRITE_WIDTH-1:0] : {(D_WIDTH){1'b0}});
			end
			
		//For global addresses
		if (GM_ADDR_REGS_REQ-1 == 0) //datapath is wide enough for direct addressing
			begin 
				assign wGM_ReadAddress[GM_ADDR_WIDTH-1:0] = (wLoadGlobal_buffered) ? (wLoadGlobal ? wInputs[wSrcB][GM_WRITE_WIDTH-1:0] : rGM_ReadAddress[GM_WRITE_WIDTH-1:0]) : ((wLoadGlobalImplicit_buffered) ? rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3][GM_WRITE_WIDTH-1:0] :{(D_WIDTH){1'b0}});
				assign wGM_WriteAddress[GM_ADDR_WIDTH-1:0] = (wStoreGlobal_buffered) ? (wStoreGlobal ? wInputs[wSrcB][GM_WRITE_WIDTH-1:0] : rGM_WriteAddress[GM_WRITE_WIDTH-1:0]) : ((wStoreGlobalImplicit_buffered) ? rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3][GM_WRITE_WIDTH-1:0] :{(D_WIDTH){1'b0}});
			end
		else //needs concatenating with registers for addressing
			begin							
				for (gBuildAddress=0; gBuildAddress < GM_ADDR_REGS_REQ-1; gBuildAddress=gBuildAddress+1)
				begin : BuildAddress
					assign wGM_ReadAddress[GM_ADDR_WIDTH-gBuildAddress*D_WIDTH-1:GM_ADDR_WIDTH-(gBuildAddress+1)*D_WIDTH] = (wLoadGlobal_buffered) ? (rConfigurationRegister[gBuildAddress+GM_ADDR_REGS_OFFSET]) : ((wLoadGlobalImplicit_buffered) ? rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+NUM_REGS_GM_ADDR-GM_ADDR_REGS_REQ+gBuildAddress-1][GM_WRITE_WIDTH-1:0] :{(D_WIDTH){1'b0}});
					assign wGM_WriteAddress[GM_ADDR_WIDTH-gBuildAddress*D_WIDTH-1:GM_ADDR_WIDTH-(gBuildAddress+1)*D_WIDTH] = (wStoreGlobal_buffered) ? (rConfigurationRegister[gBuildAddress+GM_ADDR_REGS_REQ+GM_ADDR_REGS_OFFSET]) : ((wStoreGlobalImplicit_buffered) ? rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+NUM_REGS_GM_ADDR-GM_ADDR_REGS_REQ+gBuildAddress-1][GM_WRITE_WIDTH-1:0] :{(D_WIDTH){1'b0}});
				end
				
				//for implicit loads use the lowest register, for direct loads use an input
				assign wGM_ReadAddress[GM_WRITE_WIDTH-1:0] = (wLoadGlobal_buffered) ? wInputs[wSrcB] : ((wLoadGlobalImplicit_buffered) ? (rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+NUM_REGS_GM_ADDR-1]) : {(D_WIDTH){1'b0}});
				assign wGM_WriteAddress[GM_WRITE_WIDTH-1:0] = (wStoreGlobal_buffered) ? wInputs[wSrcB] : ((wStoreGlobalImplicit_buffered) ? (rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+NUM_REGS_GM_ADDR-1]):{(D_WIDTH){1'b0}});
			end
	endgenerate	

	DATA_Buffer #(.WIDTH(D_WIDTH)) buffer_lsu_LM(.iData(wLM_ReadData), .oData(wLM_ReadData_Buffered));
	DATA_Buffer #(.WIDTH(D_WIDTH)) buffer_lsu_GM(.iData(wGM_ReadData), .oData(wGM_ReadData_Buffered));

	//unpack inputs and pack outputs, required since verilog does not allow 'arrays' as inputs or outputs for modules		
	genvar gConnectPorts;
	generate
		for (gConnectPorts=0; gConnectPorts < NUM_INPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Inputs
				assign wInputs[gConnectPorts] = iInputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH];
			end

		//data selection between data stored in registers and data just coming out of RAM, used to  make data available after 1 cycle and allowing BRAM inference for FPGA
		for (gConnectPorts=0; gConnectPorts < NUM_OUTPUTS; gConnectPorts = gConnectPorts + 1)
			begin : Outputs									
				assign wOutputs[gConnectPorts] = (gConnectPorts==rDest & (rLoad | rLoadImplicit | ((rLoadGlobalImplicit |  rLoadGlobal) & iGM_ReadDataValid))) ? ((rLoadGlobal | rLoadGlobalImplicit) ? wGM_ReadData_Buffered : wLM_ReadData_Buffered) : rOutputs[gConnectPorts];	
				assign oOutputs[(gConnectPorts+1)*D_WIDTH-1 : gConnectPorts*D_WIDTH] = wOutputs[gConnectPorts];
			end			
	endgenerate

	integer rStateCopy;
	integer gCurrStateBit;
	
	always @(posedge iClk)
	begin				
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled					
		if (!iNewStateIn)
			begin					
		`endif
			if (iReset)
				begin
					rLoad <= 0;
					rLoadGlobal <= 0;
					rLoadImplicit <= 0;
					rLoadGlobalImplicit <= 0;		
					rDest <= 0;
					rWaitForLoad <= 0;
					rWaitForStore <= 0;					
					rStallForLoad <= 0;						
					rStallForStore <= 0;	

					rLoadGlobal_buffered <= 0;
					rLoadGlobalImplicit_buffered <= 0;
					rStoreGlobal_buffered <= 0;
					rStoreGlobalImplicit_buffered <= 0;

					rWriteGranted <= 1'b0;
					rReadGranted <= 1'b0;					
				end
			else 
				begin
					rLoad <= wLoad;		
					rLoadImplicit <= wLoadImplicit;		
						
					//--------------------------------------------------------
					if (wLoadGlobal & !iGM_ReadGrantNextCycle)
						rLoadGlobal_buffered <= 1'b1;

					if (wLoadGlobalImplicit & !iGM_ReadGrantNextCycle)
						rLoadGlobalImplicit_buffered <= 1'b1;

					if ((iGM_ReadGrantNextCycle & !(wLoadGlobal | wLoadGlobalImplicit)) | iReset)
						begin
							rLoadGlobal_buffered <= 1'b0;
							rLoadGlobalImplicit_buffered <= 1'b0;
						end

					if (wStoreGlobal & !iGM_WriteGrantNextCycle)
						rStoreGlobal_buffered <= 1'b1;

					if (wStoreGlobalImplicit & !iGM_WriteGrantNextCycle)
						rStoreGlobalImplicit_buffered <= 1'b1;

					if ((iGM_WriteGrantNextCycle & !(wStoreGlobal | wStoreGlobalImplicit)) | iReset)
						begin
							rStoreGlobal_buffered <= 1'b0;
							rStoreGlobalImplicit_buffered <= 1'b0;
						end						
					//--------------------------------------------------------
					if (wLoadGlobal | wLoadGlobalImplicit)
						begin
							rReadGranted <= 1'b0;	
							rWaitForLoad <= 1;
							rDest <= wDest;
							rDataType <= wDataType;	

							if (!iGM_ReadGrantNextCycle)
								rStallForLoad <= 1;							
						end
					else
						if (iGM_ReadGrantNextCycle)
							rReadGranted <= 1'b1;							

					if (wStoreGlobal | wStoreGlobalImplicit)
						begin
							rWriteGranted <= 1'b0;	
							rWaitForStore <= 1;
							rGM_WriteData <= wInputs[wSrcA];	
							rDataType <= wDataType;
							
							if (!iGM_WriteAccept)
								rStallForStore <= 1;								
						end
					else
						if (iGM_WriteGrantNextCycle)
							rWriteGranted <= 1'b1;						
					//-------------------------------------------------------
									
					if (wLoad | wLoadImplicit)
						begin
							rLM_ReadAddressOffset <= wLM_ReadAddressOffset;
							rDest <= wDest;
							rDataType <= wDataType;
						end
						
					if (iGM_ReadDataValid & !(wLoadGlobal | wLoadGlobalImplicit))					
							rWaitForLoad <= 0;		

					
					if (iGM_ReadGrantNextCycle)					
						rStallForLoad <= 0;		
						
					if (iGM_WriteAccept)
						begin
							rWaitForStore <= 0;							
							rStallForStore <= 0;							
						end						

					if (wLoadGlobal)
						rGM_ReadAddress <= wInputs[wSrcB];

					if (wStoreGlobal)
						rGM_WriteAddress <= wInputs[wSrcB];

					if (wLoadGlobal_buffered | wLoadGlobalImplicit_buffered)
						rGM_ReadAddressOffset <= wGM_ReadAddressOffset;

					if (wLoadGlobal | wLoadGlobalImplicit | iGM_ReadDataValid)
						begin
							rLoadGlobal <= wLoadGlobal;
							rLoadGlobalImplicit <= wLoadGlobalImplicit;	
						end
					if ((rWaitForLoad & iGM_ReadDataValid) & !((wPass | wRegisterRead) & wDest == rDest))
						begin
							rOutputs[rDest] <= wGM_ReadData;
						end
											
					if (wRegisterWrite)
						rConfigurationRegister[wRegisterAddr] <= wInputs[wSrcA];
						
					if (wRegisterRead)
						 rOutputs[NUM_OUTPUTS-1] <= rConfigurationRegister[wRegisterAddr];
						
					if (wPass)
						rOutputs[wDest] <= wInputs[wSrcA];
				
					if ((rLoad | rLoadImplicit)	& !((wPass | wRegisterRead) & wDest == rDest))
						rOutputs[rDest] <= wLM_ReadData;

					//construct the various implicit register counters for different widths. Might be done nicer with a for loop but ... time
					if (wLoadImplicit)
						if (D_WIDTH == 8)
							{rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+1]} 
							<= 
							{rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+1]} 
							+ 
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+2];
						else
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+1] <= rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+1] + rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+2];
					
					if (wStoreImplicit)
						if (D_WIDTH == 8)
							{rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+1]} 
							<= 
							{rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+1]} 
							+
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+2];
						else
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+1] <= rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+1] + rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+2];
							
					if (wLoadGlobalImplicit_buffered & iGM_ReadGrantNextCycle)
						if (D_WIDTH == 8)
							{rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+1],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3]} 
							<= 
							{rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+1],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3]} 
							+ 
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+2];
						else if (D_WIDTH == 16)
							{rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3]} 
							<= 
							{rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3]} 
							+ 
							rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+2];				
						else
							rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3] <= rConfigurationRegister[CONFIG_GLOBAL_LOAD_IMPLICIT_OFFSET+3] + rConfigurationRegister[CONFIG_LOAD_IMPLICIT_OFFSET+2];				
							
					if (wStoreGlobalImplicit_buffered &  & iGM_WriteGrantNextCycle)
						if (D_WIDTH == 8)
							{rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+1],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3]} 
							<= 
							{rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+0],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+1],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3]} 
							+ 
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+2];
						else if (D_WIDTH == 16)
							{rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3]} 
							<= 
							{rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+2],
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3]} 
							+ 
							rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+2];				
						else
							rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3] <= rConfigurationRegister[CONFIG_GLOBAL_STORE_IMPLICIT_OFFSET+3] + rConfigurationRegister[CONFIG_STORE_IMPLICIT_OFFSET+2];				
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
			end			
		else
			begin						
				rLoad <= rState[0];
				rLoadGlobal <= rState[1];
				rLoadImplicit <= rState[2];
				rLoadGlobalImplicit <= rState[3];
	
				rWaitForLoad <= rState[4];
				rWaitForStore <= rState[5];		
				rDest <= rState[6];	
								
				rGM_ReadAddressOffset <= rState[7+GM_BYTE_ENABLES_WIDTH-1:7];
				rDataType <= rState[7 + GM_BYTE_ENABLES_WIDTH + TYPE_WIDTH -1:7+GM_BYTE_ENABLES_WIDTH];
							
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rOutputs[rStateCopy] <= rState[(rStateCopy+1)*D_WIDTH + STATE_OUTPUTS_OFFSET -:D_WIDTH ];

				for (rStateCopy =0; rStateCopy < NUM_REGS; rStateCopy = rStateCopy + 1)
					rConfigurationRegister[rStateCopy] <= rState[(rStateCopy+1)*D_WIDTH + STATE_REGS_OFFSET -:D_WIDTH ];
			end
			
		if (iOldStateOut)
			begin				
				rState[0] <= rLoad;
				rState[1] <= rLoadGlobal;
				rState[2] <= rLoadImplicit;
				rState[3] <= rLoadGlobalImplicit;
	
				rState[4] <= rWaitForLoad;
				rState[5] <= rWaitForStore;		
				rState[6] <= rDest;	
								
				rState[7+GM_BYTE_ENABLES_WIDTH-1:7] <= rGM_ReadAddressOffset;
				rState[7+GM_BYTE_ENABLES_WIDTH +TYPE_WIDTH-1:7+GM_BYTE_ENABLES_WIDTH] <= rDataType;
							
				for (rStateCopy =0; rStateCopy < NUM_OUTPUTS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*D_WIDTH + STATE_OUTPUTS_OFFSET -:D_WIDTH ] <= rOutputs[rStateCopy];

				for (rStateCopy =0; rStateCopy < NUM_REGS; rStateCopy = rStateCopy + 1)
					rState[(rStateCopy+1)*D_WIDTH + STATE_REGS_OFFSET -:D_WIDTH ] <= rConfigurationRegister[rStateCopy];				
			end
		
		if (iStateShift)
			begin
				rState[STATE_LENGTH-1] <= iStateDataIn;
				
				for (gCurrStateBit=0; gCurrStateBit < STATE_LENGTH-1; gCurrStateBit = gCurrStateBit + 1)		
					rState[gCurrStateBit] <= rState[gCurrStateBit+1];
			end	
		`endif
	end	
	
	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------
	
	// cadence translate_off
	// synthesis translate_off
	`ifdef DUMP_DEBUG_FILES
	integer f;
	integer x;
	
	initial begin
	  f = $fopen({"LSU_out_",TEST_ID,".txt"},"w");
		for (x=0; x < NUM_OUTPUTS; x = x + 1)
			$fwrite(f,"output[%2d]\t",x);		
		$fwrite(f,"\n");			 								
	
	  @(negedge iReset); //Wait for reset to be released
	  
	  forever
	  begin
		  @(posedge iClk)
		  begin	
				for (x=0; x < NUM_OUTPUTS; x = x + 1)
					$fwrite(f,"%b\t", wOutputs[x]);			 								
		  end
		  $fwrite(f,"\n");			 								
	  end

	  $fclose(f);  
	end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	//	--------------------------------------------------------------------------------------------------				

endmodule