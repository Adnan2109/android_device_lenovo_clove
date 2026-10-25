#!/bin/sh
# Assemble the flashable vendor_boot v4 image for TB305FU (clove).
#
# Inputs:
#   - TWRP's recovery.cpio.lz4 built by `m vendorbootimage`
#   - stock platform ramdisk, stock init_boot fragment, stock DTB (prebuilt/)
#
# Output: out/target/product/clove/vendor_boot-twrp-experimental.img
set -eu

if [ -n "${ANDROID_BUILD_TOP:-}" ]; then
    top=$ANDROID_BUILD_TOP
else
    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
    top=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
fi

device="$top/device/lenovo/clove"
product="$top/out/target/product/clove"
hostbin="$top/out/host/linux-x86/bin"
recovery="$product/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"
unsigned="$product/vendor_boot-stock-layout-unsigned.img"
output="$product/vendor_boot-twrp-experimental.img"

mkbootimg="$hostbin/mkbootimg"
avbtool="$hostbin/avbtool"
[ -x "$mkbootimg" ] || mkbootimg=$(command -v mkbootimg)
[ -x "$avbtool" ] || avbtool=$(command -v avbtool)

test -f "$recovery" || {
    echo "missing $recovery" >&2
    echo "run: m vendorbootimage" >&2
    exit 1
}
test -f "$device/prebuilt/vendor_ramdisk_platform.lz4"
test -f "$device/prebuilt/vendor_ramdisk_init_boot.lz4"
test -f "$device/prebuilt/stock.dtb"

"$mkbootimg" \
    --header_version 4 \
    --pagesize 4096 \
    --base 0x40000000 \
    --kernel_offset 0x00080000 \
    --ramdisk_offset 0x07c80000 \
    --tags_offset 0x0bc80000 \
    --dtb_offset 0x0bc80000 \
    --vendor_cmdline 'bootopt=64S3,32N2,64N2' \
    --dtb "$device/prebuilt/stock.dtb" \
    --vendor_ramdisk "$device/prebuilt/vendor_ramdisk_platform.lz4" \
    --ramdisk_type recovery \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$recovery" \
    --ramdisk_type platform \
    --ramdisk_name init_boot \
    --vendor_ramdisk_fragment "$device/prebuilt/vendor_ramdisk_init_boot.lz4" \
    --vendor_boot "$unsigned"

cp "$unsigned" "$output"
"$avbtool" add_hash_footer \
    --image "$output" \
    --partition_name vendor_boot \
    --partition_size 67108864 \
    --salt 9fb45fbcb7461e2122911082ae6a9ddc2e1a1fcafacad9ff3009c299677f20a5 \
    --prop 'com.android.build.vendor_boot.fingerprint:Lenovo/TB305FU/TB305FU:15/AP3A.240905.015.A2/__ROW:user/release-keys'

size=$(stat -c %s "$output")
test "$size" -eq 67108864 || {
    echo "unexpected image size: $size" >&2
    exit 1
}

echo "image: $output"
echo "size:  $size bytes"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$output"
fi
"$avbtool" info_image --image "$output" >/dev/null 2>&1 && echo "AVB footer: OK"
