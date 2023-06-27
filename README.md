# vagrant-k8s

vagrant install and deploy k8s tools

# Description

## Vagrantfile
Defined vagrant cluse info ,include 3 node (one master and 2 node); 

## init_node.sh
init centos8 system config, yum update and vim; blabla....

## init_k8s.sh
about k8s node update, close swap and add k8s and containerd config, install kubelet/kubeadm 

## data
host info and host pub key 

## kind dev env
```
 cp /etc/apt/sources.list /etc/apt/sources.list.bak
 sed -i -re 's/([a-z]{2}\.)?archive.ubuntu.com|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
 apt-get update && apt-get dist-upgrade
```
