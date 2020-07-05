module pipeline_MIPS32(clk1, clk2);

	input clk1, clk2; 

	reg [31:0] PC, IF_ID_IR, IF_ID_NPC; 
	reg [31:0] ID_EXE_NPC, ID_EXE_A, ID_EXE_B, ID_EXE_Imm, ID_EXE_IR;
	reg [2:0] ID_EXE_type, EXE_MEM_type, MEM_WB_type;
	reg [31:0] EXE_MEM_IR, EXE_MEM_ALUOut, EXE_MEM_B;
	reg EXE_MEM_cond; 
	reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD;

	reg [31:0] Reg [0:31];
	reg [31:0] Mem [0:1023]; 

	parameter 	ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000011, OR = 6'b000100, SLT = 6'b000101, HLT = 6'b111111,
				LW = 6'b001000, SW = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100, BNEQZ = 6'b001101, 
				BEQZ = 6'b001110; 

	parameter	RR_ALU = 3'b000, RM_ALU = = 3'b001, LOAD = 3'b010, STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;

	reg HALTED; 
	reg TAKEN_BRANCH; 

	// IF Stage

	always @ (posedge clk 1) 
		if (HALTED == 0)
		begin 
			if ((EXE_MEM_IR[31:26] == BEQZ && EXE_MEM_cond == 1) || 
				(EXE_MEM_IR[31:26] == BNEQZ && EXE_MEM_cond == 0)) 
			begin 
				IF_ID_IR <= Mem[EXE_MEM_ALUOut]; 
				TAKEN_BRANCH <= 1'b1; 
				IF_ID_NPC <= EXE_MEM_ALUOut + 1;
				PC <= EXE_MEM_ALUOut + 1;
			end
			begin 
				IF_ID_IR <= Mem[PC]; 
				IF_ID_NPC <= PC + 1; 
				PC = PC + 1; 
			end
		end


	// ID Stage 

	always @ (posedge clk2)
		if (HALTED == 0)
		begin
			if (IF_ID_IR[25:21] == 5'b00000) ID_EXE_A <= 0;
			else ID_EXE_A <= Reg[IF_ID_IR[25:21]]; 				//rs

			if (IF_ID_IR[20:16] == 5'b00000) ID_EXE_B <= 0;
			else ID_EXE_B <= Reg[IF_ID_IR[20:16]]; 				//rT

			ID_EXE_Imm 	<= {{16{IF_ID_IR[15]}, {IF_ID_IR[15:0]}};	//Sign Extention

			ID_EXE_IR 	<= IF_ID_IR; 
			ID_EXE_NPC 	<= IF_ID_NPC;

			case (IF_ID_IR[31:26])	
				ADD, SUB, AND, OR, SLT, MUL : ID_EXE_type <= RR_ALU; 
				ADDI, SUBI, SLTI, MULI 		: ID_EXE_type <= RM_ALU;
				BEQZ, BNEQZ 				: ID_EXE_type <= BRANCH;
				HLT 						: ID_EXE_type <= HALT;
				LD 							: ID_EXE_type <= LOAD;
				SW 							: ID_EXE_type <= STORE; 
				default 					: ID_EXE_type <= HALT;
			endcase
		end
				
	// EXE Stage 

	always @ (posedge clk1)
		if (HALTED == 0)
		begin
			EXE_MEM_IR 		<= ID_EXE_IR;
			EXE_MEM_type 	<= ID_EXE_type;
			TAKEN_BRANCH 	<= 0; 

			case (ID_EXE_type) 
				RR_ALU	: 	begin
								case (ID_EXE_IR[31:26])
									ADD 	: EXE_MEM_ALUOut <= ID_EXE_A + ID_EXE_B; 
									SUB 	: EXE_MEM_ALUOut <= ID_EXE_A - ID_EXE_B; 
									AND 	: EXE_MEM_ALUOut <= ID_EXE_A & ID_EXE_B; 
									OR 		: EXE_MEM_ALUOut <= ID_EXE_A | ID_EXE_B; 
									SLT 	: EXE_MEM_ALUOut <= ID_EXE_A < ID_EXE_B; 
									MUL 	: EXE_MEM_ALUOut <= ID_EXE_A * ID_EXE_B; 
									default : EXE_MEM_ALUOut <= 32'hxxxxxxxx;  	
								endcase
							end

				RM_ALU 	: 	begin 
								case (ID_EXE_IR[31:26])
									ADDI	: EXE_MEM_ALUOut <= ID_EXE_A + ID_EXE_Imm;
									SUBI	: EXE_MEM_ALUOut <= ID_EXE_A - ID_EXE_Imm;
									SLTI	: EXE_MEM_ALUOut <= ID_EXE_A < ID_EXE_Imm;
									MULI	: EXE_MEM_ALUOut <= ID_EXE_A * ID_EXE_Imm;
									default : EXE_MEM_ALUOut <= 32'hxxxxxxxx;
								endcase
							end

				BRANCH 	: 	begin
								EXE_MEM_ALUOut 	<= ID_EXE_NPC + ID_EXE_Imm;
								EXE_MEM_cond 	<= (ID_EXE_A == 0);
							end

				LOAD 	:	begin
								EXE_MEM_ALUOut <= ID_EXE_A + ID_EXE_Imm;
								EXE_MEM_B <= ID_EXE_B;
							end
	 				
	 			STORE 	:	begin
								EXE_MEM_ALUOut <= ID_EXE_A + ID_EXE_Imm;
								EXE_MEM_B <= ID_EXE_B;
							end
			endcase
		end


	// MEM

	always @ (posedge clk2)
		if (HALTED == 0)
		begin
			MEM_WB_type <= EXE_MEM_type;
			MEM_WB_IR 	<= EXE_MEM_IR;

			case (EXE_MEM_type)
				RR_ALU, RM_ALU 	: MEM_WB_ALUOut <= EXE_MEM_ALUOut; 
				LOAD			: MEM_WB_LMD 	<= Mem[EXE_MEM_ALUOut]; 
				STORE			: if (TAKEN_BRANCH == 0) 	
									Mem[EXE_MEM_ALUOut] <= EXE_MEM_B;
			endcase
		end


	// WB

	always @ (posedge clk2)
		if (TAKEN_BRANCH == 0)			// Write is disabled
		begin
			case (MEM_WB_type)
				RR_ALU 	: 	Reg[MEM_WB_IR[15:11]]	<= MEM_WB_ALUOut;
				RM_ALU	:	Reg[MEM_WB_IR[20:16]]	<= MEM_WB_ALUOut;
				LOAD 	:	Reg[MEM_WB_IR[20:16]]	<= MEM_WB_LMD;
				HALT 	:	HALTED <= 1; 
			endcase
		end

endmodule 