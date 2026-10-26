# Recovery configuration for the Lenovo Tab One (TB305FU, device codename clove).
#
# Everything here is derived from the stock Android 15 firmware
# (TB305FU_EEA / S2002997_260522_ROW / security patch 2026-05-05) and from
# values read back from a live TB305FU unit. This tree keeps the stock GKI
# kernel, DTB, platform ramdisk and init_boot ramdisk fragment, and replaces
# only the vendor_boot "recovery" ramdisk fragment.

DEVICE_PATH := device/lenovo/clove

BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a53
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_SUPPORTS_64_BIT_APPS := true

TARGET_BOARD_PLATFORM := mt6768
# Stock ro.product.board is "clove_row_wifi" even though the AOSP device
# codename used by this tree is "clove". Keep the stock value: Lenovo's
# vendor blobs and init scripts key off it.
TARGET_BOOTLOADER_BOARD_NAME := clove_row_wifi
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
BOARD_INCLUDE_DTB_IN_BOOTIMG := true

# Stock Android 15 GKI boot image, 4 KiB pages.
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS := --header_version 4 --kernel_offset 0x00080000 --ramdisk_offset 0x07c80000 --tags_offset 0x0bc80000 --dtb_offset 0x0bc80000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x07c80000
BOARD_TAGS_OFFSET := 0x0bc80000
BOARD_DTB_OFFSET := 0x0bc80000
BOARD_RAMDISK_USE_LZ4 := true

# Partition sizes read from /dev/block/by-name/* on a TB305FU.
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 11811160064
BOARD_FLASH_BLOCK_SIZE := 262144

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    dtbo \
    init_boot \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm
BOARD_USES_METADATA_PARTITION := true
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := false

# Stock vendor_boot v4 carries three fragments: platform, recovery, init_boot.
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
TARGET_NO_RECOVERY := true

TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
TW_THEME := portrait_hdpi

# Names used by ROM/OTA zips that may be flashed from this recovery.
TARGET_OTA_ASSERT_DEVICE := clove,TB305FU,clove_row_wifi
TW_DEVICE_VERSION := clove-TB305FU

# Display, battery and thermal sysfs nodes verified on TB305FU:
#   /sys/class/leds/lcd-backlight/{max_,}brightness  (max 4095)
#   /sys/class/power_supply/battery/{capacity,status}
#   thermal_zone8 -> mtktscpu
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 2048

# The AOSP health HAL cannot be hosted by u:r:recovery:s0: TWRP's
# hwservicemanager also runs as recovery, but platform policy only lets
# the hwservicemanager domain set ctl.interface_start, and hal_health.te
# neverallows a domain other than hal_health_server from registering
# IHealth. Platform recovery policy already allows reading
# sysfs_batteryinfo, so use TWRP's direct sysfs path instead.
# TW_CUSTOM_BATTERY_PATH is a directory; TWRP appends /capacity and
# /status. TW_USE_LEGACY_BATTERY_SERVICES must be set explicitly because
# bootable/recovery checks it before it is derived from the custom path.
TW_USE_LEGACY_BATTERY_SERVICES := true
TW_CUSTOM_BATTERY_PATH := /sys/class/power_supply/battery
TW_CUSTOM_CPU_TEMP_PATH := /sys/devices/virtual/thermal/thermal_zone8/temp

TW_INCLUDE_FASTBOOTD := true
TW_EXCLUDE_MTP := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_USE_TOOLBOX := true

# Do not use TW_LOAD_VENDOR_MODULES for the touch stack. Lenovo's generated
# dependency graph recursively reaches scp.ko, whose probe blocks recovery.
# Touch bring-up uses a device-specific, direct ordered loader instead.

# Stock /data uses metadata encryption and FBE v2. Enable the Android 14.1
# recovery crypto stack so vold can create the dm-default-key userdata mapping
# from /metadata/vold/metadata_encryption before mounting F2FS.
TW_INCLUDE_CRYPTO := true
TW_EXCLUDE_ENCRYPTED_BACKUPS := true
TW_SKIP_ADDITIONAL_FSTAB := true

# Stock ZUI 17 / Android 15 metadata keys are tagged 2026-05-05.
# Do not set PLATFORM_SECURITY_PATCH here; Android 14.1 requires
# RELEASE_PLATFORM_SECURITY_PATCH and changing that rebuilds the
# whole tree. Stamp /prop.default after it is generated so Beanpod
# Configure sees OS 15 / 2026-05-05. Do not recompress the recovery
# lz4 fragment; the bootloader only accepts lz4 -l (legacy).
VENDOR_SECURITY_PATCH := 2026-05-05
BOOT_SECURITY_PATCH := 2026-05-05
BOARD_RECOVERY_IMAGE_PREPARE = device/lenovo/clove/stamp-recovery-props.sh $(TARGET_RECOVERY_ROOT_OUT)

# liblog/CHECK from the Beanpod HAL and keystore2 go nowhere without logd.
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
