# Copyright 2019 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
rancher_version = ENV["RANCHER_VERSION"] || "v1.6.25"
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = "6048"
  end

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
          ip link add s6-gre2 type gretap local 192.168.33.10 remote 192.168.33.15
          ip link set s6-gre2 up
          ip link add s7-gre1 type gretap local 192.168.33.10 remote 192.168.33.16
          ip link set s7-gre1 up
          ufw disable
      NET
      net.vm.provision "shell", path: "provision.sh", args: [ "network", rancher_version ]
  end

  config.vm.define "management" do |mgt|
      mgt.vm.hostname="management"
      mgt.vm.network "private_network", ip: "192.168.33.11"
      mgt.vm.provision "shell", inline: <<-MGT
          ip link add gre1 type gretap local 192.168.33.11 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:01:03
          ip link set gre1 up
          ip addr add 10.1.1.3/24 dev gre1
          ip route add 10.1.2.0/24 via 10.1.1.254
          ip route add 10.1.3.0/24 via 10.1.1.254
          ip route add 10.1.4.0/24 via 10.1.1.254
          ip route add 10.1.5.0/24 via 10.1.1.254
	  ufw disable 
      MGT
      mgt.vm.provision "shell", path: "provision.sh", args: [ "management", rancher_version ]
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
          ip route add 10.1.5.0/24 via 10.1.2.254
 	  ufw disable
      C1
      c1.vm.provision "shell", path: "provision.sh", args: [ "compute1", rancher_version ]
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
          ip route add 10.1.5.0/24 via 10.1.3.254
 	  ufw disable
      C2
      c2.vm.provision "shell", path: "provision.sh", args: [ "compute2", rancher_version ]
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
          ip route add 10.1.5.0/24 via 10.1.4.254
 	  ufw disable
      C3
      c3.vm.provision "shell", path: "provision.sh", args: [ "compute3", rancher_version ]
  end

  config.vm.define "olt" do |olt|
      olt.vm.hostname="olt"
      olt.vm.provider "virtualbox" do |vb|
          vb.gui = false
          vb.memory = "2048"
      end
      olt.vm.network "private_network", ip: "192.168.33.15"
      olt.vm.provision "shell", inline: <<-OLT
          # Set up the fabric connection
          ip link add gre1 type gretap local 192.168.33.15 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:04:04
          ip link set gre1 up

          # Set up link between ONU and RG
          sudo ip link add onu_rg type veth peer name rg_onu
          sudo ip link set onu_rg up
          sudo ip link set rg_onu up
  
          # Set up link for OLT NNI
          sudo ip link add nni-veth type veth peer name olt-nni-veth
          sudo ip link set nni-veth up
          sudo ip link set olt-nni-veth up
          sudo ip link add dev nni0 type bridge
          sudo ip link set nni-veth master nni0
          sudo ip link set gre1 master nni0
          sudo ip link set nni0 up
          echo 8 > /sys/class/net/nni0/bridge/group_fwd_mask

          ip addr add 10.1.4.4/24 dev nni0
          ip route add 10.1.1.0/24 via 10.1.4.254
          ip route add 10.1.2.0/24 via 10.1.4.254
          ip route add 10.1.3.0/24 via 10.1.4.254
          ip route add 10.1.5.0/24 via 10.1.4.254
 	  ufw disable
      OLT
      olt.vm.provision "shell", path: "provision.sh", args: [ "olt", rancher_version ]
  end

  config.vm.define "backoffice" do |olt|
      olt.vm.hostname="backoffice"
      olt.vm.provider "virtualbox" do |vb|
          vb.gui = false
          vb.memory = "2048"
      end
      olt.vm.network "private_network", ip: "192.168.33.16"
      olt.vm.provision "shell", inline: <<-BO
          ip link add gre1 type gretap local 192.168.33.16 remote 192.168.33.10
          ip link set gre1 address c0:ff:ee:00:05:03
          ip link set gre1 up
          ip addr add 10.1.5.3/24 dev gre1
          ip route add 10.1.1.0/24 via 10.1.5.254
          ip route add 10.1.2.0/24 via 10.1.5.254
          ip route add 10.1.3.0/24 via 10.1.5.254
          ip route add 10.1.4.0/24 via 10.1.5.254
          ufw disable
      BO
      olt.vm.provision "shell", path: "provision.sh", args: [ "backoffice", rancher_version ]
  end

end
