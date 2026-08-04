#--------------------------------------------------------------
#  test_cpu.asm  --  peripheral-free CPU / hazard test
#
#  Purpose: calibration target for golden-model co-simulation.
#  Touches NO address at or above 0x800, never enables interrupts,
#  and never writes $k0/$k1, so every architectural effect is
#  reproducible by a plain ISS.
#
#  Deliberately written WITHOUT defensive nops so that the
#  forwarding paths and the load-use / branch interlocks are
#  actually exercised.
#--------------------------------------------------------------

.data
# byte 0x00 : scratch area written by the store tests
SCRATCH: .word 0, 0, 0, 0, 0, 0, 0, 0

# byte 0x20 : read-only constants
CONST:   .word 0x00000005
         .word 0x0000000B
         .word 0xFFFFFFFF
         .word 0x80000000

.text
main:
#---- group 1: immediates and the extension rules ----
    addi $t0, $zero, 5              # 0x00000005
    addi $t1, $zero, 11             # 0x0000000B
    addi $t2, $zero, -1             # 0xFFFFFFFF   (sign extend)
    ori  $t3, $zero, 0xF000         # 0x0000F000   (zero extend)
    andi $t4, $t2, 0x00FF           # 0x000000FF
    xori $t5, $t0, 0x000F           # 0x0000000A
    lui  $t6, 0xABCD                # 0xABCD0000

#---- group 2: EX->EX forwarding (back-to-back dependency) ----
    add  $s0, $t0, $t1              # 16   rs from 2 back, rt from 1 back
    sub  $s1, $s0, $t0              # 11   rs from 1 back  (EX->EX)
    and  $s2, $s1, $t1              # 11
    or   $s3, $s2, $t0              # 15
    xor  $s4, $s3, $s2              # 4

#---- group 3: MEM->EX and WB->EX forwarding ----
    addi $t7, $zero, 100
    addi $s5, $zero, 1              # filler, 1 apart -> MEM->EX
    add  $s6, $t7, $s5              # 101
    addi $s7, $zero, 2              # filler
    addi $a0, $zero, 3              # filler, 2 apart -> WB->EX
    add  $a1, $t7, $s7              # 102

#---- group 4: shifts (operand comes from rt, shamt from the field) ----
    sll  $a2, $t0, 4                # 0x50
    srl  $a3, $t6, 8                # 0x00ABCD00
    sll  $v0, $t1, 0                # 11  (shift by zero)

#---- group 5: slt / slti ----
    slt  $v1, $t0, $t1              # 5 < 11  -> 1
    slt  $fp, $t1, $t0              # 11 < 5  -> 0
    slti $gp, $t0, 6                # 5 < 6   -> 1

#---- group 6: multiply ----
    addi $t8, $zero, 7
    mul  $t9, $t8, $t8              # 49       (EX->EX into a multiply)

#---- group 7: stores and the load-use interlock ----
    sw   $s0, 0x00($zero)           # SCRATCH[0] = 16
    sw   $s1, 0x04($zero)           # SCRATCH[1] = 11
    lw   $t0, 0x00($zero)           # load
    add  $t1, $t0, $t0              # <-- LOAD-USE, requires a stall (32)
    lw   $t2, 0x20($zero)           # CONST[0] = 5
    sw   $t1, 0x08($zero)           # SCRATCH[2] = 32
    lw   $t3, 0x24($zero)           # CONST[1] = 11
    add  $t4, $t2, $t3              # 16, both from loads (no stall needed)
    sw   $t4, 0x0C($zero)           # SCRATCH[3] = 16

#---- group 8: branches ----
    addi $s0, $zero, 4
    addi $s1, $zero, 4
    beq  $s0, $s1, b_taken          # taken; operand from 1 back -> branch stall
    addi $s2, $zero, 0xBAD          # must NOT execute
b_taken:
    addi $s2, $zero, 1              # 1

    bne  $s0, $s1, b_bad            # NOT taken
    addi $s3, $zero, 2              # 2  (must execute)
    j    b_cont
b_bad:
    addi $s3, $zero, 0xBAD          # must NOT execute
b_cont:

    lw   $s4, 0x20($zero)           # 5
    addi $s5, $zero, 5
    beq  $s4, $s5, b_load           # operand from a LOAD in MEM -> stall
    addi $s6, $zero, 0xBAD          # must NOT execute
b_load:
    addi $s6, $zero, 3              # 3

#---- group 9: jal / jr ----
    addi $a0, $zero, 0
    jal  sub1
    addi $a2, $zero, 9              # executes after return  (9)
    j    done

sub1:
    addi $a0, $zero, 42             # 42
    addi $a1, $a0, 1                # 43  (EX->EX inside the callee)
    jr   $ra

#---- group 10: writes to $zero are dropped ----
done:
    addi $zero, $zero, 123          # must produce NO commit
    add  $zero, $t0, $t1            # must produce NO commit
    sw   $a1, 0x10($zero)           # SCRATCH[4] = 43

idle:
    j    idle
