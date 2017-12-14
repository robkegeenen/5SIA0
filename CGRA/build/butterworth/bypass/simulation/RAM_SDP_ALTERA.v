/********************************************************/
/*                      LICENSE:			*/
/*------------------------------------------------------*/
/* These files can be used for the Embedded Computer    */
/* Architecture course (5SIA0) at Eindhoven University  */
/* of technology. You are not allowed to distribute     */
/* these files to others.                               */
/* This header must be retained at all times		*/
/********************************************************/

//`define FORCE_ALTERA_SIM

// synthesis translate_off
	`ifndef FORCE_ALTERA_SIM
		`define SIMULATION_RAM
	`endif
// synthesis translate_on
	
module RAM_SDP_ALTERA 
#(
	parameter DATA_WIDTH = 8,
	parameter ADDR_WIDTH = 8,
	parameter DATAFILE = "../../DATA/DMEM_8"
)
(
	clock,
	data,
	rdaddress,
	wraddress,
	wren,
	q);

	input	  clock;
	input	[DATA_WIDTH-1:0]  data;
	input	[ADDR_WIDTH-1:0]  rdaddress;
	input	[ADDR_WIDTH-1:0]  wraddress;
	input	  wren;
	output	[DATA_WIDTH-1:0]  q;
	
 localparam DATAFILE_SYN = {DATAFILE,".mif"};
 localparam DATAFILE_SIM = {DATAFILE,".hex"}; 
	
`ifndef SIMULATION_RAM //it is the FPGA(?) synthesis tool
	
	`ifndef ALTERA_RESERVED_QIS
	// synopsys translate_off
	`endif
		tri1	  clock;
		tri0	  wren;
	`ifndef ALTERA_RESERVED_QIS
	// synopsys translate_on
	`endif

		reg [ADDR_WIDTH-1:0] rReadAddress;
		reg [ADDR_WIDTH-1:0] rWriteAddress;
		reg [DATA_WIDTH-1:0] rWriteData;
		reg rWriteEnable;
	
		wire [DATA_WIDTH-1:0] sub_wire0;
		wire [DATA_WIDTH-1:0] q = (rReadAddress == rWriteAddress & rWriteEnable) ? rWriteData : sub_wire0[DATA_WIDTH-1:0];
		
		always @(posedge clock)
		begin
			rReadAddress <= rdaddress;
			rWriteAddress <= wraddress;			
			rWriteData <= data;
			rWriteEnable <= wren;
		end

		altsyncram	altsyncram_component (
					.address_a (wraddress),
					.address_b (rdaddress),
					.clock0 (clock),
					.data_a (data),
					.wren_a (wren),
					.q_b (sub_wire0),
					.aclr0 (1'b0),
					.aclr1 (1'b0),
					.addressstall_a (1'b0),
					.addressstall_b (1'b0),
					.byteena_a (1'b1),
					.byteena_b (1'b1),
					.clock1 (1'b1),
					.clocken0 (1'b1),
					.clocken1 (1'b1),
					.clocken2 (1'b1),
					.clocken3 (1'b1),
					.data_b ({DATA_WIDTH{1'b1}}),
					.eccstatus (),
					.q_a (),
					.rden_a (1'b1),
					.rden_b (1'b1),
					.wren_b (1'b0));
		defparam
			altsyncram_component.address_aclr_b = "NONE",
			altsyncram_component.address_reg_b = "CLOCK0",
			altsyncram_component.clock_enable_input_a = "BYPASS",
			altsyncram_component.clock_enable_input_b = "BYPASS",
			altsyncram_component.clock_enable_output_b = "BYPASS",
			altsyncram_component.init_file = DATAFILE_SYN,
			altsyncram_component.intended_device_family = "Cyclone V",
			altsyncram_component.lpm_type = "altsyncram",
			altsyncram_component.numwords_a = 2**ADDR_WIDTH,
			altsyncram_component.numwords_b = 2**ADDR_WIDTH,
			altsyncram_component.operation_mode = "DUAL_PORT",
			altsyncram_component.outdata_aclr_b = "NONE",
			altsyncram_component.outdata_reg_b = "UNREGISTERED",
			altsyncram_component.power_up_uninitialized = "FALSE",
			altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
			altsyncram_component.widthad_a = ADDR_WIDTH,
			altsyncram_component.widthad_b = ADDR_WIDTH,
			altsyncram_component.width_a = DATA_WIDTH,
			altsyncram_component.width_b = DATA_WIDTH,
			altsyncram_component.width_byteena_a = 1;
			
`else //it is the simulator
	
	reg [ADDR_WIDTH-1:0] rReadAddress;
	reg [ADDR_WIDTH-1:0] rWriteAddress;
	reg [DATA_WIDTH-1:0] rWriteData;
		
	reg [DATA_WIDTH-1:0] rRAM [2**ADDR_WIDTH-1:0];
	reg rWriteEnable;
	
	initial begin
		$readmemb(DATAFILE_SIM, rRAM, 0, 2**ADDR_WIDTH-1);
	end
	
	always @(posedge clock)
	begin
		rReadAddress <= rdaddress;
		rWriteAddress <= wraddress;
		rWriteEnable <= wren;
		rWriteData <= data;
			
		if (rWriteEnable)
			rRAM[rWriteAddress] <= rWriteData;
	end
	
	assign q = (rReadAddress == rWriteAddress & rWriteEnable) ? rWriteData : rRAM[rReadAddress];
	
`endif


endmodule
