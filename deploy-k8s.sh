#!/bin/bash
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

if [ "$(hostname)" != "management" ]; then
    echo "This script should be run on the management VM only"
    exit 1
fi

cd /opt/kubespray
ansible-playbook -i inventory/voltha/hosts.ini --become --become-user=root cluster.yml
mkdir -p /home/vagrant/.kube
sudo cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
sudo snap install helm --classic
kubectl completion bash | sudo tee >/dev/null  /etc/bash_completion.d/kubectl
helm completion bash | sudo tee >/dev/null  /etc/bash_completion.d/helm
DNS=$(kubectl get -n  kube-system svc coredns -o go-template='{{.spec.clusterIP}}')
echo "nameserver $DNS" | sudo tee -a /etc/resolvconf/resolv.conf.d/head
echo "search default.svc.cluster.local voltha.svc.cluster.local kube-system.svc.cluster.local" | sudo tee -a /etc/resolvconf/resolv.conf.d/base
sudo resolvconf -u
for C in compute1 compute2 compute3; do
    ssh $C mkdir -p /home/vagrant/.kube
    scp /home/vagrant/.kube/config "$C:.kube/config"
    ssh $C sudo cp /home/vagrant/.kube/config /etc/kubernetes/admin.conf
    scp /etc/bash_completion.d/kubectl "$C:/tmp/kubectl_comp"
    ssh $C sudo mv /tmp/kubectl_comp /etc/bash_completion.d/kubectl
    scp /etc/bash_completion.d/helm "$C:/tmp/helm_comp"
    ssh $C sudo mv /tmp/helm_comp /etc/bash_completion.d/helm
    ssh $C 'echo "search default.svc.cluster.local voltha.svc.cluster.local kube-system.svc.cluster.local" | sudo tee -a /etc/resolvconf/resolv.conf.d/base'
    ssh $C "echo \"nameserver $DNS\" | sudo tee -a /etc/resolvconf/resolv.conf.d/head"
    ssh $C 'sudo resolvconf -u'
done
