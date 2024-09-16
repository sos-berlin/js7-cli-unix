#!/bin/bash

# set common options for connection to the JS7 REST Web Service
request_options=(--url=https://centostest-primary.sos:6446 --user=root --password=root --ca-cert=./root-ca.crt)

# ------------------------------ Controller ----------

# terminate Standalone Controller
./operate-controller.sh terminate      "${request_options[@]}" --controller-id=training

# restart Standalone Controller Connection
./operate-controller.sh restart        "${request_options[@]}" --controller-id=training

# cancel Standalone Controller
./operate-controller.sh cancel         "${request_options[@]}" --controller-id=training

# cancel and restart Standalone Controller
./operate-controller.sh cancel-restart "${request_options[@]}" --controller-id=training

# check Standalone Controller Connection
./operate-controller.sh check          "${request_options[@]}" --controller-id=training --controller-url=http://localhost:9444


# terminate Controller Cluster instance
./operate-controller.sh terminate      "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9544 --switch-over

# restart Controller Cluster instance
./operate-controller.sh restart        "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9544 --switch-over

# cancel Controller Cluster instance
./operate-controller.sh cancel         "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9544

# cancel and restart Controller Cluster instance
./operate-controller.sh cancel-restart "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9544

# switch-over Controller Cluster instance
./operate-controller.sh switch-over    "${request_options[@]}" --controller-id=training_cluster

# appoint nodes Controller Cluster
./operate-controller.sh appoint-nodes  "${request_options[@]}" --controller-id=training_cluster

# confirm node loss Controller Cluster
./operate-controller.sh confirm-loss   "${request_options[@]}" --controller-id=training_cluster

# check Controller Cluster Connection
./operate-controller.sh check          "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9544
./operate-controller.sh check          "${request_options[@]}" --controller-id=training_cluster --controller-url=http://localhost:9644

# ------------------------------ Agents ----------

# enable Standalone Agent
./operate-controller.sh enable-agent   "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId

# disable Standalone Agent
./operate-controller.sh disable-agent  "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId

# reset Standalone Agent
./operate-controller.sh reset-agent    "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId

# reset/force Standalone Agent
./operate-controller.sh reset-agent    "${request_options[@]}" --controller-id=training --agent-id=StandaloneAgentHttpId --force


# reset Agent Cluster
./operate-controller.sh reset-agent    "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01

# reset/force Agent Cluster
./operate-controller.sh reset-agent    "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --force

# switch-over Agent Cluster
./operate-controller.sh switch-over-agent  "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01

# confirm node loss Agent Cluster
./operate-controller.sh confirm-loss-agent "${request_options[@]}" --controller-id=training_cluster --agent-id=MyAgentClusterId_01


# enable Subagent in Agent Cluster
./operate-controller.sh enable-subagent    "${request_options[@]}" --controller-id=training_cluster --subagent-id=MySubagent_01

# disable Subagent in Agent Cluster
./operate-controller.sh disable-subagent   "${request_options[@]}" --controller-id=training_cluster --subagent-id=MySubagent_01

# reset Subagent in Agent Cluster
./operate-controller.sh reset-subagent     "${request_options[@]}" --controller-id=training_cluster --subagent-id=MySubagent_01

# ------------------------------ Encrypted Passwords ----------

# create Private Key
openssl ecparam -name secp384r1 -genkey -noout -out ./ca/private/encrypt.key

# create Certificate Signing Request
openssl req -new -sha512 -nodes -key ./ca/private/encrypt.key -out ./ca/csr/encrypt.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=SOS/OU=IT/CN=Encrypt"

# create Certificate
openssl x509 -req -sha512 -days 1825 -signkey ./ca/private/encrypt.key -in ./ca/csr/encrypt.csr -out ./ca/certs/encrypt.crt -extfile <(printf "keyUsage=critical,keyEncipherment,keyAgreement\n")

# encrypt
result=$(./operate-controller.sh encrypt --in=root --cert=./ca/certs/encrypt.crt --java-home=/opt/java/jdk-21)

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password="enc:BEXbHYacGkm/2bcx5NjYgLnsoxVMt1lpD3k+Dgc34aaTZIXnjbcatL5IQysNx1SUcnSNC6cr/Msfpv1Gau8znH6NiXAt08sAWTRpXQ5+YIALHl+ENt89lSfDCvfrEek82oJTAXStDHyfYMvYlJQYlb4BoelnHo7MagPiQP/E1ukqLI6S2w== VLJEgsBsKJedUUlSsMCCyQ== 7ajEelvz8w6HMvmFiGBIFA==" --key=./ca/private/encrypt.key --java-home=/opt/java/jdk-21 --controller-id=testsuite --ca-cert=./root-ca.crt)

# restart Standalone Controller Connection
./operate-controller.sh restart        "${request_options[@]}" --controller-id=training
