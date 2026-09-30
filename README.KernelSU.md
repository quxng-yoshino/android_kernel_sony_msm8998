# KernelSU-Next on Sony MSM8998 (yoshino)

This branch (`lineage-23.2-ksu`) adds [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
to the LineageOS 23.2 kernel for the Sony MSM8998 "yoshino" family
(Xperia XZ1 `poplar`, XZ1 Compact `lilac`, XZ Premium `maple`).

## What is integrated

| Item | Value |
| --- | --- |
| KernelSU-Next tree | `KernelSU-Next/` submodule, branch `legacy`, tag `v3.4.0-legacy` (`8af3d4f`) |
| Hook mode | **Manual hook** (`CONFIG_KSU_MANUAL_HOOK=y`) |
| Kernel tree | Linux 4.4.302 (CAF `msm-4.4`), `ARCH=arm64` |

`legacy` is used because this kernel is 4.4:

* `CONFIG_KSU_KPROBES_HOOK` is documented as "should not be used on kernels below 5.10".
* `CONFIG_KSU_SYSCALL_TABLE_HOOK` requires kernel >= 4.17.

Manual hook mode has no runtime dependency on kprobes, which this defconfig
does not enable (`# CONFIG_KPROBES is not set`).

## Kernel-side changes

### Config

`arch/arm64/configs/sony/yoshino.config` gains:

```
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
```

### Kbuild wiring

* `drivers/Kconfig` sources `drivers/kernelsu/Kconfig`.
* `drivers/Makefile` builds `drivers/kernelsu/`.
* `drivers/kernelsu` is a **symlink** to `../KernelSU-Next/kernel`, so the
  KernelSU sources are built as part of the kernel while still living in the
  submodule.

### Manual hook call sites

Manual hook mode requires the kernel to call into KernelSU at six points.
Each is guarded by `#ifdef CONFIG_KSU` and is a no-op until KernelSU installs
its handlers:

| File | Function | KernelSU entry point |
| --- | --- | --- |
| `fs/exec.c` | `do_execveat_common()` | `ksu_handle_execveat` / `ksu_handle_execveat_sucompat` |
| `fs/open.c` | `SYSCALL_DEFINE3(faccessat)` | `ksu_handle_faccessat` |
| `fs/stat.c` | `vfs_fstatat()` | `ksu_handle_stat` |
| `fs/read_write.c` | `vfs_read()` | `ksu_handle_vfs_read` |
| `kernel/reboot.c` | `SYSCALL_DEFINE4(reboot)` | `ksu_handle_sys_reboot` |
| `drivers/input/input.c` | `input_handle_event()` | `ksu_handle_input_handle_event` |

### Backports

KernelSU-Next normally applies these itself from its `Kbuild` via
`$(shell sed -i ...)`. That runs while `drivers/` is being parsed, i.e. *after*
`fs/` has already been compiled, which is too late for `fs/namespace.c`.
They are therefore pre-applied here:

* `fs/namespace.c`, `fs/internal.h` — `path_umount()` / `can_umount()`.
* `include/linux/seccomp.h` — `filter_count` on `struct seccomp`.
* `security/selinux/*`, `security/selinux/include/objsec.h` — `selinux_inode()`
  / `selinux_cred()` accessors used by KernelSU's SELinux helpers. Semantically
  neutral rewrites.

### Linux 4.4 compatibility

KernelSU-Next's oldest supported target is well past 4.4, so it uses a number of
interfaces that did not exist yet. All of that compatibility lives in this tree,
not in the submodule: the submodule is pinned to the upstream tag, so the
gitlink points at a commit anyone can fetch. Editing KernelSU sources here would
make `git clone --recursive` fail with "not our ref".

`include/linux/sched/signal.h` and the other headers below are *new files*.
Their paths only came into existence in the versions noted, so on 4.4 a
`#include <linux/sched/signal.h>` previously either resolved through the
`-I include/uapi` search path or failed outright. Each new header includes what
the KernelSU source actually wants from it.

| New header | Arrived upstream | Provides |
| --- | --- | --- |
| `include/linux/sched/signal.h` | 4.11 | `<linux/sched.h>` |
| `include/linux/sched/task.h` | 4.11 | `<linux/sched.h>` |
| `include/linux/sched/task_stack.h` | 4.11 | `<linux/sched.h>` |
| `include/linux/sched/types.h` | 4.11 | `<linux/sched.h>` |
| `include/linux/sched/user.h` | 4.11 | `<linux/sched.h>` |
| `include/uapi/linux/sched/types.h` | 4.13 | `struct sched_param` |
| `include/linux/compiler_types.h` | 4.19 | `<linux/compiler.h>` |
| `include/linux/pgtable.h` | 4.20 | `<asm/pgtable.h>` |
| `include/uapi/linux/mount.h` | 5.x | `MS_*` flags |

Three existing headers gained a small addition:

* `include/linux/kernel.h` — `ALIGN_DOWN()` (4.5 upstream).
* `include/linux/compiler.h` — `__nocfi` (4.19 upstream; a no-op, 4.4 has no CFI).
* `include/linux/dcache.h` — `full_name_hash()` dispatches on argument count, so
  both the 4.4 two-argument form and the post-5.2
  `full_name_hash(namespace, name, len)` are accepted. `fs/namei.c` `#undef`s it
  before defining the real two-argument function and its `EXPORT_SYMBOL`.

`include/linux/limits.h` is a new file that exists for one reason: it is the only
header `manager/apk_sign.c` includes that 4.4 does not define, and that file is
the one KernelSU source which calls `kvmalloc()` without including
`compat/kernel_compat.h`. The shim supplies `kvmalloc()` there, guarded by
`#ifdef KSU_VERSION` — a flag KernelSU's own `Kbuild` sets for its objects and
nowhere else — and is otherwise byte-identical to the uapi header that
`<linux/limits.h>` used to resolve to.

## Building

Requirements (Debian/Ubuntu):

```
sudo apt install clang lld llvm libssl-dev gcc-arm-linux-gnueabi zip
```

`gcc-arm-linux-gnueabi` is only needed so the 32-bit compat vDSO
(`CONFIG_COMPAT_VDSO=y`) has a non-empty `CROSS_COMPILE_ARM32`; clang does the
actual compiling.

Then:

```
./build.sh
```

`build.sh` merges `msmcortex-perf_defconfig` with the `sony/yoshino.config`
fragment (the same way the LineageOS build does), asserts `CONFIG_KSU=y`,
builds `Image.gz-dtb` with `LLVM=1`, copies it into `anykernel/`, and produces

```
Yoshino-KernelSU-Next-<YYYYMMDD>.zip
```

next to the output directory (`OUT`, default `./out`).

## Flashing

The zip is an [AnyKernel3](https://github.com/osm0sis/AnyKernel3) package.
Flash it from a custom recovery over an existing yoshino boot image; it patches
the kernel in place and keeps the ROM's ramdisk.

```
do.devicecheck=1   # lilac / maple / poplar
do.modules=0       # kernel image only
```

`do.modules=0` because `CONFIG_MODULE_SIG_FORCE` is not set, so the modules
already shipped in the ROM still load against this kernel. No `vendor_boot`
or ramdisk patching is required for yoshino.

After flashing, install the [KernelSU-Next manager
app](https://github.com/KernelSU-Next/KernelSU-Next/releases) to grant root.
