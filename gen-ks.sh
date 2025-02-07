#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] && exit_on_error "Must NOT run as root"

cat > $BOOTC_KICKSTART <<EOF
#
# kickstart to pull down and install OCI container as the operating system
#

text
network --bootproto=dhcp --device=link --activate

# Basic partitioning
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs

EOF

if [ ! -z "${EXTRA_BOOT_ARGS[*]}" ]
then
    cat >> $BOOTC_KICKSTART <<EOF
bootloader --append="${EXTRA_BOOT_ARGS[*]}"

EOF
fi

cat >> $BOOTC_KICKSTART <<EOF
# The referenced container image is what gets installed to the target
# edge device
ostreecontainer --url ${OS_CONTAINER_REPO}:prod

# optionally add a user
user --name ${EDGE_USER} --groups wheel --iscrypted --password ${EDGE_HASH}

reboot
EOF

if [ "$REGISTRYINSECURE" = true ]
then
    cat >> $BOOTC_KICKSTART << EOF1

# make sure to be able to pull images from an insecure registry
%pre
mkdir -p /etc/containers/registries.conf.d
cat > /etc/containers/registries.conf.d/999-local-registry.conf << EOF
[[registry]]
location = "$HOSTIP:$REGISTRYPORT"
insecure = true
EOF
%end
EOF1
fi
