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

help:
	@echo "Available targets:"
	@echo ""
	@echo "help                 - this list"
	@echo "start-network        - start mininet (in the forground)"
	@echo "inject-vms           - inject the VM interfaces into the leaf switches"
	@echo "post-onos-config     - post the configuration to ONOS"
	@echo "test-fabric          - tests the p2p connectivity of the fabric"
	@echo "ui-tunnels           - create port forwarding tunnels for application UIs"
	@echo "olt-onos-ui-tunnel   - create the port forwarding tunnel for the VOLTHA UI instance"
	@echo "deploy-k8s           - deploy Kubernetes to the compute cluster"
	@echo "post-install         - post install updated for the management VM"
	@echo "helm-etcd-operator   - use helm to deploy Etcd cluster"
	@echo "helm-kafka           - use helm to deploy Kafka"
	@echo "helm-onos            - use helm to deploy ONOS"
	@echo "helm-voltha          - use helm to deploy VOLTHA"
	@echo "test-authenticate    - test EAPOL authentication from subscriber VM"
	@echo ""
	@echo "Please see the README.md file to understand how to use the"
	@echo "various targets to deploy a simulated VOLTHA environment."

start-network:
	sudo ./lsnet.py --controller=remote,ip=127.0.0.1,port=6653 --leaves=5 --spines=2 --hosts=1 --wait --ping --onos=http://karaf:karaf@localhost:8181

inject-vms:
	sudo /vagrant/add-ports.sh

post-onos-config:
	curl --fail -X POST -HContent-type:application/json http://karaf:karaf@127.0.0.1:8181/onos/v1/network/configuration -d@/vagrant/netcfg.json

test-fabric:
	@./test_fabric.sh

ui-tunnels:
	vagrant ssh network -- -L 0.0.0.0:8181:127.0.0.1:8181 -f -n -N -q -T

olt-onos-ui-tunnel:
	vagrant ssh management -- -L 0.0.0.0:9191:onos-ui:8181 -f -n -N -q -T

deploy-k8s:
	/vagrant/deploy-k8s.sh

management-post-install:
	/vagrant/management-post-install.sh

post-install: $(shell hostname)-post-install

helm-etcd-operator:
	helm install -n etcd-operator stable/etcd-operator --version 0.8.0

helm-kafka:
	 helm install --version 0.8.8 \
		--set configurationOverrides."offsets\.topic\.replication\.factor"=1 \
		--set configurationOverrides."log\.retention\.hours"=4 \
		--set configurationOverrides."log\.message\.timestamp\.type"="LogAppendTime" \
		--set replicas=1 \
		--set persistence.enabled=false \
		--set zookeeper.replicaCount=1 \
		--set zookeeper.persistence.enabled=false \
		-n cord-kafka incubator/kafka

$(HOME)/onos-apps:
	mkdir -p $(HOME)/onos-apps

CONFIG_VER=1.4.0
SADIS_VER=2.1.0
OLT_VER=1.4.1
AAA_VER=1.6.0
DHCP_VER=1.5.0

$(HOME)/onos-apps/cord-config-$(CONFIG_VER).oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/cord-config/$(CONFIG_VER)/cord-config-$(CONFIG_VER).oar -o $(HOME)/onos-apps/cord-config-$(CONFIG_VER).oar

$(HOME)/onos-apps/sadis-app-$(SADIS_VER).oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/sadis-app/$(SADIS_VER)/sadis-app-$(SADIS_VER).oar -o $(HOME)/onos-apps/sadis-app-$(SADIS_VER).oar

$(HOME)/onos-apps/aaa-$(AAA_VER).oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/aaa/$(AAA_VER)/aaa-$(AAA_VER).oar -o $(HOME)/onos-apps/aaa-$(AAA_VER).oar

$(HOME)/onos-apps/olt-app-$(OLT_VER).oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/olt-app/$(OLT_VER)/olt-app-$(OLT_VER).oar -o $(HOME)/onos-apps/olt-app-$(OLT_VER).oar

$(HOME)/onos-apps/dhcpl2relay-1.5.0.oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/dhcpl2relay/$(DHCP_VER)/dhcpl2relay-$(DHCP_VER).oar -o $(HOME)/onos-apps/dhcpl2relay-$(DHCP_VER).oar

download-onos-apps: $(HOME)/onos-apps $(HOME)/onos-apps/cord-config-$(CONFIG_VER).oar $(HOME)/onos-apps/sadis-app-$(SADIS_VER).oar $(HOME)/onos-apps/aaa-$(AAA_VER).oar $(HOME)/onos-apps/olt-app-$(OLT_VER).oar $(HOME)/onos-apps/dhcpl2relay-$(DHCP_VER).oar

helm-onos: download-onos-apps
	helm install -n onos cord/onos
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/cord-config-$(CONFIG_VER).oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'CONFIG' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/sadis-app-$(SADIS_VER).oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'SADIS' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/olt-app-$(OLT_VER).oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'OLT' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/aaa-$(AAA_VER).oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'AAA' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/dhcpl2relay-$(DHCP_VER).oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'DHCP L2 Relay' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/json http://onos-ui:8181/onos/v1/network/configuration --data @/vagrant/olt-onos-netcfg.json 2>/dev/null | tail -1) -eq 200; do echo "Configuring VOLTHA ONOS ..."; sleep 1; done

post-onos-olt-config:
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/json http://onos-ui:8181/onos/v1/network/configuration --data @/vagrant/olt-onos-netcfg.json 2>/dev/null | tail -1) -eq 200; do echo "Configuring VOLTHA ONOS ..."; sleep 1; done

helm-voltha: # helm-kafka helm-etcd-operator helm-onos
	@echo "Waiting for etcd-operator to initialize ..." 
	@until test $$(kubectl get crd 2>/dev/null | grep -c etcd) -eq 3; do echo "waiting ..."; sleep 2; done
	helm install -n voltha cord/voltha

test-authenticate:
	docker exec -ti rg /vagrant/test/rg-authenticate.sh

