#!/usr/bin/env bash
#
# Build the Sony MSM8998 "yoshino" kernel and package it as an AnyKernel3 zip.
#
#   ./build.sh                  # maple  (Xperia XZ Premium)
#   DEVICE=lilac ./build.sh     # XZ1 Compact
#   DEVICE=poplar ./build.sh    # XZ1
#   OUT=/tmp/out ./build.sh
#
# One image per device: see the DTB note below for why a single image covering
# all three is not possible.
#
# Requirements (Debian/Ubuntu):
#   sudo apt install clang lld llvm libssl-dev gcc-arm-linux-gnueabi zip
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$ROOT/out}"
AK3="$ROOT/anykernel"
JOBS="${JOBS:-$(nproc)}"
DEVICE="${DEVICE:-${1:-maple}}"

case "$DEVICE" in
lilac | maple | poplar) ;;
*)
	echo "!! DEVICE must be lilac (XZ1 Compact), maple (XZ Premium) or" >&2
	echo "   poplar (XZ1); got '$DEVICE'" >&2
	exit 1
	;;
esac

# msmcortex-perf_defconfig plus three fragments, merged the way the LineageOS
# build does it (see device/sony/yoshino-common/BoardConfigCommon.mk):
#
#   sony/yoshino.config    the common half. It leaves every MACH_SONY_* symbol
#                          off, because upstream the per-device fragment below
#                          is what picks the machine.
#   sony/$DEVICE.config    that per-device fragment.
#   $OUT/.dtb-names.config generated here; see below.
DEFCONFIG=msmcortex-perf_defconfig

# Only this device's device trees may be appended.
#
# The yoshino DTBs are not distinguishable by the bootloader. lilac, maple and
# poplar all carry qcom,msm-id = <0x124 0x0> and qcom,board-id = <0x8 0x0> --
# byte for byte the same values, in the very properties those headers exist
# for. They differ only in model and compatible, which the bootloader's match
# does not read. An image holding all three therefore resolves to whichever
# entry is reached first, and the device gets another device's tree: wrong
# panel, wrong regulators, no boot. Hence one machine per image.
#
# This list also has to be set explicitly rather than left empty. An empty
# BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES makes arch/arm64/boot/Makefile append
# every .dtb it can find under dts/, and msmhamster-rumi.dtb is always among
# them: CONFIG_ARCH_MSMHAMSTER is on in msmcortex-perf_defconfig and its
# Makefile entry is not gated on any Sony symbol. That stray DTB, alone, was
# what an earlier build of this tree shipped.
mkdir -p "$OUT"
cat >"$OUT/.dtb-names.config" <<EOF
CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="qcom/msm8998-yoshino-${DEVICE}_generic qcom/msm8998-v2-yoshino-${DEVICE}_generic qcom/msm8998-v2.1-yoshino-${DEVICE}_generic"
EOF

FRAGMENTS=(
	"$ROOT/arch/arm64/configs/sony/yoshino.config"
	"$ROOT/arch/arm64/configs/sony/$DEVICE.config"
	"$OUT/.dtb-names.config"
)

MAKE_ARGS=(
	ARCH=arm64
	LLVM=1
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

echo "==> Configuring ($DEFCONFIG + yoshino/$DEVICE.config)"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" "$DEFCONFIG"
ARCH=arm64 "$ROOT/scripts/kconfig/merge_config.sh" \
	-O "$OUT" -m "$OUT/.config" "${FRAGMENTS[@]}"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" olddefconfig

if ! grep -q '^CONFIG_KSU=y' "$OUT/.config"; then
	echo "!! CONFIG_KSU is not enabled in $OUT/.config" >&2
	exit 1
fi

# Without its machine on, arch/arm64/boot/dts/qcom/Makefile builds no yoshino
# DTB at all and the image boots on nothing.
MACH="MACH_SONY_$(echo "$DEVICE" | tr '[:lower:]' '[:upper:]')"
if ! grep -q "^CONFIG_${MACH}=y" "$OUT/.config"; then
	echo "!! CONFIG_${MACH} is not enabled in $OUT/.config" >&2
	exit 1
fi

# The DTBs are prerequisites of Image.gz-dtb but have no rule of their own
# there -- they come from the separate dtbs target. Build them first so they
# exist by the time the image is concatenated.
echo "==> Building device trees with -j$JOBS"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" -j"$JOBS" dtbs

echo "==> Building Image.gz-dtb with -j$JOBS"
make -C "$ROOT" O="$OUT" "${MAKE_ARGS[@]}" -j"$JOBS" Image.gz-dtb

IMAGE="$OUT/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMAGE" ] || { echo "!! $IMAGE was not produced" >&2; exit 1; }

# An Image.gz-dtb no larger than Image.gz means no DTB was appended at all.
IMAGE_GZ="$OUT/arch/arm64/boot/Image.gz"
[ "$(stat -c%s "$IMAGE")" -gt "$(stat -c%s "$IMAGE_GZ")" ] || {
	echo "!! $IMAGE has no device tree appended (same size as Image.gz)" >&2
	exit 1
}

# Package from a staging copy so the repo's anykernel/ is left alone, and so
# the device check can be narrowed to the device this kernel was built for --
# a maple kernel flashed on a lilac is not a thing that works.
echo "==> Packaging AnyKernel3 zip for $DEVICE"
[ -f "$AK3/tools/ak3-core.sh" ] || { echo "!! $AK3 is missing AnyKernel3 files" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -a "$AK3/." "$STAGE/"
cp -f "$IMAGE" "$STAGE/Image.gz-dtb"

sed -i \
	-e "s|^kernel.string=.*|kernel.string=Sony MSM8998 yoshino ($DEVICE) + KernelSU-Next|" \
	-e "s|^device.name1=.*|device.name1=$DEVICE|" \
	-e "s|^device.name2=.*|device.name2=|" \
	-e "s|^device.name3=.*|device.name3=|" \
	"$STAGE/anykernel.sh"

ZIP="$(dirname "$OUT")/Yoshino-KernelSU-Next-${DEVICE}-$(date +%Y%m%d).zip"
rm -f "$ZIP"
( cd "$STAGE" && zip -r9 "$ZIP" . -x '*.git*' >/dev/null )

echo
echo "==> Done: $ZIP"
echo "    device: $DEVICE"
echo "    kernel: $(stat -c%s "$IMAGE") bytes"
echo "    dtbs:   $(grep -o 'qcom/[^ ]*\.dtb' <<<"$(cat "$OUT/arch/arm64/boot/.Image.gz-dtb.cmd")" | sed 's|.*/||' | tr '\n' ' ')"
