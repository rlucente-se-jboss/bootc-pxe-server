#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

# install the needed package
dnf -y install tftp-server

# open firewall ports permanently
firewall-cmd --permanent --add-service=tftp
firewall-cmd --reload

# access EFI boot image files from the boot ISO image
mount -t iso9660 $BOOT_ISO /mnt -o loop,ro

# copy EFI boot images from ISO
mkdir -p /var/lib/tftpboot/redhat
cp -r /mnt/EFI /var/lib/tftpboot/redhat/
chmod -R 755 /var/lib/tftpboot/redhat/

mkdir -p /var/www/html/redhat
cp -r /mnt/EFI /var/www/html/redhat/
chmod -R 755 /var/www/html/redhat/

# unmount the boot ISO image
umount /mnt

# set grub config
cat > /var/lib/tftpboot/redhat/EFI/BOOT/grub.cfg <<EOF
set timeout=60
menuentry 'RHEL Image Mode' {
  linux images/pxeboot/vmlinuz ip=dhcp inst.ks=http://$HOSTIP/$BOOTC_KICKSTART
  initrd images/pxeboot/initrd.img
}
EOF

# enable the tftp service
systemctl enable --now tftp.socket
