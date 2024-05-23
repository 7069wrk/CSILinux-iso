#!/bin/bash

# Ensure all necessary tools are installed on the host OS
sudo apt-get update
sudo apt-get install -y aria2 xorriso squashfs-tools rsync grub-pc-bin grub-efi-amd64-bin zstd zenity yad

# Navigate to /tmp directory
cd /tmp

# Ask user to download the Xubuntu ISO using aria2
read -p "Do you want to download the Xubuntu ISO using aria2? (y/n): " answer
if [[ "$answer" == "y" ]]; then
    aria2c --seed-time=0 --follow-torrent=mem https://torrent.ubuntu.com/xubuntu/releases/noble/release/minimal/xubuntu-24.04-minimal-amd64.iso.torrent
fi

# Create a directory for the new custom ISO
mkdir csi-linux-live
cd csi-linux-live

# Mount the downloaded ISO
mkdir mnt
sudo mount -o loop ../xubuntu-24.04-minimal-amd64.iso mnt

# Extract .iso contents into directory
sudo rsync -a mnt/ .

# Unmount the ISO
sudo umount mnt
sudo rmdir mnt

# Extract the squashfs filesystem
sudo unsquashfs carper/minimal.squashfs
sudo mv squashfs-root edit

# Chroot into the filesystem
cd edit
sudo mount --bind /dev/ dev/
sudo mount --bind /run/ run/
sudo mount -t proc /proc proc/
sudo mount -t sysfs /sys sys/

# Create a sudoer user "csi"
sudo chroot . adduser csi --gecos "CSI User,,," --disabled-password
echo "csi:csi" | chroot . chpasswd
echo "csi ALL=(ALL) NOPASSWD:ALL" | sudo tee etc/sudoers.d/csi
sudo chmod 0440 etc/sudoers.d/csi

# Copy /opt/csitools from the main system
sudo cp -r /opt/csitools opt/

# Install curl, wget, zenity, yad, and aria2 in the ISO
sudo chroot . apt-get update
sudo chroot . apt-get install -y curl wget zenity yad aria2

# Create a script that runs last during the install
echo '#!/bin/bash' | sudo tee opt/csitools/powerup.sh
echo '/opt/csitools/powerup' | sudo tee -a opt/csitools/powerup.sh
sudo chmod +x opt/csitools/powerup.sh

# Clean up and prepare for repackaging
sudo umount dev/ run/ proc/ sys/
cd ..

# Repackage the modified filesystem using Zstandard compression
sudo mksquashfs edit carper/minimal.squashfs -comp zstd -Xcompression-level 22

# Extra requirements for xorriso
sudo apt-get install isolinux
sudo cp -r /usr/lib/ISOLINUX/ boot/

# Create new ISO file with MBR and UEFI support
sudo xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "CSI Linux 24.04" \
    -eltorito-boot boot/ISOLINUX/isolinux.bin \
    -eltorito-catalog boot/ISOLINUX/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e /efi/boot/bootx64.efi \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output ../csi-linux-2404-live.iso \
    .

# Cleanup
cd ..
sudo rm -rf edit
echo "Custom CSI Linux ISO has been created: /tmp/csi-linux-2404-live.iso" 
