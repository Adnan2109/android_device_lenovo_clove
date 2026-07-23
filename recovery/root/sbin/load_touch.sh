#!/sbin/sh
# Manually loads the remaining ilitek touchscreen dependency chain.
# Not run automatically at boot: scp.ko (MediaTek sensor co-processor)
# has not been verified safe to load without its userspace firmware
# loader, which does not run in recovery. If this script hangs, it
# will hang on scp.ko specifically - reboot (hold power) to recover.
#
# Run from an ADB shell after TWRP has finished booting:
#   adb shell sh /sbin/load_touch.sh

MODULES="hwmon alsps_common sspm_v1 mtk-dvfsrc-helper mtk_gpu_hal mtk_gpufreq_wrapper_legacy \
mtk_gpufreq_mt6768 connadp mediatek_static_power Upower mtk_ppm_v3 \
thermal_monitor mtk_power_gs_v1 MTK_INTERNAL_SPM scp sensorHub alspshub \
tpd_notify touch_common ilitek_spi"

for m in $MODULES; do
  echo "loading $m.ko ..."
  insmod /lib/modules/${m}.ko
  if [ $? -ne 0 ]; then
    echo "FAILED to load $m.ko - stopping here, check dmesg"
    exit 1
  fi
done

echo "Touch driver chain loaded. Check 'getevent -lp' for the touchscreen input device."
