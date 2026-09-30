#ifndef __KSU_COMPAT_INCLUDE_LINUX_COMPILER_TYPES_H
#define __KSU_COMPAT_INCLUDE_LINUX_COMPILER_TYPES_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * <linux/compiler_types.h> only exists from 4.19 onwards; on 4.4 the compiler
 * attributes it holds still live in <linux/compiler.h>.
 */
#include <linux/compiler.h>
#endif
