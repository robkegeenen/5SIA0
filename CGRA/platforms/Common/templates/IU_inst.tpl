	IF //instruction fetching
	#(
		.I_WIDTH(I_IMM_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH)
	)
	IF_<<UNIT_NAME>>
	(		
		.iClk(iClk),
		.iReset(iReset),

		.iProgramCounter(<<INPUTS>>),
	
		.oInstructionAddress(<<INSTRUCTION_ADDRESS>>),
		.iInstruction(<<INSTRUCTION_DATA>>),

		.oInstruction(<<INSTRUCTION>>),
		.oInstructionReadEnable(<<INSTRUCTION_RE>>)
	);

	IU
	#(	
		.I_IMM_WIDTH(I_IMM_WIDTH),
		.D_WIDTH(D_WIDTH),
	
		.INSERT_BUBBLE(1),
	
		.TEST_ID(<<TEST_ID>>),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	)
	<<UNIT_NAME>>
	(
		.iClk(iClk),
		.iReset(iReset),

		.iStall(wStall | iStateSwitchHalt),

		//config chain
		.iConfigEnable(iConfigEnable),
		.iConfigDataIn(<<CONFIG_DATA_IN>>),
		.oConfigDataOut(<<CONFIG_DATA_OUT>>),

		`ifdef INCLUDE_STATE_CONTROL	//use only if state control is enabled				
			.iStateDataIn(<<STATE_DATA_IN>>),
			.oStateDataOut(<<STATE_DATA_OUT>>),	
			.iStateShift(iStateShift),
			.iNewStateIn(iStateNewIn),		
			.iOldStateOut(iStateOldOut),		
		`endif			
	
		.iInstruction(<<INSTRUCTION>>),
		.oImmediateOut(<<OUTPUTS>>)	
	);
