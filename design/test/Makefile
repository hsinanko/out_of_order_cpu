
VERILATOR = verilator

PKG = \
		../src/package/parameter_pkg.sv \
		../src/package/typedef_pkg.sv \
		../src/package/register_pkg.sv \
		../src/package/instruction_pkg.sv \
		../src/package/info_pkg.sv \
		../src/package/debug_pkg.sv

INT = \
		../src/interface/writeback_if.sv \
		../src/interface/execution_if.sv \
		../src/interface/physical_if.sv \
		../src/interface/rename_if.sv \
		../src/interface/retire_if.sv

COM = \
		../src/common/Back_RAT.sv \
		../src/common/Control.sv \
		../src/common/DataMemory.sv \
		../src/common/Freelist.sv \
		../src/common/Front_RAT.sv\
		../src/common/Memory.sv \
		../src/common/PhysicalRegister.sv \
		../src/common/ReorderBuffer.sv
		
		
IF = \
		../src/Fetch/BTB.sv \
		../src/Fetch/InstructionROM.sv

ID = \
		../src/Decode/ReservationStation/FreeSlot.sv \
		../src/Decode/ReservationStation/ReservationStation.sv \
		../src/Decode/Dispatch.sv \
		../src/Decode/Rename.sv \
		../src/Decode/InstructionDecode.sv 


EXE = \
		../src/Issue/Execution/ALUUnit/ALUControl.sv \
		../src/Issue/Execution/ALUUnit/ALU.sv \
		../src/Issue/Execution/BranchUnit/BranchUnit.sv \
		../src/Issue/Execution/MEMUnit/AddressGenerator.sv \
		../src/Issue/Issue.sv \
		../src/Issue/Execution/Execution.sv
WB = \
		../src/WriteBack/FreeEntry.sv \
		../src/WriteBack/LoadStoreQueue.sv \
		../src/WriteBack/WriteBack.sv

RE = \
		../src/Retire/Retire.sv

TB ?= IssueExecution_tb
VFLAGS = --binary \
		 -sv \
		 --trace \
		 -Wall \
		 -Wno-fatal \
		 -o  $(TB) \
			 $(PKG) \
			 $(INT) \
			 $(COM) \
			 $(IF) \
			 $(ID) \
			 $(EXE) \
			 $(WB) \
			 $(RE)


TEST ?= fibonacci

all: compile test

compile:
	riscv32-unknown-elf-gcc \
			-march=rv32i \
			-mabi=ilp32 \
			-nostdlib \
			-Ttext=0x0 \
			../resources/$(TEST).S \
			-o test.elf
	riscv32-unknown-elf-objcopy -O binary test.elf test.bin
	xxd -p -c 1 test.bin > ../resources/mem.hex
test:
	$(VERILATOR)  $(VFLAGS) $(TB).sv
	./obj_dir/$(TB) +trace

clean:
	rm -f *.txt
	rm -rf build
	rm -f  test.elf test.bin
.PHONY: test clean