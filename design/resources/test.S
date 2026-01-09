## fibonacci.S
## put input n in register x10 (a0)  
## put output fibonacci(n) in register x11 (a1)
## use Venus to test correctness

.text
main:
## write assembly code here.
## call fibonacci function and get return value.
	li a0, 1
    addi sp, sp, -4		
    sw a0, 0(sp)		# store n
    jal fibonacci		# fibonacci(n)
    mv a1, a0			# put return value in a1
    lw a0, 0(sp)		# load n
    addi sp, sp, 4		# pop out stack
    j exit

fibonacci:
## fibonacci function
    jr ra               # back to the return address

ret_zero:   
    mv a0, x0           # return 0
    lw ra, 0(sp)        # load return address
    addi sp, sp, 12     # pop out the stack pointer
    jr ra               # back to the return address
ret_one:
    li a0, 1		    # return 1
    lw ra, 0(sp)        # load return address
    addi sp, sp, 12     # pop out the stack pointer
    jr ra               # back to the return address
    
exit:
	ecall