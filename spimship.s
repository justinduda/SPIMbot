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

puzzle_struct: .space 4104
lexicon_struct: .space 4096
.text

main:
    # la $t0, puzzle_struct
    # sw $t0, SPIMBOT_PUZZLE_REQUEST   
    # lw $t1, 0($t0)
    # lw $t2, 4($t0)
    # lw $t3, 8($t0)
    
    sub $sp, $sp, 8
    sw $s7, 4($sp)
    la $s7, lexicon_struct
    sw $s7, SPIMBOT_LEXICON_REQUEST
    lw $a0, 4($s7)
    lw $a1, 0($s7)
    sw $ra, 0($sp)
    jal build_trie
    
    lw $ra, 0($sp)
    lw $s7, 4($sp)
    add $sp, $sp, 8


game_over:
    #clean up local vars
    jr  $ra



build_trie:
    sub $sp, $sp, 16
    sw  $ra, 0($sp)
    sw  $s0, 4($sp)
    sw  $s1, 8($sp)
    sw  $s2, 12($sp)
    move    $s0, $a0        # wordlist

    mul $t0, $a1, 4     # num_words * 4
    add $s1, $s0, $t0       # &wordlist[num_words]
    jal alloc_trie
    move    $s2, $v0        # root

bt_loop:
    beq $s0, $s1, bt_done   # loop till end of array
    move    $a0, $s2        # root
    lw  $a1, 0($s0)     # wordlist[i]
    li  $a2, 0
    jal add_word_to_trie
    add $s0, $s0, 4     # next word
    j   bt_loop

bt_done:
    move    $v0, $s2        # root
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    add $sp, $sp, 16
    jr  $ra

alloc_trie:
    li  $v0, 9
    li  $a0, 108        # sizeof(trie_t)
    syscall             # $v0 = ret_val

    sw  $zero, 0($v0)   # ret_val->word = NULL
    li  $t0, 0          # i = 0

at_loop:
    mul $t1, $t0, 4         # i * 4
    add $t1, $v0, $t1       # &ret_val->next[i] - 4
    sw  $zero, 4($t1)       # ret_val->next[i] = NULL
    add $t0, $t0, 1         # i ++
    blt $t0, 26, at_loop    # i < 26

    jr  $ra




add_word_to_trie:
    sub  $sp, $sp, 16
    sw   $ra, 12($sp)
function:
    sw   $a2, 4($sp)
    sw   $a1, 8($sp)
    add  $t0, $a1, $a2          #address index
    lb   $t1, 0($t0)            #$t1 is c
    bne  $t1, 0, part2
    sw   $a1, 0($a0)            #store word to trie
    
    lw   $ra, 12($sp)
    add  $sp, $sp, 16
    jr   $ra
    
part2:
    sub  $t2, $t1, 'A'
    mul  $t2, $t2, 4  
    add  $t2, $t2, 4  
    add  $t2, $t2, $a0         #next[c-'A'] address
    sw   $t2, 0($sp)            #store the address
    lw   $t3, 0($t2)           #trie->next[c - 'A']
    
    bne  $t3, 0, part3
    jal  alloc_trie
    lw   $t2, 0($sp)    #get the address next[c-'A']
    sw   $v0, 0($t2)
    
part3:
    lw   $t4, 4($sp)
    move $a2, $t4
    add  $a2, $a2, 1
    lw   $t2, 0($sp)
    lw   $a0, 0($t2)     #reset $a0 to next[c-'A'] address
    lw   $a1, 8($sp)
    jal    function
    
