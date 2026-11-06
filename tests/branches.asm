; Taken and not-taken branches. Instructions after a taken branch were
; already fetched and must be flushed (never write anything).
MOV R2, 3
ADDI R2, -1        ; loop body
BNZ R2, -1         ; taken twice, then falls through
BZ R2, 2           ; R2 = 0 -> taken
ADDI R5, 50        ; flushed
ADDI R6, 1
BR 2               ; always taken
ADDI R7, 50        ; flushed
BZ R6, 2           ; R6 = 1 -> not taken
ADDI R8, 1
ADDI R2, 5
BNZ R2, 3          ; branch on the value computed just before
ADDI R9, 50        ; flushed
ADDI R9, 50        ; flushed
ADDI R10, 1
BR 1               ; jump to the next instruction (no-op branch)
ADDI R11, 1
BZ R0, 2           ; taken
BR -20             ; flushed (would jump backwards)
ADDI R12, 1
