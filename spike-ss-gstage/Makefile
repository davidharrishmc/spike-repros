ISA = rv64gch_zicfiss_zimop_zaamo_svpbmt

ss_gstage.elf: ss_gstage.S link.ld
	riscv64-unknown-elf-gcc -march=rv64gch_zicfiss_zimop -mabi=lp64 -nostdlib -nostartfiles -T link.ld -o $@ ss_gstage.S

run: ss_gstage.elf
	spike --isa=$(ISA) ss_gstage.elf; echo "exit code $$?"

clean:
	rm -f ss_gstage.elf
