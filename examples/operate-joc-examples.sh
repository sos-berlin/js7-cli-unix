#!/bin/bash

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password=root --ca-cert=./root-ca.crt)

# ------------------------------ Status ----------

# get status information on JOC Cockpit and Controller instances
./operate-joc.sh status "${request_options[@]}" --controller-id=testsuite

# get status informaiton on Agents
./operate-joc.sh status-agent "${request_options[@]}" --controller-id=testsuite

# get status informiaton on Agents limited by state
./operate-joc.sh status-agent "${request_options[@]}" --controller-id=testsuite --agent-id=agent_001,agent_002

# ------------------------------ Health Check ----------

# perform health check
./operate-joc.sh health-check "${request_options[@]}" --controller-id=testsuite

# perform health check for host shutdown scenario
./operate-joc.sh health-check "${request_options[@]}" --controller-id=testsuite --agent-cluster --whatif-shutdown=joc-2-0-primary

# ------------------------------ Switch-over ----------

# switch-over active role
./operate-joc.sh switch-over "${request_options[@]}" --controller-id=testsuite

# ------------------------------ Restart / Run Service ----------

# restart service: cluster, history, dailyplan, cleanup, monitor
./operate-joc.sh restart-service "${request_options[@]}" --service-type=dailyplan

# run service: dailyplan, cleanup
./operate-joc.sh run-service "${request_options[@]}" --service-type=dailyplan

# ------------------------------ Settings ----------

# get settings
settings=$(./operate-joc.sh get-settings "${request_options[@]}")

# update settings
settings=$(echo "${settings}" | jq '.dailyplan.projections_month_ahead.value = "19"')

# store settings
./operate-joc.sh store-settings "${request_options[@]}" --settings="${settings}"

# ------------------------------ License ----------

# check license
./operate-joc.sh check-license "${request_options[@]}"

# ------------------------------ Version ----------

# get version
./operate-joc.sh version "${request_options[@]}"
./operate-joc.sh version "${request_options[@]}" --controller-id=testsuite
./operate-joc.sh version "${request_options[@]}" --agent-id=StandaloneAgentHttpId
./operate-joc.sh version "${request_options[@]}" --agent-id=MyAgentClusterId_01
./operate-joc.sh version "${request_options[@]}" --controller-id=standalone --agent-id=agent_003

# ------------------------------ Encrypted Passwords ----------

# create Private Key
openssl ecparam -name secp384r1 -genkey -noout -out ./ca/private/encrypt.key

# create Certificate Signing Request
openssl req -new -sha512 -nodes -key ./ca/private/encrypt.key -out ./ca/csr/encrypt.csr -subj "/C=DE/ST=Berlin/L=Berlin/O=SOS/OU=IT/CN=Encrypt"

# create Certificate
openssl x509 -req -sha512 -days 1825 -signkey ./ca/private/encrypt.key -in ./ca/csr/encrypt.csr -out ./ca/certs/encrypt.crt -extfile <(printf "keyUsage=critical,keyEncipherment,keyAgreement\n")

# encrypt
result=$(./operate-joc.sh encrypt --in=root --cert=./ca/certs/encrypt.crt --java-home=/opt/java/jdk-21)

# set common options for connection to the JS7 REST Web Service
request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password="enc:BEz9kY/z3D5e2RFZKL8m58c9ZpWY68kHGNMS9/Vkbj86aGjgqmMHURquLwIppu78sOZtrNWzpAFswrvvd3fTSGjwFYa1EpU43K5JTDq2x7NdXSE5djHmnJC3BFZikorfj/3W+nPEa7WYjUULS/sz/DBTBb3mWCjQcdP/y2k8QJ3WQzgYiQ== PjHY/QQcs2LYbMivSYjBLg== RjoPa/0xkdSTr8ogXUd3tA==" --key=./ca/private/encrypt.key --java-home=/opt/java/jdk-21 --controller-id=testsuite --ca-cert=./root-ca.crt)

# check license
./operate-joc.sh check-license "${request_options[@]}"
