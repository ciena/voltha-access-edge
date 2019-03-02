# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "2048"
  end

  config.vm.provision "shell", inline: <<-SHELL
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y curl git mercurial python-pip mininet make binutils bison gcc build-essential openvswitch-switch sshpass docker-ce docker-ce-cli containerd.io
    pip install -r /vagrant/requirements.txt
    usermod -aG docker vagrant
  SHELL

  config.vm.define "network" do |net|
      net.vm.hostname="network"
      net.vm.network "private_network", ip: "192.168.33.10"
      net.vm.provision "shell", inline: <<-NET
          ip link add s3-gre1 type gretap local 192.168.33.10 remote 192.168.33.11
          ip link set s3-gre1 up
          ip link add s4-gre1 type gretap local 192.168.33.10 remote 192.168.33.12
          ip link set s4-gre1 up
          ip link add s5-gre1 type gretap local 192.168.33.10 remote 192.168.33.13
          ip link set s5-gre1 up
          ip link add s6-gre1 type gretap local 192.168.33.10 remote 192.168.33.14
          ip link set s6-gre1 up
          docker run -tid --name onos --rm -p 8101:8101 -p 8181:8181 -p 6653:6653 -e ONOS_APPS=openflow,segmentrouting,layout ciena/onos:1.15.1-SNAPSHOT
      NET
  end

  config.vm.define "management" do |mgt|
      mgt.vm.hostname="management"
      mgt.vm.network "private_network", ip: "192.168.33.11"
      mgt.vm.provision "shell", inline: <<-MGT
          snap install kubectl --classic
          snap install helm --classic
          ip link add gre1 type gretap local 192.168.33.11 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:01:03
          ip link set gre1 up
          ip addr add 10.1.1.3/24 dev gre1
          ip route add 10.1.2.0/24 via 10.1.1.254
          ip route add 10.1.3.0/24 via 10.1.1.254
          ip route add 10.1.4.0/24 via 10.1.1.254
          docker run -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher
      MGT
  end

  config.vm.define "compute1" do |c1|
      c1.vm.hostname="compute1"
      c1.vm.network "private_network", ip: "192.168.33.12"
      c1.vm.provision "shell", inline: <<-C1
          ip link add gre1 type gretap local 192.168.33.12 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:02:03
          ip link set gre1 up
          ip addr add 10.1.2.3/24 dev gre1
          ip route add 10.1.1.0/24 via 10.1.2.254
          ip route add 10.1.3.0/24 via 10.1.2.254
          ip route add 10.1.4.0/24 via 10.1.2.254
      C1
  end

  config.vm.define "compute2" do |c2|
      c2.vm.hostname="compute2"
      c2.vm.network "private_network", ip: "192.168.33.13"
      c2.vm.provision "shell", inline: <<-C2
          ip link add gre1 type gretap local 192.168.33.13 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:03:03
          ip link set gre1 up
          ip addr add 10.1.3.3/24 dev gre1
          ip route add 10.1.1.0/24 via 10.1.3.254
          ip route add 10.1.2.0/24 via 10.1.3.254
          ip route add 10.1.4.0/24 via 10.1.3.254
      C2
  end

  config.vm.define "compute3" do |c3|
      c3.vm.hostname="compute3"
      c3.vm.network "private_network", ip: "192.168.33.14"
      c3.vm.provision "shell", inline: <<-C3
          ip link add gre1 type gretap local 192.168.33.14 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:04:03
          ip link set gre1 up
          ip addr add 10.1.4.3/24 dev gre1
          ip route add 10.1.1.0/24 via 10.1.4.254
          ip route add 10.1.2.0/24 via 10.1.4.254
          ip route add 10.1.3.0/24 via 10.1.4.254
      C3
  end

end
