# TWRP 14.1 for the Lenovo Tab One (TB305FU / clove)

Experimental TWRP 14.1 recovery for the Lenovo Tab One Wi‑Fi, model
`TB305FU` (product `TB305FU_EEA`, AOSP codename `clove`).

| Item | Value |
| --- | --- |
| Model / product | `TB305FU` / `TB305FU_EEA` |
| Stock `ro.product.board` | `clove_row_wifi` |
| SoC | MT6768 family, `ro.hardware=mt8786` |
| Platform | `mt6768` |
| OS | Android 15 / ZUI 17, build `AP3A.240905.015.A2` |
| Firmware | `S2002997_260522_ROW` |
| Security patch | `2026-05-05` |
| Display | 800 × 1340, density 180, backlight max 4095 |
| Slot | A/B, dynamic partitions, erofs system images |
| `/data` | f2fs, FBE v2 + metadata encryption |
| Kernel | stock 6.6 GKI (`6.6.82-android15-8-g0479d978e2c1-4k`) |

The tablet ships an Android 15 GKI `vendor_boot` v4 with three ramdisk
fragments: `platform`, `recovery`, and `init_boot`. Matching kernel source
has not been released, so this port keeps the stock kernel, DTB, platform
ramdisk, and `init_boot` fragment, and replaces only the **recovery**
fragment with TWRP.

## What was verified for this tree

Everything below was checked against a live TB305FU unit
(`S2002997_260522_ROW`, patch `2026-05-05`), not copied on faith:

- `prebuilt/kernel` is byte-identical to the stock boot kernel.
- `prebuilt/stock.dtb` is byte-identical to the DTB inside the stock
  `vendor_boot`.
- `prebuilt/vendor_ramdisk_platform.lz4` is the stock platform fragment.
- `prebuilt/vendor_ramdisk_init_boot.lz4` unpacks to the same ramdisk as the
  stock `init_boot` fragment (the on-device fragment is KernelSU-patched;
  the original `init` in it matches this prebuilt exactly).
- `prebuilt/modules/ilitek_spi.ko` and `touch_common.ko` are taken from the
  device's own `vendor_dlkm`, and their modversion CRCs, vermagic, and
  `depends=` match the reference-proven builds exactly.
- The Beanpod Keymaster/Gatekeeper and MicroTrust TEEI binaries, libraries,
  and TAs match the device.
- The AVB salt in `repack-stock-vendor-boot.sh`
  (`9fb45fbc…f20a5`) matches the stock `vendor_boot` hash descriptor.
- Partition sizes: boot 33554432, vendor_boot 67108864, init_boot 8388608,
  dtbo 8388608, super 11811160064.
- Sysfs nodes: `lcd-backlight` max 4095, `battery/capacity`, and
  `thermal_zone8` (`mtktscpu`).

`verify-prebuilts.sh` re-checks every shipped blob against
`prebuilt/SHA256SUMS`.

The tree is a re-targeted version of the working `clove_row_wifi` port; it
uses the same TWRP 14.1 platform patches and crypto stack. It has **not**
been rebuilt inside this environment (a TWRP build needs ~150 GB).

## Status

Reported working by the reference port this tree is derived from:

- TWRP UI, DRM graphics, ILITEK touch, persistent ADB
- SELinux **enforcing**
- Beanpod Keymaster 4.1 + MicroTrust TEEI + `keystore2`
- Metadata encryption unwrap (`dm-default-key` on `/dev/block/mapper/userdata`)
- `/data` mounted as f2fs from that mapper
- User-0 DE/CE key installation and `fscrypt_init_user0` under enforcing
- Automatic no-lock / default-credential synthetic-password unwrap
- Pattern credential verification through the stock Android 15 AIDL Gatekeeper

Known limitations:

- PIN and password credentials are untested; pattern and no-lock are verified.
- ADB `twrp decrypt` can crash recovery in a DRM page flip; use automatic
  startup decryption or the GUI.
- EROFS logical partitions still need follow-up mount-policy work in the UI.
- The stock `vbmeta` hashes `vendor_boot`, so flashing TWRP makes the
  bootloader show a yellow "dm-verity corruption" prompt. Press power once,
  or use the optional patched LK described below.

**Never format `/data` or `/metadata`. Flash slot A only; slot B is the
stock fallback.**

## Reproduce the build tree

You need ~150 GB free, `repo`, and the usual Android build packages.

```bash
mkdir twrp-14.1 && cd twrp-14.1
repo init --depth=1 \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
  -b twrp-14.1
repo sync -c -j"$(nproc)"
```

Place this tree at `device/lenovo/clove`. Either copy it there manually:

```bash
mkdir -p device/lenovo
cp -a /path/to/android_device_lenovo_clove-main device/lenovo/clove
```

or edit `local_manifests/clove.xml.example`, replace `YOUR_GITHUB_USER`,
copy it to `.repo/local_manifests/clove.xml`, and sync again.

Then apply the platform patches:

```bash
device/lenovo/clove/apply-patches.sh
```

They are made against the TWRP 14.1 / AOSP 14.0.0_r67 revisions listed in
`patches/BASE_REVS.txt`:

| Project | Why |
| --- | --- |
| `bootable/recovery` | DRM/touch, metadata mapper fallback, logd/keystore2 and AIDL Gatekeeper packaging |
| `build/make` | Do not rsync a host `vendor/` over the recovery ramdisk vendor tree |
| `system/logging` | logd must not FATAL on missing task profiles / already-true props |
| `system/security` | `libkm_compat` talks to HIDL Keymaster 4.1 via `defaultServiceManager1_2()` |
| `system/sepolicy` | recovery owns Binder + Keymaster/Gatekeeper/keystore2, auth-token submission, locksettings key access, metadata/FBE ioctls |
| `system/vold` | metadata/DE/CE setup, AIDL Gatekeeper credential verification, synthetic-password handle fallback, safe keystore DB copy |

If a patch stops applying, check out the matching revision in that project
(the script prints it) and retry.

## Build

Lunch is `twrp_clove-ap2a-eng` (Android 14.1 `ap2a` baseline). The stock OS is
Android 15; do not change `PLATFORM_VERSION` for the TWRP tree. Stock OS 15 /
patch `2026-05-05` is stamped into recovery `/prop.default` at pack time,
because Beanpod `Configure` is first-write per TEE session.

```bash
export ALLOW_MISSING_DEPENDENCIES=true
. build/envsetup.sh
lunch twrp_clove-ap2a-eng
m vendorbootimage -j"$(nproc)"
device/lenovo/clove/repack-stock-vendor-boot.sh
```

`m vendorbootimage` alone is **not** the flashable image. The repack script
builds a `vendor_boot` v4 containing:

1. the stock platform ramdisk,
2. the TWRP recovery fragment just built (`lz4 -l` legacy; this is what the
   bootloader decompresses),
3. the stock `init_boot` ramdisk fragment,
4. the stock DTB, plus an AVB hash footer with the stock salt.

Output:

```
out/target/product/clove/vendor_boot-twrp-experimental.img
```

It is exactly 67,108,864 bytes. Never recompress the recovery `.cpio.lz4`
with frame LZ4 (`lz4` without `-l`); that bootloops.

## Flash (slot A only)

Unlocked bootloader required. Check the product and slot first:

```bash
fastboot getvar product       # clove_row_wifi
fastboot getvar current-slot  # a
fastboot flash vendor_boot_a out/target/product/clove/vendor_boot-twrp-experimental.img
fastboot reboot recovery
```

- Do **not** flash `vendor_boot_b`.
- Do not `fastboot -w`, format `/data`, or format `/metadata`.
- Keep a dump of your current `vendor_boot_a` (or use the slot-B copy) so you
  can roll back.
- **This replaces the whole `vendor_boot`, including the `init_boot` fragment.**
  If your current `vendor_boot_a` was patched by KernelSU/Magisk, that patch
  is gone after flashing and root in Android stops working. The image here
  deliberately ships the stock (unpatched) `init_boot` fragment. Dump the
  current partition first (`su -c 'dd if=/dev/block/by-name/vendor_boot_a
  of=/sdcard/vendor_boot_a.orig.img'`) and re-patch afterwards if you still
  need KernelSU.

Because stock `vbmeta` covers `vendor_boot`, the bootloader may show a yellow
dm-verity warning. Power-cycle / press power once to continue. The reference
release also offers an optional patched `lk_a` (offset `0x69db8` patched from
`30 b5 83 b0` to `00 20 70 47`); flashing LK is riskier than flashing
recovery and is out of scope for this tree.

## Layout notes that will bite you

- `/data` is FBE v2 with metadata encryption:
  `fileencryption=aes-256-xts:aes-256-cts:v2,keydirectory=/metadata/vold/metadata_encryption`.
- `/metadata` lives on `/dev/block/by-name/md_udc`, not `metadata`.
- Logical partitions (`system`, `vendor`, `product`, `system_ext`,
  `vendor_dlkm`, `odm_dlkm`, `system_dlkm`) are erofs.
- Beanpod Keymaster is HIDL 4.1 on **hwbinder**; do not start
  `vndservicemanager`. Beanpod Gatekeeper is Android 15 AIDL on Binder.
- The HAL wrappers need `LD_LIBRARY_PATH=/vendor/lib64:/system/lib64` so the
  vendor Android 15 `libc++` loads while Gatekeeper falls through to
  recovery's compatible `libbinder`.
- `vendor/*.prop` cannot override `ro.build.*`; `/prop.default` is the system
  source that `Configure` reads. `ro.crypto.type=file` must also be present in
  the initial `/prop.default` (see `stamp-recovery-props.sh`).
- Do not use `TW_LOAD_VENDOR_MODULES` for touch: Lenovo's dependency graph
  reaches `scp.ko`, whose probe blocks recovery. Touch is loaded by
  `lenovo_module_loader` in a fixed order (`system/etc/lenovo-modules.touch-*`).
- Kernel module matching: the running kernel is
  `6.6.82-android15-8-g076ac12bde16-ab13715361-4k`, while the stock touch
  modules carry `…-g0479d978e2c1-4k`. With `CONFIG_MODVERSIONS` the kernel
  compares only the feature suffix (`SMP preempt mod_unload modversions
  aarch64`) and symbol CRCs, so both load. Do not mix in modules with a
  different feature suffix.
- The stock `init_boot` partition reads as zeros; MTK keeps the first-stage
  init ramdisk in the `vendor_boot` fragment named `init_boot`.

## Troubleshooting

- **Touch dead.** `adb shell cat /tmp/lenovo-module-loader.log` shows the
  three-module sequence. All three must report `OK`:
  `lenovo_touch_compat.ko`, `touch_common.ko`, `ilitek_spi.ko`. Confirm
  `/vendor/firmware/ili9882U.bin` exists and the panel module
  (`lcd_ili9982u_inx_inx_video.ko`) loaded from first stage. Never add
  `scp.ko` to the early list after a timeout.
- **Decryption fails.** Check `dmesg` for TEEI/Keymaster errors. The Beanpod
  HAL reads the OS/patch values only once per TEE session, so
  `/prop.default` must already say Android 15 / `2026-05-05` before it
  starts; the stamp script enforces that. `/metadata` must be `md_udc`, and
  `/data` must stay encrypted (never format it).
- **Yellow dm-verity screen.** Expected with a modified `vendor_boot`; press
  power once. Do not try to "fix" it by flashing `vbmeta`.
- **Boot loop / wrong slot.** Hold power+volume to return to fastboot and
  restore your dumped `vendor_boot_a`, or boot the stock slot B image.

## Prebuilt provenance

Extracted from TB305FU firmware / the live device:

| File | SHA-256 |
| --- | --- |
| `prebuilt/kernel` | `b71c04b0cf39fab8223b0a59ab8f546f1130da68b9cadc5401e16b81e365f79f` |
| `prebuilt/stock.dtb` | `28caeace2644cf6d3b29034dfa050dfe214bda6b87d3b64a3c61281711706897` |
| `prebuilt/vendor_ramdisk_platform.lz4` | `6d4a83834505bae83756887fa918d5ba0e8f32a425e05a1ce925560c4cf3cf41` |
| `prebuilt/vendor_ramdisk_init_boot.lz4` | `44eb007e333217fbdf8fe00e5ec81a0f070af0115d7ee693360ad52417d013ef` |
| `prebuilt/modules/ilitek_spi.ko` | `b59f73ee26732c53d24345b712fcc2f6da318dfc2f91b7a18be2087f0b4ed9ee` |
| `prebuilt/modules/touch_common.ko` | `fa73dbbf557cc186f4b996e907682ee12d383afea1da74577efc53b626698a6c` |
| `prebuilt/modules/lenovo_touch_compat.ko` | `3ab0ecf0eab2b0acefde59d45a44010dcf2298056fa9a5d116cc62241d9886ba` |
| `prebuilt/firmware/ili9882U.bin` | `bb970d5a71320618dc971cf7cdedb443398e403a586e32ed011632206f2fbab0` |

`sha256sum -c prebuilt/SHA256SUMS` covers the crypto binaries and TAs too.

Not shipped (left untouched on the device): stock `dtbo`
`fb45cf4a6f30dd9f0578942b34fcafe5cb1211d092473835dbf290d100800c18`.

## License

Makefiles, sepolicy, scripts, and the touch shim are Apache-2.0 unless a file
says otherwise. The prebuilt kernel, DTB, vendor ramdisks, firmware,
Beanpod/TEEI binaries, and Trusted Applications are proprietary Lenovo /
MediaTek / Microtrust blobs extracted from stock firmware and are
redistributed only so this recovery can be reproduced.
