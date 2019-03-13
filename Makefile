help:
	@echo "start-network        - start mininet (in the forground)"
	@echo "inject-vms           - inject the VM interfaces into the leaf switches"
	@echo "post-onos-config     - post the configuration to ONOS"

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

$(HOME)/onos-apps/sadis-app-3.0.0.oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/sadis-app/3.0.0/sadis-app-3.0.0.oar -o $(HOME)/onos-apps/sadis-app-3.0.0.oar

$(HOME)/onos-apps/aaa-1.8.0.oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/aaa/1.8.0/aaa-1.8.0.oar -o $(HOME)/onos-apps/aaa-1.8.0.oar

$(HOME)/onos-apps/olt-app-2.1.0.oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/olt-app/2.1.0/olt-app-2.1.0.oar -o $(HOME)/onos-apps/olt-app-2.1.0.oar

$(HOME)/onos-apps/dhcpl2relay-1.5.0.oar:
	curl --fail -sSL https://repo.maven.apache.org/maven2/org/opencord/dhcpl2relay/1.5.0/dhcpl2relay-1.5.0.oar -o $(HOME)/onos-apps/dhcpl2relay-1.5.0.oar

download-onos-apps: $(HOME)/onos-apps $(HOME)/onos-apps/sadis-app-3.0.0.oar $(HOME)/onos-apps/aaa-1.8.0.oar $(HOME)/onos-apps/olt-app-2.1.0.oar $(HOME)/onos-apps/dhcpl2relay-1.5.0.oar

helm-onos: download-onos-apps
	helm install -n onos cord/onos
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/sadis-app-3.0.0.oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'SADIS' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/aaa-1.8.0.oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'AAA' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/olt-app-2.1.0.oar 2>/dev/null | tail -1) -eq 409; do echo "Install 'OLT' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/octet-stream http://onos-ui:8181/onos/v1/applications?activate=true --data-binary @$(HOME)/onos-apps/dhcpl2relay-1.5.0.oar 2>/dev/null | tail -1) -eq 409; do echo "Installing 'DHCP L2 Relay' ONOS application ..."; sleep 1; done
	@until test $$(curl -w '\n%{http_code}' --fail -sSL --user karaf:karaf -X POST -H Content-Type:application/json http://onos-ui:8181/onos/v1/network/configuration --data @/vagrant/olt-onos-netcfg.json 2>/dev/null | tail -1) -eq 200; do echo "Configuring VOLTHA ONOS ..."; sleep 1; done

helm-voltha: # helm-kafka helm-etcd-operator helm-onos
	@echo "Waiting for etcd-operator to initialize ..." 
	@until test $$(kubectl get crd 2>/dev/null | grep -c etcd) -eq 3; do echo "waiting ..."; sleep 2; done
	helm install -n voltha cord/voltha

