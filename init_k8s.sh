#/bin/sh
# ====== init k8s  ======
# disable swapoff
sudo swapoff -a
sudo sed -i '/swap/s/^/#/g' /etc/fstab
sudo cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# use yum install containerd
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum install containerd -y

#kill -TERM 1
# use binary install containerd
#sudo wget https://github.com/containerd/containerd/releases/download/v1.6.9/cri-containerd-cni-1.6.9-linux-amd64.tar.gz -O /vagrant_data/containerd-1.6.9.tar.gz
#sudo tar -C / -zxvf /vagrant_data/cri-containerd-cni-1.6.9-linux-amd64.tar.gz

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
#sudo cp /vagrant_data/containerd_conf.toml /etc/containerd/config.toml
## init containerd conf
##containerd config default | sudo tee /etc/containerd/config.toml
##sed 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
##sed 's/k8s.gcr.io\/pause/registry.aliyuncs.com\/google_containers\/pause/g' /etc/containerd/config.toml
##[plugins."io.containerd.grpc.v1.cri".registry]
##  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
##    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
##      endpoint = ["https://xxx.mirror.aliyuncs.com"]
##    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
##      endpoint = ["https://xxx.mirror.aliyuncs.com"]
sudo systemctl daemon-reload
sudo systemctl enable containerd --now
sudo ctr version

sudo cat /vagrant_data/hosts >> /etc/hosts

sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes --nogpgcheck
sudo systemctl enable kubelet --now

# kubeadm config print init-defaults --kubeconfig ClusterConfiguration > kubeadm.yml
sudo cp /vagrant_data/kubeadm.yml /etc/kubernetes/kubeadm.yml
# TODO replace hostname and host ip
sudo kubeadm config images list --config /etc/kubernetes/kubeadm.yml
sudo kubeadm config images pull --config /etc/kubernetes/kubeadm.yml


