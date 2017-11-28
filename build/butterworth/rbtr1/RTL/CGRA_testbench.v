`timescale 1 ns / 1 ns

`include "config.vh"

module TB_CGRA_Top;

	parameter LOADER_OFFSET = 32'hC0000;

	//common parameters
	parameter D_WIDTH = 32;
	parameter I_WIDTH = 12;
	parameter I_IMM_WIDTH = 33;
	parameter I_DECODED_WIDTH = 16;
	
	parameter LM_ADDR_WIDTH = 16;
	parameter GM_ADDR_WIDTH = 32;	
	parameter IM_ADDR_WIDTH = 16;
	
	parameter LM_MEM_ADDR_WIDTH = 8;
	parameter GM_MEM_ADDR_WIDTH = 13;
	parameter IM_MEM_ADDR_WIDTH = 8;
	parameter LM_MEM_WIDTH = 32;
	parameter GM_MEM_WIDTH = 32;

	parameter NUM_ID = 10;
	parameter NUM_IMM = 3;
	parameter NUM_LDMEM = 2;
	parameter NUM_GDMEM = 2;
	
	parameter INTERFACE_WIDTH = 32;
	parameter INTERFACE_ADDR_WIDTH = 32;
	parameter INTERFACE_BLOCK_WIDTH = 5;

	parameter MAGIC_DMEM_LOAD = 1;

	parameter BINARY_WORDS = 2**15;
	parameter BINARY_FILE = "out.bin";
	
	parameter STATE_IDLE = 3'b000;
	parameter STATE_DATA_LOAD = 3'b001;
	parameter STATE_CONFIG_LOAD = 3'b010;
	parameter STATE_RELEASE_RESET = 3'b011;

	parameter STATE_CONFIG_STATE_READADDR = 3'b100;
	parameter STATE_CONFIG_STATE_WRITEADDR = 3'b101;
	parameter STATE_CONFIG_STATE_COMMAND = 3'b110;	
	
	//declare required registers
	reg rClk = 0;
	reg rReset = 1;
	
	//generate the master clock
	always begin
		#5 rClk <= !rClk;
	end

	reg [INTERFACE_WIDTH-1:0] rBinary [BINARY_WORDS-1:0];
	reg [INTERFACE_WIDTH-1:0] rDataBinary [2**GM_MEM_ADDR_WIDTH-1:0];
	
	reg [2:0] rState;
	reg [127:0] rCycleLimitCount;

	initial begin
		rCycleLimitCount=0;
	end

	`ifndef ASIC_NO_PERF_COUNTERS
	`ifndef ASIC_SYNTHESIS 
	always @(posedge rClk)
	begin
		rCycleLimitCount <= rCycleLimitCount + 1;

		if (rCycleLimitCount > 5000000)
		begin
			$fatal("MAXIMUM SIMULATION TIME EXCEEDED!!!");
			
		end
	end
	`endif
	`endif
		
	//---------------- FOR LOADER ----------------------
	reg rLoaderCommandValid;	
	reg rLoaderWriteValid;	
	reg rLoaderCommandReadWrite;
	wire wLoaderCommandAccept;
	wire wLoaderWriteAccept;
	wire wLoaderReadValid;
	wire [INTERFACE_WIDTH-1:0] wLoaderReadData;
	reg [INTERFACE_ADDR_WIDTH-1:0] rLoaderAddr;
		
	//reg rLoaderReadDataValid;
	reg [INTERFACE_WIDTH-1:0] rLoaderWriteData;
		
	//---------------- FOR GLOBAL MEM ----------------------
	reg rDMEMCommandValid;	
	reg rDMEMWriteValid;	
	wire wDMEMCommandAccept;
	wire wDMEMWriteAccept;
		
	//reg rDMEMReadDataValid;
	reg [INTERFACE_WIDTH-1:0] rDMEMWriteData;
	reg [INTERFACE_ADDR_WIDTH-1:0] rDMEMWriteAddr;
		
	wire wHalted;
	wire wConfigDone;

	reg [INTERFACE_WIDTH-1:0] rStateConfig;
	
	//wire wLoaderReadReq;
	//wire [INTERFACE_ADDR_WIDTH-1:0] wLoaderReadAddr;	
	//reg [INTERFACE_ADDR_WIDTH-1:0] rLoaderReadAddr;
	
	initial begin
		rState = STATE_IDLE;		
		rLoaderCommandReadWrite = 0;		
		rDMEMWriteAddr = 0;
		rDMEMCommandValid = 0;		
		rDMEMWriteValid = 0;							
		rReset = 1;
		rLoaderCommandValid = 0;		
		rLoaderWriteValid = 0;		
		rLoaderAddr = LOADER_OFFSET;
						
		#20 rReset = 0;				
		if (MAGIC_DMEM_LOAD==0)
			#20 rState = STATE_DATA_LOAD;			
		else
			#20 rState = STATE_CONFIG_LOAD;			
				
		while (!wConfigDone) //wait for config to be completed
			begin
				#100 rReset = 0;
			end		
		
		`ifdef INCLUDE_STATE_CONTROL
			#200 rState = STATE_CONFIG_STATE_READADDR;
			#200 rState = STATE_CONFIG_STATE_WRITEADDR;
			
			#1300 rStateConfig = 'b001_100; //disable shift in and request swap
			#10 rState = STATE_CONFIG_STATE_COMMAND;
			#100 rStateConfig = 'b000_000; //set everything back to zero (not timing critical, responds to rising of command bits)
			#10 rState = STATE_CONFIG_STATE_COMMAND;		
			
			#50000 rStateConfig = 'b010_100; //disable shift out and request swap
			#10 rState = STATE_CONFIG_STATE_COMMAND;
			#100 rStateConfig = 'b000_000; //set everything back to zero (not timing critical, responds to rising of command bits)
			#10 rState = STATE_CONFIG_STATE_COMMAND;			
		`endif
				
		/* //to test if restarting works
		while(!wHalted)
			begin
				#100 rReset = 0;
			end
			
		#2000 rLoaderAddr <= 32'd4;
		rLoaderWriteData <= 32'h00000001;
		rLoaderCommandValid <= 1;
		rLoaderWriteValid <= 1;					

		#2000 rLoaderAddr <= 32'd4;
		rLoaderWriteData <= 32'h00000000;
		rLoaderCommandValid <= 1;
		rLoaderWriteValid <= 1;					
		*/
		
	end
	
	always @(posedge rClk)
	begin
		if (wLoaderCommandAccept)
			rLoaderCommandValid <= 0;
			
		if (wLoaderWriteAccept)
			rLoaderWriteValid <= 0;
			
		if (wDMEMCommandAccept)
			rDMEMCommandValid <= 0;
			
		if (wDMEMWriteAccept)
			rDMEMWriteValid <= 0;	
	
		if (rState == STATE_DATA_LOAD)
			begin
				if (wDMEMWriteAccept)
					rDMEMWriteAddr <= rDMEMWriteAddr + 1'd1;				
					
					if (rDMEMWriteAddr < 2**GM_MEM_ADDR_WIDTH-1)
						begin			
							if (!(rDMEMCommandValid | rDMEMWriteValid))
								begin						
									rDMEMCommandValid <= 1;
									rDMEMWriteValid <= 1;			
									rDMEMWriteData	<= rDataBinary[rDMEMWriteAddr];
								end
						end
					else
						rState = STATE_CONFIG_LOAD;					
			end
			
		if (rState == STATE_CONFIG_LOAD)			
			begin					
					if (!(rLoaderCommandValid | rLoaderWriteValid))
						begin
							rState <= STATE_RELEASE_RESET;
							rLoaderAddr <= LOADER_OFFSET;
							rLoaderWriteData <= 32'h00000000;
							rLoaderCommandValid <= 1;
							rLoaderWriteValid <= 1;					
						end
			end
			
		if (rState == STATE_RELEASE_RESET)
			begin									
					if (wConfigDone)
						begin
							rState <= STATE_IDLE;
							rLoaderAddr <= LOADER_OFFSET+4;
							rLoaderWriteData <= 32'h00000000;
							rLoaderCommandValid <= 1;
							rLoaderWriteValid <= 1;					
						end			
			end
			
		if (rState == STATE_CONFIG_STATE_READADDR)			
			begin					
					if (!(rLoaderCommandValid | rLoaderWriteValid))
						begin
							rState <= STATE_IDLE;
							rLoaderAddr <= LOADER_OFFSET+12;
							rLoaderWriteData <= 32'd8;
							rLoaderCommandValid <= 1;
							rLoaderWriteValid <= 1;					
						end
			end		
			
		if (rState == STATE_CONFIG_STATE_WRITEADDR)			
			begin					
					if (!(rLoaderCommandValid | rLoaderWriteValid))
						begin
							rState <= STATE_IDLE;
							rLoaderAddr <= LOADER_OFFSET+16;
							rLoaderWriteData <= 32'd8;
							rLoaderCommandValid <= 1;
							rLoaderWriteValid <= 1;					
						end
			end				
			
		if (rState == STATE_CONFIG_STATE_COMMAND)			
			begin					
					if (!(rLoaderCommandValid | rLoaderWriteValid))
						begin
							rState <= STATE_IDLE;
							rLoaderAddr <= LOADER_OFFSET+8;
							rLoaderWriteData <= rStateConfig;
							rLoaderCommandValid <= 1;
							rLoaderWriteValid <= 1;					
						end
			end				
			
	/* //if you want to test reading the status register (polling)
		if (rState == STATE_IDLE)
			begin
				if (wConfigDone & !rLoaderCommandValid)
					begin
							rLoaderCommandValid <= 1;			
							rLoaderCommandReadWrite <= 1;
					end			
			end
	*/	

	if (rState == STATE_IDLE) begin
		rLoaderCommandValid <= 0;			
		rLoaderWriteValid <= 0;			
	end
					
	end
	
	integer f;
	integer x;
	reg read_return;
	
	initial begin		
		f = $fopen(BINARY_FILE, "rb");
		read_return=$fread(rBinary, f);
		$fclose(f);
		
		for (x=0; x < BINARY_WORDS; x = x + 1)
			rBinary[x] = {rBinary[x][7:0], rBinary[x][15:8], rBinary[x][23:16], rBinary[x][31:24]};

		$readmemb("data.vbin", rDataBinary, 0, 2**GM_MEM_ADDR_WIDTH-1);
	end			

	always @(posedge rClk)
		if (wHalted)
			begin
				#5 $finish();
			end

	integer file;	
	
	initial begin
	   	file = $fopen({"GM_out.txt"},"w");			   	
	
	   	@(negedge rReset); //Wait for reset to be released	  
	   	forever
	   	begin
	 	  	@(posedge wHalted)
	 	  		for (x=0; x < 2**GM_MEM_ADDR_WIDTH; x = x + 1)
 					$fwrite(file,"%b\n", dut.GM_inst.rRAM[x]);			 						  
	   	end

	   	$fclose(f);  
	 end			
	
	`ifndef ASIC_SYNTHESIS 
	`ifndef ASIC_NO_PERF_COUNTERS	
	`ifdef INCLUDE_PERF_COUNTERS
		//active counter registers
			reg [INTERFACE_WIDTH-1:0] rCounter_id_lsu_y;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_lsu_x;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_mul_y;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_mul_x;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_rf_x;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_rf_y;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_abu_contr;
			reg [INTERFACE_WIDTH-1:0] rCounter_imm_y;
			reg [INTERFACE_WIDTH-1:0] rCounter_imm_x;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_abu_stor;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_abu_y;
			reg [INTERFACE_WIDTH-1:0] rCounter_id_abu_x;
			reg [INTERFACE_WIDTH-1:0] rCounter_imm_stor;


		always @(posedge rClk)
		begin
			if (wConfigDone)	
				begin	
					//counters
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_lsu_y_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_lsu_y_inst.rStall)
						rCounter_id_lsu_y <= rCounter_id_lsu_y + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_lsu_x_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_lsu_x_inst.rStall)
						rCounter_id_lsu_x <= rCounter_id_lsu_x + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_mul_y_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_mul_y_inst.rStall)
						rCounter_id_mul_y <= rCounter_id_mul_y + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_mul_x_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_mul_x_inst.rStall)
						rCounter_id_mul_x <= rCounter_id_mul_x + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_rf_x_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_rf_x_inst.rStall)
						rCounter_id_rf_x <= rCounter_id_rf_x + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_rf_y_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_rf_y_inst.rStall)
						rCounter_id_rf_y <= rCounter_id_rf_y + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_contr_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_contr_inst.rStall)
						rCounter_id_abu_contr <= rCounter_id_abu_contr + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_y_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_y_inst.rStall)
						rCounter_imm_y <= rCounter_imm_y + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_x_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_x_inst.rStall)
						rCounter_imm_x <= rCounter_imm_x + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_stor_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_stor_inst.rStall)
						rCounter_id_abu_stor <= rCounter_id_abu_stor + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_y_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_y_inst.rStall)
						rCounter_id_abu_y <= rCounter_id_abu_y + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_x_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.id_abu_x_inst.rStall)
						rCounter_id_abu_x <= rCounter_id_abu_x + 1'd1;
					if(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_stor_inst.iInstruction != 0 & !dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.CGRA_Compute_inst.imm_stor_inst.rStall)
						rCounter_imm_stor <= rCounter_imm_stor + 1'd1;

				end

			if (rReset)
				begin
					//reset counters
					rCounter_id_lsu_y <= 0;
					rCounter_id_lsu_x <= 0;
					rCounter_id_mul_y <= 0;
					rCounter_id_mul_x <= 0;
					rCounter_id_rf_x <= 0;
					rCounter_id_rf_y <= 0;
					rCounter_id_abu_contr <= 0;
					rCounter_imm_y <= 0;
					rCounter_imm_x <= 0;
					rCounter_id_abu_stor <= 0;
					rCounter_id_abu_y <= 0;
					rCounter_id_abu_x <= 0;
					rCounter_imm_stor <= 0;

				end
		end

		integer file_perf;
		initial begin
		   	file_perf = $fopen({"performance_info.txt"},"w");			   	
		
		   	@(negedge rReset); //Wait for reset to be released	  
		   	forever
		   	begin
		 	  	@(posedge wHalted)
		 	  		begin			 			
			 			$fwrite(file_perf,"total cycles: %d\nstalled cycles: %d\n", dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter, dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter);			 			
			 			//write counters to file
						$fwrite(file_perf,"active cycles (id_lsu_y): %d, utilization: %d percent\n", rCounter_id_lsu_y, (rCounter_id_lsu_y*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_lsu_x): %d, utilization: %d percent\n", rCounter_id_lsu_x, (rCounter_id_lsu_x*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_mul_y): %d, utilization: %d percent\n", rCounter_id_mul_y, (rCounter_id_mul_y*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_mul_x): %d, utilization: %d percent\n", rCounter_id_mul_x, (rCounter_id_mul_x*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_rf_x): %d, utilization: %d percent\n", rCounter_id_rf_x, (rCounter_id_rf_x*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_rf_y): %d, utilization: %d percent\n", rCounter_id_rf_y, (rCounter_id_rf_y*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_abu_contr): %d, utilization: %d percent\n", rCounter_id_abu_contr, (rCounter_id_abu_contr*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (imm_y): %d, utilization: %d percent\n", rCounter_imm_y, (rCounter_imm_y*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (imm_x): %d, utilization: %d percent\n", rCounter_imm_x, (rCounter_imm_x*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_abu_stor): %d, utilization: %d percent\n", rCounter_id_abu_stor, (rCounter_id_abu_stor*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_abu_y): %d, utilization: %d percent\n", rCounter_id_abu_y, (rCounter_id_abu_y*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (id_abu_x): %d, utilization: %d percent\n", rCounter_id_abu_x, (rCounter_id_abu_x*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));
						$fwrite(file_perf,"active cycles (imm_stor): %d, utilization: %d percent\n", rCounter_imm_stor, (rCounter_imm_stor*100)/(dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rCycleCounter - dut.CGRA_Core_inst.CGRA_Compute_Wrapper_inst.rStallCounter));

		 			end
		   	end

		   	$fclose(f);  
		 end	
	`endif
	`endif
	`endif
	
	//SMEM DTL wires
	wire wDTL_SMEM_CommandAccept;
	wire wDTL_SMEM_WriteAccept;
	wire wDTL_SMEM_ReadValid;
	wire wDTL_SMEM_ReadLast;
	wire [INTERFACE_WIDTH-1:0] wDTL_SMEM_ReadData;
			
	wire wDTL_SMEM_CommandValid;
	wire wDTL_SMEM_WriteValid;	
	wire wDTL_SMEM_CommandReadWrite;
	wire [(INTERFACE_WIDTH/8)-1:0] wDTL_SMEM_WriteEnable;
	wire [INTERFACE_ADDR_WIDTH-1:0] wDTL_SMEM_Address;
	wire [INTERFACE_WIDTH-1:0] wDTL_SMEM_WriteData;
		
	wire [INTERFACE_BLOCK_WIDTH-1:0] wDTL_SMEM_BlockSize;
	wire wDTL_SMEM_WriteLast;
	wire wDTL_SMEM_ReadAccept;		
	
	wire [INTERFACE_ADDR_WIDTH-1:0] wReadAddr;
			
	CGRA_Top dut
	(
		.iClk(rClk),
		.iReset(rReset),
		.oHalted(wHalted),
		.oConfigDone(wConfigDone),					
		
		//peripheral connections

							
		//DTL interface for control by the host (SLAVE)
		.oDTL_Loader_CommandAccept(wLoaderCommandAccept),
		.oDTL_Loader_WriteAccept(wLoaderWriteAccept),
		.oDTL_Loader_ReadValid(wLoaderReadValid),
		.oDTL_Loader_ReadLast(),
		.oDTL_Loader_ReadData(wLoaderReadData),
			
		.iDTL_Loader_CommandValid(rLoaderCommandValid),
		.iDTL_Loader_WriteValid(rLoaderWriteValid),		
		.iDTL_Loader_CommandReadWrite(rLoaderCommandReadWrite),
		.iDTL_Loader_WriteEnable({(INTERFACE_WIDTH/8){1'b1}}),
		.iDTL_Loader_Address(rLoaderAddr),	
		.iDTL_Loader_WriteData(rLoaderWriteData),
			
		.iDTL_Loader_BlockSize({(INTERFACE_BLOCK_WIDTH){1'b0}}),
		.iDTL_Loader_WriteLast(1'b1),
		.iDTL_Loader_ReadAccept(1'b1),			
			
		//DTL interface for the shared memory with the host (MASTER)
		.iDTL_SMEM_CommandAccept(wDTL_SMEM_CommandAccept),
		.iDTL_SMEM_WriteAccept(wDTL_SMEM_WriteAccept),
		.iDTL_SMEM_ReadValid(wDTL_SMEM_ReadValid),
		.iDTL_SMEM_ReadLast(wDTL_SMEM_ReadLast),
		.iDTL_SMEM_ReadData(wDTL_SMEM_ReadData),
			
		.oDTL_SMEM_CommandValid(wDTL_SMEM_CommandValid),
		.oDTL_SMEM_WriteValid(wDTL_SMEM_WriteValid),		
		.oDTL_SMEM_CommandReadWrite(wDTL_SMEM_CommandReadWrite),
		.oDTL_SMEM_WriteEnable(wDTL_SMEM_WriteEnable),
		.oDTL_SMEM_Address(wDTL_SMEM_Address),	
		.oDTL_SMEM_WriteData(wDTL_SMEM_WriteData),
			
		.oDTL_SMEM_BlockSize(wDTL_SMEM_BlockSize),
		.oDTL_SMEM_WriteLast(wDTL_SMEM_WriteLast),
		.oDTL_SMEM_ReadAccept(wDTL_SMEM_ReadAccept),		

		//DTL interface for control by the host (SLAVE)
		.oDTL_DMEM_CommandAccept(wDMEMCommandAccept),
		.oDTL_DMEM_WriteAccept(wDMEMWriteAccept),
		.oDTL_DMEM_ReadValid(),
		.oDTL_DMEM_ReadLast(),
		.oDTL_DMEM_ReadData(),
			
		.iDTL_DMEM_CommandValid(rDMEMCommandValid),
		.iDTL_DMEM_WriteValid(rDMEMWriteValid),		
		.iDTL_DMEM_CommandReadWrite(1'b0),
		.iDTL_DMEM_WriteEnable({(INTERFACE_WIDTH/8){1'b1}}),
		.iDTL_DMEM_Address(rDMEMWriteAddr),	
		.iDTL_DMEM_WriteData(rDMEMWriteData),
			
		.iDTL_DMEM_BlockSize({(INTERFACE_BLOCK_WIDTH){1'b0}}),
		.iDTL_DMEM_WriteLast(1'b1),
		.iDTL_DMEM_ReadAccept(1'b1)					
		
	);
	
	
	dtl_sram_controller DTL_SRAM_CONTROLLER_inst
	(
	  .clk(rClk),
	  .rst(rReset),
	  .dtl_cmd_valid(wDTL_SMEM_CommandValid),
	  .dtl_cmd_accept(wDTL_SMEM_CommandAccept),
	  .dtl_cmd_addr(wDTL_SMEM_Address >> 2),
	  .dtl_cmd_read(wDTL_SMEM_CommandReadWrite),
	  .dtl_cmd_block_size(wDTL_SMEM_BlockSize),

	  .dtl_wr_valid(wDTL_SMEM_WriteValid),
	  .dtl_wr_last(wDTL_SMEM_WriteLast),
	  .dtl_wr_accept(wDTL_SMEM_WriteAccept),
	  .dtl_wr_mask(wDTL_SMEM_WriteEnable),
	  .dtl_wr_data(wDTL_SMEM_WriteData),

	  .dtl_rd_valid(wDTL_SMEM_ReadValid),
	  .dtl_rd_last(wDTL_SMEM_ReadLast),
	  .dtl_rd_accept(wDTL_SMEM_ReadAccept),
	  .dtl_rd_data(wDTL_SMEM_ReadData), 

	  .ram_clk(),
	  .ram_rst(),
	  .ram_addr(wReadAddr),
	  .ram_wr_data(),
	  .ram_en(),
	  .ram_wbe(),
	  .ram_rd_data(wDTL_SMEM_ReadValid ? rBinary[wReadAddr] : 32'bX),
	  
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

		
endmodule

