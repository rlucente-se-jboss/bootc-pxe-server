#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

# install a simple web server
dnf -y install httpd

# open ports in the firewall
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

# copy the kickstart file to the web server
cp $BOOTC_KICKSTART /var/www/html/

# start the services automatically on boot
systemctl enable --now httpd
