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

# Letting iptables see bridged traffic
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# local dns setting
echo "192.168.10.10 k8s-m" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.10.10$i k8s-w$i" >> /etc/hosts; done

# apparmor disable
systemctl stop apparmor && systemctl disable apparmor

# package install
apt update
#apt-get install bridge-utils net-tools jq tree resolvconf wireguard ipset -y
apt-get install bridge-utils jq tree resolvconf wireguard ipset quagga -y

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

# quagga bgp config
PODCIDR=$(ip route | grep 'cilium_host src' | awk '{print $1}')

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
router bgp 64512
bgp graceful-restart
maximum-paths 4
maximum-paths ibgp 4
network $PODCIDR
neighbor 192.168.10.254 remote-as 64513
!
line vty
EOF

chown quagga:quagga /etc/quagga/bgpd.conf
chmod 640 /etc/quagga/bgpd.conf
systemctl enable bgpd && systemctl start bgpd

# bgp script
curl -s -o /root/bgp.sh https://raw.githubusercontent.com/gasida/NDKS/main/8/bgp.sh

# config dnsserver ip
echo -e "nameserver 168.126.63.1\nnameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

# Install Runtime - Docker
# curl -fsSL https://get.docker.com | sh
# cat <<EOF | tee /etc/docker/daemon.json
# {"exec-opts": ["native.cgroupdriver=systemd"]}
# EOF
# systemctl daemon-reload && systemctl restart docker

# Install Runtime - Containerd
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
apt-get install ca-certificates curl gnupg lsb-release -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install containerd.io -y
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i'' -r -e "/runc.options/a\            SystemdCgroup = true" /etc/containerd/config.toml
systemctl restart containerd

# swap off
swapoff -a

# Installing kubeadm kubelet and kubectl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
#apt-get install -y kubelet kubeadm kubectl
#apt-get install -y kubelet=<VERSION> kubectl=<VERSION> kubeadm=<VERSION>
apt-get install -y kubelet=1.21.7-00 kubectl=1.21.7-00 kubeadm=1.21.7-00
apt-mark hold kubelet kubeadm kubectl
