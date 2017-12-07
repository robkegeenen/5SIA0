`timescale 1 ns / 1 ns

`include "config.vh"

module CGRA_Top
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
	parameter GM_MEM_ADDR_WIDTH = 13,
	parameter IM_MEM_ADDR_WIDTH = 8,	

	parameter LM_MEM_WIDTH = 32,
	parameter GM_MEM_WIDTH = 32,
	
	parameter NUM_ID = 6,
	parameter NUM_IMM = 3,
	
	parameter NUM_LOCAL_DMEM = 1,
	parameter NUM_GLOBAL_DMEM = 1,

	parameter MAGIC_DMEM_LOAD = 1	
)
(	
	input iClk,
	input iReset,
	output oHalted,
	output oConfigDone,
	
	//inputs and outputs for peripherals
																		
	//-------------------------------	
			
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

	//DTL interface for the global memory of the CGRA (MASTER)
	output oDTL_DMEM_CommandAccept,
	output oDTL_DMEM_WriteAccept,
	output oDTL_DMEM_ReadValid,
	output oDTL_DMEM_ReadLast,
	output [INTERFACE_WIDTH-1:0] oDTL_DMEM_ReadData,
		
	input iDTL_DMEM_CommandValid,
	input iDTL_DMEM_WriteValid,		
	input iDTL_DMEM_CommandReadWrite,
	input [(INTERFACE_WIDTH/8)-1:0] iDTL_DMEM_WriteEnable,
	input [INTERFACE_ADDR_WIDTH-1:0] iDTL_DMEM_Address,	
	input [INTERFACE_WIDTH-1:0] iDTL_DMEM_WriteData,
		
	input [INTERFACE_BLOCK_WIDTH-1:0] iDTL_DMEM_BlockSize,
	input iDTL_DMEM_WriteLast,
	input iDTL_DMEM_ReadAccept			
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
	
	localparam INTERFACE_NUM_ENABLES = (INTERFACE_WIDTH / 8);
	localparam GM_NUM_ENABLES = (GM_MEM_WIDTH / 8);
	localparam LM_NUM_ENABLES = (LM_MEM_WIDTH / 8);	
	localparam GM_BYTE_ENABLES_WIDTH = CLogB2(GM_NUM_ENABLES-1);	
	localparam INTERFACE_BYTE_ENABLES_WIDTH = CLogB2(INTERFACE_NUM_ENABLES-1);	

	localparam DMEM_PORTS = 2;	

	`ifdef NATIVE_GM_INTERFACE
		wire [GM_ADDR_WIDTH-1:0] wGM_WriteAddress;
		wire [GM_ADDR_WIDTH-1:0] wGM_ReadAddress;
		wire [(GM_MEM_WIDTH / 8)-1:0] wGM_WriteEnable;
		wire wGM_ReadEnable;
		wire [D_WIDTH-1:0] wGM_WriteData;
		wire [D_WIDTH-1:0] wGM_ReadData;
	`else
		//for global memory
		wire [D_WIDTH-1:0] wGM_WriteData;			
		wire [D_WIDTH-1:0] wGM_ReadData;	
		wire [GM_NUM_ENABLES-1:0] wGM_WriteEnable;		
		wire [GM_ADDR_WIDTH-1:0] wGM_Address;	

		//-------------------------------------------------	
		//for DTL controllers
		wire wDTL_DMEM_CommandValid;	
		wire wDTL_DMEM_WriteAccept;	
		wire wDTL_DMEM_ReadValid;	
		wire wDTL_DMEM_ReadLast;	
		
		wire wDTL_DMEM_CommandAccept;	
		wire wDTL_DMEM_WriteValid;	
		wire wDTL_DMEM_CommandReadWrite;
		wire [INTERFACE_NUM_ENABLES-1:0] wDTL_DMEM_WriteEnable;		
		wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_DMEM_Address;	
		wire [INTERFACE_WIDTH-1:0] wDTL_DMEM_WriteData;	
		wire [INTERFACE_WIDTH-1:0] wDTL_DMEM_ReadData;	
		
		wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_DMEM_BlockSize;
		wire wDTL_DMEM_WriteLast;
		wire wDTL_DMEM_ReadAccept;	

		wire [DMEM_PORTS-1:0] wDTL_CommandValid_packed;	
		wire [DMEM_PORTS-1:0] wDTL_WriteAccept_packed;	
		wire [DMEM_PORTS-1:0] wDTL_ReadValid_packed;	
		wire [DMEM_PORTS-1:0] wDTL_ReadLast_packed;	
		
		wire [DMEM_PORTS-1:0] wDTL_CommandAccept_packed;	
		wire [DMEM_PORTS-1:0] wDTL_WriteValid_packed;	
		wire [DMEM_PORTS-1:0] wDTL_CommandReadWrite_packed;
		wire [DMEM_PORTS*INTERFACE_NUM_ENABLES-1:0] wDTL_WriteEnable_packed;		
		wire [DMEM_PORTS*INTERFACE_ADDR_WIDTH-1:0] wDTL_Address_packed;	
		wire [DMEM_PORTS*INTERFACE_WIDTH-1:0] wDTL_WriteData_packed;	
		wire [DMEM_PORTS*INTERFACE_WIDTH-1:0] wDTL_ReadData_packed;	
		
		wire [DMEM_PORTS*INTERFACE_BLOCK_WIDTH-1:0] wDTL_BlockSize_packed;
		wire [DMEM_PORTS-1:0] wDTL_WriteLast_packed;
		wire [DMEM_PORTS-1:0] wDTL_ReadAccept_packed;	

		wire wDTL_ARB_CommandValid;	
		wire wDTL_ARB_WriteAccept;	
		wire wDTL_ARB_ReadValid;	
		wire wDTL_ARB_ReadLast;	
		
		wire wDTL_ARB_CommandAccept;	
		wire wDTL_ARB_WriteValid;	
		wire wDTL_ARB_CommandReadWrite;
		wire [INTERFACE_NUM_ENABLES-1:0] wDTL_ARB_WriteEnable;		
		wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_ARB_Address;	
		wire [INTERFACE_WIDTH-1:0] wDTL_ARB_WriteData;	
		wire [INTERFACE_WIDTH-1:0] wDTL_ARB_ReadData;	
		
		wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_ARB_BlockSize;
		wire wDTL_ARB_WriteLast;
		wire wDTL_ARB_ReadAccept;
		
		assign wDTL_CommandValid_packed = {wDTL_DMEM_CommandValid, iDTL_DMEM_CommandValid};	
		assign {wDTL_DMEM_WriteAccept, oDTL_DMEM_WriteAccept} = wDTL_WriteAccept_packed;	
		assign {wDTL_DMEM_ReadValid, oDTL_DMEM_ReadValid} = wDTL_ReadValid_packed;
		assign {wDTL_DMEM_ReadLast, oDTL_DMEM_ReadLast} = wDTL_ReadLast_packed;	
		
		assign {wDTL_DMEM_CommandAccept,oDTL_DMEM_CommandAccept} = wDTL_CommandAccept_packed;	
		assign wDTL_WriteValid_packed = {wDTL_DMEM_WriteValid,iDTL_DMEM_WriteValid};	
		assign wDTL_CommandReadWrite_packed = {wDTL_DMEM_CommandReadWrite,iDTL_DMEM_CommandReadWrite};
		assign wDTL_WriteEnable_packed = {wDTL_DMEM_WriteEnable,iDTL_DMEM_WriteEnable};		
		assign wDTL_Address_packed = {wDTL_DMEM_Address,iDTL_DMEM_Address};	
		assign wDTL_WriteData_packed = {wDTL_DMEM_WriteData,iDTL_DMEM_WriteData};	
		assign {wDTL_DMEM_ReadData,oDTL_DMEM_ReadData} = wDTL_ReadData_packed;	
		
		assign wDTL_BlockSize_packed = {wDTL_DMEM_BlockSize,iDTL_DMEM_BlockSize};
		assign wDTL_WriteLast_packed = {wDTL_DMEM_WriteLast,iDTL_DMEM_WriteLast};
		assign wDTL_ReadAccept_packed = {wDTL_DMEM_ReadAccept,iDTL_DMEM_ReadAccept};							

		wire [INTERFACE_WIDTH-1:0] wDTL_DMEM_GM_ReadData;
	wire wDTL_DMEM_GM_WriteAccept;
	wire wDTL_DMEM_GM_CommandAccept;
	wire wDTL_DMEM_GM_ReadValid;
	wire wDTL_DMEM_GM_ReadLast;

		assign wDTL_ARB_ReadData = wDTL_DMEM_GM_ReadData;
	assign wDTL_ARB_WriteAccept = wDTL_DMEM_GM_WriteAccept;
	assign wDTL_ARB_CommandAccept = wDTL_DMEM_GM_CommandAccept;
	assign wDTL_ARB_ReadValid = wDTL_DMEM_GM_ReadValid;
	assign wDTL_ARB_ReadLast = wDTL_DMEM_GM_ReadLast;


		//----------------------------- peripheral wires

	//wires for GM
	wire wDTL_GM_CommandValid;
	wire wDTL_GM_WriteAccept;
	wire wDTL_GM_ReadValid;
	wire wDTL_GM_ReadLast;
	wire wDTL_GM_CommandAccept;
	wire wDTL_GM_WriteValid;
	wire wDTL_GM_CommandReadWrite;
	wire [INTERFACE_NUM_ENABLES-1:0] wDTL_GM_WriteEnable;
	wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_GM_Address;
	wire [INTERFACE_WIDTH-1:0] wDTL_GM_WriteData;
	wire [INTERFACE_WIDTH-1:0] wDTL_GM_ReadData;
	wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_GM_BlockSize;
	wire wDTL_GM_WriteLast;
	wire wDTL_GM_ReadAccept;


	`endif

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
			//wires for State memory
			wire wDTL_STATE_CommandValid;
			wire wDTL_STATE_WriteAccept;
			wire wDTL_STATE_ReadValid;
			wire wDTL_STATE_ReadLast;
			wire wDTL_STATE_CommandAccept;
			wire wDTL_STATE_WriteValid;
			wire wDTL_STATE_CommandReadWrite;
			wire [INTERFACE_NUM_ENABLES-1:0] wDTL_STATE_WriteEnable;
			wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_STATE_Address;
			wire [INTERFACE_WIDTH-1:0] wDTL_STATE_WriteData;
			wire [INTERFACE_WIDTH-1:0] wDTL_STATE_ReadData;
			wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_STATE_BlockSize;
			wire wDTL_STATE_WriteLast;
			wire wDTL_STATE_ReadAccept;
			
			wire [INTERFACE_WIDTH-1:0] wSM_WriteData;			
			wire [INTERFACE_WIDTH-1:0] wSM_ReadData;	
			wire [INTERFACE_NUM_ENABLES-1:0] wSM_WriteEnable;		
			wire [INTERFACE_ADDR_WIDTH-1:0] wSM_Address;			
		`endif	
		
		wire wResetCGRA;
				
		//--------------------------------		
		`ifdef ASIC_SYNTHESIS 	
		`ifdef SYN_MEM
		CGRA_Core_WR
		`else
		CGRA_Core
		`endif
		`else						
		CGRA_Core
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
		`ifdef SYN_MEM
		CGRA_Core_WR_inst
		`else
		CGRA_Core_inst
		`endif
		`else
		CGRA_Core_inst
		`endif				
		(
			.iClk(iClk),
			.iReset(iReset),
			.oReset(wResetCGRA),
			.oHalted(oHalted),
			.oConfigDone(oConfigDone),

			.debug_0(),
			.debug_1(),

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
						
			`ifndef NATIVE_GM_INTERFACE			
				//DTL interface for the global memory (MASTER)
				.iDTL_DMEM_CommandAccept(wDTL_DMEM_CommandAccept),
				.iDTL_DMEM_WriteAccept(wDTL_DMEM_WriteAccept),
				.iDTL_DMEM_ReadValid(wDTL_DMEM_ReadValid),
				.iDTL_DMEM_ReadLast(wDTL_DMEM_ReadLast),
				.iDTL_DMEM_ReadData(wDTL_DMEM_ReadData),
					
				.oDTL_DMEM_CommandValid(wDTL_DMEM_CommandValid),
				.oDTL_DMEM_WriteValid(wDTL_DMEM_WriteValid),	
				.oDTL_DMEM_CommandReadWrite(wDTL_DMEM_CommandReadWrite),
				.oDTL_DMEM_WriteEnable(wDTL_DMEM_WriteEnable),	
				.oDTL_DMEM_Address(wDTL_DMEM_Address),
				.oDTL_DMEM_WriteData(wDTL_DMEM_WriteData),
				
				.oDTL_DMEM_BlockSize(wDTL_DMEM_BlockSize),
				.oDTL_DMEM_WriteLast(wDTL_DMEM_WriteLast),
				.oDTL_DMEM_ReadAccept(wDTL_DMEM_ReadAccept),
			`else
				.oGM_WriteAddress(wGM_WriteAddress),
				.oGM_ReadAddress(wGM_ReadAddress),
				.oGM_WriteEnable(wGM_WriteEnable),
				.oGM_ReadEnable(wGM_ReadEnable),
				.oGM_WriteData(wGM_WriteData),
				.iGM_ReadData(wGM_ReadData),
			`endif		

			`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled	
				//DTL interface for the state memory (MASTER)
				.iDTL_STATE_CommandAccept(wDTL_STATE_CommandAccept),
				.iDTL_STATE_WriteAccept(wDTL_STATE_WriteAccept),
				.iDTL_STATE_ReadValid(wDTL_STATE_ReadValid),
				.iDTL_STATE_ReadLast(wDTL_STATE_ReadLast),
				.iDTL_STATE_ReadData(wDTL_STATE_ReadData),
					
				.oDTL_STATE_CommandValid(wDTL_STATE_CommandValid),
				.oDTL_STATE_WriteValid(wDTL_STATE_WriteValid),	
				.oDTL_STATE_CommandReadWrite(wDTL_STATE_CommandReadWrite),
				.oDTL_STATE_WriteEnable(wDTL_STATE_WriteEnable),	
				.oDTL_STATE_Address(wDTL_STATE_Address),
				.oDTL_STATE_WriteData(wDTL_STATE_WriteData),
				
				.oDTL_STATE_BlockSize(wDTL_STATE_BlockSize),
				.oDTL_STATE_WriteLast(wDTL_STATE_WriteLast),
				.oDTL_STATE_ReadAccept(wDTL_STATE_ReadAccept),		
			`endif		

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
			.oDTL_SMEM_ReadAccept(oDTL_SMEM_ReadAccept)				
		);

	`ifndef NATIVE_GM_INTERFACE
		//peripheral and DTL isolator instantiations

	DTL_Address_Isolator
	#
	(
		.INTERFACE_WIDTH(INTERFACE_WIDTH),
		.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
		.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH),

		.ADDRESS_RANGE_LOW(0),
		.ADDRESS_RANGE_HIGH(32767)	
	)
	DTL_Address_Isolator_GM_inst
	(
		.iClk(iClk),
		.iReset(iReset),
		
		//input (SLAVE) DTL port
		.iDTL_IN_CommandValid(wDTL_ARB_CommandValid),
		.oDTL_IN_CommandAccept(wDTL_DMEM_GM_CommandAccept),
		.iDTL_IN_Address(wDTL_ARB_Address),
		.iDTL_IN_CommandReadWrite(wDTL_ARB_CommandReadWrite),
		.iDTL_IN_BlockSize(wDTL_ARB_BlockSize),

		.oDTL_IN_ReadValid(wDTL_DMEM_GM_ReadValid),
		.oDTL_IN_ReadLast(wDTL_DMEM_GM_ReadLast),	
		.iDTL_IN_ReadAccept(wDTL_ARB_ReadAccept),
		.oDTL_IN_ReadData(wDTL_DMEM_GM_ReadData),
		
		.iDTL_IN_WriteValid(wDTL_ARB_WriteValid),		
		.iDTL_IN_WriteLast(wDTL_ARB_WriteLast),
		.oDTL_IN_WriteAccept(wDTL_DMEM_GM_WriteAccept),
		.iDTL_IN_WriteEnable(wDTL_ARB_WriteEnable),	
		.iDTL_IN_WriteData(wDTL_ARB_WriteData),
		
		//output (MASTER) DTL port
		.oDTL_OUT_CommandValid(wDTL_GM_CommandValid),	
		.iDTL_OUT_CommandAccept(wDTL_GM_CommandAccept),
		.oDTL_OUT_Address(wDTL_GM_Address),
		.oDTL_OUT_CommandReadWrite(wDTL_GM_CommandReadWrite),
		.oDTL_OUT_BlockSize(wDTL_GM_BlockSize),
		
		.iDTL_OUT_ReadValid(wDTL_GM_ReadValid),
		.iDTL_OUT_ReadLast(wDTL_GM_ReadLast),
		.oDTL_OUT_ReadAccept(wDTL_GM_ReadAccept),
		.iDTL_OUT_ReadData(wDTL_GM_ReadData),
		
		.oDTL_OUT_WriteValid(wDTL_GM_WriteValid),	
		.oDTL_OUT_WriteLast(wDTL_GM_WriteLast),
		.iDTL_OUT_WriteAccept(wDTL_GM_WriteAccept),
		.oDTL_OUT_WriteEnable(wDTL_GM_WriteEnable),	
		.oDTL_OUT_WriteData(wDTL_GM_WriteData)
		
	);	

		
		dtl_sram_controller DTL_DMEM_CONTROLLER_inst
		(
		  	.clk(iClk),
		  	.rst(iReset),
		  	.dtl_cmd_valid(wDTL_GM_CommandValid),
		  	.dtl_cmd_accept(wDTL_GM_CommandAccept),
		  	.dtl_cmd_addr(wDTL_GM_Address),
		  	.dtl_cmd_read(wDTL_GM_CommandReadWrite),
		  	.dtl_cmd_block_size(wDTL_GM_BlockSize),

		  	.dtl_wr_valid(wDTL_GM_WriteValid),
		  	.dtl_wr_last(wDTL_GM_WriteLast),
		  	.dtl_wr_accept(wDTL_GM_WriteAccept),
		  	.dtl_wr_mask(wDTL_GM_WriteEnable),
		  	.dtl_wr_data(wDTL_GM_WriteData),

		  	.dtl_rd_valid(wDTL_GM_ReadValid),
		  	.dtl_rd_last(wDTL_GM_ReadLast),
		  	.dtl_rd_accept(wDTL_GM_ReadAccept),
		  	.dtl_rd_data(wDTL_GM_ReadData), 

		  	.ram_clk(),
		  	.ram_rst(),
		  	.ram_addr(wGM_Address),
		  	.ram_wr_data(wGM_WriteData),
		  	.ram_en(),
		  	.ram_wbe(wGM_WriteEnable),
		  	.ram_rd_data(wGM_ReadData),
		  
		  	//dummy bus used to prevent xilinx tools from optimizing stuff away
		  	//explicitly unconnected to avoid warnings about it.
		  	//.LMB_Clk(),
		  	.lmb_clk(),
		  	.lmb_rst(),
		  	.lmb_abus(),
		  	.lmb_writedbus(),
		  	.lmb_addrstrobe(),
		  	.lmb_readstrobe(),
		  	.lmb_writestrobe(),
		  	.lmb_be(),
		  	.sl_dbus(),
		  	.sl_ready(),
		  	.sl_wait(),
		  	.sl_ue(),
		  	.sl_ce()
	 	);		 
		
		//global memory ============================================================
		RAM_SDP_BE
		#(
			.DATA_WIDTH(GM_MEM_WIDTH),
			.ADDR_WIDTH(GM_MEM_ADDR_WIDTH),
			.DATAFILE("data.vbin"),
			.ADDRESSABLE_SIZE(8),
			.DO_INIT(MAGIC_DMEM_LOAD)
		)	
	    GM_inst
		(
			.clock(iClk),
			.data(wGM_WriteData),
			.rdaddress(wGM_Address[GM_MEM_ADDR_WIDTH-1+GM_BYTE_ENABLES_WIDTH:GM_BYTE_ENABLES_WIDTH]),
			.wraddress(wGM_Address[GM_MEM_ADDR_WIDTH-1+GM_BYTE_ENABLES_WIDTH:GM_BYTE_ENABLES_WIDTH]),
			.wren(wGM_WriteEnable),
			.rden(1'b1),
			.q(wGM_ReadData)
		);	


		//DTL arbiter, to allow the testbench to talk to the global memory
	    DTL_ARBITER
		#(
			.INTERFACE_WIDTH(INTERFACE_WIDTH),
			.INTERFACE_ADDR_WIDTH(INTERFACE_ADDR_WIDTH),
			.INTERFACE_BLOCK_WIDTH(INTERFACE_BLOCK_WIDTH),
			.NUM_PORTS(DMEM_PORTS)
		)
		DTL_ARBITER_TOP_inst
		(
			.iClk(iClk),
			.iReset(iReset),
			
			//input (SLAVE) DTL ports
			.iDTL_IN_CommandValid(wDTL_CommandValid_packed),
			.oDTL_IN_CommandAccept(wDTL_CommandAccept_packed),
			.iDTL_IN_Address(wDTL_Address_packed),
			.iDTL_IN_CommandReadWrite(wDTL_CommandReadWrite_packed),
			.iDTL_IN_BlockSize(wDTL_BlockSize_packed),

			.oDTL_IN_ReadValid(wDTL_ReadValid_packed),
			.oDTL_IN_ReadLast(wDTL_ReadLast_packed),	
			.iDTL_IN_ReadAccept(wDTL_ReadAccept_packed),
			.oDTL_IN_ReadData(wDTL_ReadData_packed),
			
			.iDTL_IN_WriteValid(wDTL_WriteValid_packed),		
			.iDTL_IN_WriteLast(wDTL_WriteLast_packed),
			.oDTL_IN_WriteAccept(wDTL_WriteAccept_packed),	
			.iDTL_IN_WriteEnable(wDTL_WriteEnable_packed),	
			.iDTL_IN_WriteData(wDTL_WriteData_packed),
			
			//output (MASTER) DTL port
			.oDTL_OUT_CommandValid(wDTL_ARB_CommandValid),
			.iDTL_OUT_CommandAccept(wDTL_ARB_CommandAccept),
			.oDTL_OUT_Address(wDTL_ARB_Address),
			.oDTL_OUT_CommandReadWrite(wDTL_ARB_CommandReadWrite),
			.oDTL_OUT_BlockSize(wDTL_ARB_BlockSize),
					
			.iDTL_OUT_ReadValid(wDTL_ARB_ReadValid),
			.iDTL_OUT_ReadLast(wDTL_ARB_ReadLast),
			.oDTL_OUT_ReadAccept(wDTL_ARB_ReadAccept),		
			.iDTL_OUT_ReadData(wDTL_ARB_ReadData),
						
			.oDTL_OUT_WriteValid(wDTL_ARB_WriteValid),	
			.oDTL_OUT_WriteLast(wDTL_ARB_WriteLast),
			.iDTL_OUT_WriteAccept(wDTL_ARB_WriteAccept),		
			.oDTL_OUT_WriteEnable(wDTL_ARB_WriteEnable),			
			.oDTL_OUT_WriteData(wDTL_ARB_WriteData)	
		);		
	`else	
		//global memory ============================================================
		RAM_SDP_BE
		#(
			.DATA_WIDTH(GM_MEM_WIDTH),
			.ADDR_WIDTH(GM_MEM_ADDR_WIDTH),
			.DATAFILE("data.vbin"),
			.ADDRESSABLE_SIZE(8),
			.DO_INIT(MAGIC_DMEM_LOAD)
		)	
	    GM_inst
		(
			.clock(iClk),
			.data(wGM_WriteData),
			.rdaddress(wGM_ReadAddress[GM_MEM_ADDR_WIDTH-1+GM_BYTE_ENABLES_WIDTH:GM_BYTE_ENABLES_WIDTH]),
			.wraddress(wGM_WriteAddress[GM_MEM_ADDR_WIDTH-1+GM_BYTE_ENABLES_WIDTH:GM_BYTE_ENABLES_WIDTH]),
			.wren(wGM_WriteEnable),
			.rden(wGM_ReadEnable),
			.q(wGM_ReadData)
		);		
	`endif

	//-------------------------------
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled		
		dtl_sram_controller DTL_STATE_MEM_CONTROLLER_inst
		(
			.clk(iClk),
			.rst(iReset),
			.dtl_cmd_valid(wDTL_STATE_CommandValid),
			.dtl_cmd_accept(wDTL_STATE_CommandAccept),
			.dtl_cmd_addr(wDTL_STATE_Address),
			.dtl_cmd_read(wDTL_STATE_CommandReadWrite),
			.dtl_cmd_block_size(wDTL_STATE_BlockSize),

			.dtl_wr_valid(wDTL_STATE_WriteValid),
			.dtl_wr_last(wDTL_STATE_WriteLast),
			.dtl_wr_accept(wDTL_STATE_WriteAccept),
			.dtl_wr_mask(wDTL_STATE_WriteEnable),
			.dtl_wr_data(wDTL_STATE_WriteData),

			.dtl_rd_valid(wDTL_STATE_ReadValid),
			.dtl_rd_last(wDTL_STATE_ReadLast),
			.dtl_rd_accept(wDTL_STATE_ReadAccept),
			.dtl_rd_data(wDTL_STATE_ReadData), 

			.ram_clk(),
			.ram_rst(),
			.ram_addr(wSM_Address),
			.ram_wr_data(wSM_WriteData),
			.ram_en(),
			.ram_wbe(wSM_WriteEnable),
			.ram_rd_data(wSM_ReadData),
		  
			//dummy bus used to prevent xilinx tools from optimizing stuff away
			//explicitly unconnected to avoid warnings about it.
			//.LMB_Clk(),
			.lmb_clk(),
			.lmb_rst(),
			.lmb_abus(),
			.lmb_writedbus(),
			.lmb_addrstrobe(),
			.lmb_readstrobe(),
			.lmb_writestrobe(),
			.lmb_be(),
			.sl_dbus(),
			.sl_ready(),
			.sl_wait(),
			.sl_ue(),
			.sl_ce()
		);	
	
		RAM_SDP_BE
		#(
			.DATA_WIDTH(D_WIDTH),
			.ADDR_WIDTH(8),
			.DATAFILE(""),
			.ADDRESSABLE_SIZE(8),
			.DO_INIT(0)
		)	
		 STATE_MEM_inst
		(
			.clock(iClk),
			.data(wSM_WriteData),
			.rdaddress(wSM_Address[8-1+INTERFACE_BYTE_ENABLES_WIDTH:INTERFACE_BYTE_ENABLES_WIDTH]),
			.wraddress(wSM_Address[8-1+INTERFACE_BYTE_ENABLES_WIDTH:INTERFACE_BYTE_ENABLES_WIDTH]),
			.wren(wSM_WriteEnable),
			.rden(1'b1),
			.q(wSM_ReadData)
		);			
	`endif	

endmodule
