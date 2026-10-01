### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Customized for Concordia on Sony MSM8998 "yoshino" (Xperia XZ1 / XZ1 Compact / XZ Premium)

### AnyKernel setup
# global properties
properties() { '
kernel.string=Concordia for Sony MSM8998 (yoshino) + KernelSU-Next
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=lilac
device.name2=maple
device.name3=poplar
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot; # use split_boot to skip ramdisk unpack

## no ramdisk patches are required for yoshino

write_boot; # use flash_boot to skip ramdisk repack
## end boot install
