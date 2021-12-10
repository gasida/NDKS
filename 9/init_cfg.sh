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
net.bridge.bridge-nf-call-iptables  = 1
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
apt-get install bridge-utils jq tree resolvconf wireguard ipset -y

# config dnsserver ip
echo -e "nameserver 168.126.63.1\nnameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

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
