.data
str_prompt:     .asciiz "Enter the infix expression: "
str_postFix:    .asciiz "\nPostfix expression: "
str_result:     .asciiz "\nEvaluation: "
error1:         .asciiz "Mismatched between ( and ) "
error2:         .asciiz "Operand placement is wrong "
error3:         .asciiz "Invalid characters "
buffer:         .space 256
postfix:        .space 256

.text
main:
    # Print prompt
    li $v0, 4
    la $a0, str_prompt
    syscall

    # Read input infix expression
    li $v0, 8
    la $a0, buffer
    li $a1, 256
    syscall

    la $t0, buffer      # Input buffer pointer
    la $t9, postfix     # Postfix buffer pointer
    move $s1, $sp       # Save initial stack pointer
    li $s2, 0           # Flag for operand placement
    li $s6, 1           # $s6 = 0 if the last valid character not space and () is a digit 

# Loop through the input string
loop:
    lb $t1, 0($t0)       # Load a character from input buffer    
    beqz $t1, empty_stack # If end of string, exit loop
    
    # Check if it's a space, skip if true
    li $t2, 32           # ASCII value for space
    beq $t1, $t2, next
    
    # Check if it's a digit
    li $t2, 48           # ASCII value for '0'
    li $t3, 57           # ASCII value for '9'
    blt $t1, $t2, not_digit
    bgt $t1, $t3, not_digit

    # If digit, append to postfix buffer
    sb $t1, 0($t9)
    addi $t9, $t9, 1
    li $s6, 0
    j next

not_digit:
    # Check if it's an operator
    li $t2, 42           # ASCII value for '*'
    li $t3, 43           # ASCII value for '+'
    li $t4, 45           # ASCII value for '-'
    li $t5, 47           # ASCII value for '/'

    beq $t1, $t2, push_op
    beq $t1, $t3, push_op
    beq $t1, $t4, push_op
    beq $t1, $t5, push_op

    # Check if it's '('
    li $t6, 40           # ASCII value for '('
    beq $t1, $t6, push_paren

    # Check if it's ')'
    li $t7, 41           # ASCII value for ')'
    beq $t1, $t7, pop_paren
     
    j next

push_op:
    # Handle operator precedence and stack operations
    beq $s6, 1, exception2 # If there are two consecutive operators then it's an error
    move $a0, $t1
    jal precedence_level
    move $s2, $v0

    beq $sp, $s1, level_0
    lw $s0, 0($sp)
    beq $s0, $t6, level_0
    move $a0, $s0
    jal precedence_level
    move $s3, $v0
    j continue

level_0:    
    li $s3, 0

continue:
    ble $s2, $s3, pop_op
    li $s6, 1 #Set $s6 to 1 after pushing the operand into stack
    li $a0, 32
    sb $a0, 0($t9)
    addi $t9, $t9, 1
    addi $sp, $sp, -4
    sw $t1, 0($sp)      # Store operator in stack
    j next

pop_op:
    # Pop and append operator from stack to postfix buffer
    lw $s0, 0($sp)
    addi $sp, $sp, 4
    li $a0, 32
    sb $a0, 0($t9)
    addi $t9, $t9, 1
    sb $s0, 0($t9)
    addi $t9, $t9, 1

    j push_op

push_paren:
    # Push '(' onto stack
    li $a0, 32
    sb $a0, 0($t9)
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    j next

pop_paren:
    # Pop operators until '(' is found
pop_loop:
    beq $sp, $s1, exception
    lw $t8, 0($sp)
    addi $sp, $sp, 4
    li $a0, 32
    sb $a0, 0($t9)
    addi $t9, $t9, 1
    beq $t8, $t6, pop_done
    # Append operator to postfix buffer
    sb $t8, 0($t9)
    addi $t9, $t9, 1
    j pop_loop
    
pop_done:
    j next

next:
    addi $t0, $t0, 1    # Increment index for input buffer
    j loop

empty_stack:
    beq $sp, $s1, print_postfix # Stop when stack pointer returns to original value 
    lw $t8, 0($sp)
    addi $sp, $sp, 4
    beq $t8, $t6, exception
    li $a0, 32
    sb $a0, 0($t9)
    addi $t9, $t9, 1
    sb $t8, 0($t9)
    addi $t9, $t9, 1
    j empty_stack

print_postfix:
    beq $s6, 1, exception2 # If the last valid character is an operator then it's an error
    # Null-terminate the postfix string
    sb $zero, 0($t9)
    # Print postfix expression header
    li $v0, 4
    la $a0, str_postFix
    syscall
    # Print the postfix expression
    li $v0, 4
    la $a0, postfix
    syscall

##############################################
# Evaluate the value of the expression
    la $t0, postfix      # Input buffer pointer
    # Loop through the input string
loop_2:
    lb $t1, 0($t0)       # Load a character from input buffer
    beqz $t1, result     # If end of string, exit loop

    # Check if it's a digit
    li $t2, 48           # ASCII value for '0'
    li $t3, 57           # ASCII value for '9'
    blt $t1, $t2, check_operator
    bgt $t1, $t3, check_operator

    # If digit, parse the entire number
    move $t4, $zero      # Initialize number to 0

parse_number:
    sub $t1, $t1, $t2    # Convert ASCII to integer
    mul $t4, $t4, 10     # Shift current number left by one digit
    add $t4, $t4, $t1    # Add current digit to number
    
    addi $t0, $t0, 1     # Move to next character
    lb $t1, 0($t0)       # Load next character
    beqz $t1, stop
    blt $t1, $t2, stop   # If next character is not a digit, stop parsing
    bgt $t1, $t3, stop
    j parse_number

stop:
    # Push the number onto the stack
    addi $sp, $sp, -4
    sw $t4, 0($sp)
    beqz $t1, result     # If end of string, exit loop
    j next_2

check_operator:
    # Check if it's a space, skip if true
    li $t2, 32           # ASCII value for space
    beq $t1, $t2, next_2

    # Check if it's an operator
    li $t2, 42           # ASCII value for '*'
    li $t3, 43           # ASCII value for '+'
    li $t4, 45           # ASCII value for '-'
    li $t5, 47           # ASCII value for '/'

    beq $t1, $t2, operate
    beq $t1, $t3, operate
    beq $t1, $t4, operate
    beq $t1, $t5, operate

    j next_2

operate:
    # Pop two operands from the stack
    lw $t6, 0($sp)
    addi $sp, $sp, 4
    lw $t7, 0($sp)
    addi $sp, $sp, 4

    # Perform the operation
    li $t2, 42           # ASCII value for '*'
    li $t3, 43           # ASCII value for '+'
    li $t4, 45           # ASCII value for '-'
    li $t5, 47           # ASCII value for '/'

    beq $t1, $t2, multiply
    beq $t1, $t3, adding
    beq $t1, $t4, subtract
    beq $t1, $t5, divide

multiply:
    mul $t8, $t7, $t6
    j push_result

adding:
    add $t8, $t7, $t6
    j push_result

subtract:
    sub $t8, $t7, $t6
    j push_result

divide:
    div $t7, $t6
    mflo $t8
    j push_result

push_result:
    # Push the result onto the stack
    addi $sp, $sp, -4
    sw $t8, 0($sp)
    j next_2

next_2:
    addi $t0, $t0, 1     # Move to next character
    j loop_2

result:
    # Load the result from the stack
    lw $t8, 0($sp)
    
    # Print the result
    li $v0, 4
    la $a0, str_result
    syscall

    li $v0, 1
    move $a0, $t8
    syscall

end:
    # Exit program
    li $v0, 10
    syscall

# Function to get precedence level of operator
precedence_level:
    li $v0, 0
    li $t2, 42            # ASCII value for '*'
    li $t3, 43            # ASCII value for '+'
    li $t4, 45            # ASCII value for '-'
    li $t5, 47            # ASCII value for '/'

    beq $a0, $t2, level_3
    beq $a0, $t3, level_2
    beq $a0, $t4, level_2
    beq $a0, $t5, level_3

level_2:
    li $v0, 2
    jr $ra

level_3:
    li $v0, 3
    jr $ra
    
# Exception handling
exception:
    li $v0, 4
    la $a0, error1
    syscall
    j end

exception2:
    li $v0, 4
    la $a0, error2
    syscall
    j end
    
exception3:
    li $v0, 4
    la $a0, error3
    syscall
    j end
