FROM registry.redhat.io/rhel9/rhel-bootc:latest

# add fips module to the initramfs
COPY 50-custom-added-modules.conf /usr/lib/dracut/dracut.conf.d
RUN    set -x \
    && kver="$(basename "$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)")" \
    && dracut -vf /usr/lib/modules/$kver/initramfs.img $kver

# configure an insecure local registry
RUN  mkdir -p /etc/containers/registries.conf.d
COPY 999-local-registry.conf /etc/containers/registries.conf.d/

# install a simple web server
RUN    dnf -y install httpd firewalld \
    && dnf clean all

# open holes in the firewall
RUN firewall-offline-cmd --service=http

# start the services automatically on boot
RUN systemctl enable httpd sshd firewalld

# create an awe-inspiring home page!
RUN echo '<h1 style="text-align:center;">Welcome to RHEL Image Mode</h1>' >> /var/www/html/index.html
