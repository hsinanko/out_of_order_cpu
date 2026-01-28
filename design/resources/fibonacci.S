## fibonacci.S
## put input n in register x10 (a0)  
## put output fibonacci(n) in register x11 (a1)
## use Venus to test correctness

.text
main:
## write assembly code here.
## call fibonacci function and get return value.
	li a0, 8
    addi sp, sp, -4		
    sw a0, 0(sp)		# store n
    jal fibonacci		# fibonacci(n)
    mv a1, a0			# put return value in a1
    lw a0, 0(sp)		# load n
    addi sp, sp, 4		# pop out stack
    j exit

fibonacci:
## fibonacci function
    addi sp, sp, -12
    sw ra, 0(sp)		# store return address
    sw a0, 4(sp)		# store n
	sw x0, 8(sp)		# return value
    
    li t0, 1
    bge t0, a0, ret_n   # if(n <= 1) return n

    lw t1, 4(sp)		# load n
    addi a0, t1, -1		# n-1	
    jal fibonacci	    # fibonacci(n-1)
    sw a0, 8(sp)     	# store the value = fibonacci(n-1)

    lw t1, 4(sp)		# load n
    addi a0, t1, -2		# n-2
    jal fibonacci	    # fibonacci(n-2)
    lw a1, 8(sp)
    add a0, a0, a1      # fibonacci(n-1) + fibonacci(n-2)

    lw ra, 0(sp)        # load the return address
    addi sp, sp, 12     # pop out the stack pointer 
    jr ra               # back to the return address

ret_n:   
    add a0, a0, x0      # return n
    lw ra, 0(sp)        # load return address
    addi sp, sp, 12     # pop out the stack pointer
    jr ra               # back to the return address
    
exit:
	ecall
