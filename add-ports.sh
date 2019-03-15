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

set -x

ovs-vsctl add-port s3 s3-gre1
ovs-vsctl add-port s4 s4-gre1
ovs-vsctl add-port s5 s5-gre1
ovs-vsctl add-port s6 s6-gre1
ovs-vsctl add-port s6 s6-gre2
ovs-vsctl add-port s7 s7-gre1
