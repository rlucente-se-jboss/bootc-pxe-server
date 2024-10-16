# WORK IN PROGRESS
# Setup a PXE Server
This project shows how to setup a PXE Server that supports PXE
installations of a RHEL Image Mode bootable container image. This server
also runs a lightweight registry for RHEL Image Mode installations. This
project envisions a combined server that is running services to support
PXE booting of RHEL Image Mode including:

* dhcpd - provides IP address and "next server" to complete PXE boot process
* tftpd - supports legacy PXE boot via TFTP protocol
* httpd - supports UEFI PXE with HTTP and hosts the kickstart file to install from the registry
* container registry - serves the bootable container image for the installation

The same server is also used to build a bootable container image that
can be installed on a target edge device via PXE boot.

There's also a great [article](https://developers.redhat.com/articles/2024/08/20/bare-metal-deployments-image-mode-rhel) that discusses this approach.

## Prepare your network for a new DHCP server
Since you're creating a new DHCP server, you need to make sure that there
is no competing DHCP server on the target network. How to do this really
depends on your environment. I ran this as a guest VM using libvirt on
RHEL. The specific steps I took were first to edit the default virtual
network.

First, stop the default network.

    sudo virsh net-destroy default

Edit the default network configuration.

    sudo virsh net-edit default

Then delete the `<dhcp ... />` stanza and save the file. On my
installation, I removed the following lines.

    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>

Next, restart the virtual network for the changes to take effect.

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
| Configuration | Manual |
| IP Address | 192.168.122.2 |
| Subnet Mask | 255.255.255.0 |
| Default Router | 192.168.122.1 |
| DNS Server | 192.168.122.1 |

## Prepare the host
These instructions assume that this repository is cloned or copied to
your user's home directory on the host (e.g. `~/bootc-pxe-server`). The
below instructions follow that assumption.

Edit the `demo.conf` file and make sure the settings are correct. At a
minimum, you should adjust the credentials for simple content access.
The full list of options in the `demo.conf` file are shown here.

| Red Hat Simple Content Access |
| ----------------------------- |
| SCA_USER | Your username |
| SCA_PASS | Your password |

| Target Edge Device |
| ------------------ |
| EDGE_USER | User name |
| EDGE_PASS | Plaintext password |
| EDGE_HASH | SHA-512 hash of the EDGE_PASS parameter |

| DHCP Settings |
| ------------- |
| HOSTIP      | The routable IP address to the PXE server |
| SUBNET      | The first three tuples of the IPv4 address of the subnetwork for the PXE server |
| SUBNET_MASK | The subnet mask (e.g. 255.255.255.0) for the PXE server |
| SUBNET_IP   | The network address for the subnetwork |
| ROUTER_IP   | The IP address for the default router |

| Bootable Container |
| ------------------ |
| BOOT_ISO         | Minimal boot ISO to extract kernel and initramfs to support PXE boot |
| REGISTRYPORT     | The port for the local container registry |
| CONTAINER_REPO   | The fully qualified name for your bootable container repository |
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

generate the kickstart file to be served by the tftp server for the PXE boot

    ./gen-ks.sh

set up a simple web server to host the kickstart file for the bootc container image and content for PXE http clients

    sudo ./config-httpd.sh

configure dhcpd server

    sudo ./config-dhcpd.sh

configure tftp server for PXE boot with contents from boot.iso

    sudo ./config-tftp.sh

