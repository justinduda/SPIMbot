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
SPIMBOT_PUZZLE_REQUEST 		= 0xffff1000 
SPIMBOT_SOLVE_REQUEST 		= 0xffff1004 
SPIMBOT_LEXICON_REQUEST 	= 0xffff1008 

# I/O used in competitive scenario 
INTERFERENCE_MASK 	= 0x8000 
INTERFERENCE_ACK 	= 0xffff1304 8 
SPACESHIP_FIELD_CNT  	= 0xffff110c 

.text

main:
game_start_subroutine:

find_largest_cluster_strategy:

strategy_B:

strategy_C:

scan_subroutine:

move_to_location_subroutine:

game_over:
	#clean up local vars
	jr	$ra