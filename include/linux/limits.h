#ifndef __KSU_COMPAT_INCLUDE_LINUX_LIMITS_H
#define __KSU_COMPAT_INCLUDE_LINUX_LIMITS_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * <linux/limits.h> only exists from 4.5 onwards; on 4.4 an include of it falls
 * through to the uapi header via the "-I include/uapi" search path. So this shim
 * includes exactly that, and every existing user of <linux/limits.h> in the
 * kernel keeps getting precisely what it got before.
 *
 * The KernelSU part below is why the file exists at all.
 *
 * manager/apk_sign.c is the one KernelSU source file that calls kvmalloc(), and
 * it is also the one that never includes compat/kernel_compat.h -- the header
 * the other twelve files use to get kvmalloc()/kvfree() shimmed for kernels
 * older than 4.12. Nothing in its include list provides kvmalloc(), so on 4.4 it
 * does not compile.
 *
 * Rather than include compat/kernel_compat.h from here, supply the one missing
 * function directly. <linux/limits.h> is reached extremely early (every
 * translation unit that includes <linux/sched.h> pulls it in through
 * <linux/cgroup-defs.h>), and kernel_compat.h drags in the SELinux policy and
 * keyring headers, which cannot be parsed at that point. slab.h and vmalloc.h
 * are safe to include anywhere, so the function is written in terms of those and
 * nothing else. Since 4.4's kvfree() already frees either kind of pointer (see
 * mm/util.c), this pairs with it correctly.
 *
 * KSU_VERSION is defined by drivers/kernelsu/Kbuild (which is KernelSU-Next's
 * own kernel/Kbuild) for every KernelSU object and for no other object in the
 * tree, so the block is invisible to the rest of the kernel.
 *
 * The body mirrors ksu_kvmalloc() in KernelSU-Next/kernel/compat/kernel_compat.h.
 */
#include <uapi/linux/limits.h>

#ifdef KSU_VERSION
#include <linux/slab.h>
#include <linux/vmalloc.h>

static inline void *kvmalloc(size_t size, gfp_t flags)
{
	void *buf = kmalloc(size, flags | __GFP_NOWARN);

	if (!buf)
		buf = vmalloc(size);

	return buf;
}
#endif

#endif
