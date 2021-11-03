#!/usr/bin/env bash

# install tools
apt-get install keepalived haproxy -y

# config keepalived
cat <<EOF > /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state BACKUP
    interface enp0s8
    virtual_router_id 50
    priority 100
    advert_int 1
    nopreempt
    authentication {
        auth_type PASS
        auth_pass cloudneta
    }
    virtual_ipaddress {
        192.168.100.100
    }
}
EOF
systemctl start keepalived && systemctl enable keepalived

# you need to enable HAProxy and Keepalived to bind to non-local IP address, that is to bind to the failover IP address (Floating IP)
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sysctl -p

# config haproxy
cat <<EOF >> /etc/haproxy/haproxy.cfg
frontend kubernetes-master-lb
    bind 192.168.100.100:16443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    option tcplog
    server master0 192.168.100.10:6443 check
EOF
for (( m=1; m<=$1; m++ )); do echo "    server master$m 192.168.100.1$m:6443 check" >> /etc/haproxy/haproxy.cfg; done
systemctl restart haproxy && systemctl enable haproxy

# join kubernetes 
MYIP=$(ip addr show enp0s8 | grep -w inet | grep -v 'inet 127' | awk '{ print $2 }' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
kubeadm join 192.168.100.100:16443 --control-plane --apiserver-advertise-address=$MYIP --discovery-token-unsafe-skip-ca-verification --token 123456.1234567890123456 --certificate-key=1234567890123456789012345678901234567890123456789012345678901234

# config for master node only 
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# etcdctl install
apt install etcd-client -y

# source bash-completion for kubectl kubeadm
source <(kubectl completion bash)
source <(kubeadm completion bash)

## Source the completion script in your ~/.bashrc file
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile

## alias kubectl to k 
echo 'alias k=kubectl' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile

## kubectx kubens install
git clone https://github.com/ahmetb/kubectx /opt/kubectx
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

## kube-ps1 install
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1
cat <<"EOT" >> ~/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=false
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT
kubectl config rename-context "kubernetes-admin@kubernetes" "admin-k8s"

## kube-tail install
curl -O https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
chmod 744 kubetail && mv kubetail /usr/bin
curl -o /root/kubetail.bash https://raw.githubusercontent.com/johanhaleby/kubetail/master/completion/kubetail.bash
cat <<EOT>> ~/.bash_profile
source /root/kubetail.bash
EOT