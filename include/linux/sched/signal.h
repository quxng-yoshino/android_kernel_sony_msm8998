#ifndef __KSU_COMPAT_INCLUDE_LINUX_SCHED_SIGNAL_H
#define __KSU_COMPAT_INCLUDE_LINUX_SCHED_SIGNAL_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * KernelSU-Next assumes the post-4.11 split-up of <linux/sched.h> (and a few
 * other headers). This tree predates all of them. Each shim just forwards to
 * the 4.4 header that still holds the declarations.
 */
#include <linux/sched.h>
#endif
