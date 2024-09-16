#!/bin/bash

# set common options for connection to the JS7 REST Web Service
request_options=(--url=https://centostest-primary.sos:6446 --user=root --password=root --ca-cert=./root-ca.crt)

# ------------------------------ Controller ----------

# register Standalone Controller
./deploy-controller.sh register   "${request_options[@]}" --primary-url=http://localhost:9444 --primary-cluster-url=http://localhost:9444 --primary-title="Standalone Controller"

# check Standalone Controller Connection
./deploy-controller.sh check      "${request_options[@]}" --controller-url=http://localhost:9444

# unregister Standalone Controller
./deploy-controller.sh unregister "${request_options[@]}" --controller-id=training


# register Controller Cluster
./deploy-controller.sh register   "${request_options[@]}" --primary-url=http://localhost:9544   --primary-cluster-url=http://localhost:9544   --primary-title="Primary Controller" \
    --secondary-url=http://localhost:9644 --secondary-cluster-url=http://localhost:9644 --secondary-title="Secondary Controller"

# check Controller Cluster Connections
./deploy-controller.sh check      "${request_options[@]}" --controller-url=http://localhost:9544
./deploy-controller.sh check      "${request_options[@]}" --controller-url=http://localhost:9644

# unregister Controller Cluster
./deploy-controller.sh unregister "${request_options[@]}" --controller-id=training_cluster

# ------------------------------ Agents ----------

# store Standalone Agent
./deploy-controller.sh store-agent     "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId --agent-name=StandaloneAgentHttpName \
    --agent-url="http://localhost:9446"  --title="Standalone HTTP Agent" \
    --alias=Alias-1-StandaloneAgentHttp,Alias-2-StandaloneAgentHttp2 --process-limit=42

# delete Standalone Agent
./deploy-controller.sh delete-agent    "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId

# deploy Standalone Agent
./deploy-controller.sh deploy-agent    "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId

# revoke Standalone Agent
./deploy-controller.sh revoke-agent    "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId


# store Cluster Agent
./deploy-controller.sh store-agent     "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --agent-name=MyAgentClusterName_01 \
    --title="My Agent Cluster" --alias=Alias-1-AgentCluster,Alias-2-AgentCluster --process-limit=42 \
    --primary-subagent-id=primary-director-01     --primary-url=https://centostest-primary.sos:9645   --primary-title="My Primary Director" \
    --secondary-subagent-id=secondary-director-01 --secondary-url=https://centostest-primary.sos:9745 --secondary-title="My Secondary Director"

# delete Agent Cluster
./deploy-controller.sh delete-agent    "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01

# deploy Agent Cluster
./deploy-controller.sh deploy-agent    "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --cluster

# revoke Agent Cluster
./deploy-controller.sh revoke-agent    "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --cluster


# store Subagent
./deploy-controller.sh store-subagent  "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --subagent-id=MySubagent_01 \
                                                              --subagent-url=https://centostest-primary.sos:9845 --title="My Subagent 01"
./deploy-controller.sh store-subagent  "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --subagent-id=MySubagent_02 \
                                                              --subagent-url=http://centostest-primary.sos:9846 --title="My Subagent 02"

# delete Subagent
./deploy-controller.sh delete-subagent "${request_options[@]}" --controller-id=training_cluster --subagent-id=MySubagent_01


# store Subagent Cluster
./deploy-controller.sh store-cluster   "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 \
                                                             --cluster-id=active-passive --subagent-id=MySubagent_01,MySubagent_02 --priority=first --title="Active-Passive"

./deploy-controller.sh store-cluster   "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 \
                                                             --cluster-id=active-active --subagent-id=MySubagent_01,MySubagent_02 --priority=next --title="Active-Active"

# delete Subagent Cluster
./deploy-controller.sh delete-cluster   "${request_options[@]}" --controller-id=training_cluster --cluster-id=active-passive
./deploy-controller.sh delete-cluster   "${request_options[@]}" --controller-id=training_cluster --cluster-id=active-active

# deploy Subagent Cluster
./deploy-controller.sh deploy-cluster   "${request_options[@]}" --controller-id=training_cluster --cluster-id=active-passive
./deploy-controller.sh deploy-cluster   "${request_options[@]}" --controller-id=training_cluster --cluster-id=active-active

# revoke Subagent Cluster
./deploy-controller.sh revoke-cluster   "${request_options[@]}" --controller-id=training_cluster --cluster-id=active-active


# export Agents
./deploy-controller.sh export-agent     "${request_options[@]}" --controller-id=training_cluster --file=export_agents.zip --agent-id=StandaloneAgentHttpId,MyAgentClusterId_01

# import Agents
./deploy-controller.sh import-agent     "${request_options[@]}" --controller-id=training_cluster --file=export_agents.zipx

# ------------------------------ Encrypted Passwords ----------

# create Private Key
openssl ecparam -name secp384r1 -genkey -noout -out ./ca/private/encrypt.key

# create Certificate Signing Request
openssl req -new -sha512 -nodes -key ./ca/private/encrypt.key -out ./ca/csr/encrypt.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=SOS/OU=IT/CN=Encrypt"

# create Certificate
openssl x509 -req -sha512 -days 1825 -signkey ./ca/private/encrypt.key -in ./ca/csr/encrypt.csr -out ./ca/certs/encrypt.crt -extfile <(printf "keyUsage=critical,keyEncipherment,keyAgreement\n")

# encrypt
result=$(./deploy-controller.sh encrypt --in=root --cert=./ca/certs/encrypt.crt --java-home=/opt/java/jdk-21)

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password="enc:BEz9kY/z3D5e2RFZKL8m58c9ZpWY68kHGNMS9/Vkbj86aGjgqmMHURquLwIppu78sOZtrNWzpAFswrvvd3fTSGjwFYa1EpU43K5JTDq2x7NdXSE5djHmnJC3BFZikorfj/3W+nPEa7WYjUULS/sz/DBTBb3mWCjQcdP/y2k8QJ3WQzgYiQ== PjHY/QQcs2LYbMivSYjBLg== RjoPa/0xkdSTr8ogXUd3tA==" --key=./ca/private/encrypt.key --java-home=/opt/java/jdk-21 --controller-id=testsuite --ca-cert=./root-ca.crt)

# export Agents
./deploy-controller.sh export-agent "${request_options[@]}" --controller-id=training_cluster --file=export_agents.zip --agent-id=StandaloneAgentHttpId,MyAgentClusterId_01
