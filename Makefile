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
