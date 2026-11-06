; ADD-ST [ADDR], RX : Mem[ADDR] <- Mem[ADDR] + RX   (ADDR in hex)
; The pipeline runs it as 3 micro-ops with a hidden register T:
; LD T <- Mem[ADDR] ; ADD T <- T + RX ; ST Mem[ADDR] <- T
MOV R2, 5
ADD-ST [3], R2     ; Mem[3] = 0 + 5 = 5        RX computed just before
ADD-ST [3], R2     ; Mem[3] = 10               back-to-back on the same address
LD [R0, 3]         ; R1 = 10                   load right after ADD-ST's store
ADD-ST [3], R1     ; Mem[3] = 20               RX loaded just before
MOV R1, 7
ST [R0, 4]         ; Mem[4] = 7
ADD-ST [4], R1     ; Mem[4] = 14               store, then ADD-ST on that address
ADD-ST [3], R1     ; Mem[3] = 27
LD [R0, 4]         ; R1 = 14
ADD R3, R1, R1     ; R3 = 28                   normal instructions continue after
MOV R4, -1
ADD-ST [4], R4     ; Mem[4] = 13               negative RX
MOV R5, 3
ADD-ST [6], R5     ; loop body: Mem[6] += R5   (3 + 2 + 1 = 6)
ADDI R5, -1
BNZ R5, -2         ; taken twice, back to the ADD-ST
LD [R0, 6]         ; R1 = 6
BR 2               ; taken
ADD-ST [6], R5     ; flushed: fetched after a taken branch, must not run
ADD-ST [F], R1     ; Mem[15] = 6               ADD-ST at a branch target
BZ R0, 1           ; branch right after ADD-ST (jumps to the next instruction)
LD [R0, F]         ; R1 = 6
ADD-ST [7], R1     ; Mem[7] = 6
ADD-ST [7], R1     ; Mem[7] = 12
LD [R0, 7]         ; R1 = 12
