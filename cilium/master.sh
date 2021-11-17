#!/usr/bin/env bash

# init kubernetes 
kubeadm init --skip-phases=addon/kube-proxy --token 123456.1234567890123456 --token-ttl 0 --pod-network-cidr=172.16.0.0/16 --apiserver-advertise-address=192.168.200.10

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

# kubectx kubens install
git clone https://github.com/ahmetb/kubectx /opt/kubectx
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

# kube-ps1 install
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
kubectl config rename-context "kubernetes-admin@kubernetes" "cilium-k8s"

## kube-tail install
curl -O https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
chmod 744 kubetail && mv kubetail /usr/bin
curl -o /root/kubetail.bash https://raw.githubusercontent.com/johanhaleby/kubetail/master/completion/kubetail.bash
cat <<EOT >> ~/.bash_profile
source /root/kubetail.bash
EOT

# Install Helm v3
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install Clilium Hubble w/Helm
helm repo add cilium https://helm.cilium.io/
#helm install cilium cilium/cilium --version 1.10.5 --namespace kube-system --set kubeProxyReplacement=strict --set k8sServiceHost=192.168.200.10 --set k8sServicePort=6443 --set ipam.mode=cluster-pool --set ipam.operator.clusterPoolIPv4PodCIDR=172.16.0.0/16 --set ipam.operator.clusterPoolIPv4MaskSize=24 --set hubble.relay.enabled=true --set hubble.ui.enabled=true
helm install cilium cilium/cilium --version 1.10.5 --namespace kube-system --set kubeProxyReplacement=strict --set k8sServiceHost=192.168.200.10 --set k8sServicePort=6443 --set ipam.mode=kubernetes –set ipam.operator.clusterPoolIPv4PodCIDR=172.16.0.0/16 –set ipam.operator.clusterPoolIPv4MaskSize=24 --set tunnel=geneve
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

# Install Hubble Client
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz
tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin

# Change Service Type For hubble-ui
#kubectl patch -n kube-system svc hubble-ui -p '{"spec": {"type": "NodePort"}}'
