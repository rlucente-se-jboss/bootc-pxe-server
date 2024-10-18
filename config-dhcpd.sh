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
# Declare the Client System Architecture Type (code 93) option as two
# octects.
option architecture-type code 93 = unsigned integer 16;

# Provide dynamic IP Addresses for the network $SUBNET_IP/$SUBNET_MASK
subnet $SUBNET_IP netmask $SUBNET_MASK {
  # Packet routers on the network
  option routers $ROUTER_IP;

  # DNS servers on the network
  option domain-name-servers $ROUTER_IP;

  # hand out addresses in the given range
  range $SUBNET.100 $SUBNET.200;

  # configuration for PXE clients using vendor-class-identifier
  class "pxeclients" {
    # if the first nine characters match "PXEClient"
    match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
    next-server $HOSTIP;

    # We will look for 00:07 (EFI Bytecode) or 00:09 (EFI x86-64) from
    # the client
    if option architecture-type = 00:07 or option architecture-type = 00:09 {
      filename "redhat/EFI/BOOT/BOOTX64.EFI";
    }
  }

  # configuration for UEFI HTTP clients using vendor-class-identifier
  class "httpclients" {
    # if the first ten characters match "HTTPClient"
    match if substring (option vendor-class-identifier, 0, 10) = "HTTPClient";
    option vendor-class-identifier "HTTPClient";
    filename "http://$HOSTIP/redhat/EFI/BOOT/BOOTX64.EFI";
  }
}
EOF

# enable the dhcp service
systemctl enable --now dhcpd
