	ALU
	#(
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH (D_WIDTH),
		
		.NUM_INPUTS(<<NUM_INPUTS>>),
		.NUM_OUTPUTS(<<NUM_OUTPUTS>>),
		
		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.TEST_ID(<<TEST_ID>>)
	)
	<<UNIT_NAME>>
	(	
		.iClk(iClk),
		.iReset(iReset),

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
		
		.iCarryIn(<<CARRY_IN>>),
		.oCarryOut(<<CARRY_OUT>>),

		.iInputs(<<INPUTS>>), 
		.oOutputs(<<OUTPUTS>>),
		
		.iDecodedInstruction(<<ID_DECODED>>)
	);
