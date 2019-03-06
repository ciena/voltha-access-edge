#!/usr/bin/env bash
node=${1:-management}
rancher_ver=${2:-stable}
major=$(echo $rancher_ver | cut -d "." -f1)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y curl git mercurial python-pip mininet make binutils bison gcc build-essential openvswitch-switch sshpass containerd.io

if [ "$major" = "v1" ]; then
  curl https://releases.rancher.com/install-docker/17.03.sh | sh
  rancher_tag=server:$rancher_ver
else
  apt-get install -y docker-ce docker-ce-cli
  rancher_tag=rancher:$rancher_ver
fi
usermod -aG docker vagrant
pip install -r /vagrant/requirements.txt

if [ "$node" = "network" ]; then
    echo "Starting ONOS on $node"
    docker run -tid --name onos --rm -p 8101:8101 -p 8181:8181 -p 6653:6653 -e ONOS_APPS=openflow,segmentrouting,layout ciena/onos:1.15.1-SNAPSHOT
fi

if [ "$node" = "management" ]; then
    echo "Installing rancher/$rancher_tag"
    docker run -d --restart=unless-stopped -p 80:80 -p 443:443 -p 8080:8080 rancher/$rancher_tag
    if [ "$major" = "v1" ]; then
	echo "Installing kubectl 1.10.0 and helm 2.8.0"
	curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.10.0/bin/linux/amd64/kubectl
	chmod +x kubectl
	mv kubectl /usr/local/bin
	wget -O helm-install.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get
	chmod +x helm-install.sh
	./helm-install.sh --version v2.8.0
	rm -f helm-install.sh
    else
	snap install kubectl --classic
	snap install helm --classic
    fi
fi

