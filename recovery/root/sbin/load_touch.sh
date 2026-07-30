#!/sbin/sh

# Loads thermal/utility modules in correct dependency order.
# Skips SCP chain (broken in recovery), tries alt touch drivers.
#
# Run from ADB shell: sh /sbin/load_touch.sh

set +e

load_mod() {
  mod=$1
  mod_n=$(echo "$mod" | tr '-' '_')
  if grep -q "^${mod_n} " /proc/modules 2>/dev/null; then
    echo "[OK] $mod (already loaded)"
    return 0
  fi
  insmod /lib/modules/${mod}.ko 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "[OK] $mod"
    return 0
  else
    echo "[FAIL] $mod"
    return 1
  fi
}

echo "=== Phase 1: Foundation modules ==="

load_mod hwmon
load_mod alsps_common
load_mod sspm_v1
load_mod mtk-dvfsrc-helper
load_mod mtk_gpu_hal
load_mod mtk_gpufreq_wrapper_legacy
load_mod mtk_gpufreq_mt6768
load_mod connadp
load_mod mediatek_static_power

echo ""
echo "=== Phase 2: Power chain (sspm_v1 -> Upower -> mtk_ppm_v3 -> thermal_monitor) ==="

load_mod Upower
load_mod mtk_cpuhp
load_mod mtk_ppm_v3
load_mod thermal_monitor
load_mod mtk_power_gs_v1
load_mod mtk_cpuidle

echo ""
echo "=== Phase 3: Timer + SPM (timer-mediatek provides symbols for MTK_INTERNAL_SPM) ==="

load_mod timer-mediatek
load_mod MTK_INTERNAL_SPM
load_mod mtk-scpsys-bringup

echo ""
echo "=== Phase 4: SCP chain (SKIPPED - firmware disabled in recovery) ==="

echo "[SKIP] scp.ko"
echo "[SKIP] sensorHub.ko -> alspshub.ko -> tpd_notify.ko -> touch_common.ko -> ilitek_spi.ko"

echo ""
echo "=== Phase 5: Alternative touch (no SCP needed) ==="

# None of these exist in this build - will fail gracefully
load_mod gt1151
load_mod chipone
load_mod chipone9916

echo ""
echo "=== Done ==="

# Check if CPU temp zone appeared
if [ -d /sys/class/thermal/thermal_zone8 ]; then
  echo "CPU temp zone found: /sys/class/thermal/thermal_zone8/type = $(cat /sys/class/thermal/thermal_zone8/type)"
  echo "Temp: $(cat /sys/class/thermal/thermal_zone8/temp)"
else
  echo "No thermal_zone8 found. Listing all zones:"
  ls /sys/class/thermal/
fi
