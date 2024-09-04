#!/bin/bash

set -e

request_options=(--url=https://centostest-primary.sos:6446 --user=root --password=root --ca-cert=./root-ca.crt)

# terminate Standalone Controller
./operate-controller.sh terminate ${request_options[@]}          --controller-id=training

# restart Standalone Controller Connection
./operate-controller.sh restart ${request_options[@]}            --controller-id=training

# cancel Standalone Controller
./operate-controller.sh cancel ${request_options[@]}             --controller-id=training

# cancel and restart Standalone Controller
./operate-controller.sh cancel-restart ${request_options[@]}     --controller-id=training

# check Standalone Controller Connection
./operate-controller.sh check ${request_options[@]}              --controller-id=training --controller-url=http://localhost:9444


# terminate Controller Cluster instance
./operate-controller.sh terminate ${request_options[@]}          --controller-id=training_cluster --controller-url=http://localhost:9544 --switch-over

# restart Controller Cluster instance
./operate-controller.sh restart ${request_options[@]}            --controller-id=training_cluster --controller-url=http://localhost:9544 --switch-over

# cancel Controller Cluster instance
./operate-controller.sh cancel ${request_options[@]}             --controller-id=training_cluster --controller-url=http://localhost:9544

# cancel and restart Controller Cluster instance
./operate-controller.sh cancel-restart ${request_options[@]}     --controller-id=training_cluster --controller-url=http://localhost:9544

# switch-over Controller Cluster instance
./operate-controller.sh switch-over ${request_options[@]}        --controller-id=training_cluster

# appoint nodes Controller Cluster
./operate-controller.sh appoint-nodes ${request_options[@]}      --controller-id=training_cluster

# confirm node loss Controller Cluster
./operate-controller.sh confirm-loss ${request_options[@]}       --controller-id=training_cluster

# check Controller Cluster Connection
./operate-controller.sh check ${request_options[@]}              --controller-id=training_cluster --controller-url=http://localhost:9544
./operate-controller.sh check ${request_options[@]}              --controller-id=training_cluster --controller-url=http://localhost:9644


# enable Standalone Agent
./operate-controller.sh enable-agent ${request_options[@]}       --controller-id=training --agent-id=StandaloneAgentHttpId

# disable Standalone Agent
./operate-controller.sh disable-agent ${request_options[@]}      --controller-id=training --agent-id=StandaloneAgentHttpId

# reset Standalone Agent
./operate-controller.sh reset-agent ${request_options[@]}        --controller-id=training --agent-id=StandaloneAgentHttpId

# reset/force Standalone Agent
./operate-controller.sh reset-agent ${request_options[@]}        --controller-id=training --agent-id=StandaloneAgentHttpId --force


# reset Agent Cluster
./operate-controller.sh reset-agent ${request_options[@]}        --controller-id=training_cluster --agent-id=MyAgentClusterId_01

# reset/force Agent Cluster
./operate-controller.sh reset-agent ${request_options[@]}        --controller-id=training_cluster --agent-id=MyAgentClusterId_01 --force

# switch-over Agent Cluster
./operate-controller.sh switch-over-agent ${request_options[@]}  --controller-id=training_cluster --agent-id=MyAgentClusterId_01

# confirm node loss Agent Cluster
./operate-controller.sh confirm-loss-agent ${request_options[@]} --controller-id=training_cluster --agent-id=MyAgentClusterId_01


# enable Subagent in Agent Cluster
./operate-controller.sh enable-subagent ${request_options[@]}    --controller-id=training_cluster --subagent-id=MySubagent_01

# disable Subagent in Agent Cluster
./operate-controller.sh disable-subagent ${request_options[@]}   --controller-id=training_cluster --subagent-id=MySubagent_01

# reset Subagent in Agent Cluster
./operate-controller.sh reset-subagent ${request_options[@]}     --controller-id=training_cluster --subagent-id=MySubagent_01
