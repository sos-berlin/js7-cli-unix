#!/bin/bash

set -e

request_options=(--url=http://joc-2-0-primary.sos:7446 --user=root --password=root --controller-id=testsuite --ca-cert=./root-ca.crt)

# export workflows
./deploy-workflow.sh export ${request_options[@]} --file=export.zip --path=/ap/ap3jobs,/ap/Agent/apRunAsUser --type=WORKFLOW

# export draft schedules
./deploy-workflow.sh export ${request_options[@]} --file=export.zip --path=/ap/Agent/apAgentSchedule01,/ap/Agent/apAgentSchedule02 --type=SCHEDULE --no-released

# export objects from folder
./deploy-workflow.sh export ${request_options[@]} --file=export.zip --folder=/ap --recursive

# export objects from folder using relative path
./deploy-workflow.sh export ${request_options[@]} --file=export.zip --folder=/ap/Agent --recursive --use-short-path

# export objects from folder, limiting object type and validity, feeding audit log
./deploy-workflow.sh export ${request_options[@]} --file=export.zip --folder=/ap --recursive --type=WORKFLOW,NOTICEBOARD --no-invalid --audit-message="export to prod"


# import objects
./deploy-workflow.sh import ${request_options[@]} --file=export.zip --overwrite

# import objects with suffix
./deploy-workflow.sh import ${request_options[@]} --file=export.zip --folder=/ap --suffix=ap22


# export and import/deploy for high security level
request_options=(--url=https://centostest-primary.sos:6446 --user=ap-si-ecdsa --password=ap-si-ecdsa --controller-id=training --ca-cert=./training-ca.crt)
# export objects from folder for signing
./deploy-workflow.sh export ${request_options[@]}  --file=export.zip --folder=/myFolder --recursive --for-signing
# import/deploy objects
./deploy-workflow.sh import-deploy ${request_options[@]} --file=import-from-signing.zip


# deploy objects from folder
./deploy-workflow.sh deploy ${request_options[@]} --folder=/ap/Agent --recursive --date-from=now

# deploy workflows
./deploy-workflow.sh deploy ${request_options[@]} --path=/ap/ap3jobs,/ap/apEnv --type=WORKFLOW --date-from=now

# revoke objects from folder
./deploy-workflow.sh revoke ${request_options[@]} --folder=/ap/Agent --recursive 

# revoke workflows
./deploy-workflow.sh revoke ${request_options[@]} --path=/ap/ap3jobs,/ap/apEnv --type=WORKFLOW


e release objects from folder
./deploy-workflow.sh release ${request_options[@]} --folder=/ap/Agent --recursive --date-from=now

# release schedules
./deploy-workflow.sh release ${request_options[@]} --path=/ap/Agent/apAgentSchedule01,/ap/Agent/apAgentSchedule02 --type=SCHEDULE --date-from=now

# recall and remove schedule
./deploy-workflow.sh release ${request_options[@]} --path=/ap/Agent/apAgentSchedule03 --type=SCHEDULE --remove

# recall objects from folder
./deploy-workflow.sh recall ${request_options[@]} --folder=/ap/Agent --recursive 

# recall schedules
./deploy-workflow.sh recall ${request_options[@]} --path=/ap/Agent/apAgentSchedule01,/ap/Agent/apAgentSchedule02 --type=SCHEDULE


# store object
./deploy-workflow.sh store ${request_options[@]} --path=/ap/NewFolder01/NewWorkflow01 --type=WORKFLOW --file=NewWorkflow01.workflow.json

# remove object, update daily plan
./deploy-workflow.sh remove ${request_options[@]} --path=/ap/NewFolder01/NewWorkflow01 --type=WORKFLOW --date-from=now

# remove objects from folder, update daily plan
./deploy-workflow.sh remove ${request_options[@]} --folder=/ap/NewFolder01 --date-from=now


# restore object from trash, using suffix for restored objectd
./deploy-workflow.sh restore ${request_options[@]} --path=/ap/NewFolder01/NewWorkflow01 --type=WORKFLOW --new-path=/ap/NewFolder01/NewWorkflow01 --suffix=restored

# delete object from trash
./deploy-workflow.sh delete ${request_options[@]} --path=/ap/NewFolder01/NewWorkflow01 --type=WORKFLOW

# delete objects from trash by folder
./deploy-workflow.sh delete ${request_options[@]} --folder=/ap/NewFolder01

