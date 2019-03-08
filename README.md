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

### Deploy Ponnet
`ponnet` is a secondary network used to connect to simulated PON devices.
```bash
vagrant ssh management
cd /vagrant
make helm-ponnet
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
default       cord-kafka-0                                                      1/1     Running   0          97m
default       cord-kafka-zookeeper-0                                            1/1     Running   0          97m
default       etcd-cluster-47gfxhdbhm                                           1/1     Running   0          87m
default       etcd-cluster-kd7d7jw5fp                                           1/1     Running   0          90m
default       etcd-cluster-kf78qwkz74                                           1/1     Running   0          88m
default       etcd-operator-etcd-operator-etcd-backup-operator-6f6ffc75956pll   1/1     Running   0          97m
default       etcd-operator-etcd-operator-etcd-operator-7478ddcb4f-9qndw        1/1     Running   0          97m
default       etcd-operator-etcd-operator-etcd-restore-operator-794f5858czc84   1/1     Running   0          97m
kube-system   calico-kube-controllers-756b58d95d-65pgd                          1/1     Running   0          111m
kube-system   calico-node-7vxpz                                                 1/1     Running   0          111m
kube-system   calico-node-hm9j9                                                 1/1     Running   0          111m
kube-system   calico-node-lzw5h                                                 1/1     Running   0          111m
kube-system   calico-node-x2297                                                 1/1     Running   0          111m
kube-system   coredns-788d98cc7b-8v7ql                                          1/1     Running   0          110m
kube-system   coredns-788d98cc7b-ksvhn                                          1/1     Running   0          110m
kube-system   dns-autoscaler-66b95c57d9-gvcc5                                   1/1     Running   0          110m
kube-system   genie-network-admission-controller-tpwhs                          1/1     Running   0          99m
kube-system   genie-plugin-2ldw9                                                1/1     Running   0          99m
kube-system   genie-plugin-567wp                                                1/1     Running   0          99m
kube-system   genie-plugin-gv9rj                                                1/1     Running   0          99m
kube-system   genie-plugin-v7n56                                                1/1     Running   0          99m
kube-system   genie-policy-controller-h2g8z                                     1/1     Running   0          99m
kube-system   genie-policy-controller-jd2wl                                     1/1     Running   0          99m
kube-system   genie-policy-controller-pbbzz                                     1/1     Running   0          99m
kube-system   genie-policy-controller-qk5d7                                     1/1     Running   0          99m
kube-system   kube-apiserver-management                                         1/1     Running   0          112m
kube-system   kube-controller-manager-management                                1/1     Running   0          112m
kube-system   kube-proxy-6w9zt                                                  1/1     Running   0          110m
kube-system   kube-proxy-kgbzg                                                  1/1     Running   0          110m
kube-system   kube-proxy-mdp9h                                                  1/1     Running   0          111m
kube-system   kube-proxy-pm2d2                                                  1/1     Running   0          110m
kube-system   kube-scheduler-management                                         1/1     Running   0          112m
kube-system   kubernetes-dashboard-5db4d9f45f-cn6sw                             1/1     Running   0          110m
kube-system   nginx-proxy-compute1                                              1/1     Running   0          112m
kube-system   nginx-proxy-compute2                                              1/1     Running   0          112m
kube-system   nginx-proxy-compute3                                              1/1     Running   0          112m
kube-system   pon0-plugin-jk7d6                                                 1/1     Running   0          99m
kube-system   pon0-plugin-lj8q7                                                 1/1     Running   0          99m
kube-system   pon0-plugin-mzglt                                                 1/1     Running   0          99m
kube-system   pon0-plugin-qsvkm                                                 1/1     Running   0          99m
kube-system   tiller-deploy-7dc9577bfd-zvz9w                                    1/1     Running   0          100m
voltha        default-http-backend-798fb4f44c-cntcr                             1/1     Running   0          90m
voltha        freeradius-754bc76b5-g6qfw                                        1/1     Running   0          90m
voltha        netconf-85bf8d9db6-pwd42                                          1/1     Running   0          90m
voltha        nginx-ingress-controller-5fc7b87c86-tzzdr                         1/1     Running   0          90m
voltha        ofagent-6fd6dc8545-kmqkc                                          1/1     Running   0          90m
voltha        vcli-756fdb6685-mzw8l                                             1/1     Running   0          90m
voltha        vcore-0                                                           1/1     Running   0          90m
voltha        voltha-75486b7995-xv95t                                           1/1     Running   0          90m
```

```bash
kubectl get --namespace=voltha  services
```

```
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                        AGE
default-http-backend   ClusterIP   10.233.6.242    <none>        80/TCP                                                         92m
freeradius             ClusterIP   None            <none>        1812/UDP,1813/UDP,18120/TCP                                    92m
ingress-nginx          NodePort    10.233.3.127    <none>        80:30080/TCP,443:30443/TCP                                     92m
netconf                ClusterIP   None            <none>        830/TCP                                                        92m
vcli                   NodePort    10.233.58.167   <none>        5022:30110/TCP                                                 92m
vcore                  ClusterIP   None            <none>        8880/TCP,18880/TCP,50556/TCP                                   92m
voltha                 NodePort    10.233.31.16    <none>        8882:30125/TCP,8001:30648/TCP,8443:32443/TCP,50555:30959/TCP   92m
```

You should be able to `ssh` into the VOLTHA CLI from any node: management, compute1, compute2, or compute3. Use the `CLUSTER-IP` from the list above for the `vcli` and simply `ssh` into the CLI.
```bash
vagrant ssh management
ssh -p 5022 voltha@10.233.58.167 # Use the password `admin`
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

### Start the PON simulator
```bash
vagrant ssh management
helm install -n ponsimv2 cord/ponsimv2
```

Use the command `kubectl get --all-namespaces pods` to ensure all pods are running before continuing

### Register PON simulator with VOLTHA
```bash
vagrant ssh management
ssh -p 5022 voltha@10.233.58.167 # Use the password `admin`
(voltha) preprovision_olt -t ponsim_olt -H 10.233.56.128:50060
success (device id = 0001f3fea3271b74)
(voltha) devices
Devices:
+------------------+------------+----------------+---------------------+
|               id |       type |    admin_state |       host_and_port |
+------------------+------------+----------------+---------------------+
| 0001f3fea3271b74 | ponsim_olt | PREPROVISIONED | 10.233.56.128:50060 |
+------------------+------------+----------------+---------------------+
(voltha) enable
enabling 0001f3fea3271b74
success (logical device id = 0001aabbccddeeff)
(voltha) devices
Devices:
+------------------+------------+------+------------------+---------------------+------+-------------+-------------+----------------+----------------+---------------------+-------------------------+--------------------------+
|               id |       type | root |        parent_id |       serial_number | vlan | admin_state | oper_status | connect_status | parent_port_no |       host_and_port | proxy_address.device_id | proxy_address.channel_id |
+------------------+------------+------+------------------+---------------------+------+-------------+-------------+----------------+----------------+---------------------+-------------------------+--------------------------+
| 0001f3fea3271b74 | ponsim_olt | True | 0001aabbccddeeff | 10.233.56.128:50060 |      |     ENABLED |      ACTIVE |      REACHABLE |                | 10.233.56.128:50060 |                         |                          |
| 0001dc0a607d34e9 | ponsim_onu |      | 0001f3fea3271b74 |        PSMO12345678 |  128 |     ENABLED |      ACTIVE |      REACHABLE |              1 |                     |        0001f3fea3271b74 |                      128 |
+------------------+------------+------+------------------+---------------------+------+-------------+-------------+----------------+----------------+---------------------+-------------------------+--------------------------+
(voltha)
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

## Connecting VMs to Trellis (`mininet`)
In order to **wire in** the VMs into the `mininet` based fabric a GRE tunnel is created from the `network` VM to each of the other MV (`management` and `compute{1,2,3}`). The GRE tunnel is created in the `192.168.33.0/24` network space.

On the `network` VM the interfaces associated with the GRE tunnels are added to `openvswitch` instance that is created when `mininet` is started using `ovs-vsctl`. This is done by executing the include shell script `add-ports.sh`, which can be invoked by using `make inject-vms`.
