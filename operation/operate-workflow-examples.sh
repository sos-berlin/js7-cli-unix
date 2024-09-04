#!/bin/bash

set -e

request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password=root --controller-id=testsuite --ca-cert=./root-ca.crt)

# add ad hoc order
./operate-workflow.sh add-order ${request_options[@]}          --workflow=ap3jobs

# add ad hoc order
./operate-workflow.sh add-order ${request_options[@]}          --date-to=now --workflow=ap3jobs --order-name=sample-1 --start-position=job2 --end-position=job3

# add pending order
./operate-workflow.sh add-order ${request_options[@]}          --date-to=never --workflow=ap3jobs --order-name=sample-1 --start-position=job2 --end-position=job3

# add scheduled order and force admission
./operate-workflow.sh add-order ${request_options[@]}          --date-to=now+15 --workflow=ap3jobs --order-name=sample-1 --start-position=job2 --end-position=job3 --force

# add ad hoc order and feed audit log
./operate-workflow.sh add-order ${request_options[@]}          --workflow=ap3jobs \
                                                               --audit-message="order added by operate-workflow.sh" --audit-time-spent=1 \
                                                               --audit-link="https://www.sos-berlin.com"


# cancel order by state
./operate-workflow.sh cancel-order ${request_options[@]}       --date-to=-2h --workflow=ap3jobs --state=SCHEDULED,PROMPTING,SUSPENDED,INPROGRESS,RUNNING

# cancel order by state, folder recursively
./operate-workflow.sh cancel-order ${request_options[@]}       --date-to=-2h --folder=/ap --recursive --state=SCHEDULED,PROMPTING,SUSPENDED,INPROGRESS,RUNNING


# suspend order
./operate-workflow.sh suspend-order ${request_options[@]}      --workflow=ap3jobs

# suspend order and terminate running job
./operate-workflow.sh suspend-order ${request_options[@]}      --workflow=ap3jobs -force


# resume suspended orders
./operate-workflow.sh resume-order ${request_options[@]}       --workflow=ap3jobs --state=SUSPENDED


# let run waiting order
./operate-workflow.sh letrun-order ${request_options[@]}       --workflow=ap3jobs --state=WAITING


# transfer order
./operate-workflow.sh transfer-order ${request_options[@]}     --workflow=ap3jobs


# suspend workflow
./operate-workflow.sh suspend-workflow ${request_options[@]}   --workflow=ap3jobs


# resume workflow
./operate-workflow.sh resume-workflow ${request_options[@]}    --workflow=ap3jobs


# stop jobs
./operate-workflow.sh stop-job ${request_options[@]}           --workflow=ap3jobs --label=job1,job2

# unstop jobs
./operate-workflow.sh unstop-job ${request_options[@]}         --workflow=ap3jobs --label=job1,job2


# skip job
./operate-workflow.sh skip-job ${request_options[@]}           --workflow=ap3jobs --label=job1,job2

# unskip job
./operate-workflow.sh unskip-job -${request_options[@]}        --workflow=ap3jobs --label=job1,job2


# post notice for current daily plan
./operate-workflow.sh post-notice ${request_options[@]}        --notice-board=ap3jobs

# post notice for specific daily plan date
./operate-workflow.sh post-notice ${request_options[@]}        --notice-board=ap3jobs --notice-id=2024-08-26 --notice-lifetime=6h

# get notices by folder
./operate-workflow.sh get-notice ${request_options[@]}         --folder=/ap --recursive

# delete notice for current daily plan
./operate-workflow.sh delete-notice ${request_options[@]}      --notice-board=ap3jobs

# delete notice for specific daily plan date
./operate-workflow.sh delete-notice ${request_options[@]}      --notice-board=ap3jobs --notice-id=2024-08-25,2024-08-26

# delete notices by folder
./operate-workflow.sh delete-notice ${request_options[@]}      --folder=/ap --recursive

