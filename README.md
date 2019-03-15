# Setting up VOLTHA with Kubernetes Cluster and ONOS Trellis

## Overview

![](overview.png)

This repository contains instructions on deploying a simulated VOLTHA access edge environment that can be utilized for development and various test use cases. This environment strives to be as similar to an physical deployment as possible using virtualization tools such as `Mininet`, `Vagrant`, and `Docker`.

The environment consists of a **ONF Trellis** networking fabric with two (2) spines and four (4) leaves. Additionally there is an *aggregation* leaf which represents the backoffice of a deployment where infrastructure services are executed.

Each leaf has a single `mininet` host attached as well as has at least one (1) VM attached. The VMs are created using `Vagrant` and attached to the leaves via `gre` tunnels.

A Kubernetes cluster is formed over four (4) of the VMs (`management`, `compute1`, `compute2`, and `compute3`) where `management` is a Kubernetes manager and `compute{1,2,3}` are Kubernetes workers.

A DHCP and RADIUS server are invoked on the `backoffice` VM and a simulate OLT, ONU, and RG are invoked on the `olt` VM.

## Requirements
As stated above and below, this environment creates 7 VMs using `Vagrant`. The resources allocated to each VM are in the table below. Suffice to say, that this environment might require more than a simple laptop.

|VM|CPUs|Memory (G)|Disk (G)|
|---|---|---|---|
|network|2|6|10|
|management|2|6|10|
|compute{1,2,3}|2|6|10|
|olt|2|2|10|
|backoffice|2|2|10|

It is possible that the environment may execute with fewer resources allocated, it has just not been tested.

## Virtual Machines

The included `Vagrantfile` creates 7 VMs for this demonstration environment
- `network` - this VM hosts the `mininet` based Trellis leaf/spine network, including the switches and an instance of ONOS to control the network
- `management` - this VM hosts an instance of `rancher` which is used to create and manage the Kubernetes cluster
- `compute{1,2,3}` - these VMs are used as nodes for the Kubernetes cluster
- `olt` - this VM simulates an OLT, ONU, and a [eventually] RG
- `backoffice` - thie VM simulates the infrastructure services of a deployment

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
After creating the network devices the script will leave you in the `mininet` CLI and as such the terminal in you you execute `make start-network` is now dedicated. **NOTE:** *It is reccomended that you start `mininet` in a `screen` session, so that the `mininet` process can continue to run if you have to disconnect from the host.*

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

## Authenticate Subscriber Test
On the `olt` VM there should be three (3) containers running: `olt`, `onu`, and `rg`. These containers represent/simulate the physical OLT, ONU, and residential gateway devices in a physical deployment. To perform an end to end test of the solution an authentication can be attempted from the RG, which will send and EAPOL request that is proxied via ONOS to the a radius server on the VM `backoffice`.

```
vagrant ssh olt
cd /vagrant
make test-authenticate
```

**Output:**
```
docker exec -ti rg /vagrant/test/rg-authenticate.sh
wpa_supplicant v2.4
random: Trying to read entropy from /dev/random
Successfully initialized wpa_supplicant
Initializing interface 'eth1' conf '/vagrant/test/wpa_supplicant.conf' driver 'wired' ctrl_interface 'N/A' bridge 'N/A'
Configuration file '/vagrant/test/wpa_supplicant.conf' -> '/vagrant/test/wpa_supplicant.conf'
Reading configuration file '/vagrant/test/wpa_supplicant.conf'
ctrl_interface='/var/run/wpa_supplicant'
ap_scan=0
Line: 3 - start of a new network block
key_mgmt: 0x8
eap methods - hexdump(len=16): 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00
identity - hexdump_ascii(len=4):
     75 73 65 72                                       user
password - hexdump_ascii(len=8): [REMOVED]
eapol_flags=0 (0x0)
Priority group 0
   id=0 ssid=''
wpa_driver_wired_init: Added multicast membership with packet socket
Add interface eth1 to a new radio N/A
eth1: Own MAC address: 02:42:c0:a8:38:03
eth1: RSN: flushing PMKID list in the driver
eth1: Setting scan request: 0.100000 sec
TDLS: TDLS operation not supported by driver
TDLS: Driver uses internal link setup
TDLS: Driver does not support TDLS channel switching
eth1: WPS: UUID based on MAC address: 7b57a627-5637-5eaf-bf98-28534b18f3c7
ENGINE: Loading dynamic engine
ENGINE: Loading dynamic engine
EAPOL: SUPP_PAE entering state DISCONNECTED
EAPOL: Supplicant port status: Unauthorized
EAPOL: KEY_RX entering state NO_KEY_RECEIVE
EAPOL: SUPP_BE entering state INITIALIZE
EAP: EAP entering state DISABLED
eth1: Added interface eth1
eth1: State: DISCONNECTED -> DISCONNECTED
random: Got 20/20 bytes from /dev/random
EAPOL: External notification - EAP success=0
EAPOL: External notification - EAP fail=0
EAPOL: External notification - portControl=Auto
eth1: Already associated with a configured network - generating associated event
eth1: Event ASSOC (0) received
eth1: Association info event
FT: Stored MDIE and FTIE from (Re)Association Response - hexdump(len=0):
eth1: State: DISCONNECTED -> ASSOCIATED
eth1: Associated to a new BSS: BSSID=01:80:c2:00:00:03
Add randomness: count=1 entropy=0
random pool - hexdump(len=128): [REMOVED]
random_mix_pool - hexdump(len=16): [REMOVED]
random_mix_pool - hexdump(len=6): [REMOVED]
random pool - hexdump(len=128): [REMOVED]
eth1: Select network based on association information
eth1: Network configuration found for the current AP
eth1: WPA: clearing AP WPA IE
eth1: WPA: clearing AP RSN IE
eth1: WPA: clearing own WPA/RSN IE
eth1: Failed to get scan results
EAPOL: External notification - EAP success=0
EAPOL: External notification - EAP fail=0
EAPOL: External notification - portControl=Auto
eth1: Associated with 01:80:c2:00:00:03
eth1: WPA: Association event - clear replay counter
eth1: WPA: Clear old PTK
TDLS: Remove peers on association
EAPOL: External notification - portEnabled=0
EAPOL: External notification - portValid=0
EAPOL: External notification - portEnabled=1
EAPOL: SUPP_PAE entering state CONNECTING
EAPOL: SUPP_BE entering state IDLE
EAP: EAP entering state INITIALIZE
EAP: EAP entering state IDLE
eth1: Cancelling scan request
WMM AC: Missing IEs
EAPOL: startWhen --> 0
EAPOL: SUPP_PAE entering state CONNECTING
EAPOL: txStart
TX EAPOL: dst=01:80:c2:00:00:03
TX EAPOL - hexdump(len=4): 01 01 00 00
l2_packet_receive: src=00:00:00:00:10:01 len=46
eth1: RX EAPOL from 00:00:00:00:10:01
RX EAPOL - hexdump(len=46): 01 00 00 05 01 39 00 05 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
EAPOL: Received EAP-Packet frame
EAPOL: SUPP_PAE entering state RESTART
EAP: EAP entering state INITIALIZE
EAP: EAP entering state IDLE
EAPOL: SUPP_PAE entering state AUTHENTICATING
EAPOL: SUPP_BE entering state REQUEST
EAPOL: getSuppRsp
EAP: EAP entering state RECEIVED
EAP: Received EAP-Request id=57 method=1 vendor=0 vendorMethod=0
EAP: EAP entering state IDENTITY
eth1: CTRL-EVENT-EAP-STARTED EAP authentication started
EAP: Status notification: started (param=)
EAP: EAP-Request Identity data - hexdump_ascii(len=0):
EAP: using real identity - hexdump_ascii(len=4):
     75 73 65 72                                       user
EAP: EAP entering state SEND_RESPONSE
EAP: EAP entering state IDLE
EAPOL: SUPP_BE entering state RESPONSE
EAPOL: txSuppRsp
TX EAPOL: dst=01:80:c2:00:00:03
TX EAPOL - hexdump(len=13): 01 00 00 09 02 39 00 09 01 75 73 65 72
EAPOL: SUPP_BE entering state RECEIVE
l2_packet_receive: src=00:00:00:00:10:01 len=46
eth1: RX EAPOL from 00:00:00:00:10:01
RX EAPOL - hexdump(len=46): 01 00 00 16 01 3a 00 16 04 10 33 5d af 27 c9 3e 25 cf 62 3d e2 2f 1a 26 16 df 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
EAPOL: Received EAP-Packet frame
EAPOL: SUPP_BE entering state REQUEST
EAPOL: getSuppRsp
EAP: EAP entering state RECEIVED
EAP: Received EAP-Request id=58 method=4 vendor=0 vendorMethod=0
EAP: EAP entering state GET_METHOD
eth1: CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=4
EAP: Status notification: accept proposed method (param=MD5)
EAP: Initialize selected EAP method: vendor 0 method 4 (MD5)
eth1: CTRL-EVENT-EAP-METHOD EAP vendor 0 method 4 (MD5) selected
EAP: EAP entering state METHOD
EAP-MD5: Challenge - hexdump(len=16): 33 5d af 27 c9 3e 25 cf 62 3d e2 2f 1a 26 16 df
EAP-MD5: Generating Challenge Response
EAP-MD5: Response - hexdump(len=16): 53 ac db d9 d5 d7 f8 80 9a 4b 85 b3 a1 24 1e 81
EAP: method process -> ignore=FALSE methodState=DONE decision=COND_SUCC eapRespData=0x560a42080330
EAP: EAP entering state SEND_RESPONSE
EAP: EAP entering state IDLE
EAPOL: SUPP_BE entering state RESPONSE
EAPOL: txSuppRsp
TX EAPOL: dst=01:80:c2:00:00:03
TX EAPOL - hexdump(len=26): 01 00 00 16 02 3a 00 16 04 10 53 ac db d9 d5 d7 f8 80 9a 4b 85 b3 a1 24 1e 81
EAPOL: SUPP_BE entering state RECEIVE
l2_packet_receive: src=00:00:00:00:10:01 len=46
eth1: RX EAPOL from 00:00:00:00:10:01
RX EAPOL - hexdump(len=46): 01 00 00 04 03 3a 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
EAPOL: Received EAP-Packet frame
EAPOL: SUPP_BE entering state REQUEST
EAPOL: getSuppRsp
EAP: EAP entering state RECEIVED
EAP: Received EAP-Success
EAP: Status notification: completion (param=success)
EAP: EAP entering state SUCCESS
eth1: CTRL-EVENT-EAP-SUCCESS EAP authentication completed successfully
EAPOL: IEEE 802.1X for plaintext connection; no EAPOL-Key frames required
eth1: WPA: EAPOL processing complete
eth1: Cancelling authentication timeout
eth1: State: ASSOCIATED -> COMPLETED
eth1: CTRL-EVENT-CONNECTED - Connection to 01:80:c2:00:00:03 completed [id=0 id_str=]
EAPOL: SUPP_PAE entering state AUTHENTICATED
EAPOL: Supplicant port status: Authorized
EAPOL: SUPP_BE entering state RECEIVE
EAPOL: SUPP_BE entering state SUCCESS
EAPOL: SUPP_BE entering state IDLE
EAPOL authentication completed - result=SUCCESS
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
|`backoffice`|`192.168.33.16`|`10.1.5.3`|

## Connecting VMs to Trellis (`mininet`)
In order to **wire in** the VMs into the `mininet` based fabric a GRE tunnel is created from the `network` VM to each of the other MV (`management` and `compute{1,2,3}`). The GRE tunnel is created in the `192.168.33.0/24` network space.

On the `network` VM the interfaces associated with the GRE tunnels are added to `openvswitch` instance that is created when `mininet` is started using `ovs-vsctl`. This is done by executing the include shell script `add-ports.sh`, which can be invoked by using `make inject-vms`.
