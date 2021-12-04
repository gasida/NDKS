#!/usr/bin/env bash

# root password
echo ">>>> root password <<<<<<"
printf "qwe123\nqwe123\n" | passwd

# config sshd
echo ">>>> ssh-config <<<<<<"
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl restart sshd

# profile bashrc settting
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> .bashrc

# apparmor disable
systemctl stop apparmor && systemctl disable apparmor

# package install
apt update
apt-get install net-tools jq tree resolvconf quagga lynx -y

# config dnsserver ip
echo -e "nameserver 168.126.63.1\nnameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

# ip forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p
sysctl --system

# dummy interface 
modprobe dummy
ip link add loop1 type dummy
ip link set loop1 up
ip addr add 10.1.2.254/24 dev loop1

# quagga logging
mkdir /var/log/quagga
chown quagga:quagga /var/log/quagga

# quagga config
cat <<EOF > /etc/quagga/zebra.conf
hostname zebra
password zebra
enable password zebra
!
log file /var/log/quagga/zebra.log
!
line vty
EOF
systemctl enable zebra && systemctl start zebra

cat <<EOF > /etc/quagga/bgpd.conf
hostname zebra-bgpd
password zebra
enable password zebra
!
log file /var/log/quagga/bgpd.log
!
debug bgp events
debug bgp filters
debug bgp fsm
debug bgp keepalives
debug bgp updates
!
router bgp 64514
bgp router-id 192.168.20.100
bgp graceful-restart
network 10.1.2.0/24
neighbor 192.168.20.254 remote-as 64513
!
line vty
EOF

chown quagga:quagga /etc/quagga/bgpd.conf
chmod 640 /etc/quagga/bgpd.conf
systemctl enable bgpd && systemctl start bgpd

# Install Apache
apt install apache2 -y
echo -e "<h1>Web Server : $(hostname)</h1>" > /var/www/html/index.html
