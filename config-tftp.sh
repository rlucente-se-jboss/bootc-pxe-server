#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

# install the needed package
dnf -y install tftp-server

# open firewall ports permanently
firewall-cmd --permanent --add-service=tftp
firewall-cmd --reload

# access EFI boot image files from the boot ISO image
mount -o loop $BOOT_ISO /mnt

# copy EFI boot images from ISO
mkdir -p /var/lib/tftpboot/redhat
cp -r /mnt/* /var/lib/tftpboot/redhat
chmod -R 755 /var/lib/tftpboot/redhat/

cp -r /var/lib/tftpboot/redhat /var/www/html/

# unmount the boot ISO image
umount /mnt

# set grub config
cat > /var/lib/tftpboot/redhat/EFI/BOOT/grub.cfg <<EOF
### BEGIN /etc/grub.d/10_linux ###
menuentry 'Install RHEL Image Mode' --class fedora --class gnu-linux --class gnu –class os {
  linuxefi redhat/images/pxeboot/vmlinuz inst.stage2=http://$HOSTIP/redhat quiet inst.ks=http://$HOSTIP/$BOOTC_KICKSTART
  initrdefi redhat/images/pxeboot/initrd.img
}
EOF

# enable the tftp service
systemctl enable --now tftp.socket
