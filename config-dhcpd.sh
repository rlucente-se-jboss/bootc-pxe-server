#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

# install the needed package
dnf -y install dhcp-server

# open firewall ports permanently
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --reload

# enable configuration
cat > /etc/dhcp/dhcpd.conf <<EOF
option architecture-type code 93 = unsigned integer 16;

subnet $SUBNET_IP netmask $SUBNET_MASK {
  option routers $ROUTER_IP;
  option domain-name-servers $ROUTER_IP;
  range $SUBNET.100 $SUBNET.200;
  class "pxeclients" {
    match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
    next-server $HOSTIP;
          if option architecture-type = 00:07 {
            filename "redhat/EFI/BOOT/BOOTX64.EFI";
          }
          else {
            filename "pxelinux/pxelinux.0";
          }
  }
  class "httpclients" {
    match if substring (option vendor-class-identifier, 0, 10) = "HTTPClient";
    option vendor-class-identifier "HTTPClient";
    filename "http://$HOSTIP/redhat/EFI/BOOT/BOOTX64.EFI";
  }
}
EOF

# enable the dhcp service
systemctl enable --now dhcpd
