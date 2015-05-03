# syscall constants
PRINT_STRING = 4

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
SPIMBOT_PUZZLE_REQUEST 		= 0xffff1000 
SPIMBOT_SOLVE_REQUEST 		= 0xffff1004 
SPIMBOT_LEXICON_REQUEST 	= 0xffff1008 

# I/O used in competitive scenario 
INTERFERENCE_MASK 	= 0x8000 
INTERFERENCE_ACK 	= 0xffff1304
SPACESHIP_FIELD_CNT = 0xffff110c 

.data
.align 2

sectors:	.space 256
SCAN_COMP:	.space 4
planet_info:.space 32

#
#end I/O names/fields
#

#
#start interrupt handlers
#

.kdata					# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers


non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180

interrupt_handler:
.set noat
	move	$k1, $at		# Save $at

.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     
    sw  $v0, 8($k0)

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, ENERGY_MASK	# is there a timer interrupt?
	bne	$a0, 0, energy_interrupt
    
    and $a0, $k0, SCAN_MASK     # scan interrupt?
    bne $a0, 0, scan_interrupt

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

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

non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
    lw  $v0, 8($k0)
.set noat
	move	$at, $k1		# Restore $at
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

enable_interrupts:
	#li	$t4, TIMER_MASK		# timer interrupt enable bit
    li 	$t4	SCAN_MASK  		# scan interrupt bit
    or  $t4	$t4	ENERGY_MASK
	or	$t4	$t4	1			# global interrupt enable
	mtc0	$t4	$12			# set interrupt mask (Status register)

game_start_subroutine:
	# enable interrupts

start_over:
    li $t0, 0
    sw $t0, SCAN_COMP

    li $t0, 0
    sw $t0, VELOCITY

#time_check:
#	# request timer interrupt
#	lw	$t0, TIMER		# read current time
#	add	$t0, $t0, 50		# add 50 to current time
#	sw	$t0, TIMER		# request timer interrupt in 50 cycles
#
#	#li	$a0, 10
#	#sw	$a0, VELOCITY		# drive
    li $t0, 0             #set t0 to 0

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
    j find_densest_sector

found_dense_sector:     #t4 has number of particles in densest sector
                        #t2 has sector number of densest sector times 4
    li $t0, 4
    div $t2, $t0 
    mflo $t2            #t2 has sector number of densest sector

#
# end scanning sectors
# $t2 has sector number of densest sector (out of 64)
#



# compute desired coords
# go to correct x , then correct y
#
drive_to_sect:         
    move $t0, $t2       #t0 has sector numebr of densest sector
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

#
# Bot reached ~middle of sector with the most amount of dust
#

	#max field strength very quickly to pull dust to ship
    li $t3, 10
    sw $t3, FIELD_STRENGTH 

	#lower field strength to conserve energy
    li $t3, 6
    sw $t3, FIELD_STRENGTH


#
# Go to your planet
#

    li $t3, 3
    sw $t3, VELOCITY

align_x_to_plan:
    
    lw $t3, BOT_X
    lw $t4, BOT_Y
    la $t0, planet_info
    sw $t0, PLANETS_REQUEST

    lw $t1, 0($t0)
    lw $t2, 4($t0)
    
    bne $t3, $t1, xy_not_eq
    bne $t4, $t2, xy_not_eq
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
    beq $t3, $t1, at_plan_x

    j align_x_to_plan
    

at_plan_x: 

#briefly increase field strength so that dust isn't lost during a turn

li $t3, 10
sw $t3, FIELD_STRENGTH

	#reduce field strength again
	li $t3, 6
	sw $t3, FIELD_STRENGTH

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
    beq $t3, $t2, align_x_to_plan

    j align_plan_y
    

at_plan_xy: 

#
#returned dust to our planet
#
   
    li $t0, 0
    sw $t0, FIELD_STRENGTH
    
    j start_over


infinite: 
	j      infinite

find_largest_cluster_strategy:

strategy_B:

strategy_C:

scan_subroutine:

move_to_location_subroutine:

game_over:
	#clean up local vars
	jr	$ra
