
module <<MODULE_NAME>>
#(
	parameter D_WIDTH = <<D_WIDTH>>,	
	parameter I_WIDTH = <<I_WIDTH>>,
	parameter I_IMM_WIDTH = <<I_IMM_WIDTH>>,
	parameter I_DECODED_WIDTH = <<DECODED_WIDTH>>,
	
	parameter LM_ADDR_WIDTH = <<LM_ADDR_WIDTH>>,	
	parameter IM_ADDR_WIDTH = <<IM_ADDR_WIDTH>>,
	
	parameter LM_MEM_ADDR_WIDTH = <<LM_DEPTH_WIDTH>>,	
	parameter IM_MEM_ADDR_WIDTH = <<IM_DEPTH_WIDTH>>,	
	
	parameter LM_MEM_WIDTH = <<LM_MEM_WIDTH>>,	
	
	parameter NUM_ID = <<NUM_ID>>,
	parameter NUM_IMM = <<NUM_IMM>>,
	parameter NUM_LOCAL_DMEM = <<NUM_LDMEM>>	
)	
(
	input iClk,
		
	//local memory interfaces
	input [NUM_LOCAL_DMEM*(LM_MEM_WIDTH / 8)-1:0] iLM_WriteEnable,
	input [NUM_LOCAL_DMEM-1:0] iLM_ReadEnable,
	input [NUM_LOCAL_DMEM*LM_MEM_ADDR_WIDTH-1:0] iLM_WriteAddress,
	input [NUM_LOCAL_DMEM*D_WIDTH-1:0] iLM_WriteData,
	input [NUM_LOCAL_DMEM*LM_MEM_ADDR_WIDTH-1:0] iLM_ReadAddress,
	output  [NUM_LOCAL_DMEM*D_WIDTH-1:0] oLM_ReadData,		
	
	//instruction memory interfaces
	input [(NUM_IMM+NUM_ID)-1:0] iIM_WriteEnable,
	input [(NUM_IMM+NUM_ID)-1:0] iIM_ReadEnable,
	input [IM_MEM_ADDR_WIDTH-1:0] iIM_WriteAddress,
	input [I_WIDTH-1:0] iIM_WriteData,	
	input [I_IMM_WIDTH-1:0] iIM_WriteData_IMM,	
	input [(NUM_IMM+NUM_ID)*IM_MEM_ADDR_WIDTH-1:0] iIM_ReadAddress,
	output [NUM_IMM*I_IMM_WIDTH+NUM_ID*I_WIDTH-1:0] oIM_ReadData		
);

	//for local memories
	wire [(LM_MEM_WIDTH / 8)-1:0] wLM_WriteEnable [NUM_LOCAL_DMEM-1:0];
	wire wLM_ReadEnable [NUM_LOCAL_DMEM-1:0];
	wire [LM_MEM_ADDR_WIDTH-1:0] wLM_WriteAddress [NUM_LOCAL_DMEM-1:0];
	wire [D_WIDTH-1:0] wLM_WriteData [NUM_LOCAL_DMEM-1:0];	
	wire [LM_MEM_ADDR_WIDTH-1:0] wLM_ReadAddress [NUM_LOCAL_DMEM-1:0];
	wire [D_WIDTH-1:0] wLM_ReadData [NUM_LOCAL_DMEM-1:0];	

	//for instruction memories	
	wire [IM_MEM_ADDR_WIDTH-1:0] wIM_ReadAddress [NUM_IMM+NUM_ID-1:0];
	wire [I_WIDTH-1:0] wIM_ReadData [NUM_ID-1:0];		
	wire [I_IMM_WIDTH-1:0] wIM_ReadData_IMM [NUM_IMM-1:0];

	wire [I_WIDTH-1:0] wIM_WriteData = iIM_WriteData;
	wire [I_IMM_WIDTH-1:0] wIM_WriteData_IMM = iIM_WriteData_IMM;
	wire [IM_MEM_ADDR_WIDTH-1:0] wIM_WriteAddress = iIM_WriteAddress;
	wire [(NUM_IMM+NUM_ID)-1:0] wIM_WriteEnable = iIM_WriteEnable;
	wire [(NUM_IMM+NUM_ID)-1:0] wIM_ReadEnable = iIM_ReadEnable;

	genvar gConnectMemory;
	generate		
		for (gConnectMemory=0; gConnectMemory < NUM_LOCAL_DMEM; gConnectMemory = gConnectMemory + 1)
			begin : LocalMemory
				assign wLM_WriteEnable[gConnectMemory] = iLM_WriteEnable[gConnectMemory*(LM_MEM_WIDTH / 8)+:(LM_MEM_WIDTH / 8)];
				assign wLM_ReadEnable[gConnectMemory] = iLM_ReadEnable[gConnectMemory];
				
				assign wLM_WriteAddress[gConnectMemory] = iLM_WriteAddress[(gConnectMemory+1)*LM_MEM_ADDR_WIDTH-1 : gConnectMemory*LM_MEM_ADDR_WIDTH];
				assign wLM_ReadAddress[gConnectMemory] = iLM_ReadAddress[(gConnectMemory+1)*LM_MEM_ADDR_WIDTH-1 : gConnectMemory*LM_MEM_ADDR_WIDTH];
				
				assign wLM_WriteData[gConnectMemory] = iLM_WriteData[(gConnectMemory+1)*D_WIDTH-1 : gConnectMemory*D_WIDTH];
				assign oLM_ReadData[(gConnectMemory+1)*D_WIDTH-1 : gConnectMemory*D_WIDTH] = wLM_ReadData[gConnectMemory];
			end			
			
		for (gConnectMemory=0; gConnectMemory < NUM_ID; gConnectMemory = gConnectMemory + 1)
			begin : InstructionMemory				
				assign wIM_ReadAddress[gConnectMemory] = iIM_ReadAddress[(gConnectMemory+1)*IM_MEM_ADDR_WIDTH-1 : gConnectMemory*IM_MEM_ADDR_WIDTH];
				assign oIM_ReadData[(gConnectMemory+1)*I_WIDTH-1 : gConnectMemory*I_WIDTH] = wIM_ReadData[gConnectMemory];
			end				

			//for the immediate units
		for (gConnectMemory=0; gConnectMemory < NUM_IMM; gConnectMemory = gConnectMemory + 1)
			begin : InstructionMemory_IMM
				assign wIM_ReadAddress[gConnectMemory+NUM_ID] = iIM_ReadAddress[(gConnectMemory+NUM_ID+1)*IM_MEM_ADDR_WIDTH-1 : (gConnectMemory+NUM_ID)*IM_MEM_ADDR_WIDTH];
				assign oIM_ReadData[(gConnectMemory+1)*I_IMM_WIDTH+NUM_ID*I_WIDTH-1 : gConnectMemory*I_IMM_WIDTH+NUM_ID*I_WIDTH] = wIM_ReadData_IMM[gConnectMemory];
			end
		
	endgenerate	

	//local memories ============================================================
<<LOCAL_MEMORIES>>

	//instruction memories ============================================================
<<INSTRUCTION_MEMORIES>>

endmodule

