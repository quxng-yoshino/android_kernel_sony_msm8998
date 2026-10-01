# Concordia

Concordia is a kernel for the Sony MSM8998 "yoshino" family (Xperia XZ1
`poplar`, XZ1 Compact `lilac`, XZ Premium `maple`). It is the LineageOS 23.2
kernel with [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
added, and lives on the `lineage-23.2-ksu` branch.

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

### SELinux transition hooks

KernelSU rewrites the task's SELinux SID itself when it hands out root, but
SELinux would otherwise deny the resulting `init -> su` transition. Two checks
stand in the way:

* `security_bounded_transition()` — the new domain must be bounded by the old
  one.
* `check_nnp_nosuid()` — when the caller is under `no_new_privs` or the
  executable lives on a `nosuid` mount, only transitions to bounded domains are
  permitted.

`KernelSU-Next/kernel/selinux/selinux.c` exports `is_ksu_transition()` for
exactly this purpose. It is declared `__maybe_unused` because the kernel side is
expected to provide the call sites; without them KernelSU cannot transition into
its own domain under an enforcing policy.

Two call sites are added, each guarded by `#ifdef CONFIG_KSU`:

| File | Function |
| --- | --- |
| `security/selinux/hooks.c` | `check_nnp_nosuid()` |
| `security/selinux/ss/services.c` | `security_bounded_transition()` |

The upstream helper takes `const struct task_security_struct *` arguments, and
the `hooks.c` call site already holds both. `security_bounded_transition()` only
receives two `u32` SIDs, so it builds sid-only stand-ins; `is_ksu_transition()`
reads nothing but `->sid`. Doing it this way keeps the submodule pinned to the
upstream tag — some trees instead fork KernelSU-Next and change the helper to
take `u32` directly, at the cost of owning a fork.

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

Four existing headers gained a small addition:

* `include/linux/kernel.h` — `ALIGN_DOWN()` (4.5 upstream).
* `include/linux/compiler.h` — `__nocfi` (4.19 upstream; a no-op, 4.4 has no CFI).
* `include/linux/dcache.h` — `full_name_hash()` dispatches on argument count, so
  both the 4.4 two-argument form and the post-5.2
  `full_name_hash(namespace, name, len)` are accepted. `fs/namei.c` `#undef`s it
  before defining the real two-argument function and its `EXPORT_SYMBOL`.
* `include/linux/slab.h` — a `kvmalloc()` at the very end of the header, guarded
  by `#ifdef KSU_VERSION`.

`manager/apk_sign.c` is the one KernelSU source that calls `kvmalloc()` without
including its own `compat/kernel_compat.h`, so on 4.4 it has to get a definition
from the kernel. The `KSU_VERSION` guard makes the block invisible to every
other object in the tree — KernelSU's `Kbuild` sets that flag for its own
sources and nowhere else — and the body mirrors `ksu_kvmalloc()` from
`KernelSU-Next/kernel/compat/kernel_compat.h`. It does not clash with that
header's `#define kvmalloc ksu_kvmalloc`, because the header sets its include
guard and pulls in `slab.h` before defining the macro.

It cannot live in a header `apk_sign.c` includes such as `<linux/limits.h>`:
`slab.h` reaches `limits.h` itself, by way of
`kasan.h -> sched.h -> cgroup-defs.h`, so `limits.h` is entered with
`_LINUX_SLAB_H` already defined and `kmalloc()` not declared until well after it
has been called. The tail of `slab.h` is only reached once the rest of the
header has been parsed, so `kmalloc()` exists by then.

### kernel_read() and kernel_write()

These two changed shape in 4.14. From there on they take

	ssize_t kernel_read (struct file *file, void *buf, size_t count, loff_t *pos);
	ssize_t kernel_write(struct file *file, const void *buf, size_t count, loff_t *pos);

whereas 4.4's put the offset third, and take it by value for the write.
KernelSU-Next calls the 4.14 form throughout.

The mismatch does not fail the build. KernelSU's `Kbuild` passes
`-Wno-int-conversion`, so a buffer address is assigned to an `loff_t` and a
size to a `char *` without a murmur. At run time the offset is a stack
address, `rw_verify_area()` rejects it as a negative offset, and the buffer is
never filled. Manager detection is what that looks like from outside — every
`base.apk` fails its v2 signature check with "error: cannot find eocd", so no
manager is ever crowned — but the same call shape also parses `packages.list`
into an empty list and reads and writes the allowlist at a garbage offset.

Two adapters in `fs/read_write.c`, `ksu_kernel_read()` and
`ksu_kernel_write()`, implement the 4.14 prototypes over `vfs_read()` and
`vfs_write()`. `include/linux/fs.h` declares them and, under
`#ifdef KSU_VERSION`, points `kernel_read` and `kernel_write` at them. As with
the `kvmalloc()` shim, `KSU_VERSION` is what confines the redirection to
KernelSU's own objects: `fs/exec.c`, `fs/splice.c` and every in-tree caller
keep the 4.4 functions.

`compat/kernel_compat.c` picks between its own fallback and the new API by
grepping `fs/read_write.c` for those two prototypes, so they are spelled out
there as well, above the adapters. Both `KSU_OPTIONAL_KERNEL_READ` and
`KSU_OPTIONAL_KERNEL_WRITE` then define. Without that, the fallback body —
which is written in the *old* argument order — would itself be rewritten by
the macro into the wrong shape.

This class of bug is invisible by construction, so the way to look for the
next one is to rebuild KernelSU's objects with the warning restored. The clang
command line is kept in the object's `.cmd` file:

```sh
cd out   # OUT, the build directory
obj=drivers/kernelsu/manager/apk_sign.o
cmd=$(sed -n "s|^cmd_${obj} := ||p" "$(dirname $obj)/.$(basename $obj).cmd")
cmd=$(printf '%s' "$cmd" | sed -e 's/-Wno-int-conversion/-Wint-conversion/' \
      -e 's|-Wp,-MD,[^ ]*|-Wp,-MMD,/tmp/dep|' -e 's| -o [^ ]*\.o||')
eval "$cmd -fsyntax-only"
```

`-fsyntax-only` and dropping `-o` are what keep it from overwriting the real
object. As of this writing the only remaining hit is
`ksud_integration.c:917`, in `__maybe_unused` code.

## Building

Requirements (Debian/Ubuntu):

```
sudo apt install clang lld llvm libssl-dev gcc-arm-linux-gnueabi zip
```

`gcc-arm-linux-gnueabi` is only needed so the 32-bit compat vDSO
(`CONFIG_COMPAT_VDSO=y`) has a non-empty `CROSS_COMPILE_ARM32`; clang does the
actual compiling.

Then, one device at a time:

```
./build.sh                 # maple, the default
DEVICE=lilac ./build.sh    # XZ1 Compact
DEVICE=poplar ./build.sh   # XZ1
```

`build.sh` merges `msmcortex-perf_defconfig` with three fragments — the common
`sony/yoshino.config`, the per-device `sony/<DEVICE>.config`, and a generated
list of device trees to append (see below) — asserts `CONFIG_KSU=y` and the
matching `CONFIG_MACH_SONY_*`, builds the DTBs and `Image.gz-dtb` with
`LLVM=1`, and produces

```
Concordia-KernelSU-Next-<device>-<YYYYMMDD>.zip
```

next to the output directory (`OUT`, default `./out`). The zip carries an
AnyKernel3 device check narrowed to the device it was built for.

The kernel reports itself as `4.4.302-concordia`, which is what `uname -r` and
the kernel version in Settings → About phone show. That is
`CONFIG_LOCALVERSION` in `msmcortex-perf_defconfig`; `build.sh` also passes an
empty `LOCALVERSION=` so `scripts/setlocalversion` does not append a `+` for an
untagged tree.

### Why one image per device

The yoshino device trees cannot be told apart by the bootloader. Compiled out,
lilac, maple and poplar all carry the same identifying properties:

```
qcom,msm-id  = <0x124 0x0>;
qcom,board-id = <0x8 0x0>;
```

They differ only in `model` and `compatible`, which the bootloader's match does
not read. An image appending all three would therefore resolve to whichever DTB
came first, and a maple would boot on lilac's tree — wrong panel, wrong
regulators, no boot. So the machine is selected at build time, exactly as the
LineageOS build does it, and each device gets its own zip.

This is also why the append list is set explicitly rather than left to default.
The base defconfig leaves `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES` empty,
and an empty list makes `arch/arm64/boot/Makefile` append *every* `.dtb` it
finds under `dts/`. `msmhamster-rumi.dtb` is always among them, because
`CONFIG_ARCH_MSMHAMSTER` is on in `msmcortex-perf_defconfig` and its Makefile
entry is not gated on any Sony symbol. An earlier build of this tree shipped
that DTB, and nothing else, as its device tree.

## Flashing

The zip is an [AnyKernel3](https://github.com/osm0sis/AnyKernel3) package.
Flash it from a custom recovery over an existing boot image for the *same*
device; it patches the kernel in place and keeps the ROM's ramdisk.

```
do.devicecheck=1   # narrowed to the device the zip was built for
do.modules=0       # kernel image only
```

`do.modules=0` because `CONFIG_MODULE_SIG_FORCE` is not set, so the modules
already shipped in the ROM still load against this kernel. No `vendor_boot`
or ramdisk patching is required for yoshino.

After flashing, install the [KernelSU-Next manager
app](https://github.com/KernelSU-Next/KernelSU-Next/releases) to grant root.
