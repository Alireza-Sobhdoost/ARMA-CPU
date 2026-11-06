; Every instruction once (based on the 16-instruction program used to test the
; single-cycle CPU), followed by the examples from the README.
ADDI R1, 10
ADDI R2, 3
ADD R3, R1, R2
SUB R4, R1, R2
MOV R5, R3
NOT R6
SHL R7, R2
SHR R8, R1
OR R9, R1, R2
ST [R2, 2]
ADDI R1, 1
LD [R2, 2]
ADD-ST [5], R3     ; Mem[5] = 10 + 13 = 23
LD [R0, 5]         ; read it back: R1 = 23
BZ R0, 2
ADDI R10, 99
ADDI R11, 7
MOV R1, 10
MOV R2, 4
ADD R3, R1, R2
MOV R1, 15
ST [R0, 5]
MOV R1, 0
LD [R0, 5]
