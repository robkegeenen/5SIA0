`timescale 1 ns / 1 ns

`include "config.vh"

module CGRA_Core
#
(
	parameter D_WIDTH = 32,	
	parameter I_WIDTH = 12,
	parameter I_IMM_WIDTH=33,
	parameter I_DECODED_WIDTH = 16,

	parameter INTERFACE_WIDTH = 32,
	parameter INTERFACE_ADDR_WIDTH = 32,
	parameter INTERFACE_BLOCK_WIDTH = 5,
	
	parameter LM_ADDR_WIDTH = 16,
	parameter GM_ADDR_WIDTH = 32,	
	parameter IM_ADDR_WIDTH = 16,	
	
	parameter LM_MEM_ADDR_WIDTH = 8,
	parameter IM_MEM_ADDR_WIDTH = 8,	

	parameter LM_MEM_WIDTH = 32,
	parameter GM_MEM_WIDTH = 32,
	
	parameter NUM_ID = 10,
	parameter NUM_IMM = 3,
	
	parameter NUM_LOCAL_DMEM = 2,
	parameter NUM_GLOBAL_DMEM = 2
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
			
	`ifndef NATIVE_GM_INTERFACE			
		//DTL interface for the global memory (MASTER)
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
	output oDTL_SMEM_ReadAccept
);

	localparam INTERFACE_NUM_ENABLES = (INTERFACE_WIDTH / 8);	
	localparam LM_NUM_ENABLES = (LM_MEM_WIDTH / 8);

	//for local memories
	wire [NUM_LOCAL_DMEM*LM_NUM_ENABLES-1:0] wLM_WriteEnable_packed;
	wire [NUM_LOCAL_DMEM-1:0] wLM_ReadEnable_packed;
	wire [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] wLM_WriteAddress_packed;
	wire [NUM_LOCAL_DMEM*D_WIDTH-1:0] wLM_WriteData_packed;	
	wire [NUM_LOCAL_DMEM*LM_ADDR_WIDTH-1:0] wLM_ReadAddress_packed;
	wire [NUM_LOCAL_DMEM*D_WIDTH-1:0] wLM_ReadData_packed;

	wire [NUM_LOCAL_DMEM*LM_MEM_ADDR_WIDTH-1:0] wLM_WriteAddress_repacked;
	wire [NUM_LOCAL_DMEM*LM_MEM_ADDR_WIDTH-1:0] wLM_ReadAddress_repacked;
	
	//for instruction memories
	wire [(NUM_IMM+NUM_ID)*IM_ADDR_WIDTH-1:0] wIM_ReadAddress_packed;
	wire [NUM_IMM*I_IMM_WIDTH+NUM_ID*I_WIDTH-1:0] wIM_ReadData_packed;
	wire [(NUM_IMM+NUM_ID)*IM_MEM_ADDR_WIDTH-1:0] wIM_ReadAddress_repacked;
	wire [(NUM_IMM+NUM_ID)-1:0] wIM_ReadEnable_packed;

	wire [NUM_IMM+NUM_ID-1:0] wIM_WriteEnable;
	wire [IM_MEM_ADDR_WIDTH-1:0] wIM_WriteAddress;
	wire [I_WIDTH-1:0] wIM_WriteData;	
	wire [I_IMM_WIDTH-1:0] wIM_WriteData_IMM;	
	
	genvar gCurrMem;
	generate
		for (gCurrMem=0; gCurrMem < NUM_LOCAL_DMEM; gCurrMem = gCurrMem + 1)
		begin : LocalMemory									
			assign wLM_WriteAddress_repacked[(gCurrMem+1)*LM_MEM_ADDR_WIDTH-1 : gCurrMem*LM_MEM_ADDR_WIDTH] = wLM_WriteAddress_packed[(gCurrMem*LM_ADDR_WIDTH)+LM_MEM_ADDR_WIDTH-1 : gCurrMem*LM_ADDR_WIDTH];
			assign  wLM_ReadAddress_repacked[(gCurrMem+1)*LM_MEM_ADDR_WIDTH-1 : gCurrMem*LM_MEM_ADDR_WIDTH] =  wLM_ReadAddress_packed[(gCurrMem*LM_ADDR_WIDTH)+LM_MEM_ADDR_WIDTH-1 : gCurrMem*LM_ADDR_WIDTH];			
		end
		
		for (gCurrMem=0; gCurrMem < NUM_ID+NUM_IMM; gCurrMem = gCurrMem + 1)
		begin : IDMemory									
			assign  wIM_ReadAddress_repacked[(gCurrMem+1)*IM_MEM_ADDR_WIDTH-1 : gCurrMem*IM_MEM_ADDR_WIDTH] =  wIM_ReadAddress_packed[(gCurrMem*IM_ADDR_WIDTH)+IM_MEM_ADDR_WIDTH-1 : gCurrMem*IM_ADDR_WIDTH];			
		end				
	endgenerate
				
	`ifdef ASIC_SYNTHESIS 	
	`ifndef SYN_MEM
	CGRA_Compute_Wrapper_WR
	`else
	CGRA_Compute_Wrapper	
	`endif
	`else	
	CGRA_Compute_Wrapper	
	`endif
	`ifndef ASIC_SYNTHESIS
	#(
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH),
	
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
		.NUM_IMM(NUM_IMM),
		.NUM_LOCAL_DMEM(NUM_LOCAL_DMEM),
		.NUM_GLOBAL_DMEM(NUM_GLOBAL_DMEM)	
	)
	`endif
	`ifdef ASIC_SYNTHESIS 
	`ifndef SYN_MEM
		CGRA_Compute_Wrapper_WR_inst
	`else
	`endif
		CGRA_Compute_Wrapper_inst
	`else
		CGRA_Compute_Wrapper_inst
	`endif
	(
		.iClk(iClk),
		.iReset(iReset),
		.oReset(oReset),
		.oHalted(oHalted),
		.oConfigDone(oConfigDone),

		.debug_0(debug_0),
		.debug_1(debug_1),	

		//DTL interface for control by the host (SLAVE)
		.oDTL_Loader_CommandAccept(oDTL_Loader_CommandAccept),
		.oDTL_Loader_WriteAccept(oDTL_Loader_WriteAccept),
		.oDTL_Loader_ReadValid(oDTL_Loader_ReadValid),
		.oDTL_Loader_ReadLast(oDTL_Loader_ReadLast),
		.oDTL_Loader_ReadData(oDTL_Loader_ReadData),
			
		.iDTL_Loader_CommandValid(iDTL_Loader_CommandValid),
		.iDTL_Loader_WriteValid(iDTL_Loader_WriteValid),		
		.iDTL_Loader_CommandReadWrite(iDTL_Loader_CommandReadWrite),
		.iDTL_Loader_WriteEnable(iDTL_Loader_WriteEnable),
		.iDTL_Loader_Address(iDTL_Loader_Address),	
		.iDTL_Loader_WriteData(iDTL_Loader_WriteData),
			
		.iDTL_Loader_BlockSize(iDTL_Loader_BlockSize),
		.iDTL_Loader_WriteLast(iDTL_Loader_WriteLast),
		.iDTL_Loader_ReadAccept(iDTL_Loader_ReadAccept),			
			
		//DTL interface for the shared memory with the host (MASTER)
		.iDTL_SMEM_CommandAccept(iDTL_SMEM_CommandAccept),
		.iDTL_SMEM_WriteAccept(iDTL_SMEM_WriteAccept),
		.iDTL_SMEM_ReadValid(iDTL_SMEM_ReadValid),
		.iDTL_SMEM_ReadLast(iDTL_SMEM_ReadLast),
		.iDTL_SMEM_ReadData(iDTL_SMEM_ReadData),
			
		.oDTL_SMEM_CommandValid(oDTL_SMEM_CommandValid),
		.oDTL_SMEM_WriteValid(oDTL_SMEM_WriteValid),		
		.oDTL_SMEM_CommandReadWrite(oDTL_SMEM_CommandReadWrite),
		.oDTL_SMEM_WriteEnable(oDTL_SMEM_WriteEnable),
		.oDTL_SMEM_Address(oDTL_SMEM_Address),	
		.oDTL_SMEM_WriteData(oDTL_SMEM_WriteData),
			
		.oDTL_SMEM_BlockSize(oDTL_SMEM_BlockSize),
		.oDTL_SMEM_WriteLast(oDTL_SMEM_WriteLast),
		.oDTL_SMEM_ReadAccept(oDTL_SMEM_ReadAccept),	
			
		`ifndef NATIVE_GM_INTERFACE			
			//DTL interface for the global memory (MASTER)
			.iDTL_DMEM_CommandAccept(iDTL_DMEM_CommandAccept),
			.iDTL_DMEM_WriteAccept(iDTL_DMEM_WriteAccept),
			.iDTL_DMEM_ReadValid(iDTL_DMEM_ReadValid),
			.iDTL_DMEM_ReadLast(iDTL_DMEM_ReadLast),
			.iDTL_DMEM_ReadData(iDTL_DMEM_ReadData),
				
			.oDTL_DMEM_CommandValid(oDTL_DMEM_CommandValid),
			.oDTL_DMEM_WriteValid(oDTL_DMEM_WriteValid),	
			.oDTL_DMEM_CommandReadWrite(oDTL_DMEM_CommandReadWrite),
			.oDTL_DMEM_WriteEnable(oDTL_DMEM_WriteEnable),	
			.oDTL_DMEM_Address(oDTL_DMEM_Address),
			.oDTL_DMEM_WriteData(oDTL_DMEM_WriteData),
			
			.oDTL_DMEM_BlockSize(oDTL_DMEM_BlockSize),
			.oDTL_DMEM_WriteLast(oDTL_DMEM_WriteLast),
			.oDTL_DMEM_ReadAccept(oDTL_DMEM_ReadAccept),		
		`else
			.oGM_WriteAddress(oGM_WriteAddress),
			.oGM_ReadAddress(oGM_ReadAddress),
			.oGM_WriteEnable(oGM_WriteEnable),
			.oGM_ReadEnable(oGM_ReadEnable),
			.oGM_WriteData(oGM_WriteData),
			.iGM_ReadData(iGM_ReadData),
		`endif		

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
			//DTL interface for the state memory (MASTER)
			.iDTL_STATE_CommandAccept(iDTL_STATE_CommandAccept),
			.iDTL_STATE_WriteAccept(iDTL_STATE_WriteAccept),
			.iDTL_STATE_ReadValid(iDTL_STATE_ReadValid),
			.iDTL_STATE_ReadLast(iDTL_STATE_ReadLast),
			.iDTL_STATE_ReadData(iDTL_STATE_ReadData),
				
			.oDTL_STATE_CommandValid(oDTL_STATE_CommandValid),
			.oDTL_STATE_WriteValid(oDTL_STATE_WriteValid),	
			.oDTL_STATE_CommandReadWrite(oDTL_STATE_CommandReadWrite),
			.oDTL_STATE_WriteEnable(oDTL_STATE_WriteEnable),	
			.oDTL_STATE_Address(oDTL_STATE_Address),
			.oDTL_STATE_WriteData(oDTL_STATE_WriteData),
			
			.oDTL_STATE_BlockSize(oDTL_STATE_BlockSize),
			.oDTL_STATE_WriteLast(oDTL_STATE_WriteLast),
			.oDTL_STATE_ReadAccept(oDTL_STATE_ReadAccept),			
		`endif				
	
		//local memory wires
		.oLM_WriteEnable(wLM_WriteEnable_packed),
		.oLM_ReadEnable(wLM_ReadEnable_packed),
		.oLM_WriteAddress(wLM_WriteAddress_packed),
		.oLM_WriteData(wLM_WriteData_packed),
		.oLM_ReadAddress(wLM_ReadAddress_packed),
		.iLM_ReadData(wLM_ReadData_packed),	
	
		//instruction memory interfaces
		.oIM_ReadAddress(wIM_ReadAddress_packed),
		.iIM_ReadData(wIM_ReadData_packed),	
		.oIM_ReadEnable(wIM_ReadEnable_packed),
		.oIM_WriteEnable(wIM_WriteEnable),
		.oIM_WriteAddress(wIM_WriteAddress),
		.oIM_WriteData(wIM_WriteData),
		.oIM_WriteData_IMM(wIM_WriteData_IMM)		
	);	
	
	CGRA_Memory
	#(
		.D_WIDTH(D_WIDTH),	
		.I_WIDTH(I_WIDTH),
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
	
		.LM_ADDR_WIDTH(LM_ADDR_WIDTH),		
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH),
		
		.LM_MEM_ADDR_WIDTH(LM_MEM_ADDR_WIDTH),
		.IM_MEM_ADDR_WIDTH(IM_MEM_ADDR_WIDTH),			

		.LM_MEM_WIDTH(LM_MEM_WIDTH),
		
		.NUM_ID(NUM_ID),
		.NUM_LOCAL_DMEM(NUM_LOCAL_DMEM)
	)	
	CGRA_Memory_inst
	(
		.iClk(iClk),
		
		//local memory interfaces
		.iLM_WriteEnable(wLM_WriteEnable_packed),
		.iLM_ReadEnable(wLM_ReadEnable_packed),
		.iLM_WriteAddress(wLM_WriteAddress_repacked),
		.iLM_WriteData(wLM_WriteData_packed),
		.iLM_ReadAddress(wLM_ReadAddress_repacked),
		.oLM_ReadData(wLM_ReadData_packed),	
		
		//instruction memory interfaces
		.iIM_WriteEnable(wIM_WriteEnable),
		.iIM_ReadEnable(wIM_ReadEnable_packed),
		.iIM_WriteAddress(wIM_WriteAddress),
		.iIM_WriteData(wIM_WriteData),		
		.iIM_WriteData_IMM(wIM_WriteData_IMM),	
		.iIM_ReadAddress(wIM_ReadAddress_repacked),
		.oIM_ReadData(wIM_ReadData_packed)	
	);		
endmodule
	
