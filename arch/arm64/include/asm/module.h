/*
 * Copyright (C) 2012 ARM Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef __ASM_MODULE_H
#define __ASM_MODULE_H

#include <asm-generic/module.h>
#include <asm/memory.h>

#define MODULE_ARCH_VERMAGIC	"aarch64"

#ifdef CONFIG_ARM64_MODULE_PLTS
struct mod_arch_specific {
	struct elf64_shdr	*plt;
	int			plt_num_entries;
	int			plt_max_entries;
};
#endif

u64 module_emit_plt_entry(struct module *mod, const Elf64_Rela *rela,
			  Elf64_Sym *sym);

#ifdef CONFIG_RANDOMIZE_BASE
/*
 * ARCH_RELOCATES_KCRCTAB was deliberately removed here — this is upstream commit
 * 3b3c6c24de7f ("arm64/module: revert to unsigned interpretation of ABS16/32
 * relocations")'s companion revert of 9c0e83c371cf, which this tree had
 * backported.
 *
 * With it defined, maybe_relocated() in kernel/module.c subtracts reloc_start
 * from the kernel's __kcrctab entry before comparing it against the module's
 * recorded CRC. But __kcrctab is never relocated at boot: __crc_<sym> is an
 * ABSOLUTE symbol, so no R_AARCH64_RELATIVE is emitted for it. The comparison is
 * therefore module_crc == link_crc - kaslr_slide, which cannot hold for any
 * module, and MODVERSIONS is simply broken whenever CONFIG_RANDOMIZE_BASE is on.
 *
 * The symptom is `insmod: Exec format error` with "disagrees about version of
 * symbol module_layout" in dmesg — for EVERY module, including the vendor's own
 * tcp_bic.ko, which is why /vendor/lib/modules shipped modules nothing could
 * load. It bit the NFC driver selection, which needs pn553.ko and
 * sony_carillon_nfc.ko to be loadable.
 *
 * reloc_start had no other user on arm64 (kernel/module.c:1283 was the only one),
 * so dropping the definition simply restores the honest comparison.
 */
extern u64 module_alloc_base;
#else
#define module_alloc_base	((u64)_etext - MODULES_VSIZE)
#endif

#endif /* __ASM_MODULE_H */
