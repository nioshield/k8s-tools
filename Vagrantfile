# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 2.3.2"

boxes = [
    {
        :name => "k8s-master",
        :eth1 => "192.168.56.11",
        :mem => "2048",
        :cpu => "2"
    },
    {
        :name => "k8s-node1",
        :eth1 => "192.168.56.12",
        :mem => "2048",
        :cpu => "1"
    },
    {
        :name => "k8s-node2",
        :eth1 => "192.168.56.13",
        :mem => "2048",
        :cpu => "1"
    }

]

Vagrant.configure(2) do |config|

  config.vm.box = "centos8"
  boxes.each do |opts|
    config.vm.define opts[:name] do |config|
      config.vm.hostname = opts[:name]
      config.vm.provider "vmware_fusion" do |v|
        v.vmx["memsize"] = opts[:mem]
        v.vmx["numvcpus"] = opts[:cpu]
      end
      config.vm.provider "virtualbox" do |v|
        v.customize ["modifyvm", :id, "--memory", opts[:mem]]
        v.customize ["modifyvm", :id, "--cpus", opts[:cpu]]
      end

      config.vm.synced_folder "./data", "/vagrant_data", type: "nfs", mount_options: ["nolock", "vers=3", "udp", "noatime", "actimeo=1"]
      config.vm.network :private_network, ip: opts[:eth1]
    end
  end
  #config.vm.provision "shell", privileged: true, path: "./setup.sh"
end
