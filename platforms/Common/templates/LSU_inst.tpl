	LSU 
	#(		
		.I_DECODED_WIDTH(I_DECODED_WIDTH),
		.D_WIDTH(D_WIDTH),	
		.NUM_INPUTS(<<NUM_INPUTS>>),
		.NUM_OUTPUTS(<<NUM_OUTPUTS>>),	
		.LM_ADDR_WIDTH(LM_ADDR_WIDTH),
		.GM_ADDR_WIDTH(GM_ADDR_WIDTH),

		.LM_MEM_ADDR_WIDTH(LM_MEM_ADDR_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),

		.SRC_WIDTH(SRC_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),

		.TEST_ID(<<TEST_ID>>),
		.NUM_STALL_GROUPS(NUM_STALL_GROUPS)
	) 
	<<UNIT_NAME>>
	(
		.iClk(iClk),
		.iReset(iReset),
		
		.oStall(wStall_<<LSU_PORT>>), 

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
		
		.iDecodedInstruction(<<ID_DECODED>>),
				
		.iLM_ReadData(wLM_ReadData[<<LSU_PORT>>]),
		.oLM_ReadAddress(wLM_ReadAddress[<<LSU_PORT>>]),		
		.oLM_WriteData(wLM_WriteData[<<LSU_PORT>>]),
		.oLM_WriteAddress(wLM_WriteAddress[<<LSU_PORT>>]),
		.oLM_WriteEnable(wLM_WriteEnable[<<LSU_PORT>>]),	
		.oLM_ReadEnable(wLM_ReadEnable[<<LSU_PORT>>]),
		
		//`ifdef NATIVE_GM_INTERFACE
			.iGM_ReadGrantNextCycle(wGM_ReadGrantNextCycle[<<LSU_PORT>>]),
			.iGM_WriteGrantNextCycle(wGM_WriteGrantNextCycle[<<LSU_PORT>>]),
		//`endif				

		.iGM_ReadData(wGM_ReadData[<<LSU_PORT>>]),
		.iGM_ReadDataValid(wGM_ReadDataValid[<<LSU_PORT>>]),
		.oGM_ReadRequest(wGM_ReadRequest[<<LSU_PORT>>]),		
		.oGM_ReadAddress(wGM_ReadAddress[<<LSU_PORT>>]),	
		.oGM_WriteAddress(wGM_WriteAddress[<<LSU_PORT>>]),	
		.oGM_WriteData(wGM_WriteData[<<LSU_PORT>>]),
		.oGM_WriteEnable(wGM_WriteEnable[<<LSU_PORT>>]),	
		.oGM_WriteRequest(wGM_WriteRequest[<<LSU_PORT>>]),
		.iGM_WriteAccept(wGM_WriteAccept[<<LSU_PORT>>])		

	);
