#!/usr/bin/env bash
node=${1:-management}
rancher_ver=${2:-v1.6.25}
major=$(echo $rancher_ver | cut -d "." -f1)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y curl git mercurial python-pip mininet make binutils bison gcc build-essential openvswitch-switch sshpass containerd.io docker-ce docker-ce-cli
usermod -aG docker vagrant
pip install -r /vagrant/requirements.txt
mkdir -p /home/vagrant/.ssh
cp /vagrant/ssh/id_rsa /vagrant/ssh/id_rsa.pub /vagrant/ssh/config /home/vagrant/.ssh/
cat /vagrant/ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/id_rsa /home/vagrant/.ssh/id_rsa.pub /home/vagrant/.ssh/config /home/vagrant/.ssh/authorized_keys

if [ "$node" = "network" ]; then
    echo "Starting ONOS on $node"
    docker run -tid --name onos --rm -p 8101:8101 -p 8181:8181 -p 6653:6653 -e ONOS_APPS=openflow,segmentrouting,layout ciena/onos:1.15.1-SNAPSHOT
fi

if [ "$node" = "management" ]; then
    git clone https://github.com/kubernetes-incubator/kubespray.git -b release-2.8 /opt/kubespray
    pip install -r /opt/kubespray/requirements.txt
    cp -rfp /opt/kubespray/inventory/sample /opt/kubespray/inventory/voltha
    cp /vagrant/hosts.ini /opt/kubespray/inventory/voltha/hosts.ini
    chown -R $(id -u):$(id -g) /opt/kubespray
fi

if [[ "$node" =~ ^compute[123]$ ]]; then
    snap install kubectl --classic
fi
