#!/usr/bin/env bash
function exec_command {
    node=$1
    cmd=$2
    echo "Running cmd $cmd"
    vagrant ssh $node -- $cmd
}
echo "Starting the mininet topology on network vm"
exec_command network 'cd /vagrant && make start-network'
sleep 60
echo "Adding ports to the network"
exec_command network 'cd /vagrant && make inject-vms'
echo "Posting ONOS trellis config"
exec_command network 'cd /vagrant && make post-onos-config'
sleep 60
while true; do
    make test-fabric
    res=$?
    if [ $res -eq 0 ]; then
	echo "Fabric working"
	break
    else
	echo "Waiting for fabric to come up"
    fi
    sleep 1
done
echo "Deploying the kubernetes cluster"
exec_command management 'cd /vagrant && make deploy-k8s'
echo "Initializing helm"
exec_command management '/vagrant/management-post-install.sh'
sleep 60
echo "Initializing kafka"
exec_command management 'cd /vagrant && make helm-kafka'
sleep 30
echo "Initializing etcd operator"
exec_command management 'cd /vagrant && make helm-etcd-operator'
sleep 60
echo "Initializing voltha ONOS"
exec_command management 'cd /vagrant && make helm-onos'
sleep 30
echo "Initializing voltha"
exec_command management 'cd /vagrant && make helm-voltha'
