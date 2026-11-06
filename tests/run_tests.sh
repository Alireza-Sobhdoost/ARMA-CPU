#!/bin/bash
# Checks the pipelined CPU against the single-cycle CPU.
# Every tests/*.asm program (plus src/program.data) is run on both CPUs, and
# both must make the same register and memory writes in the same order.
# Usage: tests/run_tests.sh [program.asm ...]

cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Analyze (VHDL-2008 is needed by the comparison testbench)
for f in ALU Instruction_Memory_Unit Memory_Unit PC_Unit Register_Bank Control_Unit \
         CPU CPU_Pipeline TestBench/cpu_compare_TB; do
    ghdl -a --std=08 -fsynopsys --workdir="$WORK" "src/$f.vhd" || exit 1
done

# Runs the comparison in directory $1, which holds the program.data to use
run_compare() {
    (cd "$1" && ghdl --elab-run --std=08 -fsynopsys --workdir="$WORK" cpu_compare_tb \
        --ieee-asserts=disable-at-0 2>&1)
}

passed=0
failed=0
report() {   # name, output, exit code
    if [ "$3" -eq 0 ] && grep -q "PASS" <<< "$2"; then
        echo "PASS  $1    $(grep -o 'Register writes compared: [0-9]*' <<< "$2" | grep -o '[0-9]*$') register writes," \
             "$(grep -o 'Memory writes compared: [0-9]*' <<< "$2" | grep -o '[0-9]*$') memory writes"
        passed=$((passed + 1))
    else
        echo "FAIL  $1"
        grep -E "error|FAIL" <<< "$2" | sed 's/^.*(report error): /      /; s/^.*(assertion failure): /      /'
        failed=$((failed + 1))
    fi
}

programs=("$@")
[ ${#programs[@]} -eq 0 ] && programs=(tests/*.asm)

for asm in "${programs[@]}"; do
    dir="$WORK/$(basename "$asm" .asm)"
    mkdir -p "$dir"
    # Assemble (text after ';' is a comment)
    PYTHONDONTWRITEBYTECODE=1 python3 - "$asm" "$dir/program.data" <<'EOF' || { echo "FAIL  $asm (assembler error)"; failed=$((failed + 1)); continue; }
import sys
sys.path.insert(0, ".")
import assembler
lines = [l.split(";")[0].strip() for l in open(sys.argv[1])]
assembler.assemble([l for l in lines if l], sys.argv[2])
EOF
    out=$(run_compare "$dir")
    report "$asm" "$out" $?
done

# The program currently in src/program.data
if [ $# -eq 0 ]; then
    mkdir -p "$WORK/current" && cp src/program.data "$WORK/current/"
    out=$(run_compare "$WORK/current")
    report "src/program.data" "$out" $?
fi

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
