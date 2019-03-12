#!/bin/bash 

set -x

ovs-vsctl add-port s3 s3-gre1
ovs-vsctl add-port s4 s4-gre1
ovs-vsctl add-port s5 s5-gre1
ovs-vsctl add-port s6 s6-gre1
ovs-vsctl add-port s6 s6-gre2
ovs-vsctl add-port s7 s7-gre1
