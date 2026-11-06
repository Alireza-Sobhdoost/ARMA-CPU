; Back-to-back dependencies: every instruction uses the result of the one
; (or two) before it, so the values must come from forwarding.
MOV R1, 5          ; XOR R1,R1,R1 then ADDI R1,5 (ADDI needs the XOR result)
ADD R2, R1, R1     ; R1 from EX/MEM
ADD R3, R2, R1     ; R2 from EX/MEM, R1 from MEM/WB
SUB R4, R3, R2
XOR R5, R4, R3
OR R6, R5, R4
AND R7, R6, R5
NOT R8, R7
SHL R9, R8
SHR R10, R9
ADDI R10, 1
ADDI R10, 1
MOV R11, R10
ADD R12, R11, R11
ADD-ST [1], R12    ; RX computed just before (forwarded into the ADD micro-op)
SUB R13, R12, R12  ; result 0
ADD R14, R13, R2   ; two-instruction-old value through the WB bypass
