#!/bin/bash

qemu_git="https://github.com/qemu/qemu.git"
qemu_branch="v7.2.0"
qemu_dir="$(pwd)/qemu-comp"
patch_url="https://patchwork.kernel.org/series/710627/mbox/"
patch_file="glibc236.patch"
glibc_version=$(ldd --version | grep -oE '[0-9]+\.[0-9]+')

function main()
{
  qemu_compile
}

function qemu_compile()
{
  if [[ -e $qemu_dir ]]; then
    rm -rf $qemu_dir
  fi

  mkdir -p $qemu_dir
  git clone --branch $qemu_branch $qemu_git $qemu_dir
  cd $qemu_dir

  qemu_motherboard_bios_vendor="AMI"
  qemu_bios_string1="ALASKA"
  qemu_bios_string2="ASPC    " # Must be 8 chars
  qemu_disk_vendor="Western Digital Technologies, Inc."
  qemu_disk_name="WDC WD10JPVX-22JC3T0"
  qemu_cd_vendor="ASUS"
  qemu_cd_name="ASUS DRW 24F1ST"
  qemu_tablet_vendor="Wacom"
  qemu_tablet_name="Wacom Tablet"
  cpu_brand=$(grep -m 1 'vendor_id' /proc/cpuinfo | cut -c13-)
  cpu_speed=$(dmidecode | grep "Current Speed:" | cut -d" " -f3)

  sed -i "s/\"BOCHS \"/\"$qemu_bios_string1\"/"                                             $qemu_dir/include/hw/acpi/aml-build.h
  sed -i "s/\"BXPC    \"/\"$qemu_bios_string2\"/"                                           $qemu_dir/include/hw/acpi/aml-build.h
  sed -i "s/\"QEMU\"/\"$qemu_disk_vendor\"/"                                                $qemu_dir/hw/scsi/scsi-disk.c
  sed -i "s/\"QEMU HARDDISK\"/\"$qemu_disk_name\"/"                                         $qemu_dir/hw/scsi/scsi-disk.c
  sed -i "s/\"QEMU HARDDISK\"/\"$qemu_disk_name\"/"                                         $qemu_dir/hw/ide/core.c
  sed -i "s/\"QEMU DVD-ROM\"/\"$qemu_cd_name\"/"                                            $qemu_dir/hw/ide/core.c
  sed -i "s/\"QEMU\"/\"$qemu_cd_vendor\"/"                                                  $qemu_dir/hw/ide/atapi.c
  sed -i "s/\"QEMU DVD-ROM\"/\"$qemu_cd_name\"/"                                            $qemu_dir/hw/ide/atapi.c
  sed -i "s/\"QEMU\"/\"$qemu_tablet_vendor\"/"                                              $qemu_dir/hw/usb/dev-wacom.c
  sed -i "s/\"Wacom PenPartner\"/\"$qemu_tablet_name\"/"                                    $qemu_dir/hw/usb/dev-wacom.c
  sed -i "s/\"QEMU PenPartner Tablet\"/\"$qemu_tablet_name\"/"                              $qemu_dir/hw/usb/dev-wacom.c
  sed -i "s/#define DEFAULT_CPU_SPEED 2000/#define DEFAULT_CPU_SPEED $cpu_speed/"           $qemu_dir/hw/smbios/smbios.c
  sed -i "s/KVMKVMKVM\\\\0\\\\0\\\\0/$cpu_brand/"                                           $qemu_dir/include/standard-headers/asm-x86/kvm_para.h
  sed -i "s/KVMKVMKVM\\\\0\\\\0\\\\0/$cpu_brand/"                                           $qemu_dir/target/i386/kvm/kvm.c
  sed -i "s/\"bochs\"/\"$qemu_motherboard_bios_vendor\"/"                                   $qemu_dir/block/bochs.c

  if [[ "$glibc_version" > "2.35" ]]; then
    echo "glibc version higher than 2.35, applying patches..."
    wget "$patch_url" -O "$patch_file"
    git apply "$patch_file"
  fi

  ./configure --enable-spice --disable-werror
  make -j$(nproc)

  chown -R $SUDO_USER:$SUDO_USER $qemu_dir
}
main
