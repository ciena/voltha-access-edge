#!/bin/bash

if [ "$(hostname)" != "management" ]; then
    echo "This script should be run on the management VM only"
    exit 1
fi

cd /opt/kubespray
ansible-playbook -i inventory/voltha/hosts.ini --become --become-user=root cluster.yml
mkdir -p /home/vagrant/.kube
sudo cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
DNS=$(kubectl get -n  kube-system svc coredns -o go-template='{{.spec.clusterIP}}')
for C in compute1 compute2 compute3; do
    ssh $C mkdir -p /home/vagrant/.kube
    scp /home/vagrant/.kube/config "$C:.kube/config"
    ssh $C sudo cp /home/vagrant/.kube/config /etc/kubernetes/admin.conf
    ssh $C 'echo "search default.svc.cluster.local voltha.svc.cluster.local kube-system.svc.cluster.local" | sudo tee -a /etc/resolvconf/resolv.conf.d/base'
    ssh $C "echo \"nameserver $DNS\" | sudo tee -a /etc/resolvconf/resolv.conf.d/head"
    ssh $C 'sudo resolvconf -u'
done

sudo snap install helm --classic
