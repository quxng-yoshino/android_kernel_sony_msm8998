#ifndef __KSU_COMPAT_INCLUDE_LINUX_PGTABLE_H
#define __KSU_COMPAT_INCLUDE_LINUX_PGTABLE_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * <linux/pgtable.h> only exists from 4.20 onwards; on 4.4 the page table
 * definitions are still per-architecture, in <asm/pgtable.h>.
 */
#include <asm/pgtable.h>
#endif
