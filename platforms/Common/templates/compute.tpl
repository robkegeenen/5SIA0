`timescale 1 ns / 1 ns

`include "config.vh"

module <<MODULE_NAME>>
#
(
	parameter D_WIDTH = <<D_WIDTH>>,	
	parameter I_WIDTH = <<I_WIDTH>>,
	parameter I_IMM_WIDTH = <<I_IMM_WIDTH>>,
	parameter I_DECODED_WIDTH = <<DECODED_WIDTH>>,
	
	parameter LM_ADDR_WIDTH = <<LM_ADDR_WIDTH>>,
	parameter GM_ADDR_WIDTH = <<GM_ADDR_WIDTH>>,	
	parameter IM_ADDR_WIDTH = <<IM_ADDR_WIDTH>>,

	parameter IM_MEM_ADDR_WIDTH = <<IM_DEPTH_WIDTH>>,	
	parameter LM_MEM_ADDR_WIDTH = <<LM_DEPTH_WIDTH>>,	
	
	parameter LM_MEM_WIDTH = <<LM_MEM_WIDTH>>,
	parameter GM_MEM_WIDTH = <<GM_MEM_WIDTH>>,
	
	parameter NUM_ID = <<NUM_ID>>,
	parameter NUM_IMM = <<NUM_IMM>>,
	parameter NUM_LOCAL_DMEM = <<NUM_LDMEM>>,
	parameter NUM_GLOBAL_DMEM = <<NUM_GDMEM>>,

	parameter NUM_STALL_GROUPS = <<NUM_STALL_GROUPS>>	
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
	
	localparam SRC_WIDTH = <<SRC_WIDTH>>;
	localparam DEST_WIDTH = <<DEST_WIDTH>>;	
	localparam REG_ADDR_WIDTH = <<REG_WIDTH>>;
		
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

<<WOR_WIRES>>
	genvar gCurrStall;
	generate
		for (gCurrStall=0; gCurrStall < NUM_STALL_GROUPS; gCurrStall = gCurrStall + 1)
			begin : stallGroups
<<WOR_ASSIGNS>>
			end
	endgenerate

	<<ID_wires>>
	<<ID_INS_wires>>
	<<ID_DECODED_INS_wires>>

	<<IU_wires>>
	<<IU_INS_wires>>

	//data wires 
	<<DATA_wires>>

	//control wires 
	<<CONTROL_wires>>
	
	//configuration wires
	<<CONFIG_wires>>

	//Carrychain wires
	<<CARRY_WIRES>>

	//assigns for global memories
	assign oGM_WriteEnable = {<<GM_WE>>};
	assign oGM_WriteAddress = {<<GM_WA>>};
	assign oGM_WriteData = {<<GM_WD>>};	
	assign oGM_ReadAddress = {<<GM_RA>>};
	assign oGM_ReadRequest = {<<GM_RR>>};
	assign oGM_WriteRequest = {<<GM_WR>>};
	assign {<<GM_RD>>} = iGM_ReadData;
	assign {<<GM_RV>>} = iGM_ReadDataValid;
	assign {<<GM_WACC>>} = iGM_WriteAccept;
	//`ifdef NATIVE_GM_INTERFACE
		assign {<<GM_RGNC>>} = iGM_ReadGrantNextCycle;
		assign {<<GM_WGNC>>} = iGM_WriteGrantNextCycle;
	//`endif
	
	//assigns for local memories
	assign oLM_WriteEnable = {<<LM_WE>>};
	assign oLM_ReadEnable = {<<LM_RE>>};
	assign oLM_WriteAddress = {<<LM_WA>>};
	assign oLM_WriteData = {<<LM_WD>>};	
	assign oLM_ReadAddress = {<<LM_RA>>};
	assign {<<LM_RD>>} = iLM_ReadData;

	//assigns for instruction memories
	assign oIM_ReadAddress = {<<IM_RA>>};
	assign oIM_ReadEnable = {<<IM_RE>>};
	assign {<<IM_RD>>} = iIM_ReadData;	

	//assign for halting
	assign oHalted = wHalted;
	assign oStall = wStall;
	
	//----------------------------------
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled					
		<<STATE_WIRES>>
	`else
		wire iStateSwitchHalt = 0;
	`endif	

    //instruction decode units
<<DECODERS>>
			
endmodule


