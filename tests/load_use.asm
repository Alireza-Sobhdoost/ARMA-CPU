; LD followed right away by an instruction that needs R1 (1-cycle stall),
; and ST of a value that was computed just before (store-data forwarding).
MOV R1, 7
ST [R0, 3]         ; R1 = 7 must be forwarded into the store
MOV R1, 0
LD [R0, 3]         ; R1 <- 7
ADD R2, R1, R1     ; load-use: needs R1 from the LD
MOV R1, 0          ; so a stale R1 in the next ST would store 0, not 7
LD [R0, 3]
ST [R0, 4]         ; load then store of R1
LD [R0, 4]
BNZ R1, 2          ; load then branch on R1
ADDI R3, 99        ; skipped
ADDI R4, 1
MOV R1, 2
LD [R1, 1]         ; base register R1 computed just before -> Mem[3] = 7
LD [R1, 0]         ; base register R1 loaded just before (load-use) -> Mem[7]
ADDI R1, 9
ST [R2, 1]         ; Mem[15] <- R1, both from recent instructions
LD [R0, F]
ADD R5, R1, R2
