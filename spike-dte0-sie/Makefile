SPIKE ?= spike
run: spike_dte0_sie.elf
	-$(SPIKE) --isa=rv64gch_smdbltrp_ssdbltrp spike_dte0_sie.elf
spike_dte0_sie.elf: spike_dte0_sie.S exit.h link.ld
	riscv64-unknown-elf-gcc -nostdlib -nostartfiles -T link.ld -I. -march=rv64gc_zicsr -mabi=lp64 $< -o $@
clean:
	rm -f *.elf
