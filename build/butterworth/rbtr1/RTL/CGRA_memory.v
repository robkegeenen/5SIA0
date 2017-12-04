
module CGRA_Memory
#(
	parameter D_WIDTH = 32,	
	parameter I_WIDTH = 12,
	parameter I_IMM_WIDTH = 33,
	parameter I_DECODED_WIDTH = 16,
	
	parameter LM_ADDR_WIDTH = 16,	
	parameter IM_ADDR_WIDTH = 16,
	
	parameter LM_MEM_ADDR_WIDTH = 8,	
	parameter IM_MEM_ADDR_WIDTH = 8,	
	
	parameter LM_MEM_WIDTH = 32,	
	
	parameter NUM_ID = 10,
	parameter NUM_IMM = 3,
	parameter NUM_LOCAL_DMEM = 1	
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
	RAM_SDP_BE
	#(
		.DATA_WIDTH(LM_MEM_WIDTH),
		.ADDR_WIDTH(LM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.ADDRESSABLE_SIZE(8),
		.DO_INIT(0)
	)	
    LM_lsu_stor
	(
		.clock(iClk),
		.data(wLM_WriteData[0]),
		.rdaddress(wLM_ReadAddress[0][LM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wLM_WriteAddress[0][LM_MEM_ADDR_WIDTH-1:0]),
		.wren(wLM_WriteEnable[0]),
		.rden(wLM_ReadEnable[0]),
		.q(wLM_ReadData[0])
	);



	//instruction memories ============================================================
	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_lsu_stor
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[7][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[7]),
		.rden(wIM_ReadEnable[7]),
		.q(wIM_ReadData[7])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_mul_y
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[8][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[8]),
		.rden(wIM_ReadEnable[8]),
		.q(wIM_ReadData[8])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_mul_x
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[9][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[9]),
		.rden(wIM_ReadEnable[9]),
		.q(wIM_ReadData[9])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_rf_x
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[2][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[2]),
		.rden(wIM_ReadEnable[2]),
		.q(wIM_ReadData[2])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_rf_y
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[3][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[3]),
		.rden(wIM_ReadEnable[3]),
		.q(wIM_ReadData[3])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_abu
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[6][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[6]),
		.rden(wIM_ReadEnable[6]),
		.q(wIM_ReadData[6])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_alu
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[5][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[5]),
		.rden(wIM_ReadEnable[5]),
		.q(wIM_ReadData[5])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_IMM_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_imm_y
	(
		.clock(iClk),
		.data(wIM_WriteData_IMM),
		.rdaddress(wIM_ReadAddress[1+NUM_ID][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[1+NUM_ID]),
		.rden(wIM_ReadEnable[1+NUM_ID]),
		.q(wIM_ReadData_IMM[1])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_IMM_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_imm_x
	(
		.clock(iClk),
		.data(wIM_WriteData_IMM),
		.rdaddress(wIM_ReadAddress[2+NUM_ID][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[2+NUM_ID]),
		.rden(wIM_ReadEnable[2+NUM_ID]),
		.q(wIM_ReadData_IMM[2])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_abu_stor
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[0][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[0]),
		.rden(wIM_ReadEnable[0]),
		.q(wIM_ReadData[0])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_abu_y
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[1][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[1]),
		.rden(wIM_ReadEnable[1]),
		.q(wIM_ReadData[1])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_id_abu_x
	(
		.clock(iClk),
		.data(wIM_WriteData),
		.rdaddress(wIM_ReadAddress[4][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[4]),
		.rden(wIM_ReadEnable[4]),
		.q(wIM_ReadData[4])
	);

	RAM_SDP 
	#(
		.DATA_WIDTH(I_IMM_WIDTH),
		.ADDR_WIDTH(IM_MEM_ADDR_WIDTH),
		.DATAFILE(""),
		.DO_INIT(0)
	)	
    IM_imm_stor
	(
		.clock(iClk),
		.data(wIM_WriteData_IMM),
		.rdaddress(wIM_ReadAddress[0+NUM_ID][IM_MEM_ADDR_WIDTH-1:0]),
		.wraddress(wIM_WriteAddress[IM_MEM_ADDR_WIDTH-1:0]),
		.wren(wIM_WriteEnable[0+NUM_ID]),
		.rden(wIM_ReadEnable[0+NUM_ID]),
		.q(wIM_ReadData_IMM[0])
	);



endmodule

