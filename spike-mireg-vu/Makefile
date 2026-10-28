ISA = rv64gch_smstateen_smcsrind_sscsrind

mireg.elf: mireg.S link.ld
	riscv64-unknown-elf-gcc -march=rv64g -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o $@ mireg.S

run: mireg.elf
	spike --isa=$(ISA) mireg.elf; echo "exit code $$?"

clean:
	rm -f mireg.elf
