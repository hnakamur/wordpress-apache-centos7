# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANT_CONFIGURATION_VERSION = 2

Vagrant.configure(VAGRANT_CONFIGURATION_VERSION) do |config|
  config.vm.box = "centos/7"

  config.vm.network "private_network", ip: "192.168.33.18"

  #config.vm.synced_folder ".", "/vagrant", type: "nfs"

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048", "--cpus", "2", "--ioapic", "on"]
  end
end
