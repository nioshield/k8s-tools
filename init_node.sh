#/bin/sh
# ===== init system ======
sudo systemctl stop firewalld
sudo systemctl disable firewalld
#sudo systemctl stop NetworkManager 
#sudo systemctl disable  NetworkManager

sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

## open password auth for backup if ssh key doesn't work, bydefault, username=vagrant password=vagrant
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo cat /vagrant_data/host.pub >> /home/vagrant/.ssh/authorized_keys
sudo systemctl restart sshd

#sudo su
sudo rename '.repo' '.repo.bak' /etc/yum.repos.d/*.repo
sudo cp /vagrant_data/Centos-8.repo /etc/yum.repos.d/CentOS-Base.repo
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
sudo dnf --disablerepo '*' --enablerepo=extras swap centos-linux-repos centos-stream-repos -y
sudo dnf distro-sync -y

sudo yum clean all && yum makecache && yum update -y && yum install vim net-tools -y


