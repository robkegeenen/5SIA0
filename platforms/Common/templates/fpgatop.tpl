// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Mon Jun 17 20:35:29 2013
// ============================================================================

`define ENABLE_HPS

module <<MODULE_NAME>>
(
	///////// ADC /////////
	inout              ADC_CS_N,
	output             ADC_DIN,
	input              ADC_DOUT,
	output             ADC_SCLK,

	///////// AUD /////////
	input              AUD_ADCDAT,
	inout              AUD_ADCLRCK,
	inout              AUD_BCLK,
	output             AUD_DACDAT,
	inout              AUD_DACLRCK,
	output             AUD_XCK,

	///////// CLOCK2 /////////
	input              CLOCK2_50,

	///////// CLOCK3 /////////
	input              CLOCK3_50,

	///////// CLOCK4 /////////
	input              CLOCK4_50,

	///////// CLOCK /////////
	input              CLOCK_50,

	///////// DRAM /////////
	output      [12:0] DRAM_ADDR,
	output      [1:0]  DRAM_BA,
	output             DRAM_CAS_N,
	output             DRAM_CKE,
	output             DRAM_CLK,
	output             DRAM_CS_N,
	inout       [15:0] DRAM_DQ,
	output             DRAM_LDQM,
	output             DRAM_RAS_N,
	output             DRAM_UDQM,
	output             DRAM_WE_N,

	///////// FAN /////////
	output             FAN_CTRL,

	///////// FPGA /////////
	output             FPGA_I2C_SCLK,
	inout              FPGA_I2C_SDAT,

	///////// GPIO /////////
	inout     [35:0]         GPIO_0,
	inout     [35:0]         GPIO_1,

	///////// HEX /////////
	output      [6:0]  HEX0,
	output      [6:0]  HEX1,
	output      [6:0]  HEX2,
	output      [6:0]  HEX3,
	output      [6:0]  HEX4,
	output      [6:0]  HEX5,

	`ifdef ENABLE_HPS
	  	///////// HPS /////////
	  	inout              HPS_CONV_USB_N,
	  	output      [14:0] HPS_DDR3_ADDR,
	  	output      [2:0]  HPS_DDR3_BA,
	  	output             HPS_DDR3_CAS_N,
	  	output             HPS_DDR3_CKE,
	  	output             HPS_DDR3_CK_N,
	  	output             HPS_DDR3_CK_P,
	  	output             HPS_DDR3_CS_N,
	  	output      [3:0]  HPS_DDR3_DM,
	  	inout       [31:0] HPS_DDR3_DQ,
	  	inout       [3:0]  HPS_DDR3_DQS_N,
	  	inout       [3:0]  HPS_DDR3_DQS_P,
	  	output             HPS_DDR3_ODT,
	  	output             HPS_DDR3_RAS_N,
	  	output             HPS_DDR3_RESET_N,
	  	input              HPS_DDR3_RZQ,
	  	output             HPS_DDR3_WE_N,
	  	output             HPS_ENET_GTX_CLK,
	  	inout              HPS_ENET_INT_N,
	  	output             HPS_ENET_MDC,
	  	inout              HPS_ENET_MDIO,
	  	input              HPS_ENET_RX_CLK,
	  	input       [3:0]  HPS_ENET_RX_DATA,
	  	input              HPS_ENET_RX_DV,
	  	output      [3:0]  HPS_ENET_TX_DATA,
	  	output             HPS_ENET_TX_EN,
	  	inout       [3:0]  HPS_FLASH_DATA,
	  	output             HPS_FLASH_DCLK,
	  	output             HPS_FLASH_NCSO,
	  	inout              HPS_GSENSOR_INT,
	  	inout              HPS_I2C1_SCLK,
	  	inout              HPS_I2C1_SDAT,
	  	inout              HPS_I2C2_SCLK,
	  	inout              HPS_I2C2_SDAT,
	  	inout              HPS_I2C_CONTROL,
	  	inout              HPS_KEY,
	  	inout              HPS_LED,
	  	inout              HPS_LTC_GPIO,
	  	output             HPS_SD_CLK,
	  	inout              HPS_SD_CMD,
	  	inout       [3:0]  HPS_SD_DATA,
	  	output             HPS_SPIM_CLK,
	  	input              HPS_SPIM_MISO,
	  	output             HPS_SPIM_MOSI,
	  	inout              HPS_SPIM_SS,
	  	input              HPS_UART_RX,
	  	output             HPS_UART_TX,
	  	input              HPS_USB_CLKOUT,
	  	inout       [7:0]  HPS_USB_DATA,
	  	input              HPS_USB_DIR,
	  	input              HPS_USB_NXT,
	  	output             HPS_USB_STP,
	`endif /*ENABLE_HPS*/

	///////// IRDA /////////
	input              IRDA_RXD,
	output             IRDA_TXD,

	///////// KEY /////////
	input       [3:0]  KEY,

	///////// LEDR /////////
	output      [9:0]  LEDR,

	///////// PS2 /////////
	inout              PS2_CLK,
	inout              PS2_CLK2,
	inout              PS2_DAT,
	inout              PS2_DAT2,

	///////// SW /////////
	input       [9:0]  SW,

	///////// TD /////////
	input              TD_CLK27,
	input      [7:0]  TD_DATA,
	input             TD_HS,
	output             TD_RESET_N,
	input             TD_VS,


	///////// VGA /////////
	output      [7:0]  VGA_B,
	output             VGA_BLANK_N,
	output             VGA_CLK,
	output      [7:0]  VGA_G,
	output             VGA_HS,
	output      [7:0]  VGA_R,
	output             VGA_SYNC_N,
	output             VGA_VS
);

	// internal wires and registers declaration
	wire [3:0]  fpga_debounced_buttons;
	wire [9:0]  fpga_led_internal;
	wire        hps_fpga_reset_n;
	wire [2:0]  hps_reset_req;
	wire        hps_cold_reset;
	wire        hps_warm_reset;
	wire        hps_debug_reset;
	//wire [27:0] stm_hw_events;

	// connection of internal logics
	//  assign LEDR = fpga_led_internal;
	// assign stm_hw_events    = {{3{1'b0}},SW, fpga_led_internal, fpga_debounced_buttons};


	//read data lower bits are on hex segments
	//	hexto7segment ht27_0 ( read_data[3:0],   HEX0);
	//	hexto7segment ht27_1 ( read_data[7:4],   HEX1);
	//	hexto7segment ht27_2 ( read_data[11:8],  HEX2);
	//	hexto7segment ht27_3 ( read_data[15:12], HEX3);
	//	hexto7segment ht27_4 ( read_data[19:16], HEX4);
	//	hexto7segment ht27_5 ( read_data[23:20], HEX5);

	//////////////////////////////////	
	// AXI to DRR interfaces	
	//
	parameter AXI_MASTER_DATA_WIDTH = 32;
	parameter AXI_MASTER_ADDR_WIDTH = 32;

	//Interface 0 (SMEM)
	parameter DTL0_DATA_WIDTH 					= <<INTERFACE_WIDTH>>;
	parameter DTL0_ADDR_WIDTH 					= <<INTERFACE_ADDR_WIDTH>>;

	parameter DTL0_MEM_WIDTH 					= <<INTERFACE_WIDTH>>;
	parameter DTL0_NUM_ENABLES 					= DTL0_MEM_WIDTH/8;
	parameter DTL0_INTERFACE_BLOCK_WIDTH		= <<INTERFACE_BLOCK_WIDTH>>;

	//Interface 1 (DMEM)
	parameter DTL1_DATA_WIDTH 					= <<INTERFACE_WIDTH>>;
	parameter DTL1_ADDR_WIDTH 					= <<INTERFACE_ADDR_WIDTH>>;

	parameter DTL1_MEM_WIDTH 					= <<INTERFACE_WIDTH>>;
	parameter DTL1_NUM_ENABLES 					= DTL1_MEM_WIDTH/8;
	parameter DTL1_INTERFACE_BLOCK_WIDTH		= <<INTERFACE_BLOCK_WIDTH>>;

	//Interface LW (LOADER)
	parameter DTL_LOADER_INTERFACE_WIDTH 		= <<INTERFACE_WIDTH>>;
	parameter DTL_LOADER_ADDR_WIDTH 			= <<INTERFACE_ADDR_WIDTH>>;
	parameter DTL_LOADER_INTERFACE_BLOCK_WIDTH 	= <<INTERFACE_BLOCK_WIDTH>>;	
		
	localparam INTERFACE_WIDTH 					= DTL1_DATA_WIDTH;
	localparam INTERFACE_ADDR_WIDTH 			= DTL1_ADDR_WIDTH;		
	localparam INTERFACE_NUM_ENABLES 			= DTL1_NUM_ENABLES;
	localparam INTERFACE_BLOCK_WIDTH 			= DTL1_INTERFACE_BLOCK_WIDTH;

	defparam pulse_cold_reset.PULSE_EXT = 6;
	defparam pulse_cold_reset.EDGE_TYPE = 1;
	defparam pulse_cold_reset.IGNORE_RST_WHILE_BUSY = 1;

	defparam pulse_warm_reset.PULSE_EXT = 2;
	defparam pulse_warm_reset.EDGE_TYPE = 1;
	defparam pulse_warm_reset.IGNORE_RST_WHILE_BUSY = 1;

	defparam pulse_debug_reset.PULSE_EXT = 32;
	defparam pulse_debug_reset.EDGE_TYPE = 1;
	defparam pulse_debug_reset.IGNORE_RST_WHILE_BUSY = 1;

	parameter SDRAM_SYS_OFFSET = 'h30000000; //offset in bytes of the start of the CGRA memory in the DDR memory
	parameter SDRAM_SIZE_MASK  = 'h0FFFFFFF; //available address bits (256MB)

	//// DTL 0 -------------------------------------------------------------
	wire 								 		wSDRAM0_awvalid, wSDRAM0_awready;
	wire [DTL0_ADDR_WIDTH-1:0] 					wSDRAM0_awaddr;

	wire 									 	wSDRAM0_wvalid, wSDRAM0_wready;
	wire [DTL0_DATA_WIDTH-1:0]	 				wSDRAM0_wdata;
	wire [DTL0_DATA_WIDTH/8-1:0] 				wSDRAM0_wstrb;

	wire 								 		wSDRAM0_bvalid, wSDRAM0_bready;
	wire [1:0] 						 			wSDRAM0_bresp;	

	wire 								 		wSDRAM0_arvalid, wSDRAM0_arready;
	wire [DTL0_ADDR_WIDTH-1:0]	 				wSDRAM0_araddr;

	wire 									 	wSDRAM0_rvalid, wSDRAM0_rready;
	wire [DTL0_DATA_WIDTH-1:0]	 				wSDRAM0_rdata;
	wire [1:0] 							 		wSDRAM0_rresp;

	wire 										wCGRA_SMEM_CommandValid;
	wire 										wCGRA_SMEM_CommandAccept;
	wire [DTL0_ADDR_WIDTH-1:0] 					wCGRA_SMEM_Address;
	wire 										wCGRA_SMEM_CommandReadWrite;
	wire 										wCGRA_SMEM_BlockSize;
	wire 										wCGRA_SMEM_WriteLast;
	wire 										wCGRA_SMEM_WriteValid;
	wire 										wCGRA_SMEM_WriteAccept;
	wire [DTL0_MEM_WIDTH-1:0] 					wCGRA_SMEM_WriteData;
	wire [(DTL0_MEM_WIDTH/8)-1:0] 				wCGRA_SMEM_WriteEnable;
	wire 										wCGRA_SMEM_ReadLast;
	wire 										wCGRA_SMEM_ReadValid;
	wire 										wCGRA_SMEM_ReadAccept;
	wire [DTL0_MEM_WIDTH-1:0] 					wCGRA_SMEM_ReadData;

	//// DTL 1 -------------------------------------------------------------
	wire 									 	wSDRAM1_awvalid, wSDRAM1_awready;
	wire [DTL1_ADDR_WIDTH-1:0] 					wSDRAM1_awaddr;

	wire 									 	wSDRAM1_wvalid, wSDRAM1_wready;
	wire [DTL1_DATA_WIDTH-1:0]	 				wSDRAM1_wdata;
	wire [DTL1_DATA_WIDTH/8-1:0] 				wSDRAM1_wstrb;

	wire 									 	wSDRAM1_bvalid, wSDRAM1_bready;
	wire [1:0] 						 			wSDRAM1_bresp;	

	wire 									 	wSDRAM1_arvalid, wSDRAM1_arready;
	wire [DTL1_ADDR_WIDTH-1:0]	 				wSDRAM1_araddr;

	wire 								 		wSDRAM1_rvalid, wSDRAM1_rready;
	wire [DTL1_DATA_WIDTH-1:0]	 				wSDRAM1_rdata;
	wire [1:0] 						 			wSDRAM1_rresp;

	wire 										wDTL_ARB_CommandValid;
	wire 										wDTL_ARB_CommandAccept;
	wire [DTL1_ADDR_WIDTH-1:0] 					wDTL_ARB_Address;
	wire 										wDTL_ARB_CommandReadWrite;
	wire 										wDTL_ARB_BlockSize;
	wire 										wDTL_ARB_WriteLast;
	wire 										wDTL_ARB_WriteValid;
	wire 										wDTL_ARB_WriteAccept;
	wire [DTL1_MEM_WIDTH-1:0] 					wDTL_ARB_WriteData;
	wire [(DTL1_MEM_WIDTH/8)-1:0]				wDTL_ARB_WriteEnable;
	wire 										wDTL_ARB_ReadLast;
	wire 										wDTL_ARB_ReadValid;
	wire 										wDTL_ARB_ReadAccept;
	wire [DTL1_MEM_WIDTH-1:0] 					wDTL_ARB_ReadData;

	//// DTL LOADER -------------------------------------------------------
	wire 										wDTL_Loader_CommandAccept;
	wire 										wDTL_Loader_WriteAccept;
	wire 										wDTL_Loader_ReadValid;
	wire 										wDTL_Loader_ReadLast;
	wire [DTL_LOADER_INTERFACE_WIDTH-1:0] 		wDTL_Loader_ReadData;
			
	wire 										wDTL_Loader_CommandValid;
	wire 										wDTL_Loader_WriteValid;	
	wire 										wDTL_Loader_CommandReadWrite;
	wire [(DTL_LOADER_INTERFACE_WIDTH/8)-1:0] 	wDTL_Loader_WriteEnable;
	wire [DTL_LOADER_ADDR_WIDTH-1:0] 			wDTL_Loader_Address;
	wire [DTL_LOADER_INTERFACE_WIDTH-1:0] 		wDTL_Loader_WriteData;
			
	wire [DTL_LOADER_INTERFACE_BLOCK_WIDTH-1:0] wDTL_Loader_BlockSize;
	wire  										wDTL_Loader_WriteLast;
	wire  										wDTL_Loader_ReadAccept;		

	//AXI master interface wires ------------------------------------------
	wire 										wAXI_MASTER_AWVALID;
	wire 										wAXI_MASTER_AWREADY;
	wire [AXI_MASTER_ADDR_WIDTH-1:0]			wAXI_MASTER_AWADDR;

	wire 										wAXI_MASTER_WVALID;
	wire 										wAXI_MASTER_WREADY;
	wire [AXI_MASTER_DATA_WIDTH-1:0] 			wAXI_MASTER_WDATA;
	wire [(AXI_MASTER_DATA_WIDTH/8)-1:0] 		wAXI_MASTER_WSTRB;

	wire 										wAXI_MASTER_BVALID;
	wire 										wAXI_MASTER_BREADY;
	wire [1:0] 									wAXI_MASTER_BRESP;

	wire 										wAXI_MASTER_ARVALID;
	wire 										wAXI_MASTER_ARREADY;
	wire [AXI_MASTER_ADDR_WIDTH-1:0]  			wAXI_MASTER_ARADDR;

	wire 										wAXI_MASTER_RVALID;      
	wire 										wAXI_MASTER_RREADY;     
	wire [AXI_MASTER_DATA_WIDTH-1:0] 			wAXI_MASTER_RDATA;
	wire [1:0] 									wAXI_MASTER_RRESP;
		
	//for VGA clock
	wire CLOCK_25;
	wire CLOCK_25_locked;
	wire wCGRA_Reset;
	wire wCGRA_Halted;
	wire wCGRA_ConfigDone;

	wire iClk = CLOCK_50;
	wire iReset = wCGRA_Reset;

	wire [11:0] wlw_axi_master_awid, wlw_axi_master_arid;
	wire [DTL0_DATA_WIDTH-1:0] wSDRAM0_rdata_mangled;	 
	wire [DTL1_DATA_WIDTH-1:0] wSDRAM1_rdata_mangled;

	wire iVGAClk_VGA = CLOCK_25;

	wire [7:0] oVGA_R_VGA;
	wire [7:0] oVGA_G_VGA;
	wire [7:0] oVGA_B_VGA;
	wire oVGA_Clk_VGA;
	wire oVGA_Sync_VGA;
	wire oVGA_Blank_VGA;
	wire oVGA_VS_VGA;
	wire oVGA_HS_VGA;	

	<<PERIPHERAL_DTL_WIRES>>

<<PERIPHERAL_WOR_WIRES>> 	
	//------------------------------------------------------------------------------------------------

	assign LEDR[0] = wCGRA_Reset;
	assign LEDR[1] = wCGRA_Halted;
	assign LEDR[2] = wCGRA_ConfigDone;
	assign LEDR[9] = CLOCK_25_locked;

	assign VGA_R = oVGA_R_VGA;	
	assign VGA_G = oVGA_G_VGA;
	assign VGA_B = oVGA_B_VGA;
	assign VGA_CLK = oVGA_Clk_VGA;
	assign VGA_SYNC_N = oVGA_Sync_VGA;
	assign VGA_BLANK_N = oVGA_Blank_VGA;
	assign VGA_HS = oVGA_HS_VGA;
	assign VGA_VS = oVGA_VS_VGA;

	//N.B. , AXI, when used in 32-bit mode swaps the nibbles of data, here we demangle this
	//MW: possibly we could change this to a generate statement
	assign wSDRAM0_rdata = {wSDRAM0_rdata_mangled[7:0],wSDRAM0_rdata_mangled[15:8], wSDRAM0_rdata_mangled[23:16], wSDRAM0_rdata_mangled[31:24]};	
	assign wSDRAM1_rdata =  {wSDRAM1_rdata_mangled[7:0],wSDRAM1_rdata_mangled[15:8], wSDRAM1_rdata_mangled[23:16], wSDRAM1_rdata_mangled[31:24]};

<<PERIPHERAL_WOR_ASSIGNS>>
	
	dtl_axi4lite_bridge  
	#(
		.C_DATA_WIDTH(DTL0_DATA_WIDTH),
		.C_ADDR_WIDTH(DTL0_ADDR_WIDTH),
		.C_DTL_BLK_SIZE_WIDTH(DTL0_INTERFACE_BLOCK_WIDTH),
		.C_DTL_MASK_WIDTH(DTL0_NUM_ENABLES),
		.C_FAMILY("cyclonev")
	)
	DTL_SMEM 
	(
		.clk(CLOCK_50),
		.rst_n(hps_fpga_reset_n),

		//////////////////////////////////
		// AXI4lite 
		//

		// AXI4lite master interface
		// AXI clock and reset pins
		//.M_AXI_ACLK(CLOCK_50),        
		//.M_AXI_ARESETN(hps_fpga_reset_n),

		// AXI write address channel
		.M_AXI_AWVALID(wSDRAM0_awvalid),
		.M_AXI_AWREADY(wSDRAM0_awready),
		.M_AXI_AWADDR(wSDRAM0_awaddr),

		// AXI write data channel
		.M_AXI_WVALID(wSDRAM0_wvalid),
		.M_AXI_WREADY(wSDRAM0_wready),
		.M_AXI_WDATA(wSDRAM0_wdata),
		.M_AXI_WSTRB(wSDRAM0_wstrb),

		// AXI write response channel
		.M_AXI_BVALID(wSDRAM0_bvalid),
		.M_AXI_BREADY(wSDRAM0_bready),
		.M_AXI_BRESP(wSDRAM0_bresp),

		// AXI read address channel
		.M_AXI_ARVALID(wSDRAM0_arvalid),
		.M_AXI_ARREADY(wSDRAM0_arready),
		.M_AXI_ARADDR(wSDRAM0_araddr),

		// AXI read data/response channel
		.M_AXI_RVALID(wSDRAM0_rvalid),
		.M_AXI_RREADY(wSDRAM0_rready),
		.M_AXI_RDATA(wSDRAM0_rdata),
		.M_AXI_RRESP(wSDRAM0_rresp),

		//////////////////////////////////
		// DTL 
		//
		.dtl_cmd_valid(wCGRA_SMEM_CommandValid),
		.dtl_cmd_accept(wCGRA_SMEM_CommandAccept),
		.dtl_cmd_addr(wCGRA_SMEM_Address),
		.dtl_cmd_read(wCGRA_SMEM_CommandReadWrite), 
		.dtl_cmd_block_size(wCGRA_SMEM_BlockSize),

		// DTL write data channel
		.dtl_wr_last(wCGRA_SMEM_WriteLast),
		.dtl_wr_valid(wCGRA_SMEM_WriteValid),
		.dtl_wr_accept(wCGRA_SMEM_WriteAccept),
		.dtl_wr_data(wCGRA_SMEM_WriteData),
		.dtl_wr_mask(wCGRA_SMEM_WriteEnable),

		// DTL read data channel
		.dtl_rd_last(wCGRA_SMEM_ReadLast),
		.dtl_rd_valid(wCGRA_SMEM_ReadValid), 
		.dtl_rd_accept(wCGRA_SMEM_ReadAccept),
		.dtl_rd_data(wCGRA_SMEM_ReadData)
	);
		
	dtl_axi4lite_bridge  
	#(
		.C_DATA_WIDTH(DTL1_DATA_WIDTH),
		.C_ADDR_WIDTH(DTL1_ADDR_WIDTH),
		.C_DTL_BLK_SIZE_WIDTH(DTL1_INTERFACE_BLOCK_WIDTH),
		.C_DTL_MASK_WIDTH(DTL1_NUM_ENABLES),
		.C_FAMILY("cyclonev")
	)
	DTL_DMEM 
	(
		.clk(CLOCK_50),
		.rst_n(hps_fpga_reset_n),

		//////////////////////////////////
		// AXI4lite 
		//

		// AXI4lite master interface
		// AXI clock and reset pins
		//.M_AXI_ACLK(CLOCK_50),        
		//.M_AXI_ARESETN(hps_fpga_reset_n),

		// AXI write address channel
		.M_AXI_AWVALID(wSDRAM1_awvalid),
		.M_AXI_AWREADY(wSDRAM1_awready),
		.M_AXI_AWADDR(wSDRAM1_awaddr),

		// AXI write data channel
		.M_AXI_WVALID(wSDRAM1_wvalid),
		.M_AXI_WREADY(wSDRAM1_wready),
		.M_AXI_WDATA(wSDRAM1_wdata),
		.M_AXI_WSTRB(wSDRAM1_wstrb),

		// AXI write response channel
		.M_AXI_BVALID(wSDRAM1_bvalid),
		.M_AXI_BREADY(wSDRAM1_bready),
		.M_AXI_BRESP(wSDRAM1_bresp),

		// AXI read address channel
		.M_AXI_ARVALID(wSDRAM1_arvalid),
		.M_AXI_ARREADY(wSDRAM1_arready),
		.M_AXI_ARADDR(wSDRAM1_araddr),

		// AXI read data/response channel
		.M_AXI_RVALID(wSDRAM1_rvalid),
		.M_AXI_RREADY(wSDRAM1_rready),
		.M_AXI_RDATA(wSDRAM1_rdata),
		.M_AXI_RRESP(wSDRAM1_rresp),

		//////////////////////////////////
		// DTL 
		//
		.dtl_cmd_valid(wDTL_GM_CommandValid),
		.dtl_cmd_accept(wDTL_GM_CommandAccept),
		.dtl_cmd_addr(wDTL_GM_Address),
		.dtl_cmd_read(wDTL_GM_CommandReadWrite), 
		.dtl_cmd_block_size(wDTL_GM_BlockSize),

		// DTL write data channel
		.dtl_wr_last(wDTL_GM_WriteLast),
		.dtl_wr_valid(wDTL_GM_WriteValid),
		.dtl_wr_accept(wDTL_GM_WriteAccept),
		.dtl_wr_data(wDTL_GM_WriteData),
		.dtl_wr_mask(wDTL_GM_WriteEnable),

		// DTL read data channel
		.dtl_rd_last(wDTL_GM_ReadLast),
		.dtl_rd_valid(wDTL_GM_ReadValid), 
		.dtl_rd_accept(wDTL_GM_ReadAccept),
		.dtl_rd_data(wDTL_GM_ReadData)
	);
		
	axi4lite_dtl_bridge  
	#(
		.C_DATA_WIDTH(AXI_MASTER_DATA_WIDTH),
		.C_ADDR_WIDTH(AXI_MASTER_ADDR_WIDTH),
		.C_DTL_BLK_SIZE_WIDTH(5),
		.C_BASEADDR0('hFFFFFFFF),
		.C_HIGHADDR0('h00000000),
		.C_BASEADDR1('hFFFFFFFF),
		.C_HIGHADDR1('h00000000),
		.C_BASEADDR2('hFFFFFFFF),
		.C_HIGHADDR2('h00000000),
		.C_BASEADDR3('hFFFFFFFF),
		.C_HIGHADDR3('h00000000),
		.C_FAMILY("Cyclonev")
	)
	DTL_Loader
	(
		.S_AXI_ACLK(CLOCK_50),
		.S_AXI_ARESETN(hps_fpga_reset_n),

		// AXI write address channel
		.S_AXI_AWVALID(wAXI_MASTER_AWVALID),
		.S_AXI_AWREADY(wAXI_MASTER_AWREADY),     
		.S_AXI_AWADDR(wAXI_MASTER_AWADDR),

		//AXI write data channel
		.S_AXI_WVALID(wAXI_MASTER_WVALID),
		.S_AXI_WREADY(wAXI_MASTER_WREADY),
		.S_AXI_WDATA(wAXI_MASTER_WDATA),
		.S_AXI_WSTRB(wAXI_MASTER_WSTRB),

		//AXI write response channel
		.S_AXI_BVALID(wAXI_MASTER_BVALID),
		.S_AXI_BREADY(wAXI_MASTER_BREADY),
		.S_AXI_BRESP(wAXI_MASTER_BRESP),

		// AXI read address channel
		.S_AXI_ARVALID(wAXI_MASTER_ARVALID),
		.S_AXI_ARREADY(wAXI_MASTER_ARREADY),
		.S_AXI_ARADDR(wAXI_MASTER_ARADDR),

		// AXI read data/response channel
		.S_AXI_RVALID(wAXI_MASTER_RVALID),
		.S_AXI_RREADY(wAXI_MASTER_RREADY),
		.S_AXI_RDATA(wAXI_MASTER_RDATA),
		.S_AXI_RRESP(wAXI_MASTER_RRESP),

		// DTL master interface
		// DTL command/address channel
		.dtl_cmd_valid(wDTL_Loader_CommandValid),
		.dtl_cmd_accept(wDTL_Loader_CommandAccept),
		.dtl_cmd_addr(wDTL_Loader_Address),
		.dtl_cmd_read(wDTL_Loader_CommandReadWrite),
		.dtl_cmd_block_size(wDTL_Loader_BlockSize),

		// DTL write data channel
		.dtl_wr_last(wDTL_Loader_WriteLast),
		.dtl_wr_valid(wDTL_Loader_WriteValid),
		.dtl_wr_accept(wDTL_Loader_WriteAccept),
		.dtl_wr_data(wDTL_Loader_WriteData),
		.dtl_wr_mask(wDTL_Loader_WriteEnable),

		// DTL read data channel
		.dtl_rd_last(wDTL_Loader_ReadLast),
		.dtl_rd_valid(wDTL_Loader_ReadValid),
		.dtl_rd_accept(wDTL_Loader_ReadAccept),
		.dtl_rd_data(wDTL_Loader_ReadData)

		//.dtl_rst(), //out
		//.dtl_rst_n()  //out
	);

	soc_system u0 
	(   
		//   __________________                       
		//	|    			   |                       
		//	|  HPS AXI Master  |                      
		//	|__________________| 
		.hps_0_h2f_lw_axi_master_awid(wlw_axi_master_awid),
		.hps_0_h2f_lw_axi_master_awaddr(wAXI_MASTER_AWADDR),       
		//output wire [3:0]  hps_0_h2f_lw_axi_master_awlen,      
		//output wire [2:0]  hps_0_h2f_lw_axi_master_awsize,      
		//output wire [1:0]  hps_0_h2f_lw_axi_master_awburst,      
		//output wire [1:0]  hps_0_h2f_lw_axi_master_awlock,    
		//output wire [3:0]  hps_0_h2f_lw_axi_master_awcache,       
		//output wire [2:0]  hps_0_h2f_lw_axi_master_awprot,      
		.hps_0_h2f_lw_axi_master_awvalid(wAXI_MASTER_AWVALID),    
		.hps_0_h2f_lw_axi_master_awready(wAXI_MASTER_AWREADY),      

		//output wire [11:0] hps_0_h2f_lw_axi_master_wid,         
		.hps_0_h2f_lw_axi_master_wdata(wAXI_MASTER_WDATA),        
		.hps_0_h2f_lw_axi_master_wstrb(wAXI_MASTER_WSTRB),       
		//output wire        hps_0_h2f_lw_axi_master_wlast,       
		.hps_0_h2f_lw_axi_master_wvalid(wAXI_MASTER_WVALID),       
		.hps_0_h2f_lw_axi_master_wready(wAXI_MASTER_WREADY),      

		.hps_0_h2f_lw_axi_master_bid(wlw_axi_master_awid),
		.hps_0_h2f_lw_axi_master_bresp(wAXI_MASTER_BRESP),        
		.hps_0_h2f_lw_axi_master_bvalid(wAXI_MASTER_BVALID),      
		.hps_0_h2f_lw_axi_master_bready(wAXI_MASTER_BREADY),       

		.hps_0_h2f_lw_axi_master_arid(wlw_axi_master_arid), 
		.hps_0_h2f_lw_axi_master_araddr(wAXI_MASTER_ARADDR),      
		//output wire [3:0]  hps_0_h2f_lw_axi_master_arlen,        
		//output wire [2:0]  hps_0_h2f_lw_axi_master_arsize,        
		//output wire [1:0]  hps_0_h2f_lw_axi_master_arburst,      
		//output wire [1:0]  hps_0_h2f_lw_axi_master_arlock,       
		//output wire [3:0]  hps_0_h2f_lw_axi_master_arcache,       
		//output wire [2:0]  hps_0_h2f_lw_axi_master_arprot,        
		.hps_0_h2f_lw_axi_master_arvalid(wAXI_MASTER_ARVALID),       
		.hps_0_h2f_lw_axi_master_arready(wAXI_MASTER_ARREADY),       

		.hps_0_h2f_lw_axi_master_rid(wlw_axi_master_arid),
		.hps_0_h2f_lw_axi_master_rdata(wAXI_MASTER_RDATA),       
		.hps_0_h2f_lw_axi_master_rresp(wAXI_MASTER_RRESP),       
		.hps_0_h2f_lw_axi_master_rlast('b1),       
		.hps_0_h2f_lw_axi_master_rvalid(wAXI_MASTER_RVALID),     
		.hps_0_h2f_lw_axi_master_rready(wAXI_MASTER_RREADY),      

		//   _________________________                       
		//	|    				      |                       
		//	|  AXI--> DDR Interface 0 |                      
		//	|_________________________|                       
		.hps_sdram0_data_araddr((wSDRAM0_araddr&SDRAM_SIZE_MASK)|SDRAM_SYS_OFFSET),    		
		.hps_sdram0_data_arlen(0),     							
		.hps_sdram0_data_arid(0),      							
		.hps_sdram0_data_arsize(2),    						
		.hps_sdram0_data_arburst(0),   							
		.hps_sdram0_data_arlock(0),    						
		.hps_sdram0_data_arprot(2),    							
		.hps_sdram0_data_arvalid(wSDRAM0_arvalid),   		
		.hps_sdram0_data_arcache('b0000),   					
		.hps_sdram0_data_arready(wSDRAM0_arready),    

		.hps_sdram0_data_awaddr((wSDRAM0_awaddr&SDRAM_SIZE_MASK)|SDRAM_SYS_OFFSET),    		
		.hps_sdram0_data_awlen(0),     							
		.hps_sdram0_data_awid(0),      						
		.hps_sdram0_data_awsize(2),    			           
		.hps_sdram0_data_awburst(0),   							
		.hps_sdram0_data_awlock(0),    							
		.hps_sdram0_data_awprot(2),    							
		.hps_sdram0_data_awvalid(wSDRAM0_awvalid),   		
		.hps_sdram0_data_awcache('b0000),   					
		.hps_sdram0_data_awready(wSDRAM0_awready),   		

		.hps_sdram0_data_bresp(wSDRAM0_bresp),     			
		//.hps_sdram0_data_bid(),       							// .bid     	OUT 	ignore
		.hps_sdram0_data_bvalid(wSDRAM0_bvalid),    		
		.hps_sdram0_data_bready(wSDRAM0_bready),    		

		.hps_sdram0_data_rdata(wSDRAM0_rdata_mangled),     			
		.hps_sdram0_data_rresp(wSDRAM0_rresp),     			
		//.hps_sdram0_data_rlast(),     							// .rlast   	OUT 	ignore
		//.hps_sdram0_data_rid(),       							// .rid     	OUT 	ignore
		.hps_sdram0_data_rvalid(wSDRAM0_rvalid),    		
		.hps_sdram0_data_rready(wSDRAM0_rready),    		

		.hps_sdram0_data_wlast(wSDRAM0_awvalid),     		//NOTE: change this when actual bursts are going to be used. Now any command is always last...
		.hps_sdram0_data_wvalid(wSDRAM0_wvalid),    		   
		.hps_sdram0_data_wdata(wSDRAM0_wdata),    			
		.hps_sdram0_data_wstrb(wSDRAM0_wstrb),     			
		.hps_sdram0_data_wready(wSDRAM0_wready),    		
		.hps_sdram0_data_wid(0), 

		//   _________________________                       
		//	| 				          |                       
		//	|  AXI--> DDR Interface 1 |                      
		//	|_________________________|                       
		.hps_sdram1_data_araddr((wSDRAM1_araddr&SDRAM_SIZE_MASK)|SDRAM_SYS_OFFSET),    		
		.hps_sdram1_data_arlen(0),     							
		.hps_sdram1_data_arid(1),      							
		.hps_sdram1_data_arsize(2),    						
		.hps_sdram1_data_arburst(0),   							
		.hps_sdram1_data_arlock(0),    						
		.hps_sdram1_data_arprot(2),    							
		.hps_sdram1_data_arvalid(wSDRAM1_arvalid),   		
		.hps_sdram1_data_arcache('b0000),   					
		.hps_sdram1_data_arready(wSDRAM1_arready),    

		.hps_sdram1_data_awaddr((wSDRAM1_awaddr&SDRAM_SIZE_MASK)|SDRAM_SYS_OFFSET),    		
		.hps_sdram1_data_awlen(0),     							
		.hps_sdram1_data_awid(1),      						
		.hps_sdram1_data_awsize(2),    			           
		.hps_sdram1_data_awburst(0),   							
		.hps_sdram1_data_awlock(0),    							
		.hps_sdram1_data_awprot(2),    							
		.hps_sdram1_data_awvalid(wSDRAM1_awvalid),   		
		.hps_sdram1_data_awcache('b0000),   					
		.hps_sdram1_data_awready(wSDRAM1_awready),   		

		.hps_sdram1_data_bresp(wSDRAM1_bresp),     			
		//.hps_sdram1_data_bid(),       							// .bid     	OUT 	ignore
		.hps_sdram1_data_bvalid(wSDRAM1_bvalid),    		
		.hps_sdram1_data_bready(wSDRAM1_bready),    		

		.hps_sdram1_data_rdata(wSDRAM1_rdata_mangled),     			
		.hps_sdram1_data_rresp(wSDRAM1_rresp),     			
		//.hps_sdram1_data_rlast(),     							// .rlast   	OUT 	ignore
		//.hps_sdram1_data_rid(),       							// .rid     	OUT 	ignore
		.hps_sdram1_data_rvalid(wSDRAM1_rvalid),    		
		.hps_sdram1_data_rready(wSDRAM1_rready),    		

		.hps_sdram1_data_wlast(wSDRAM1_awvalid),     				//NOTE: change this when actual bursts are going to be used. Now any command is always last...
		.hps_sdram1_data_wvalid(wSDRAM1_wvalid),    		   
		.hps_sdram1_data_wdata(wSDRAM1_wdata),    			
		.hps_sdram1_data_wstrb(wSDRAM1_wstrb),     			
		.hps_sdram1_data_wready(wSDRAM1_wready),    		
		.hps_sdram1_data_wid(1), 

		.pio_led_external_connection_export    (),     				// pinso_led_external_connection.export (LEDR)
		 
		.memory_mem_a(HPS_DDR3_ADDR),								// memory.mem_a
		.memory_mem_ba(HPS_DDR3_BA),								//       .mem_ba
		.memory_mem_ck(HPS_DDR3_CK_P),								//       .mem_ck
		.memory_mem_ck_n(HPS_DDR3_CK_N),							//       .mem_ck_n
		.memory_mem_cke(HPS_DDR3_CKE),								//       .mem_cke
		.memory_mem_cs_n(HPS_DDR3_CS_N),							//       .mem_cs_n
		.memory_mem_ras_n(HPS_DDR3_RAS_N),							//       .mem_ras_n
		.memory_mem_cas_n(HPS_DDR3_CAS_N),							//       .mem_cas_n
		.memory_mem_we_n(HPS_DDR3_WE_N),							//       .mem_we_n
		.memory_mem_reset_n(HPS_DDR3_RESET_N),						//       .mem_reset_n
		.memory_mem_dq(HPS_DDR3_DQ),								//       .mem_dq
		.memory_mem_dqs(HPS_DDR3_DQS_P),							//       .mem_dqs
		.memory_mem_dqs_n(HPS_DDR3_DQS_N),							//       .mem_dqs_n
		.memory_mem_odt(HPS_DDR3_ODT),								//       .mem_odt
		.memory_mem_dm(HPS_DDR3_DM),								//       .mem_dm
		.memory_oct_rzqin(HPS_DDR3_RZQ),							//       .oct_rzqin

		.hps_0_hps_io_hps_io_emac1_inst_TX_CLK(HPS_ENET_GTX_CLK),	// hps_0_hps_io.hps_io_emac1_inst_TX_CLK
		.hps_0_hps_io_hps_io_emac1_inst_TXD0(HPS_ENET_TX_DATA[0]),	//             .hps_io_emac1_inst_TXD0
		.hps_0_hps_io_hps_io_emac1_inst_TXD1(HPS_ENET_TX_DATA[1]),	//             .hps_io_emac1_inst_TXD1
		.hps_0_hps_io_hps_io_emac1_inst_TXD2(HPS_ENET_TX_DATA[2]),	//             .hps_io_emac1_inst_TXD2
		.hps_0_hps_io_hps_io_emac1_inst_TXD3(HPS_ENET_TX_DATA[3]),	//             .hps_io_emac1_inst_TXD3
		.hps_0_hps_io_hps_io_emac1_inst_RXD0(HPS_ENET_RX_DATA[0]),	//             .hps_io_emac1_inst_RXD0
		.hps_0_hps_io_hps_io_emac1_inst_MDIO(HPS_ENET_MDIO),		//             .hps_io_emac1_inst_MDIO
		.hps_0_hps_io_hps_io_emac1_inst_MDC(HPS_ENET_MDC),			//             .hps_io_emac1_inst_MDC
		.hps_0_hps_io_hps_io_emac1_inst_RX_CTL(HPS_ENET_RX_DV),		//             .hps_io_emac1_inst_RX_CTL
		.hps_0_hps_io_hps_io_emac1_inst_TX_CTL(HPS_ENET_TX_EN),		//             .hps_io_emac1_inst_TX_CTL
		.hps_0_hps_io_hps_io_emac1_inst_RX_CLK(HPS_ENET_RX_CLK),	//             .hps_io_emac1_inst_RX_CLK
		.hps_0_hps_io_hps_io_emac1_inst_RXD1(HPS_ENET_RX_DATA[1]),	//             .hps_io_emac1_inst_RXD1
		.hps_0_hps_io_hps_io_emac1_inst_RXD2(HPS_ENET_RX_DATA[2]),	//             .hps_io_emac1_inst_RXD2
		.hps_0_hps_io_hps_io_emac1_inst_RXD3(HPS_ENET_RX_DATA[3]),	//             .hps_io_emac1_inst_RXD3


		.hps_0_hps_io_hps_io_qspi_inst_IO0(HPS_FLASH_DATA[0]),		//             .hps_io_qspi_inst_IO0
		.hps_0_hps_io_hps_io_qspi_inst_IO1(HPS_FLASH_DATA[1]),		//             .hps_io_qspi_inst_IO1
		.hps_0_hps_io_hps_io_qspi_inst_IO2(HPS_FLASH_DATA[2]),		//             .hps_io_qspi_inst_IO2
		.hps_0_hps_io_hps_io_qspi_inst_IO3(HPS_FLASH_DATA[3]),		//             .hps_io_qspi_inst_IO3
		.hps_0_hps_io_hps_io_qspi_inst_SS0(HPS_FLASH_NCSO),			//             .hps_io_qspi_inst_SS0
		.hps_0_hps_io_hps_io_qspi_inst_CLK(HPS_FLASH_DCLK),			//             .hps_io_qspi_inst_CLK

		.hps_0_hps_io_hps_io_sdio_inst_CMD(HPS_SD_CMD),				//             .hps_io_sdio_inst_CMD
		.hps_0_hps_io_hps_io_sdio_inst_D0(HPS_SD_DATA[0]),			//             .hps_io_sdio_inst_D0
		.hps_0_hps_io_hps_io_sdio_inst_D1(HPS_SD_DATA[1]),			//             .hps_io_sdio_inst_D1
		.hps_0_hps_io_hps_io_sdio_inst_CLK(HPS_SD_CLK),				//             .hps_io_sdio_inst_CLK
		.hps_0_hps_io_hps_io_sdio_inst_D2(HPS_SD_DATA[2]),			//             .hps_io_sdio_inst_D2
		.hps_0_hps_io_hps_io_sdio_inst_D3(HPS_SD_DATA[3]),			//             .hps_io_sdio_inst_D3
			  
		.hps_0_hps_io_hps_io_usb1_inst_D0(HPS_USB_DATA[0]),			//             .hps_io_usb1_inst_D0
		.hps_0_hps_io_hps_io_usb1_inst_D1(HPS_USB_DATA[1]),			//             .hps_io_usb1_inst_D1
		.hps_0_hps_io_hps_io_usb1_inst_D2(HPS_USB_DATA[2]),			//             .hps_io_usb1_inst_D2
		.hps_0_hps_io_hps_io_usb1_inst_D3(HPS_USB_DATA[3]),			//             .hps_io_usb1_inst_D3
		.hps_0_hps_io_hps_io_usb1_inst_D4(HPS_USB_DATA[4]),			//             .hps_io_usb1_inst_D4
		.hps_0_hps_io_hps_io_usb1_inst_D5(HPS_USB_DATA[5]),			//             .hps_io_usb1_inst_D5
		.hps_0_hps_io_hps_io_usb1_inst_D6(HPS_USB_DATA[6]),			//             .hps_io_usb1_inst_D6
		.hps_0_hps_io_hps_io_usb1_inst_D7(HPS_USB_DATA[7]),			//             .hps_io_usb1_inst_D7
		.hps_0_hps_io_hps_io_usb1_inst_CLK(HPS_USB_CLKOUT),			//             .hps_io_usb1_inst_CLK
		.hps_0_hps_io_hps_io_usb1_inst_STP(HPS_USB_STP),			//             .hps_io_usb1_inst_STP
		.hps_0_hps_io_hps_io_usb1_inst_DIR(HPS_USB_DIR),			//             .hps_io_usb1_inst_DIR
		.hps_0_hps_io_hps_io_usb1_inst_NXT(HPS_USB_NXT),			//             .hps_io_usb1_inst_NXT
			  
		.hps_0_hps_io_hps_io_spim1_inst_CLK(HPS_SPIM_CLK),			//             .hps_io_spim1_inst_CLK
		.hps_0_hps_io_hps_io_spim1_inst_MOSI(HPS_SPIM_MOSI),		//             .hps_io_spim1_inst_MOSI
		.hps_0_hps_io_hps_io_spim1_inst_MISO(HPS_SPIM_MISO),		//             .hps_io_spim1_inst_MISO
		.hps_0_hps_io_hps_io_spim1_inst_SS0(HPS_SPIM_SS),			//             .hps_io_spim1_inst_SS0
			
		.hps_0_hps_io_hps_io_uart0_inst_RX(HPS_UART_RX),			//             .hps_io_uart0_inst_RX
		.hps_0_hps_io_hps_io_uart0_inst_TX(HPS_UART_TX),			//             .hps_io_uart0_inst_TX

		.hps_0_hps_io_hps_io_i2c0_inst_SDA(HPS_I2C1_SDAT),			//             .hps_io_i2c0_inst_SDA
		.hps_0_hps_io_hps_io_i2c0_inst_SCL(HPS_I2C1_SCLK),			//             .hps_io_i2c0_inst_SCL

		.hps_0_hps_io_hps_io_i2c1_inst_SDA(HPS_I2C2_SDAT),			//             .hps_io_i2c1_inst_SDA
		.hps_0_hps_io_hps_io_i2c1_inst_SCL(HPS_I2C2_SCLK),			//             .hps_io_i2c1_inst_SCL

		.hps_0_hps_io_hps_io_gpio_inst_GPIO09(HPS_CONV_USB_N),		//             .hps_io_gpio_inst_GPIO09
		.hps_0_hps_io_hps_io_gpio_inst_GPIO35(HPS_ENET_INT_N),		//             .hps_io_gpio_inst_GPIO35
		.hps_0_hps_io_hps_io_gpio_inst_GPIO40(HPS_LTC_GPIO),		//             .hps_io_gpio_inst_GPIO40
		//.hps_0_hps_io_hps_io_gpio_inst_GPIO41  (HPS_GPIO[1]),		//             .hps_io_gpio_inst_GPIO41
		.hps_0_hps_io_hps_io_gpio_inst_GPIO48(HPS_I2C_CONTROL),		//             .hps_io_gpio_inst_GPIO48
		.hps_0_hps_io_hps_io_gpio_inst_GPIO53(HPS_LED),				//             .hps_io_gpio_inst_GPIO53
		.hps_0_hps_io_hps_io_gpio_inst_GPIO54(HPS_KEY),				//             .hps_io_gpio_inst_GPIO54
		.hps_0_hps_io_hps_io_gpio_inst_GPIO61(HPS_GSENSOR_INT),		//             .hps_io_gpio_inst_GPIO61

		//.hps_0_f2h_stm_hw_events_stm_hwevents  (stm_hw_events),	// hps_0_f2h_stm_hw_events.stm_hwevents

		.clk_clk(CLOCK_50),											// clk.clk
		.reset_reset_n(hps_fpga_reset_n),							// reset.reset_n
		.hps_0_h2f_reset_reset_n(hps_fpga_reset_n),					// hps_0_h2f_reset.reset_n
		.hps_0_f2h_warm_reset_req_reset_n(~hps_warm_reset),			// hps_0_f2h_warm_reset_req.reset_n
		.hps_0_f2h_debug_reset_req_reset_n(~hps_debug_reset),		// hps_0_f2h_debug_reset_req.reset_n
		.hps_0_f2h_cold_reset_req_reset_n(~hps_cold_reset)			// hps_0_f2h_cold_reset_req.reset_n
	);
	  
	// Source/Probe megawizard instance
	hps_reset hps_reset_inst 
	(
		.source_clk (CLOCK_50),
		.source     (hps_reset_req)
	);

	altera_edge_detector pulse_cold_reset 
	(
		.clk       (CLOCK_50),
		.rst_n     (hps_fpga_reset_n),
		.signal_in (hps_reset_req[0]),
		.pulse_out (hps_cold_reset)
	);

	altera_edge_detector pulse_warm_reset 
	(
		.clk       (CLOCK_50),
		.rst_n     (hps_fpga_reset_n),
		.signal_in (hps_reset_req[1]),
		.pulse_out (hps_warm_reset)
	);
	  
	altera_edge_detector pulse_debug_reset 
	(
		.clk       (CLOCK_50),
		.rst_n     (hps_fpga_reset_n),
		.signal_in (hps_reset_req[2]),
		.pulse_out (hps_debug_reset)
	);
	  
	PLL PLL_inst 
	(
		.refclk(CLOCK_50),   
		.rst(!hps_fpga_reset_n),   
		.outclk_0(), //50MHz
		.outclk_1(CLOCK_25), //25 MHz
		.locked(CLOCK_25_locked)   
	);	  
	
	//------------------------------------------------------------------------------------------------------------------------------------------------------------

	<<CORE_NAME>> <<CORE_NAME>>_inst
	(
		//inputs and outputs
		.iClk(CLOCK_50),
		.iReset(SW[0]), //~hps_fpga_reset_n),
		.oReset(wCGRA_Reset),
		.oHalted(wCGRA_Halted),
		.oConfigDone(wCGRA_ConfigDone),

		//DTL interface for control by the host (SLAVE)
		.oDTL_Loader_CommandAccept(wDTL_Loader_CommandAccept),
		.oDTL_Loader_WriteAccept(wDTL_Loader_WriteAccept),
		.oDTL_Loader_ReadValid(wDTL_Loader_ReadValid),
		.oDTL_Loader_ReadLast(wDTL_Loader_ReadLast),
		.oDTL_Loader_ReadData(wDTL_Loader_ReadData),
			
		.iDTL_Loader_CommandValid(wDTL_Loader_CommandValid),
		.iDTL_Loader_WriteValid(wDTL_Loader_WriteValid),		
		.iDTL_Loader_CommandReadWrite(wDTL_Loader_CommandReadWrite),
		.iDTL_Loader_WriteEnable(wDTL_Loader_WriteEnable),
		.iDTL_Loader_Address(wDTL_Loader_Address),	
		.iDTL_Loader_WriteData(wDTL_Loader_WriteData),
			
		.iDTL_Loader_BlockSize(wDTL_Loader_BlockSize),
		.iDTL_Loader_WriteLast(wDTL_Loader_WriteLast),
		.iDTL_Loader_ReadAccept(wDTL_Loader_ReadAccept),				
			
		//DTL interface for the shared memory with the host (MASTER)
		.iDTL_SMEM_CommandAccept(wCGRA_SMEM_CommandAccept),
		.iDTL_SMEM_WriteAccept(wCGRA_SMEM_WriteAccept),
		.iDTL_SMEM_ReadValid(wCGRA_SMEM_ReadValid),
		.iDTL_SMEM_ReadLast(wCGRA_SMEM_ReadLast),
		.iDTL_SMEM_ReadData(wCGRA_SMEM_ReadData),
				
		.oDTL_SMEM_CommandValid(wCGRA_SMEM_CommandValid),
		.oDTL_SMEM_WriteValid(wCGRA_SMEM_WriteValid),		
		.oDTL_SMEM_CommandReadWrite(wCGRA_SMEM_CommandReadWrite),
		.oDTL_SMEM_WriteEnable(wCGRA_SMEM_WriteEnable),
		.oDTL_SMEM_Address(wCGRA_SMEM_Address),	
		.oDTL_SMEM_WriteData(wCGRA_SMEM_WriteData),
			
		.oDTL_SMEM_BlockSize(wCGRA_SMEM_BlockSize),
		.oDTL_SMEM_WriteLast(wCGRA_SMEM_WriteLast),
		.oDTL_SMEM_ReadAccept(wCGRA_SMEM_ReadAccept),	
		
		//DTL interface for the global memory (MASTER)
		.iDTL_DMEM_CommandAccept(wDTL_ARB_CommandAccept),
		.iDTL_DMEM_WriteAccept(wDTL_ARB_WriteAccept),
		.iDTL_DMEM_ReadValid(wDTL_ARB_ReadValid),
		.iDTL_DMEM_ReadLast(wDTL_ARB_ReadLast),
		.iDTL_DMEM_ReadData(wDTL_ARB_ReadData),
				
		.oDTL_DMEM_CommandValid(wDTL_ARB_CommandValid),
		.oDTL_DMEM_WriteValid(wDTL_ARB_WriteValid),		
		.oDTL_DMEM_CommandReadWrite(wDTL_ARB_CommandReadWrite),
		.oDTL_DMEM_WriteEnable(wDTL_ARB_WriteEnable),
		.oDTL_DMEM_Address(wDTL_ARB_Address),	
		.oDTL_DMEM_WriteData(wDTL_ARB_WriteData),
			
		.oDTL_DMEM_BlockSize(wDTL_ARB_BlockSize),
		.oDTL_DMEM_WriteLast(wDTL_ARB_WriteLast),
		.oDTL_DMEM_ReadAccept(wDTL_ARB_ReadAccept)	

	//		`ifdef INCLUDE_STATE_CONTROL	,//use only if state control is enabled	
	//			//DTL interface for the state memory (MASTER)
	//			input iDTL_STATE_CommandAccept,
	//			input iDTL_STATE_WriteAccept,
	//			input iDTL_STATE_ReadValid,
	//			input iDTL_STATE_ReadLast,
	//			input [INTERFACE_WIDTH-1:0] iDTL_STATE_ReadData,
	//				
	//			output oDTL_STATE_CommandValid,
	//			output oDTL_STATE_WriteValid,	
	//			output oDTL_STATE_CommandReadWrite,
	//			output [(INTERFACE_WIDTH/8)-1:0] oDTL_STATE_WriteEnable,	
	//			output [INTERFACE_ADDR_WIDTH-1:0] oDTL_STATE_Address,
	//			output [INTERFACE_WIDTH-1:0] oDTL_STATE_WriteData,
	//			
	//			output [INTERFACE_BLOCK_WIDTH-1:0] oDTL_STATE_BlockSize,
	//			output oDTL_STATE_WriteLast,
	//			output oDTL_STATE_ReadAccept	
	//		`endif		
	);

	  
	<<PERIPHERALS>>

endmodule

