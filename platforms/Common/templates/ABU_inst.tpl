
	ABU
	#(  //parameters that can be externally configured
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),
		.IM_ADDR_WIDTH(IM_ADDR_WIDTH),
	
		.NUM_INPUTS(<<NUM_INPUTS>>),
		.NUM_OUTPUTS(<<NUM_OUTPUTS>>),
	
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
	
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
	
		.TEST_ID(<<TEST_ID>>),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
		
	)
	<<UNIT_NAME>>
	(	//inputs and outputs
		.iClk(iClk),
		.iReset(iReset),
		.oHalted(wHalted),
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
		
		.iInputs(<<INPUTS>>),
		.oOutputs(<<OUTPUTS>>),
		
		.iDecodedInstruction(<<ID_DECODED>>)	
	);
