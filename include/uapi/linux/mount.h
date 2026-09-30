#ifndef __KSU_COMPAT_INCLUDE_UAPI_LINUX_MOUNT_H
#define __KSU_COMPAT_INCLUDE_UAPI_LINUX_MOUNT_H
/*
 * Linux 4.4 compat shim for KernelSU-Next.
 *
 * On 4.4 the MS_* mount flags are still in <uapi/linux/fs.h>, which is where
 * infra/su_mount_ns.c -- the only user of <uapi/linux/mount.h> -- reads them.
 */
#include <uapi/linux/fs.h>
#endif
