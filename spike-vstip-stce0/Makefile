ISA = rv64gch_sstc

vstip.elf: vstip.S link.ld
	riscv64-unknown-elf-gcc -march=rv64g -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o $@ vstip.S

run: vstip.elf
	spike --isa=$(ISA) vstip.elf; echo "exit code $$?"

clean:
	rm -f vstip.elf
