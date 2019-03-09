help:
	@echo "start-network        - start mininet (in the forground)"
	@echo "inject-vms           - inject the VM interfaces into the leaf switches"
	@echo "post-onos-config     - post the configuration to ONOS"

start-network:
	sudo ./lsnet.py --controller=remote,ip=127.0.0.1,port=6653 --leaves=4 --spines=2 --hosts=1 --wait --ping --onos=http://karaf:karaf@localhost:8181

inject-vms:
	sudo /vagrant/add-ports.sh

post-onos-config:
	curl --fail -X POST -HContent-type:application/json http://karaf:karaf@127.0.0.1:8181/onos/v1/network/configuration -d@/vagrant/netcfg.json

ui-tunnels:
	vagrant ssh network -- -L 0.0.0.0:8181:127.0.0.1:8181 -f -n -N -q -T

deploy-k8s:
	/vagrant/deploy-k8s.sh

management-post-install:
	/vagrant/management-post-install.sh

post-install: $(shell hostname)-post-install

helm-ponnet:
	helm install -n ponnet cord/ponnet

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

helm-onos:
	helm install -n onos cord/onos

helm-voltha: #helm-ponnet helm-kafka helm-etcd-operator helm-onos
	@echo "Waiting for etcd-operator to initialize ..." 
	@until test $$(kubectl get crd 2>/dev/null | grep -c etcd) -eq 3; do echo "waiting ..."; sleep 2; done
	helm install -n voltha cord/voltha

