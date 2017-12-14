`include "config.vh"

module ID
#( //parameters that can be externally configured
	parameter I_WIDTH = 16,
	parameter I_DECODED_WIDTH = 16,
	parameter D_WIDTH = 8,
	parameter SRC_WIDTH = 2,
	parameter DEST_WIDTH = 1,
	parameter REG_ADDR_WIDTH = 4,
	parameter BRANCH_IMM_WIDTH = 6,
	parameter ID_TYPE = 2'b00,
	parameter NUM_STALL_GROUPS = 1,
	
	parameter TEST_ID = "0"
)
(  //inputs and outputs
	input iClk,
	input iReset,
	
	input [NUM_STALL_GROUPS-1:0] iStall,
	
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

	input [I_WIDTH-1:0] iInstruction,	
	output [I_DECODED_WIDTH-1:0] oDecodedInstruction			
	
); //local parameters, these depend on the actual implementation of the module and therefore are not configurable
	//from outside the module.
	
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
	
	localparam ID_TYPE_LSU = 3'b000;	
	localparam ID_TYPE_RF  = 3'b001;	
	localparam ID_TYPE_ALU = 3'b010;	
	localparam ID_TYPE_ABU = 3'b011;	
	localparam ID_TYPE_MUL = 3'b100;	
	
	localparam CONTROL_OFFSET = 2*SRC_WIDTH + DEST_WIDTH;
	localparam STALL_GROUP_WIDTH = MAX(CLogB2(NUM_STALL_GROUPS-1),1);
	localparam CONFIG_WIDTH = 3+STALL_GROUP_WIDTH;
	
	//instruction format:
	reg [I_DECODED_WIDTH-1:0] 	rDecodedInstruction;	
	reg [CONFIG_WIDTH-1:0] 		rConfig; 
			
	//if !R:
	// R | L/N  G/L  I/A | S/N  G/L  I/A | DEST | SRCB | SRCA
	
	//if R:	
	// R | 0  |  0000              |  R3   R2   R1   R0 | SRCA
	
	// R | !0 | free space
	
	// FOR LSU ------------------------------------------------------
	// 0_000_000_d_bb_aa = NOP (NOP)
	
	// 0_000_100_d_bb_aa = Nothing | Store Local Address  (SLA)
	// 0_000_101_d_bb_aa = Nothing | Store Local Implicit (SLI)
	// 0_000_110_d_bb_aa = Nothing | Store Global Address (SGA)
	// 0_000_111_d_bb_aa = Nothing | Store Global Implicit (SGI)
	
	// 0_100_000_d_bb_aa = Load Local Address  | Nothing (LLA)
	// 0_101_000_d_bb_aa = Load Local Implicit | Nothing  (LLI)
	// 0_110_000_d_bb_aa = Load Global Address  | Nothing (LGA)
	// 0_111_000_d_bb_aa = Load Global Implicit | Nothing (LGI)
		
	// 0_101_100_d_bb_aa = Load Local Implicit | Store Global Address	 (LLI_SGA)
	// 0_111_100_d_bb_aa = Load Global Implicit | Store Global Address (LGI_SGA)	
	// 0_100_101_d_bb_aa = Load Local Address | Store Local Implicit (LLA_SLI)
	// 0_101_101_d_bb_aa = Load Local Implicit | Store Local Implicit (LLI_SLI)
	// 0_110_101_d_bb_aa = Load Global Address | Store Local Implicit (LGA_SLI)
	// 0_111_101_d_bb_aa = Load Global Implicit | Store Local Implicit (LGI_SLI)
	
	// 0_101_110_d_bb_aa = Load Local Implicit | Store Global Address	 (LLI_SGA)
	// 0_111_110_d_bb_aa = Load Global Implicit | Store Global Address (LGI_SGA)		
	// 0_100_111_d_bb_aa = Load Local Address | Store Global Implicit (LLA_SGI)
	// 0_101_111_d_bb_aa = Load Local Implicit | Store Global Implicit (LLI_SGI)
	// 0_110_111_d_bb_aa = Load Global Address | Store Global Implicit (SGA_SGI)
	// 0_111_111_d_bb_aa = Load Global Implicit | Store Global Implicit (LGI_SGI)		
	
	// 1_0_0000_yyyy_aa = store data from srcA in register yyyy (SRM)
	//	1_1_xxxx_xxxx_aa = NOT SUPPORTED BY LSU			
	
	//NOT POSSIBLE (because of addressable input limitations)
	// 		0_100_100 = Load Local Address | Store Local Address 	
	// 		0_110_100 = Load Global Address | Store Global Address
	//			0_100_110 = Load Local Address | Store Global Address
	//			0_110_110 = Load Global Address | Store Global Address
	
	//lsu requires:	
	// wRegFromOpcodeA (1 bit)
	// wRegisterWriteImmediate
	// wLoadGlobalImplicit
	// wLoadGlobal
	// wLoadImplicit
	// wLoad
	// wStoreGlobalImplicit
	// wStoreGlobal
	// wStoreImplicit
	// wStore
	// wDest
	// wSrcB (2)
	// wSrcA (2)
	
	// FOR RF -------------------------------------------------------
	// 1_1_xxxx_yyyy_aa  = load data from (xxxx) | store data from srcA in register yyyy (SLM_SRM)
	// 1_0_0000_yyyy_aa  = store data from srcA in specified register yyyy (SRM)
	// 1_0_1000_yyyy_00  = load data from register yyyy (LRM)
	// 1_0_0100_00_bb_aa = store data SRCA into register SRCB (SRA)
	// 1_0_0010_00_bb_00 = load data from register SRCB (LRA)

	//rf requires
	//	wRegFromOpcodeB (4 bit)
	//	wRegFromOpcodeA (1 bit)
	//	wRegisterRead
	//	wRegisterReadImmediate
	//	wRegisterWrite
	//	wRegisterWriteImmediate
	//	wSrcB
	//	wSrcA		
	
	// FOR ALU ------------------------------------------------------
	
	//    000_00_00 (NOP)
	
	// 	001_10_10 (ADD)		
	// 	001_10_11 (SUB)		
												
	// 	001_00_00 (AND)		
	//		011_00_00 (NAND)		
	// 	001_00_01 (OR)			
	//	 	011_00_01 (NOR)		
	// 	001_00_10 (XOR)		
	//	 	011_00_11 (NEG)
	// 	111_00_11 (CMOV)
	// 	001_00_11 (PASS)
	
	// 	110_11_11 (EQ)
	// 	101_11_11 (NEQ)	
	// 	001_11_11 (LTU)
	// 	100_11_11 (LTS)
	// 	011_11_11 (GEU)
	// 	010_11_11 (GES)	

	// 	001_01_00 (SHLL1)
	// 	001_01_01 (SHLL4)
	// 	001_01_10 (SHRL1)
	// 	001_01_11 (SHRL4)
	// 	000_01_10 (SHRA1)
	// 	000_01_11 (SHRA4)
	
	// 1_0_0_0_0 = 000 
	// 0_0_0_0_0 = 001 
	// 0_0_1_1_0 = 010 
	// 0_0_0_1_0 = 011 
	// 0_0_1_0_0 = 100 
	// 0_0_0_1_1 = 101 
	// 0_0_0_0_1 = 110 
	// 0_1_0_0_0 = 111 
	
	//    00		01		10		11
	// 00 AND	SLL1	x		x
	// 01	OR		SLL4	x		x
	// 10	XOR	SR*1	!Sub	!Sub
	//	11 PASS	SR*4	Sub	Sub
	
	//ALU requires:
	// wShiftA_L
	// wIsCMOV
 	// wIsSigned
	// wInvert
 	// wEQ_LT
	
 	// wType
 	// wALU_Operation
	
	// wDest
 	// wSrcB
	// wSrcA
	
	// FOR Branch unit ------------------------------------------------------
	
	// functions:
	// 000000_0_UU_UU			OPCODE											NOP
	// 110010_RRRR_AA 		OPCODE, REG, 	SRCA 							ACCU 		Accumulate unsigned
	// 110011_RRRR_AA			OPCODE, REG, 	SRCA							ACCS		Accumulate signed
	// 100000_RRRR_AA			OPCODE, REG, 	SRCA							SRM		Store register immediate
	// 101000_RRRR_UU			OPCODE, REG										LRM		Load register immediate
	// 110000_00BB_UU			OPCODE, 		 	SRCA							JR			Jump relative (srcB treated as signed)					
	// 110100_00BB_UU			OPCODE, 		 	SRCA							JA			Jump absolute (srcB treated as unsigned)
	// 11110000_BB_AA			OPCODE, SRCB,	SRCA							BCR		Branch conditional relative (srcB treated as signed, srcA = condition)					
	// 11110000_BB_AA			OPCODE, SRCB,	SRCA							BCA		Branch conditional absolute (srcB treated as unsigned, srcA = condition)
	// 0001IIII_II_UU			OPCODE, IMM										JRI		Jump relative immediate (signed)
	// 0011IIII_II_UU			OPCODE, IMM										JAI		Jump absolute immediate (unsigned)
	// 0101IIII_II_AA			OPCODE, IMM,	SRCB							BCRI		Branch conditional relative immediate (signed, srcA = condition)
	// 0111IIII_II_AA			OPCODE, IMM, 	SRCB							BCAI		Branch conditional absolute immediate (unsigned, srcA = condition)	
						
	//----------------------------------------
	//	SCAN CHAIN CONFIG CODE
	//----------------------------------------
			
	integer gCurrBit;
	always @(posedge iClk)
	begin
		if (iConfigEnable)
			begin
				rConfig <= (rConfig >> 1) | (iConfigDataIn << (CONFIG_WIDTH-1));

				//for (gCurrBit=0; gCurrBit < CONFIG_WIDTH-1; gCurrBit = gCurrBit + 1)		
				//	rConfig[gCurrBit] <= rConfig[gCurrBit+1];
			end
	end
	
	assign oConfigDataOut = rConfig[0];
	
	`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
		//----------------------------------------
		// STATE SAVING
		//----------------------------------------		
		localparam STATE_LENGTH = I_DECODED_WIDTH + 1; //output registers + Flag register 
		reg [STATE_LENGTH-1:0] rState;			
		assign oStateDataOut = rState[0];				
		//----------------------------------------	
	`endif
	
	wire [STALL_GROUP_WIDTH-1:0] wStallGroup = rConfig[CONFIG_WIDTH-1:CONFIG_WIDTH-STALL_GROUP_WIDTH];
	
	reg rStall;
	
	//structural description
	integer gCurrStateBit;
	
	always @(posedge iClk)
	begin
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled			
		if (!iNewStateIn)
			begin			
		`endif								
				if (iReset)
					begin
						rStall <= 1'b0;
						case(rConfig[CONFIG_WIDTH-STALL_GROUP_WIDTH-1:0]) //select by ID type configuration (LSU/RF/ALU)
							ID_TYPE_ALU :
								rDecodedInstruction <= 16'b00_11000_0000_00000;						
							default:
								rDecodedInstruction <= {(I_DECODED_WIDTH){1'b0}};
						endcase			
					end
				else begin
					rStall <= iStall[wStallGroup];
				end
					
				if (!rStall & !iReset)
					begin		
						case(rConfig[CONFIG_WIDTH-STALL_GROUP_WIDTH-1:0]) //select by ID type configuration (LSU/RF/ALU)
							ID_TYPE_LSU: 
								begin					
								
									if (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+2] != 5'b10000 & iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+2] != 5'b10100) //not a register operation
										begin
											rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
											rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
											rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
											
											if (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+2] != 5'b00100) 
												rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+8] <= 1'b0; //reg write imm				
											else
												rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+8] <= 1'b1; //reg write imm				
												
											rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+9] <= iInstruction[CONTROL_OFFSET+1:CONTROL_OFFSET+0];
																																	
											case (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+2]) 
												5'b00000 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0000;																							
															end
												5'b00001 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0001;																							
															end
												5'b00010 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0010;																							
															end
												5'b00011 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0100;																							
															end
												5'b00100 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0000;																							
															end
												5'b00101 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0001_0000;																							
															end
												5'b00110 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0010_0000;																							
															end
												5'b00111 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0100_0000;																							
															end
												5'b01000 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b1000_0000;																							
															end
												5'b01001 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0010_0001;																							
															end
												5'b01010 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b1000_0001;																							
															end
												5'b01011 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0001_0010;																							
															end
												5'b01100 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0010_0010;																							
															end
												5'b01101 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0100_0010;																							
															end
												5'b01110 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b1000_0010;																							
															end
												5'b01111 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0010_0100;																							
															end
												5'b10001 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b1000_0100;																							
															end
												5'b10010 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0001_1000;																							
															end
												5'b10011 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0010_1000;																							
															end
//												5'b10100 : 	begin														
//																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0100_1000;																							
//															end
												5'b10101 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b1000_1000;																							
															end													
												5'b10110 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_1000;																							
															end															
												5'b10111 : 	begin														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0100_1000;																							
															end															
												default:
															begin
																//do nothing
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0000_0000;		
															end
											endcase				
										end
									else //register operations for LSU
										begin
											if (!iInstruction[CONTROL_OFFSET+5]) 
																	
												rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
												rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
												rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
												rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+9] <= 2'b0;
									
												begin
													case (iInstruction[CONTROL_OFFSET+5:CONTROL_OFFSET+2])
														4'b0000 : begin
																		// register write
																		rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+8] <= 1'b1; //reg write imm		
																		rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET+0] <= 1'b0;
																	end
														4'b0100 : begin
																		// register read																		
																		rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+8] <= 1'b1; //reg read		
																		rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET] <= 8'b0001_0000;	//enable 'loading register' 
																	end																	
														default:
																	begin
																		//do nothing
																		rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+8] <= 1'b0;		
																		rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET+0] <= 1'b0;
																	end												
													endcase
																											
													rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+CONTROL_OFFSET+9-1:CONTROL_OFFSET+9] <= iInstruction[REG_ADDR_WIDTH+CONTROL_OFFSET-DEST_WIDTH-SRC_WIDTH-1:CONTROL_OFFSET];																
												end
										end
								end				
							
							ID_TYPE_RF: 
								begin	
									if (!iInstruction[CONTROL_OFFSET+6])
										begin
											rDecodedInstruction <= 1'b0; //NOP
										end
									else //upper half of the instruction space (register operations for RF)
										begin
											if (!iInstruction[CONTROL_OFFSET+5]) 										
												begin
												
													rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
													rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
													rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
												
													case (iInstruction[CONTROL_OFFSET+4:CONTROL_OFFSET+1])
														4'b0000 : begin
																		// register write
																		rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0001; //!reg read, !reg read imm, !reg write, reg write imm		
																	end
														4'b1000 : begin
																		//register read
																		rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0100; //!reg read, reg read imm, !reg write, !reg write imm		
																	end
														4'b0100 : begin
																		//variable register write
																		rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0010; //!reg read, !reg read imm, reg write, !reg write imm		
																	end												
														4'b0010 : begin
																		//variable register read
																		rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b1000; //reg read, !reg read imm, !reg write, !reg write imm		
																	end												
																	
														default:
																	begin
																		//do nothing
																		rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0000;		
																	end												
													endcase
														
													rDecodedInstruction[I_DECODED_WIDTH-1:CONTROL_OFFSET+5] <= 1'b0;
													rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+CONTROL_OFFSET+4-1:CONTROL_OFFSET+4] <= iInstruction[CONTROL_OFFSET+REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:CONTROL_OFFSET+0];																
												end
											else //parallel load | store (only supported in RF)
												begin					
													rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
													rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
													rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
												
													rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0101; //!reg read, reg read imm, !reg write, reg write	imm							
													rDecodedInstruction[I_DECODED_WIDTH-1:CONTROL_OFFSET+5] <= 1'b0;
													rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+CONTROL_OFFSET+4-1:CONTROL_OFFSET+4] <= iInstruction[CONTROL_OFFSET+REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH-1:CONTROL_OFFSET+0];														
													rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+REG_ADDR_WIDTH+CONTROL_OFFSET+4-1:CONTROL_OFFSET+4] <= iInstruction[CONTROL_OFFSET+REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+REG_ADDR_WIDTH-1:CONTROL_OFFSET+0];
												end
										end
								end
								
							ID_TYPE_ALU: 
								begin	
										rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
										rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
										
										if (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET] != 0)
											begin
												rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
												rDecodedInstruction[CONTROL_OFFSET+9] <= 1'b1;
											end
										else
											begin
												rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= 1'b0; //dest = unbuffered output
												rDecodedInstruction[CONTROL_OFFSET+9] <= 1'b0;
											end
										
										rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= iInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0]; //copy type and alu operations
										
										//to check if it is a sign extention instruction
										if (iInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+2] == 2'b10 | iInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] == 4'b0011)
											if (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4] == 3'b010 | iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4] == 3'b110 | iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4] == 3'b101 | iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4] == 3'b100)
												rDecodedInstruction[CONTROL_OFFSET+10] <= 1'b1;								
											else
												rDecodedInstruction[CONTROL_OFFSET+10] <= 1'b0;	
										else							
											rDecodedInstruction[CONTROL_OFFSET+10] <= 1'b0;	
											
										//decoding from 3b to 5b for control wires
										case (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4])
												3'b000 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b1_1_0_0_0;
												3'b001 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b0_0_0_0_0;
												3'b010 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b1_0_1_1_0;
												3'b011 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b0_0_0_1_0;
												3'b100 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b0_0_1_0_0;
												3'b101 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b1_0_0_1_1;
												3'b110 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b0_0_0_0_1;
												3'b111 : rDecodedInstruction[CONTROL_OFFSET+8:CONTROL_OFFSET+4] <= 5'b0_1_0_0_0;						
										endcase
								end
							ID_TYPE_ABU:
								begin																		
									if(iInstruction[CONTROL_OFFSET+6]) //register or non-immediate operation
										begin
											rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
											
											//assign {wRegFromOpcodeA, wImmediate_Addressed, wAbsolute_Relative, wJump, wBranchConditional, wAccSigned_Unsigned, wAccumulate, wRegisterReadImmediate, wRegisterWriteImmediate, wDest, wSrcB, wSrcA} = iDecodedInstruction[ABU_DECODED_WIDTH-1:0];
												if(!iInstruction[CONTROL_OFFSET+5]) //register operation
													begin
														rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
														rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
														rDecodedInstruction[CONTROL_OFFSET+0] <= !iInstruction[CONTROL_OFFSET+4];
														rDecodedInstruction[CONTROL_OFFSET+1] <= iInstruction[CONTROL_OFFSET+4];
														rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET+2] <= 1'b0;
														rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+CONTROL_OFFSET+8-1:CONTROL_OFFSET+8] <= iInstruction[REG_ADDR_WIDTH+CONTROL_OFFSET-DEST_WIDTH-SRC_WIDTH-1:CONTROL_OFFSET];																
													end
												else
													begin //branch/jump/accumulate operation
														if(iInstruction[CONTROL_OFFSET+2]) //accumulate instruction
															begin
																rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
																rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
																rDecodedInstruction[CONTROL_OFFSET+1:CONTROL_OFFSET+0] <= 2'b00; //no register operations														
																rDecodedInstruction[CONTROL_OFFSET+2] <= 1'b1;
																rDecodedInstruction[CONTROL_OFFSET+3] <= iInstruction[CONTROL_OFFSET+1];														
																rDecodedInstruction[CONTROL_OFFSET+7:CONTROL_OFFSET+4] <= 1'b0;
																rDecodedInstruction[REG_ADDR_WIDTH-DEST_WIDTH-SRC_WIDTH+CONTROL_OFFSET+8-1:CONTROL_OFFSET+8] <= iInstruction[REG_ADDR_WIDTH+CONTROL_OFFSET-DEST_WIDTH-SRC_WIDTH-1:CONTROL_OFFSET];																
															end
														else
															begin //branch/jump
																rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb
																rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= 1'b0;
																rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= 4'b0000; //no register operations	
																rDecodedInstruction[CONTROL_OFFSET+4] <= iInstruction[CONTROL_OFFSET+4];
																rDecodedInstruction[CONTROL_OFFSET+5] <= !iInstruction[CONTROL_OFFSET+4];
																rDecodedInstruction[CONTROL_OFFSET+6] <= iInstruction[CONTROL_OFFSET+3];
																rDecodedInstruction[CONTROL_OFFSET+7] <= 1'b0; //always addressed in this case
																rDecodedInstruction[CONTROL_OFFSET+8] <= 1'b0; //always 0
															end
													end
										end
									else
										begin
											rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca		
										
											if (!iInstruction[CONTROL_OFFSET+3]) //nop	
												rDecodedInstruction <= 1'b0;
											else
												begin		//branch/jump immediate operation									
													//wRegFromOpcodeA,			8		0
													//wImmediate_Addressed,		7		1
													//wAbsolute_Relative,		6
													//wJump,							5
													//wBranchConditional,		4
													//wAccSigned_Unsigned,		3		0
													//wAccumulate,					2		I
													//wRegisterReadImmediate,	1		I
													//wRegisterWriteImmediate, 0		I
													//wDest,									I
													//wSrcB,									II
													//wSrcA
												
													rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
													rDecodedInstruction[SRC_WIDTH+BRANCH_IMM_WIDTH-1:SRC_WIDTH] <= iInstruction[SRC_WIDTH+BRANCH_IMM_WIDTH-1:SRC_WIDTH];											
													rDecodedInstruction[CONTROL_OFFSET+3] <= 1'b0;
													rDecodedInstruction[CONTROL_OFFSET+4] <= iInstruction[CONTROL_OFFSET+5];
													rDecodedInstruction[CONTROL_OFFSET+5] <= !iInstruction[CONTROL_OFFSET+5];
													rDecodedInstruction[CONTROL_OFFSET+6] <= iInstruction[CONTROL_OFFSET+4];
													rDecodedInstruction[CONTROL_OFFSET+7] <= 1'b1; //always immediate in this case
													rDecodedInstruction[CONTROL_OFFSET+8] <= 1'b0; //always 0
												end
										end
								end
							ID_TYPE_MUL: 
								begin	
										rDecodedInstruction[SRC_WIDTH-1:0] <= iInstruction[SRC_WIDTH-1:0]; //srca
										rDecodedInstruction[2*SRC_WIDTH-1:SRC_WIDTH] <= iInstruction[2*SRC_WIDTH-1:SRC_WIDTH]; //srcb														
										rDecodedInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH] <= iInstruction[2*SRC_WIDTH+DEST_WIDTH-1:2*SRC_WIDTH]; //dest
										rDecodedInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0] <= iInstruction[CONTROL_OFFSET+3:CONTROL_OFFSET+0]; //copy type and alu operations
										rDecodedInstruction[CONTROL_OFFSET+5:CONTROL_OFFSET+4] <= 2'b0;
										
										//decoding from 3b to 5b for control wires
										case (iInstruction[CONTROL_OFFSET+6:CONTROL_OFFSET+4])
												3'b000 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b0000;
												3'b010 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b0010;
												3'b001 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b0010;
												3'b100 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b1000;
												3'b101 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b1001;
												3'b110 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b1100;
												3'b111 : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b1101;						
												default : rDecodedInstruction[CONTROL_OFFSET+10:CONTROL_OFFSET+6] <= 4'b0000;
										endcase
								end						
						endcase
					end
		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled								
			end
		else
			begin
				rStall <= rState[0];				
				rDecodedInstruction <= rState[1+I_DECODED_WIDTH-1:1];
			end
			
		if (iOldStateOut)
			begin
				rState[0] <= rStall;				
				rState[1+I_DECODED_WIDTH-1:1] <= rDecodedInstruction;
			end
		
		if (iStateShift)
			begin
				rState[STATE_LENGTH-1] <= iStateDataIn;
				
				for (gCurrStateBit=0; gCurrStateBit < STATE_LENGTH-1; gCurrStateBit = gCurrStateBit + 1)		
					rState[gCurrStateBit] <= rState[gCurrStateBit+1];
			end						
		`endif
	end
	
	reg [I_DECODED_WIDTH-1:0] wDecodedInstruction;
	
	always @(rDecodedInstruction or rStall or iReset or rConfig)
	begin
		if (!rStall & !iReset)
			wDecodedInstruction = rDecodedInstruction;
		else 
			if (rStall)
				begin
					case(rConfig[CONFIG_WIDTH-STALL_GROUP_WIDTH-1:0]) //select by ID type configuration (LSU/RF/ALU)
						ID_TYPE_ALU :
							wDecodedInstruction = {11'b00_11000_0000, rDecodedInstruction[CONTROL_OFFSET-1:0]}; //_00000;						
						default:
							wDecodedInstruction = {{(I_DECODED_WIDTH-CONTROL_OFFSET){1'b0}},rDecodedInstruction[CONTROL_OFFSET-1:0]};
					endcase
				end
			else
				wDecodedInstruction = {(I_DECODED_WIDTH){1'b0}};
	end
	
	assign oDecodedInstruction = wDecodedInstruction;


	// FOR SIMULATION/UNIT TESTING ONLY, SHOULD NOT BE SYNTHESIZED --------------------------------------

	// cadence translate_off	
	// synthesis translate_off
	`ifdef DUMP_DEBUG_FILES
	 integer f;
	 integer x;
	
	 initial begin
	   f = $fopen({"ID_out_",TEST_ID,".txt"},"w");		
	   $fwrite(f,"Dec_instr.\n");		
	
	   @(negedge iReset); //Wait for reset to be released
	  
	   forever
	   begin
	 	  @(posedge iClk)
	 			$fwrite(f,"%b\t%b\t%b\n", iInstruction, rStall, rDecodedInstruction);			 						  
	   end

	   $fclose(f);  
	 end
	`endif
	// synthesis translate_on	
	// cadence translate_on
	//	--------------------------------------------------------------------------------------------------	
		
endmodule
