# Network Boot of Red Hat Enterprise Linux (RHEL) Image Mode
This project shows how to setup a SERVER that supports PXE installations
of a CLIENT device using a RHEL Image Mode bootable container image. The
terms SERVER and CLIENT will be used consistently throughout this
document. The SERVER also runs a lightweight container registry for
managing the RHEL Image Mode installations. The full list of services
running on the SERVER include:

* dhcpd - provides IP address and "next server" to complete PXE boot process
* tftpd - supports legacy PXE boot via TFTP protocol
* httpd - supports UEFI PXE with HTTP and hosts the kickstart file to install from the registry
* container registry - serves the bootable container image for the installation

The SERVER also includes tooling both to build a bootable container image
that can be installed on a CLIENT device via PXE boot and to create a
small web application deployed as a container application on the CLIENT.

There's a great [article](https://developers.redhat.com/articles/2024/08/20/bare-metal-deployments-image-mode-rhel)
by [Ben Breard](https://developers.redhat.com/author/ben-breard) that discusses PXE booting a client with a RHEL Image Mode
container image.

## Prepare your network for a new DHCP server
Since you're creating a new DHCP server, you'll need to make sure that there
is no competing DHCP server on the target network. How to do this really
depends on your environment.

At a minimum, you should identify the following network parameters for
your environment. These values will be used during SERVER installation
and/or provided by the `demo.conf` file after installation when
configuring the various services.

|    Parameter   |     Value     |
| -------------- | ------------- |
| IP Address     | 192.168.40.2  |
| Subnet Mask    | 255.255.255.0 |
| Default Router | 192.168.40.1  |
| DNS Server     | 192.168.40.1  |

### Testing on a physical network
On a physical network, you'll need to turn off DHCP services on
other routers or servers since the SERVER will be providing DHCP
addresses. Again, how you do this really depends on the environment
you're using, but it's important to avoid conflicting DHCP services.

### Testing with KVM virtual machines
The following instructions address how to configure a host running KVM
to support testing this capability. I did the following on a laptop that
had libvirt installed with guest VMs as my SERVER and CLIENT.

You can create a new virtual network using the libvirt `virsh` command
and the XML file included in this repository. Please adjust settings in
the `pxe.xml` file to match your desired network settings if they differ
from those enumerated above.

Use the following commands to validate the XML and create a persistent
virtual network that auto-starts at host system boot.

    sudo virsh net-define --validate pxe.xml
    sudo virsh net-autostart pxe
    sudo virsh net-start pxe

Finally, check that the virtual network is running.

    sudo virsh net-info pxe

The virtual network should show as active and persistent with auto-start
enabled.

## Start with minimal RHEL 9 installation
Start with a minimal install of the latest RHEL 9 release on the
SERVER (either a baremetal device or a guest VM). You can get the
latest RHEL 9 installation ISO files from the [Red Hat Customer Portal](https://access.redhat.com/downloads/content/rhel).

Make sure to use UEFI firmware, if you're able to, when installing the
SERVER. Also make sure there's sufficient disk space on the SERVER to
support the demo. I typically configure a 128 GiB disk.

Make sure to enable FIPS mode during installation, so that configuring
FIPS on any bootable container you create also uses properly defined
keys. To do that, select `Install Red Hat Enterprise Linux 9.x` within
the GRUB boot menu and then press `e` to edit the boot commandline. Add
`fips=1` to the end of the line that begins with `linuxefi` and then
press CTRL-X to continue booting.

During RHEL installation, configure a regular user with administrator
(`sudo`) privileges on the host.

You'll also need to manually configure a static IP address for the SERVER
as it will be the DHCP server for it's network. Use the same settings
outlined above in preparing the network.

## Prepare the SERVER to build and distribute containers
These instructions assume that this repository is cloned or copied to
your user's home directory on the SERVER (e.g. `~/bootc-pxe-server`). The
below instructions follow that assumption.

Edit the `demo.conf` file and make sure the settings are correct. At a
minimum, you should adjust the credentials for simple content access to
enable pulling packages from the Red Hat repositories. The full list of
options in the `demo.conf` file are shown here.

#### Red Hat Simple Content Access
| Parameter |  Description  |
| --------- | ------------- |
| SCA_USER  | Your username |
| SCA_PASS  | Your password |

#### Target Edge Device
| Parameter |               Description               |
| --------- | --------------------------------------- |
| EDGE_USER | User name                               |
| EDGE_PASS | Plaintext password                      |
| EDGE_HASH | SHA-512 hash of the EDGE_PASS parameter |

#### DHCP Settings
|   Parameter   |                                   Description                                   |
| ------------- | ------------------------------------------------------------------------------- |
| HOSTIP        | The routable IP address to the PXE server                                       |
| SUBNET        | The first three tuples of the IPv4 address of the subnetwork for the PXE server |
| SUBNET_MASK   | The subnet mask (e.g. 255.255.255.0) for the PXE server                         |
| SUBNET_IP     | The network address for the subnetwork                                          |
| ROUTER_IP     | The IP address for the default router                                           |
| DHCP_IP_START | The start of the dynamically assigned IP address range                          |
| DHCP_IP_END   | The end (inclusive) of the dynamically assigned IP address range                |

#### Bootable Container Image and Container Registry
|     Parameter      |                            Description                               |
| ------------------ | ---------------------------------------------------------------------|
| BOOT_ISO           | Minimal boot ISO to extract kernel and initramfs to support PXE boot |
| REGISTRYPORT       | The port for the local container registry                            |
| OS_CONTAINER_REPO  | The fully qualified name for your bootable container repository      |
| APP_CONTAINER_REPO | The fully qualified name for your container application repository   |
| REGISTRYINSECURE   | Boolean for whether the registry requires TLS                        |
| BOOTC_KICKSTART    | The kickstart file to send to the PXE client                         |
| EXTRA_BOOT_ARGS    | Additional kernel boot arguments as a shell array                    |

Make sure to download the latest `BOOT_ISO` file, e.g.
[rhel-9.5-x86_64-boot.iso](https://access.redhat.com/downloads/content/rhel)
to the local copy of this repository on the SERVER
(e.g. ~/bootc-pxe-server). Run the following script to register and
update the system.

    sudo ./register-and-update.sh
    sudo reboot

### Install tooling to build containers
The network installation supports RHEL Image Mode, aka bootable
containers. Install the tooling necessary to support creating a bootable
container image as well as container applications on the SERVER.

    sudo ./config-bootc.sh

### Configure a local image registry
During the network install, the CLIENT will need to pull the bootable
container image and container application images from a registry. This
can be a secure registry, but for this example we'll install an insecure
local image registry on the SERVER.

    sudo ./config-registry.sh

## Managing bootable container images
It's strongly advised to carefully plan how you want to build and
maintain your bootable container images. This example will create a
`base` bootable container image that includes a simple web server to
validate that the system is functional. Another bootable container
image, `webapp`, will inherit from `base` and add a simple container
application to show how to deploy container applications to the CLIENT
using the podman/systemd/quadlet technology. You could customize the
`base` bootable container image (e.g. adding device-specific drivers)
by building a child container image inheriting from `base`. You could
then inherit from that bootable container image to deploy any container
applications. This is illustrated here.

![Relationship of bootable container images](/images/manage-bootable-container-images.png)

A little planning here can go a long way to simplifying maintenance of
both your CLIENT operating system and any container applications.

### Build the base bootable container image
In order to build the bootable container image, you'll need to pull the
base layer from the Red Hat registry. Use your Red Hat credentials to
login to the registry so the later build can pull the base layer.

    . demo.conf
    podman login --username $SCA_USER --password $SCA_PASS registry.redhat.io

We're now ready to build bootable container image and push it to the
local image registry. This bootable container image will be installed
on the CLIENT natively as the operating system. The container image is
tagged as `base` so that you can inherit from it for additional customized
bootable container images.

    podman build --pull=newer -f BaseContainerfile -t $OS_CONTAINER_REPO:base .
    podman push $OS_CONTAINER_REPO:base

The base operating system image includes a simple web application
that provides some data about its host. The demo is setup to have the
CLIENT look for container images tagged as `prod` for installation and
updates. We'll tag the `base` image as `prod` and push it to the registry
so it gets deployed to the CLIENT during the PXE boot.

    podman tag $OS_CONTAINER_REPO:base $OS_CONTAINER_REPO:prod
    podman push $OS_CONTAINER_REPO:prod

### Build a simple container application
Let's build a simple container application that can run on the
CLIENT. This web application displays a rotating wireframe cube.

    podman build --pull=newer -f AppContainerfile -t $APP_CONTAINER_REPO:v1 .

Push the simple container application to the registry so the CLIENT can
fetch it later when we update.

    podman push $APP_CONTAINER_REPO:v1

### Extend the operating system to deploy the simple container application
Next, we'll extend the existing bootable container image to deploy the
simple container application. The following uses the quadlet technology to
allow systemd, which manages the operating system services on the CLIENT,
to start the container application at boot time and restart it if it
should fail. The detailed commands to do this are automatically generated
based on a simple descriptor file under `/etc/containers/systemd`. This
is a very lightweight way to deploy container applications that don't
require orchestration.

    podman build --pull=newer -f DeployAppContainerfile \
        -t $OS_CONTAINER_REPO:webapp \
        --build-arg BASE_IMAGE=$OS_CONTAINER_REPO:base \
        --build-arg APP_IMAGE=$APP_CONTAINER_REPO:v1 .

We'll use the `webapp` tag to deploy the container application to the
CLIENT. Push the updated bootable container image to the registry. This is
not labeled as `prod` yet, so it won't be installed via PXE and updates
will not pull this change just yet.

    podman push $OS_CONTAINER_REPO:webapp

## Prepare the PXE boot services
At this point, we've built our `base` bootable container image that holds
the operating system content. This is also tagged as `prod` to indicate
it's the intended production operating system. We also built a simple
web application packaged as a container and we also built an updated
operating system image, tagged as `webapp`, to deploy that application
to the running system on the CLIENT.

Next, let's prepare the SERVER to support PXE booting the CLIENT
systems. The server will use the bootable container image tagged as
`prod` for the initial installation to the CLIENT.

### Create a kickstart for automated network installations
Now, create the kickstart file that will be used to automate the
installation of the CLIENT via the network installation. Of note is the
`ostreecontainer` directive in the generated kickstart file, which will
pull operating system content for the CLIENT from the local container
registry.

    ./gen-ks.sh

Review the generated file using the following command:

    . demo.conf
    less $BOOTC_KICKSTART

### Create web server for kickstart and UEFI HTTP installs
Set up a simple web server to host the kickstart file you previously
generated as well as the kernel and initial ram disk for network
installations. This server also supports UEFI HTTP client installations.

    sudo ./config-httpd.sh

### Create the DHCP server
The SERVER acts as the DHCP server for its local area network, providing
IP addresses, routers, DNS servers, and other information including
network boot parameters to its clients.

    sudo ./config-dhcpd.sh

### Create the TFTP server for PXE boot clients
The last thing we configure is the TFTP server for legacy PXE boot
clients. This takes content from the RHEL 9.5 boot ISO to provide the
kernel and initial ram disk to the PXE clients.

    sudo ./config-tftp.sh

## Review the setup
Now that we've installed the services necessary for PXE and UEFI HTTP
client network boots, we can review all the files that were created and
make sure that the services are running.

First, let's make sure the image registry is running and that the bootable
container image is available for network installations.

    systemctl status --no-pager -l local-registry.service tftp.socket dhcpd httpd

You should see that the services are `active`. Check that the bootable
container image repository is available for installations.

    . demo.conf
    curl -s http://$HOSTIP:$REGISTRYPORT/v2/_catalog

You should see the bootable container image repository listed.

Next, check the DHCP server configuration.

    sudo cat /etc/dhcp/dhcpd.conf

You should see configuration set for both PXE and UEFI HTTP clients.

Confirm the web server is running and has the RHEL boot content to
support an network installation.

    systemctl status httpd

The service should be `active`. You can also review that the RHEL boot
content is available to clients as well.

    find /var/www/html

You should see the kickstart file under `/var/www/html/` and the RHEL
network boot content under `/var/www/html/redhat/`.

Finally, you can review the RHEL network boot content for legacy PXE
clients using the following command:

    find /var/lib/tftpboot

You can also review the GRUB boot menu entries here that will install
the guest operating system.

    cat /var/lib/tftpboot/redhat/EFI/BOOT/grub.cfg

## Test the CLIENT
We are now prepared to demonstrate how we can PXE boot a CLIENT and then
update it by deploying a simple web container application.

### PXE boot and validate the CLIENT is running
How to PXE boot your CLIENT will vary based on the installed UEFI
BIOS. Restart the CLIENT after enabling PXE boot. You will see the
bootable container image being downloaded and written to the CLIENT during
the installation. When the CLIENT reboots, you'll be at a standard RHEL
login prompt.

You can confirm that the CLIENT operating system is installed by
browsing to the CLIENT's IP address. You can discover the IP address
by reviewing the `/var/lib/dhcpd/dhcp.leases` file on the SERVER and
then matching the MAC address for the CLIENT with the entry for the IP
address assignment. On the SERVER,

    cat /var/lib/dhcpd/dhcp.leases

### Test the default PHP web application on the CLIENT
Once you know the IP address, browse to the URL `http://CLIENT_IP` and
you should see a PHP information page, describing various facts about
the CLIENT.

### Test the web console on the CLIENT
You can also review the web console for the client which enables you
to drill down into many aspects of the edge device. To access the web
console, browse to the URL `https://CLIENT_IP:9090` and you should see
the login page. Use the credentials `EDGE_USER` and `EDGE_PASS` in the
`demo.conf` file to login to the web console. You'll then be presented
with the web console page with a navigation bar on the left hand side to
drill into various aspects of the system. You can enable administrative
access by clicking on that link and then using the `EDGE_PASS` parameter
to enable it.

### Deploy a container application by updating the CLIENT
Next, let's update the CLIENT to deploy the simple container web
application. First, verify that no container application is currently
running on the CLIENT. Browse to the URL `http://CLIENT_IP:8080` using
the CLIENT IP address you discovered previously. You should get an error
as no such application is listening on port 8080.

On the SERVER, tag the `webapp` image as `prod` and push it to the
registry to indicate that this is the updated production bootable
container image.

    cd ~/bootc-pxe-server
    . demo.conf
    podman tag $OS_CONTAINER_REPO:webapp $OS_CONTAINER_IMAGE:prod
    podman push $OS_CONTAINER_REPO:prod

The credentials to login to the CLIENT are the `EDGE_USER` and `EDGE_PASS`
parameters in the `demo.conf` file on the SERVER.

Connect to the CLIENT using either ssh or a connection to its console.
Update to the latest production operating system image using the
following command:

    sudo bootc update

You should see output indicating the number of container layers used to
initially install the operating system on the CLIENT and the number of
changed layers for the update. The CLIENT is not running as a container,
but it's using container technology to deploy and maintain it's natively
installed operating system.

Reboot the CLIENT once the operating system update has finished.

    sudo reboot

### Test the container application
After the CLIENT reboots, give it a minute or so to pull the web container
application image and start it. You should then be able to browse to
the CLIENT at the URL `http://CLIENT_IP:8080`. You should see a welcome
message with a rotating cube.
