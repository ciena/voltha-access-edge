# Setting up Kubernetes Cluster with ONOS Trellis

The included `Vagrantfile` creates 5 VMs for this demonstration environment
- `network` - this VM hosts the `mininet` based Trellis leaf/spine network, including the switches and an instance of ONOS to control the network
- `management` - this VM hosts an instance of `rancher` which is used to create and manage the Kubernetes cluster
- `compute{1,2,3}` - these VMs are used as nodes for the Kubernetes cluster

# Walkthrough

## Create the VMs
```bash
vagrant up
```
This could take a while. Go get a cup of coffee. Chat with a friend.

## Start Trellis Network

### Start `mininet`
```bash
vagrant ssh network
cd /vagrant
make start-network
```
After creating the network devices the script will leave you in the `mininet` CLI and as such the terminal in you you execute `make start-network` is now dedicated.

### Add VM Interfaces to Network
```bash
vagrant ssh network
cd /vagrant
make inject-vms
```

### Configure ONOS
```bash
make post-onos-config
```

At this point the fabric should be up and operational. You may need to ping from the `management` and `compute` hosts their gateway address so that ONOS is aware the hosts exists.

If the fabric is not working it is sometimes helpful to `ssh` into ONOS and `deactivate` and then `activate` the segment routing application.
```bash
ssh -p 8101 karaf@localhost
Password: karaf
onos> app deactivate segmentrouting
onos> app activate segmentrouting
```

## Create Kubernetes Cluster

### Access the Rancher Web UI
From your browser, open the URL `https://192.168.33.11`. This wil start the Rancher UI and you will be prompted to create a user and password. `admin`/`admin` works well and when prompted accept the default URL with IP address `192.168.33.11`.

Via the Rancher UI you will want to create a **custom** cluster. Add the compute nodes into the cluster. `compute1` should have the roles `etcd`, `Control Plane`, and `worker`. `compute2` and `compute3` should just be workers.

Under the **Advanced Options** for each node, the `Public Address` should be the host's address in the `192.168.33.0/24` network and the `Internal Address` should be the host's address in the `10.1.0.0/16` network.

You will need to copy the `ranger-agent` command line to execute and invoke it on each of the compute nodes. As you change the options on the UI the command changes, so the command executed on each compute hosts is slightly different.

Rancher will spin for a while, Docker images will be downloaded, but eventually all nodes should become active. You can access `kubctl` directly from the Rancher UI or download a `kubectl` config and run it locally.

# Details
## IP Addressing
Each VM is NAT-ed to the Vagrant host as well as has a management IP. The hosts that participate in the Trellis fabric have an additional IP address that represents their address on the fabric

|HOST|MANAGEMENT IP|FABRIC IP|
| --- | --- | --- |
|`network`|`192.168.33.10`|N/A|
|`management`|`192.168.33.11`|`10.1.1.3`|
|`compute1`|`192.168.33.12`|`10.1.2.3`|
|`compute2`|`192.168.33.13`|`10.1.3.3`|
|`compute3`|`192.168.33.14`|`10.1.4.3`|

## Connecting VMs to Trellis (`mininet`)
In order to **wire in** the VMs into the `mininet` based fabric a GRE tunnel is created from the `network` VM to each of the other MV (`management` and `compute{1,2,3}`). The GRE tunnel is created in the `192.168.33.0/24` network space.

On the `network` VM the interfaces associated with the GRE tunnels are added to `openvswitch` instance that is created when `mininet` is started using `ovs-vsctl`. This is done by executing the include shell script `add-ports.sh`, which can be invoked by using `make inject-vms`.
