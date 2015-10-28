# -*- mode: ruby -*-
# vi: set ft=ruby :

PRIVATE_IP_ADDRESS = "192.168.33.18"

Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.network "private_network", ip: PRIVATE_IP_ADDRESS

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "setup.sh",
    args: ["--site-host", PRIVATE_IP_ADDRESS]
end
