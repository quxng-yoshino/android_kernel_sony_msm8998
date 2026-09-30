#!/usr/bin/env bash
#
# Build the Sony MSM8998 "yoshino" kernel and package it as an AnyKernel3 zip.
#
#   ./build.sh            # build Image.gz-dtb and produce a flashable zip
#   OUT=/tmp/out ./build.sh
#
# Requirements (Debian/Ubuntu):
#   sudo apt install clang lld llvm libssl-dev gcc-arm-linux-gnueabi zip
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$ROOT/out}"
AK3="$ROOT/anykernel"
JOBS="${JOBS:-$(nproc)}"

# msmcortex-perf_defconfig + the yoshino fragment, merged the same way the
# LineageOS build does it (see device/sony/yoshino-common/BoardConfigCommon.mk).
DEFCONFIG=msmcortex-perf_defconfig
FRAGMENT="$ROOT/arch/arm64/configs/sony/yoshino.config"

MAKE_ARGS=(
	ARCH=arm64
	LLVM=1
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

echo "==> Configuring ($DEFCONFIG + sony/yoshino.config)"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" "$DEFCONFIG"
ARCH=arm64 "$ROOT/scripts/kconfig/merge_config.sh" \
	-O "$OUT" -m "$OUT/.config" "$FRAGMENT"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" olddefconfig

if ! grep -q '^CONFIG_KSU=y' "$OUT/.config"; then
	echo "!! CONFIG_KSU is not enabled in $OUT/.config" >&2
	exit 1
fi

echo "==> Building Image.gz-dtb with -j$JOBS"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" -j"$JOBS" Image.gz-dtb

IMAGE="$OUT/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMAGE" ] || { echo "!! $IMAGE was not produced" >&2; exit 1; }

echo "==> Packaging AnyKernel3 zip"
[ -f "$AK3/tools/ak3-core.sh" ] || { echo "!! $AK3 is missing AnyKernel3 files" >&2; exit 1; }
cp -f "$IMAGE" "$AK3/Image.gz-dtb"

ZIP="$(dirname "$OUT")/Yoshino-KernelSU-Next-$(date +%Y%m%d).zip"
rm -f "$ZIP"
( cd "$AK3" && zip -r9 "$ZIP" . -x '*.git*' >/dev/null )

echo
echo "==> Done: $ZIP"
echo "    kernel: $(ls -l "$IMAGE" | awk '{print $5" bytes"}')"
