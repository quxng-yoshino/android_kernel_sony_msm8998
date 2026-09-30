#ifndef __KSU_COMPAT_INCLUDE_UAPI_LINUX_SCHED_TYPES_H
#define __KSU_COMPAT_INCLUDE_UAPI_LINUX_SCHED_TYPES_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * <uapi/linux/sched/types.h> only exists from 4.13 onwards; on 4.4
 * struct sched_param is still declared in <linux/sched.h>.
 */
#include <linux/sched.h>
#endif
