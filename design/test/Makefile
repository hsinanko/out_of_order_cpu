
VERILATOR = verilator

PKG = \
		../src/package/parameter_pkg.sv \
		../src/package/typedef_pkg.sv \
		../src/package/register_pkg.sv \
		../src/package/instruction_pkg.sv \
		../src/package/debug_pkg.sv
COM = \
		../src/common/Front_RAT.sv\
		../src/common/Back_RAT.sv \
		../src/common/Memory.sv \
		../src/common/ReorderBuffer.sv \
		../src/common/PhysicalRegister.sv \
		../src/common/Freelist.sv
ID = \
		../src/Decode/Dispatch.sv \
		../src/Decode/Rename.sv \
		../src/Decode/InstructionDecode.sv 
IF = \
		../src/Fetch/InstructionROM.sv \
		../src/Fetch/InstructionFetch.sv


EXE = \
		../src/Issue/Execution/ALUUnit/ALUControl.sv \
		../src/Issue/Execution/ALUUnit/ALU.sv \
		../src/Issue/Execution/BranchUnit/BranchUnit.sv \
		../src/Issue/Execution/MEMUnit/MEMUnit.sv \
		../src/Issue/ReservationStation/FreeSlot.sv \
		../src/Issue/ReservationStation/ReservationStation.sv \
		../src/Issue/Issue.sv \
		../src/Issue/Execution/Execution.sv
WB = \
		../src/WriteBack/WriteBack.sv \
		../src/WriteBack/FIFO.sv \
		../src/WriteBack/StoreQueue.sv
TB ?= IssueExecution_tb
VFLAGS = --binary -sv --trace -Wall -Wno-fatal \
						-o  $(TB) \
							$(PKG) \
							$(COM) \
							$(IF) \
							$(ID) \
							$(EXE) \
							$(WB)

all: test


test:
	$(VERILATOR)  $(VFLAGS) $(TB).sv
	./obj_dir/$(TB) +trace

clean:
	rm -rf obj_dir
	rm -f *.vcd
	rm -f *.txt
	rm -rf build
	
.PHONY: test clean