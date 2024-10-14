# WORK IN PROGRESS
# Setup a PXE Server
This project shows how to setup a PXE Server that supports PXE
installations of a RHEL Image Mode bootable container image. This server
also runs a lightweight registry for RHEL Image Mode installations.

## Prepare your network for a new DHCP server
Since you're creating a new DHCP server, you need to make sure that there
is no competing DHCP server on the target network. How to do this really
depends on your environment. I ran this as a guest VM using libvirt on
RHEL. The specific steps I took were first to edit the default virtual
network.

    sudo virsh net-edit default

Then delete the following stanza and save the file.

    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>

Next, stop and restart the virtual network for the changes to take effect.

    sudo virsh net-destroy default
    sudo virsh net-start default

Finally, check that the virtual network is running.

    sudo virsh net-info default

The virtual network should show as active.

## Start with minimal RHEL 9.4 installation
Start with a minimal install of RHEL 9.4 either on baremetal or on a guest
VM. Use UEFI firmware, if able to, when installing your system. Also
make sure there's sufficient disk space on the RHEL 9.4 instance to
support the demo. I typically configure a 128 GiB disk on the guest VM.

Make sure to enable FIPS mode when installing RHEL. When the installer
first boots, select `Install Red Hat Enterprise Linux 9.4` on the GRUB
boot menu and then press `e` to edit the boot commandline. Add `fips=1`
to the end of the line that begins with `linuxefi` and then press CTRL-X
to continue booting.

During RHEL installation, configure a regular user with `sudo` privileges
on the host.

You'll also need to manually configure a static IP address for this server
as it will be the DHCP server for it's network. The network settings
should make sense for the network being used. When manually configuring
my guest VM, I used the following network settings based on my libvirt
network.

| Parameter | Value |
| --------- | ----- |
| IP Address | 192.168.122.2 |
| Subnet Mask | 255.255.255.0 |
| Default Router | 192.168.122.1 |
| DNS Server | 192.168.122.1 |

## Prepare the host
These instructions assume that this repository is cloned or copied to
your user's home directory on the host (e.g. `~/pxe-server`). The below
instructions follow that assumption.

Edit the `demo.conf` file and make sure the settings are correct. At a
minimum, you should adjust the credentials for simple content access.
The full list of options in the `demo.conf` file are shown here.

| Option           | Description |
| ---------------- | ----------- |
| SCA_USER         | Your username for Red Hat Simple Content Access |
| SCA_PASS         | Your password for Red Hat Simple Content Access |
| EDGE_USER        | The name of a user on the target edge device |
| EDGE_PASS        | The plaintext password for the user on the target edge device |
| EDGE_HASH        | A SHA-512 hash of the EDGE_PASS parameter |
| BOOT_ISO         | Minimal boot ISO used to create a custom ISO with additional kernel command line arguments and a custom kickstart file |
| CONTAINER_REPO   | The fully qualified name for your bootable container repository |
| HOSTIP           | The routable IP address to this host |
| SUBNET_MASK      | The subnet mask (e.g. 255.255.255.0) for this network |
| SUBNET_IP        | The first three of four tuples from the HOSTIP |
| ROUTER_IP        | The IP address for the default router |
| REGISTRYPORT     | The port for the local container registry |
| REGISTRYINSECURE | Boolean for whether the registry requires TLS |
| BOOTC_KICKSTART  | The kickstart file to send to the PXE client |

Make sure to download the `BOOT_ISO` file, e.g.
[rhel-9.4-x86_64-boot.iso](https://access.redhat.com/downloads/content/rhel)
to the local copy of this repository on your RHEL instance
(e.g. ~/pxe-server). Run the following script to register and update
the system.

    sudo ./register-and-update.sh
    sudo reboot

# Configure the rest of it
enable building bootable containers

    sudo ./config-bootc.sh

set up an insecure local registry

    sudo ./config-registry.sh

login to the registry using your Red Hat credentials to pull the base
image.

    podman login registry.redhat.io

build and push a bootc container image to the local registry. this will
be installed on the target device.

    . demo.conf
    podman build -f Containerfile -t $CONTAINER_REPO:v1 .
    podman push $CONTAINER_REPO:v1

tag the image as `prod` to mark it for our use case as the "production" image

    podman tag $CONTAINER_REPO:v1 $CONTAINER_REPO:prod
    podman push $CONTAINER_REPO:prod

# create a kickstart for the bootable container image
generate the kickstart file to be served by the tftp server for the PXE boot

    ./gen-ks.sh

set up a simple web server to host the kickstart file for the bootc container image and content for PXE http clients

    sudo ./config-httpd.sh

configure dhcpd server

    sudo ./config-dhcpd.sh

configure tftp server for PXE boot with contents from boot.iso

    sudo ./config-tftp.sh

