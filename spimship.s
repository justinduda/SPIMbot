.data

# movement memory-mapped I/O
VELOCITY            = 0xffff0010
ANGLE               = 0xffff0014
ANGLE_CONTROL       = 0xffff0018

# coordinates memory-mapped I/O
BOT_X               = 0xffff0020
BOT_Y               = 0xffff0024

# planet memory-mapped I/O
PLANETS_REQUEST     = 0xffff1014

# scanning memory-mapped I/O
SCAN_REQUEST        = 0xffff1010
SCAN_SECTOR         = 0xffff101c

# gravity memory-mapped I/O
FIELD_STRENGTH      = 0xffff1100

# bot info memory-mapped I/O
SCORES_REQUEST      = 0xffff1018
ENERGY              = 0xffff1104

# debugging memory-mapped I/O
PRINT_INT           = 0xffff0080

# interrupt constants
SCAN_MASK           = 0x2000
SCAN_ACKNOWLEDGE    = 0xffff1204
ENERGY_MASK         = 0x4000
ENERGY_ACKNOWLEDGE  = 0xffff1208  

# puzzle interface locations 
SPIMBOT_PUZZLE_REQUEST      = 0xffff1000 
SPIMBOT_SOLVE_REQUEST       = 0xffff1004 
SPIMBOT_LEXICON_REQUEST     = 0xffff1008 

# I/O used in competitive scenario 
INTERFERENCE_MASK   = 0x8000 
INTERFERENCE_ACK    = 0xffff13048
SPACESHIP_FIELD_CNT     = 0xffff110c 

num_rows:
    .word 0
num_columns:
    .word 0
puzzle_struct: .space 4104
lexicon_struct: .space 4096
solution_struct: .space 4104
offset: .space 16

PRINT_STRING = 4

.align 2

sectors:    .space 256
SCAN_COMP:  .space 4
planet_info:.space 32
energy_low: .space 4



.kdata                  # interrupt handler data (separated just for readability)
chunkIH:    .space 8    # space for two registers


non_intrpt_str: .asciiz "Non-interrupt exception\n"
unhandled_str:  .asciiz "Unhandled interrupt type\n"

.ktext 0x80000180

interrupt_handler:
.set noat
    move    $k1, $at        # Save $at

.set at
    la  $k0, chunkIH
    sw  $a0, 0($k0)     # Get some free registers                  
    sw  $a1, 4($k0)     # by storing them to a global variable     
    sw  $v0, 8($k0)

    mfc0    $k0, $13        # Get Cause register                       
    srl $a0, $k0, 2                
    and $a0, $a0, 0xf       # ExcCode field                            
    bne $a0, 0, non_intrpt         

interrupt_dispatch:         # Interrupt:                             
    mfc0    $k0, $13        # Get Cause register, again                 
    beq $k0, 0, done        # handled all outstanding interrupts     

    and $a0, $k0, ENERGY_MASK   # is there a timer interrupt?
    bne $a0, 0, energy_interrupt
    
    and $a0, $k0, SCAN_MASK     # scan interrupt?
    bne $a0, 0, scan_interrupt

    # add dispatch for other interrupt types here.

    li  $v0, PRINT_STRING   # Unhandled interrupt types
    la  $a0, unhandled_str
    syscall 
    j   done

scan_interrupt:
    li $a0, 1
    sw $a0, SCAN_ACKNOWLEDGE
    li $a1, 1
    sw $a1, SCAN_COMP   #set global variable scan_comp(lete) to 1
    
    j interrupt_dispatch

energy_interrupt:
    li $a0, 1
    sw $a0, ENERGY_ACKNOWLEDGE
    
    j interrupt_dispatch

non_intrpt:             # was some non-interrupt
    li  $v0, PRINT_STRING
    la  $a0, non_intrpt_str
    syscall             # print out an error message
    # fall through to done

done:
    la  $k0, chunkIH
    lw  $a0, 0($k0)     # Restore saved registers
    lw  $a1, 4($k0)
    lw  $v0, 8($k0)
.set noat
    move    $at, $k1        # Restore $at
.set at 
    eret

#
# end interrupt code
#

#
# start main BOT code
#






.text


main:
    # la $t0, puzzle_struct
    # sw $t0, SPIMBOT_PUZZLE_REQUEST   
    # lw $t1, 0($t0)
    # lw $t2, 4($t0)
    # lw $t3, 8($t0)
    
    


enable_interrupts:
    #li $t4, TIMER_MASK     # timer interrupt enable bit
    li  $t4 SCAN_MASK       # scan interrupt bit
    or  $t4 $t4 ENERGY_MASK
    or  $t4 $t4 1           # global interrupt enable
    mtc0    $t4 $12         # set interrupt mask (Status register)


sub $sp, $sp, 4
li $a0, 0
sw $a0, 0($sp)

start_over:


    li $t0, 0
    sw $t0, SCAN_COMP

    li $t0, 0
    sw $t0, VELOCITY

    li $t0, 0             #set t0 to 0

    lw $a0, 0($sp)
## Scan for sector with most dust
    jal scan_sectors
## $v0 holds sector with most dust


    move $a0, $v0

    jal drive_to_sect

#
# Bot reached ~middle of sector with the most amount of dust
#

	#max field strength very quickly to pull dust to ship

    li $t3, 6
    sw $t3, FIELD_STRENGTH

    li $t3, 4
    sw $t3, VELOCITY

#
# Go to your planet
#

    jal drive_to_planet
    lw $v0, 0($sp)
#
#returned dust to our planet
#so turn field off
#
   
   
    li $t0, 0
    sw $t0, FIELD_STRENGTH

    lw $t1, ENERGY 
    jal puzzle_solver 
    
    j start_over

##################    END MAIN #####################


###############
# Subroutines #
###############


### Scanning ######################################################3
scan_sectors:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    mul $a0, $a0, 4

sectors_scanning:
    
    beq $t0, 64, scans_done
    

    la $t1, sectors
    sw $t0, SCAN_SECTOR    #store t0 [0,63] to SCAN_SECTOR I/O
    sw $t1, SCAN_REQUEST

#
# Start scanning sectors
#

scanning: 

    lw $t9, SCAN_COMP
    beq $t9, 1, one_scan_done
    j scanning
one_scan_done:
    
    li $t9, 0           #
    sw $t9, SCAN_COMP      #set SCAN_COMP to 0

    addi $t0, $t0, 1 
    j sectors_scanning
    
scans_done:

    #store the sector address with the greatest number of dust in t0
    li $t0, 0           #offset start at 0
    la $t1, sectors
    move $t2, $t1       #save sector[0] address
    lw $t4, 0($t2)      #load number of dust at sector[0]

find_densest_sector:
    beq $t0, 256, found_dense_sector   #when offset at end of array, end loop
    add $t3, $t1, $t0   #add offset to sector address
    lw $t5, 0($t3)      #load number of dust at sector[t0]
    ble $t5, $t4, not_more_dust

more_dust:
    move $t4, $t5       #set $t4 to $t5
    move $t2, $t0      #set $t2 to $t0
not_more_dust:
    
    addi $t0, $t0, 4
    
    #skip $a0 sector
    bne $t0, $a0, reg_scan
    addi $t0, $t0, 4
reg_scan:

    j find_densest_sector

found_dense_sector:     #t4 has number of particles in densest sector
                        #t2 has sector number of densest sector times 4
    li $t0, 4
    div $t2, $t0 
    mflo $t2            #t2 has sector number of densest sector

    move $v0, $t2

    lw $ra, 0($sp)
    add $sp, $sp, 4
    
    jr $ra

###END SCANNING ##################################################

### DRIVE TO SECTOR AT $A0 #######################################
drive_to_sect:         
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    move $t0, $a0       #t0 has sector numebr of densest sector
    li $t1, 8
    div $t0, $t1
    mflo $t2            #sector y numb
    mfhi $t1            #sector x numb

    mul $t1, $t1, 37
    addi $t1, $t1, 15
    mul $t2, $t2, 37
    addi $t2, $t2, 15
    

    li $t3, 10
    sw $t3, VELOCITY
    lw $t3, BOT_X
    blt $t1, $t3, bot_on_right

bot_on_left:
    li $t3, 0
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_x_to_sec

bot_on_right:
    li $t3, 180
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_x_to_sec

adj_x_to_sec:
    lw $t3, BOT_X
    beq $t3, $t1, at_sector_x

    j adj_x_to_sec
    

at_sector_x: 

    lw $t3, BOT_Y
    blt $t3, $t2, bot_is_below
    
bot_is_above:
    li $t3, 270
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_y_to_sec

bot_is_below:
    li $t3, 90
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_y_to_sec

adj_y_to_sec:
    lw $t3, BOT_Y
    beq $t3, $t2, at_sector_y

    j adj_y_to_sec
    

at_sector_y: 

    move $v0, $t0
    lw $ra, 0($sp)
    add $sp, $sp, 4

    jr $ra


### END DRIVE TO SECTOR AT $A0 ###################################


### DRIVE TO YOUR PLANET #########################################
drive_to_planet:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

align_x_to_plan:
    
    lw $t3, BOT_X
    lw $t4, BOT_Y
    la $t0, planet_info
    sw $t0, PLANETS_REQUEST

    lw $t1, 0($t0)
    lw $t2, 4($t0)

    #If bot is within 3 x-spaces to planet, good enough
    sub $t5, $t3, $t1
    abs $t5, $t5
    bgt $t5, 2, xy_not_eq 

    #If bot is within 3 y-spaces to planet, good enough
    sub $t5, $t4, $t2
    abs $t5, $t5
    bgt $t5, 2, xy_not_eq 
    
    #bne $t3, $t1, xy_not_eq
    #bne $t4, $t2, xy_not_eq
    j at_plan_xy

xy_not_eq:
    blt $t1, $t3, bot_on_right_plan

bot_on_left_plan:
    li $t3, 0
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_x_to_plan

bot_on_right_plan:
    li $t3, 180
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL
    j adj_x_to_plan

adj_x_to_plan:
    lw $t3, BOT_X

    #beq $t3, $t1, at_plan_x
    #If bot is within 3 x-spaces to planet, good enough
    sub $t5, $t3, $t1
    abs $t5, $t5
    ble $t5, 3, at_plan_x

    j align_x_to_plan
    

at_plan_x: 

#briefly increase field strength so that dust isn't lost during a turn

    #li $t3, 10
    #sw $t3, FIELD_STRENGTH

    #reduce field strength again
    #li $t3, 6
    #sw $t3, FIELD_STRENGTH

align_plan_y:
    lw $t3, BOT_Y
    la $t0, planet_info
    sw $t0, PLANETS_REQUEST

    lw $t2, 4($t0)
    blt $t3, $t2, bot_is_below_plan
    
bot_is_above_plan:
    li $t3, 270
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL


    j adj_y_to_plan

bot_is_below_plan:
    li $t3, 90
    sw $t3, ANGLE
    li $t3, 1
    sw $t3, ANGLE_CONTROL


    j adj_y_to_plan

adj_y_to_plan:

    
    lw $t3, BOT_Y
    #beq $t3, $t2, align_x_to_plan
    #If bot is within 3 y-spaces to planet, good enough
    sub $t5, $t3, $t2
    abs $t5, $t5
    ble $t5, 3, align_x_to_plan

    j align_plan_y
    

at_plan_xy: 

    # calculate sector number and return that
    lw $t0, BOT_X
    lw $t1, BOT_Y
    
    li $t4, 37

    div $t0, $t4
    mflo $t2          #$t2 has sector number in x direction

    div $t1, $t4
    mflo $t3          #$t3 has sector number in y direction
    
    mul $v0, $t3, 8
    add $v0, $v0, $t2

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra
    

### END DRIVE TO YOUR PLANET #####################################


###PUZZLE SOLVER#################################################


puzzle_solver:
    sub $sp, $sp, 16
    sw $s7, 4($sp)
    sw $ra, 0($sp)
    la $s7, lexicon_struct
    sw $s7, SPIMBOT_LEXICON_REQUEST
    
    sw $s6, 8($sp)
    la $s6, puzzle_struct
    sw $s6, SPIMBOT_PUZZLE_REQUEST

    sw $s5, 12($sp)
    la $s5, solution_struct
   

    la $t0, 4($s7)    #lexicon array of char pointers
    lw $t1, 0($s7)    #lexicon_size int
    move $a0, $t0
    move $a1, $t1

    jal find_words
    lw     $t0, offset
    div    $t0, $t0, 2
    la     $t1, solution_struct
    sw     $t0, 0($t1)
    sw     $t1, SPIMBOT_SOLVE_REQUEST

    lw $ra, 0($sp)
    lw $s7, 4($sp)
    lw $s6, 8($sp)
    lw $s5, 12($sp)
    add $sp, $sp, 16
    jr $ra


find_words:
    sub $sp, $sp, 40
    sw  $ra, 0($sp)
    sw  $s0, 4($sp)
    sw  $s1, 8($sp)
    sw  $s2, 12($sp)
    sw  $s3, 16($sp)
    sw  $s4, 20($sp)
    sw  $s5, 24($sp)
    sw  $s6, 28($sp)
    sw  $s7, 32($sp)
    sw  $s8, 36($sp)

    move    $s0, $a0        # dictionary
    move    $s1, $a1        # dictionary_size
    lw  $s2, num_columns
    li  $s3, 0          # i = 0

fw_i:
    lw  $t0, num_rows
    bge $s3, $t0, fw_done   # !(i < num_rows)
    li  $s4, 0          # j = 0

fw_j:
    bge $s4, $s2, fw_i_next # !(j < num_columns)
    mul $t0, $s3, $s2       # i * num_columns
    add $s5, $t0, $s4       # start = i * num_columns + j
    add $t0, $t0, $s2       # equivalent to (i + 1) * num_columns
    sub $s6, $t0, 1     # end = (i + 1) * num_columns - 1
    li  $s7, 0          # k = 0

fw_k:
    bge $s7, $s1, fw_j_next # !(k < dictionary_size)
    mul $t0, $s7, 4     # k * 4
    add $t0, $s0, $t0       # &dictionary[k]
    lw  $s8, 0($t0)     # word = dictionary[k]

    move    $a0, $s8        # word
    move    $a1, $s5        # start
    move    $a2, $s6        # end
    jal horiz_strncmp
    ble $v0, 0, fw_vert     # !(word_end > 0)
    move    $a0, $s8        # word
    move   $a1, $s5        # start
    move   $a2, $v0        # word_end
    jal record_word
    

fw_vert:
    move    $a0, $s8        # word
    move    $a1, $s3        # i
    move    $a2, $s4        # j
    jal vert_strncmp
    ble $v0, 0, fw_k_next   # !(word_end > 0)
    move    $a0, $s8        # word
    move   $a1, $s5        # start
    move   $a2, $v0        # word_end
    jal record_word

fw_k_next:
    add $s7, $s7, 1     # k++
    j   fw_k

fw_j_next:
    add $s4, $s4, 1     # j++
    j   fw_j

fw_i_next:
    add $s3, $s3, 1     # i++
    j   fw_i

fw_done:
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    lw  $s3, 16($sp)
    lw  $s4, 20($sp)
    lw  $s5, 24($sp)
    lw  $s6, 28($sp)
    lw  $s7, 32($sp)
    lw  $s8, 36($sp)
    add $sp, $sp, 40
    jr  $ra


#record_word
.globl record_word
record_word:
    la  $t0, solution_struct
    add $t4, $t0, 4
    lw  $t1, offset
    mul $t3, $t1, 4
    add $t2, $t4, $t3
    sw  $a1, 0($t2)
    sw  $a2, 4($t2)

    add $t1, $t1, 2
    sw  $t1, offset
    jr  $ra

#get character
get_character:
    lw  $t0, num_columns
    mul $t0, $a0, $t0       # i * num_columns
    add $t0, $t0, $a1       # i * num_columns + j
    lw  $t1, puzzle
    add $t1, $t1, $t0       # &puzzle[i * num_columns + j]
    lbu $v0, 0($t1)     # puzzle[i * num_columns + j]
    jr  $ra

#horiz_strncmp
.globl horiz_strncmp
horiz_strncmp:
    li  $t0, 0          # word_iter = 0
    lw  $t1, puzzle

hs_while:
    bgt $a1, $a2, hs_end    # !(start <= end)

    add $t2, $t1, $a1       # &puzzle[start]
    lbu $t2, 0($t2)     # puzzle[start]
    add $t3, $a0, $t0       # &word[word_iter]
    lbu $t4, 0($t3)     # word[word_iter]
    beq $t2, $t4, hs_same   # !(puzzle[start] != word[word_iter])
    li  $v0, 0          # return 0
    jr  $ra

hs_same:
    lbu $t4, 1($t3)     # word[word_iter + 1]
    bne $t4, 0, hs_next     # !(word[word_iter + 1] == '\0')
    move    $v0, $a1        # return start
    jr  $ra

hs_next:
    add $a1, $a1, 1     # start++
    add $t0, $t0, 1     # word_iter++
    j   hs_while

hs_end:
    li  $v0, 0          # return 0
    jr  $ra

#vertical
.globl vert_strncmp
vert_strncmp:
    
    sub  $sp, $sp, 32
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)
    sw   $s6, 28($sp)
      
    li   $s0, 0  # word_iter $s0
    
    move $s1, $a0  #word
    move $s2, $a1  #start_i
    move $s3, $a2  # j
    lw   $s4, num_rows
    move $s5, $s2  # i
    lw   $s6, num_columns
    
loop:
    bge  $s5, $s4, loop_done
    move $a0, $s5   #i
    move $a1, $s3   #j
    jal get_character   # character in now in v0
    #lw   $ra, 0($sp)
    move $t0, $v0    #result get_character
    add  $t1, $s1, $s0  #offset
    lb   $t2, 0($t1)    #word
    beq  $t0, $t2, part2
    li   $v0, 0
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    lw  $s3, 16($sp)
    lw  $s4, 20($sp)
    lw  $s5, 24($sp)
    lw  $s6, 28($sp)
    add $sp, $sp, 32
    jr   $ra
    
part2:
    add  $t1, $t1, 1
    lb   $t2, 0($t1)
    bne  $t2, $0, part3
    mul  $t3, $s5, $s6
    add  $t3, $t3, $s3
    move $v0, $t3
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    lw  $s3, 16($sp)
    lw  $s4, 20($sp)
    lw  $s5, 24($sp)
    lw  $s6, 28($sp)
    add $sp, $sp, 32
    jr   $ra
    
part3:
    add  $s5, $s5, 1
    add  $s0, $s0, 1
    j  loop
    
    

    
loop_done: li  $v0, 0
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    lw  $s3, 16($sp)
    lw  $s4, 20($sp)
    lw  $s5, 24($sp)
    lw  $s6, 28($sp)
    add $sp, $sp, 32
    jr  $ra

###END PUZZLE SOLVER##############################################
