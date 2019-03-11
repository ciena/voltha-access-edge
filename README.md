# Setting up Kubernetes Cluster with ONOS Trellis

The included `Vagrantfile` creates 5 VMs for this demonstration environment
- `network` - this VM hosts the `mininet` based Trellis leaf/spine network, including the switches and an instance of ONOS to control the network
- `management` - this VM hosts an instance of `rancher` which is used to create and manage the Kubernetes cluster
- `compute{1,2,3}` - these VMs are used as nodes for the Kubernetes cluster
- `olt` - this VM simulates an OLT, ONU, and a [eventually] RG

# Walkthrough

## Create the VMs
```bash
vagrant up
```
This could take a while. Go get a cup of coffee. Chat with a friend.

## Start UI Tunnel (Optional)
Starting the UI tunnel will expose the ONOS UI on the VM host machine. This is one way to allow access to the ONOS UI running on the VM to external browsers.
```bash
make ui-tunnels
```

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

### Configure ONOS Trellis Fabric
```bash
make post-onos-config
```

At this point the fabric should be up and operational. You may need to ping from the `management`, `compute`, and `olt` hosts their gateway address so that ONOS is aware the hosts exists.

#### Test Fabric
The connectivity of fabric can be tested using the command `make test-fabric`. This test will ssh to each VM and then attempt to `ping` each of the fabric IPs.

##### Success Example
```
$ make test-fabric
TEST: management ... PASS
TEST: compute1 ... PASS
TEST: compute2 ... PASS
TEST: compute3 ... PASS
TEST: olt ... PASS
PASS: Fabric functioning correctly
```

##### Failure Example
```
$ make test-fabric
TEST: management ... FAILED (10.1.4.4)
TEST: compute1 ... FAILED (10.1.4.4)
TEST: compute2 ... FAILED (10.1.4.4)
TEST: compute3 ... FAILED (10.1.4.4)
TEST: olt ... FAILED (10.1.4.4)
FAIL: Fabric not functioning correctly/completely
```

If the fabric is not working it is sometimes helpful to `ssh` into ONOS and `deactivate` and then `activate` the segment routing application.
```bash
ssh -p 8101 karaf@localhost
Password: karaf
onos> app deactivate segmentrouting
onos> app activate segmentrouting
```

Additionally things that can be tried, is issing the `wipe-out please` command to ONOS and then re-`POST`ing the ONOS config and the `deactivate`/`activate` `segmentrouting`.

## Create Kubernetes Cluster

`Kubespray` is used to deploy the Kubernetes cluster. During VM provisioning it was installed in `/opt/kubespray` on the `management` VM. The following command will deploy the Kubernetes cluster:
```bash
vagrant ssh management
cd /vagrant
make deploy-k8s
```
This will run an Ansible playbook to dploy the cluster.

## Deploy VOLTHA
This environment uses `make` to simplify command invocation. If you want to see the commands run you can do a `make -n` instead of a `make` in these commands and the commands executed will be displayed.

### Initialize Helm
`Helm` is used to deploy voltha. To initialize `Helm` do the following commands:
```bash
vagrant ssh management
cd /vagrant
make post-install
```

### Deploy Kafka
`kafka` is used for inter-process messaging
```bash
vagrant ssh management
cd /vagrant
make helm-kafka
```

### Deploy ETCd
`etcd` is used for VOLTHA storage.
```bash
vagrant ssh management
cd /vagrant
make helm-etcd-operator
```

### Deploy ONOS to Control VOLTHA
There are two instances of ONOS operating in this environment. The first is running on the `network` VM and is controllering the Trellis fabric. The second, which the following command starts, controls the VOLTHA installation and its associated virtual devices.
```bash
vagrant ssh management
cd /vagrant
make helm-onos
```

### Actually Deploy VOLTHA
There is a wait on this command in the `Makefile`. It waits until `kubectl get crd 2>/dev/null | grep -c etcd` returns a count of 3. After 3 instances are found the VOLTHA helm chart will be installed.
```bash
vagrant ssh management
cd /vagrant
make helm-voltha
```

### Verification
To verify the installation to this point, you can use `kubectl` to look at the `pods` that are running. It should look similar to below:
```bash
vagrant ssh management
kubectl get --all-namespaces pods
```

```bash
NAMESPACE     NAME                                                              READY   STATUS    RESTARTS   AGE
default       cord-kafka-0                                                      1/1     Running   0          14m
default       cord-kafka-zookeeper-0                                            1/1     Running   0          14m
default       etcd-cluster-4bjtggk88n                                           1/1     Running   0          3m14s
default       etcd-cluster-bz6km9vkxj                                           1/1     Running   0          4m52s
default       etcd-cluster-vp4q44gvtt                                           1/1     Running   0          2m16s
default       etcd-operator-etcd-operator-etcd-backup-operator-6f6ffc759nzdzw   1/1     Running   0          11m
default       etcd-operator-etcd-operator-etcd-operator-7478ddcb4f-zzlmc        1/1     Running   0          11m
default       etcd-operator-etcd-operator-etcd-restore-operator-794f5858j844p   1/1     Running   0          11m
default       onos-6788ff95dc-kdptt                                             2/2     Running   0          11m
kube-system   calico-kube-controllers-756b58d95d-gl62j                          1/1     Running   0          29m
kube-system   calico-node-8wsmc                                                 1/1     Running   0          29m
kube-system   calico-node-9hdpv                                                 1/1     Running   0          29m
kube-system   calico-node-dmh76                                                 1/1     Running   0          29m
kube-system   calico-node-gnrfb                                                 1/1     Running   0          29m
kube-system   coredns-788d98cc7b-5qtbv                                          1/1     Running   0          28m
kube-system   coredns-788d98cc7b-96rx9                                          1/1     Running   0          28m
kube-system   dns-autoscaler-66b95c57d9-72gnk                                   1/1     Running   0          28m
kube-system   kube-apiserver-management                                         1/1     Running   0          31m
kube-system   kube-controller-manager-management                                1/1     Running   0          31m
kube-system   kube-proxy-jckzj                                                  1/1     Running   0          29m
kube-system   kube-proxy-mld5r                                                  1/1     Running   0          29m
kube-system   kube-proxy-v8lj5                                                  1/1     Running   0          29m
kube-system   kube-proxy-zvv75                                                  1/1     Running   0          29m
kube-system   kube-scheduler-management                                         1/1     Running   0          31m
kube-system   kubernetes-dashboard-5db4d9f45f-zz2pk                             1/1     Running   0          28m
kube-system   nginx-proxy-compute1                                              1/1     Running   0          30m
kube-system   nginx-proxy-compute2                                              1/1     Running   0          30m
kube-system   nginx-proxy-compute3                                              1/1     Running   0          30m
kube-system   tiller-deploy-7dc9577bfd-8nr5q                                    1/1     Running   0          15m
voltha        default-http-backend-798fb4f44c-lfhg8                             1/1     Running   0          4m53s
voltha        freeradius-754bc76b5-b2jr7                                        1/1     Running   0          4m53s
voltha        netconf-85bf8d9db6-5jlfk                                          1/1     Running   0          4m53s
voltha        nginx-ingress-controller-5fc7b87c86-g6gct                         1/1     Running   0          4m53s
voltha        ofagent-6fd6dc8545-w576g                                          1/1     Running   0          4m53s
voltha        vcli-756fdb6685-qlzqg                                             1/1     Running   0          4m53s
voltha        vcore-0                                                           1/1     Running   0          4m53s
voltha        voltha-75486b7995-rqgh5                                           1/1     Running   0          4m53s
```

```bash
kubectl get --namespace=voltha  services
```

```
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                        AGE
default-http-backend   ClusterIP   10.233.55.203   <none>        80/TCP                                                         5m21s
freeradius             ClusterIP   None            <none>        1812/UDP,1813/UDP,18120/TCP                                    5m21s
ingress-nginx          NodePort    10.233.63.223   <none>        80:30080/TCP,443:30443/TCP                                     5m21s
netconf                ClusterIP   None            <none>        830/TCP                                                        5m21s
vcli                   NodePort    10.233.28.52    <none>        5022:30110/TCP                                                 5m21s
vcore                  ClusterIP   None            <none>        8880/TCP,18880/TCP,50556/TCP                                   5m21s
voltha                 NodePort    10.233.21.100   <none>        8882:30125/TCP,8001:32195/TCP,8443:32443/TCP,50555:30736/TCP   5m21s
```

The DNS name resolution on each of the cluster VMs (`management`, `compute1`, `compute2`, and `compute3`) has been updated so that the Kubernetes services names can be resolved to the cluster IP.

You should be able to `ssh` into the VOLTHA CLI from any node using the service name.

```bash
vagrant ssh management
ssh -p 5022 voltha@vcli # Use the password `admin`
```

Once connected you should be able to execute the `health` command and the `adapters` command to get output similar to below:
```bash
         _ _   _            ___ _    ___
__ _____| | |_| |_  __ _   / __| |  |_ _|
\ V / _ \ |  _| ' \/ _` | | (__| |__ | |
 \_/\___/_|\__|_||_\__,_|  \___|____|___|
(to exit type quit or hit Ctrl-D)
(voltha) health
{
    "state": "HEALTHY"
}
(voltha) adapters
Adapters:
+----------------------+---------------------------+---------+
|                   id |                    vendor | version |
+----------------------+---------------------------+---------+
|                 acme |                 Acme Inc. |     0.1 |
|           adtran_olt |              ADTRAN, Inc. |    1.33 |
|        asfvolt16_olt |                  Edgecore |    0.98 |
|    brcm_openomci_onu |            Voltha project |    0.50 |
|         broadcom_onu |            Voltha project |    0.46 |
|              cig_olt |                  CIG Tech |    0.11 |
|     cig_openomci_onu |                  CIG Tech |    0.10 |
|             dpoe_onu |   Sumitomo Electric, Inc. |     0.1 |
|            maple_olt |            Voltha project |     0.4 |
|        microsemi_olt |     Microsemi / Celestica |     0.2 |
+----------------------+---------------------------+---------+
|              openolt |      OLT white box vendor |     0.1 |
|             pmcs_onu |                      PMCS |     0.1 |
|           ponsim_olt |            Voltha project |     0.4 |
|           ponsim_onu |            Voltha project |     0.4 |
|        simulated_olt |            Voltha project |     0.1 |
|        simulated_onu |            Voltha project |     0.1 |
|          tellabs_olt |              Tellabs Inc. |     0.1 |
| tellabs_openomci_onu |              Tellabs Inc. |     0.1 |
|            tibit_olt | Tibit Communications Inc. |     0.1 |
|            tibit_onu | Tibit Communications Inc. |     0.1 |
+----------------------+---------------------------+---------+
|             tlgs_onu |                      TLGS |     0.1 |
+----------------------+---------------------------+---------+
(voltha)
```

## Start Simulated PON devices and Connect them to VOLTHA

### Register PON simulator with VOLTHA
```bash
vagrant ssh management
ssh -p 5022 voltha@10.233.58.167 # Use the password `admin`
(voltha) preprovision_olt -t ponsim_olt -H 10.1.4.4:50060
success (device id = 0001a5aa69c456fb)
(voltha) enable
enabling 0001a5aa69c456fb
success (logical device id = 0001aabbccddeeff)
(voltha) devices
Devices:
+------------------+------------+------+------------------+----------------+------+-------------+-------------+----------------+----------------+----------------+-------------------------+--------------------------+
|               id |       type | root |        parent_id |  serial_number | vlan | admin_state | oper_status | connect_status | parent_port_no |  host_and_port | proxy_address.device_id | proxy_address.channel_id |
+------------------+------------+------+------------------+----------------+------+-------------+-------------+----------------+----------------+----------------+-------------------------+--------------------------+
| 0001a5aa69c456fb | ponsim_olt | True | 0001aabbccddeeff | 10.1.4.4:50060 |      |     ENABLED |      ACTIVE |      REACHABLE |                | 10.1.4.4:50060 |                         |                          |
| 0001cf0246d7462c | ponsim_onu |      | 0001a5aa69c456fb |   PSMO12345678 |  128 |     ENABLED |      ACTIVE |      REACHABLE |              1 |                |        0001a5aa69c456fb |                      128 |
+------------------+------------+------+------------------+----------------+------+-------------+-------------+----------------+----------------+----------------+-------------------------+--------------------------+
```

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
|`olt`|`192.168.33.15`|`10.1.4.4`|

## Connecting VMs to Trellis (`mininet`)
In order to **wire in** the VMs into the `mininet` based fabric a GRE tunnel is created from the `network` VM to each of the other MV (`management` and `compute{1,2,3}`). The GRE tunnel is created in the `192.168.33.0/24` network space.

On the `network` VM the interfaces associated with the GRE tunnels are added to `openvswitch` instance that is created when `mininet` is started using `ovs-vsctl`. This is done by executing the include shell script `add-ports.sh`, which can be invoked by using `make inject-vms`.
