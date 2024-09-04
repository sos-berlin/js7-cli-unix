#!/bin/bash

set -e

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2024-08-24
# Purpose:  Deployment Operations on Workflows
# ------------------------------------------------------------
#
# Examples, see https://kb.sos-berlin.com/x/-YZvCQ

# request_options=(--url=http://localhost:4446 --user=root --password=root)  
#
# restart Standalone Controller
# ./operate-controller.sh restart ${request_options[@]} --controller-id=controller
#
# restart Controller Cluster
#./operate-controller.sh restart ${request_options[@]} --controller-id=controller_cluster --controller-url=http://localhost:9544
#
# reset Standalone Agent
# /operate-controller.sh reset-agent ${request_options[@]} --controller-id=controller --agent-id=StandaloneAgent
#
# reset/force Agent Cluster
# /operate-controller.sh reset-agent ${request_options[@]} --controller-id=controller_cluster --agent-id=ClusterAgent --force

# ------------------------------
# Global script variables
# ------------------------------

joc_url=
joc_user=
joc_password=
joc_cacert=
joc_client_cert=
joc_client_key=
timeout=60
make_dirs=
show_logs=
log_dir=
log_dir=
verbose=0
action=

item=
start_time=$(date +"%Y-%m-%dT%H-%M-%S")
response_json=
access_token=

controller_id=
controller_url=
agent_id=
subagent_id=
switch_over=false
force=false

audit_message=
audit_time_spent=0
audit_link=

# ------------------------------
# Inline Functions
# ------------------------------

AskPassword() {
    joc_password="$(
        exec < /dev/tty || exit
        tty_config=$(stty -g) || exit
        trap 'stty "$tty_config"' EXIT INT TERM
        stty -echo || exit
        printf 'Password: ' > /dev/tty
        IFS= read -r password; rc=$? 2> /dev/tty
        echo > /dev/tty
        printf '%s\n' "$password"
        exit "$rc"
    )"
}

Log()
{
    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
    then
        echo "$@" >> "${log_file}"
    fi
    
    if [ -z "${show_logs}" ]
    then
        echo "$@"
    fi
}

LogVerbose()
{
    if [ "${verbose}" -gt 0 ]
    then
        if [ -n "${log_file}" ] && [ -f "${log_file}" ]
        then
            echo "$@" >> "${log_file}"
        fi
    
        if [ -z "${show_logs}" ]
        then
            echo "$@"
        fi
    fi
}

LogWarning()
{
    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
    then
        echo "[WARN]" "$@" >> "${log_file}"
    fi
    
    >&2 echo "[WARN]" "$@"
}

LogError()
{
    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
    then
        echo "[ERROR]" "$@" >> "${log_file}"
    fi
    
    >&2 echo "[ERROR]" "$@"
}

Curl_Options()
{ 
    LogVerbose ".... Curl_Options"
    curl_options=(-k -L -s -S -X POST -m "${timeout}")

    if [ -n "${joc_user}" ] && [ -n "${joc_password}" ]
    then
        curl_options+=(--user "${joc_user}":"${joc_password}")
    fi

    if [ "${joc_cacert}" != "" ]
    then
        curl_options+=(--cacert "${joc_cacert}")
    fi

    if [ "${joc_client_cert}" != "" ]
    then
        curl_options+=(--cert "${joc_client_cert}")
    fi

    if [ "${joc_client_key}" != "" ]
    then
        curl_options+=(--key "${joc_client_key}")
    fi

    if [ "${verbose}" -gt 1 ]
    then
        curl_options+=(--verbose)
    fi
}

Audit_Log_Request()
{
    if [ -n "${audit_message}" ]
    then
        request_body="${request_body}, \"auditLog\": { \"comment\": \"${audit_message}\""

        if [ "${audit_time_spent}" -gt 0 ]
        then
            request_body="${request_body}, \"timeSpent\": ${audit_time_spent}"
        fi

        if [ -n "${audit_link}" ]
        then
            request_body="${request_body}, \"ticketLink\": \"${audit_link}\""
        fi

        request_body="${request_body} }"
    fi
}

Login()
{ 
    LogVerbose ".. Login"
    Curl_Options

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H "Accept: application/json" -H "Content-Type: application/json" ${joc_url}/joc/api/authentication/login"
    response_json=$(curl ${curl_options[@]} -H "Accept: application/json" -H "Content-Type: application/json" "${joc_url}"/joc/api/authentication/login)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        access_token=$(echo "${response_json}" | jq -r '.accessToken // empty' | sed 's/^"//' | sed 's/"$//')
        LogVerbose ".... access token: ${access_token}"
        if [ -z "${access_token}" ]
        then
            LogError "Login failed: ${response_json}"
            exit 4
        fi
    else
        LogError "Login failed: ${response_json}"
        exit 4
    fi
}

Logout()
{
    LogVerbose ".. Logout"
    Curl_Options

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" ${joc_url}/joc/api/authentication/logout"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" "${joc_url}"/joc/api/authentication/logout)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        item=$(echo "${response_json}" | jq -r 'select(.isAuthenticated == false) // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${item}" ]
        then
            LogError "Logout failed: ${response_json}"
            exit 4
        fi
        access_token=
    else
        LogError "Logout failed: ${response_json}"
        exit 4
    fi
}

Terminate_Controller()
{
    LogVerbose ".. Terminate_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${controller_url}" ]
    then
        request_body="${request_body}, \"url\": \"${controller_url}\""
    fi

    request_body="${request_body}, \"withSwitchover\": ${switch_over}"
    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/terminate"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/terminate)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        # Standalone Controller response
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')

        if [ -z "${ok}" ]
        then
            # Controller Cluster response
            ok=$(echo "${response_json}" | jq -r '.roles // empty' | sed 's/^"//' | sed 's/"$//')
        fi

        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Terminate_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Terminate_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Terminate_Controller() failed: ${response_json}"
        exit 4
    fi
}

Terminate_Restart_Controller()
{
    LogVerbose ".. Terminate_Restart_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${controller_url}" ]
    then
        request_body="${request_body}, \"url\": \"${controller_url}\""
    fi

    request_body="${request_body}, \"withSwitchover\": ${switch_over}"
    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/restart"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/restart)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Terminate_Restart_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Terminate_Restart_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Terminate_Restart_Controller() failed: ${response_json}"
        exit 4
    fi
}

Cancel_Controller()
{
    LogVerbose ".. Cancel_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${controller_url}" ]
    then
        request_body="${request_body}, \"url\": \"${controller_url}\""
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/abort"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/abort)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Cancel_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Cancel_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Cancel_Controller() failed: ${response_json}"
        exit 4
    fi
}

Cancel_Restart_Controller()
{
    LogVerbose ".. Cancel_Restart_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${controller_url}" ]
    then
        request_body="${request_body}, \"url\": \"${controller_url}\""
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/abort_and_restart"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/abort_and_restart)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Cancel_Restart_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Cancel_Restart_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Cancel_Restart_Controller() failed: ${response_json}"
        exit 4
    fi
}

Switchover_Controller()
{
    LogVerbose ".. Switchover_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/cluster/switchover"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/cluster/switchover)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Switchover_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Switchover_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Switchover_Controller() failed: ${response_json}"
        exit 4
    fi
}

Appoint_Nodes_Controller()
{
    LogVerbose ".. Appoint_Nodes_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/cluster/appoint_nodes"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/cluster/appoint_nodes)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Appoint_Nodes_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Appoint_Nodes_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Appoint_Nodes_Controller() failed: ${response_json}"
        exit 4
    fi
}

Confirm_Node_Loss_Controller()
{
    LogVerbose ".. Confirm_Node_Loss_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/cluster/confirm_node_loss"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/cluster/confirm_node_loss)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Confirm_Node_Loss_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Confirm_Node_Loss_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Confirm_Node_Loss_Controller() failed: ${response_json}"
        exit 4
    fi
}

Check_Controller()
{
    LogVerbose ".. Check_Controller()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\", \"url\": \"${controller_url}\""
    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/test"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/test)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.controller // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Check_Controller() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Check_Controller() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Check_Controller() failed: ${response_json}"
        exit 4
    fi
}

Enable_Standalone_Agent()
{
    LogVerbose ".. Enable_Standalone_Agent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    
    if [ -n "${agent_id}" ]
    then
        request_body="${request_body}, \"agentIds\": ["
        comma=
        set -- "$(echo "${agent_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents/inventory/enable"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents/inventory/enable)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Enable_Standalone_Agent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Enable_Standalone_Agent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Enable_Standalone_Agent() failed: ${response_json}"
        exit 4
    fi
}

Disable_Standalone_Agent()
{
    LogVerbose ".. Disable_Standalone_Agent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    
    if [ -n "${agent_id}" ]
    then
        request_body="${request_body}, \"agentIds\": ["
        comma=
        set -- "$(echo "${agent_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents/inventory/disable"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents/inventory/disable)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Disable_Standalone_Agent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Disable_Standalone_Agent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Disable_Standalone_Agent() failed: ${response_json}"
        exit 4
    fi
}

Reset_Agent()
{
    LogVerbose ".. Reset_Agent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\", \"agentId\": \"${agent_id}\", \"force\": ${force}"

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agent/reset"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agent/reset)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Reset_Agent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Reset_Agent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Reset_Agent() failed: ${response_json}"
        exit 4
    fi
}

Switchover_Agent()
{
    LogVerbose ".. Switchover_Agent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\", \"agentId\": \"${agent_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agent/cluster/switchover"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agent/cluster/switchover)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Switchover_Agent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Switchover_Agent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Switchover_Agent() failed: ${response_json}"
        exit 4
    fi
}

Confirm_Node_Loss_Agent()
{
    LogVerbose ".. Confirm_Node_Loss_Agent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\", \"agentId\": \"${agent_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agent/cluster/confirm_node_loss"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agent/cluster/confirm_node_loss)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Confirm_Node_Loss_Agent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Confirm_Node_Loss_Agent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Confirm_Node_Loss_Agent() failed: ${response_json}"
        exit 4
    fi
}

Enable_Subagent()
{
    LogVerbose ".. Enable_Subagent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    
    if [ -n "${subagent_id}" ]
    then
        request_body="${request_body}, \"subagentIds\": ["
        comma=
        set -- "$(echo "${subagent_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents/inventory/cluster/subagents/enable"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents/inventory/cluster/subagents/enable)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Enable_Subagent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Enable_Subagent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Enable_Subagent() failed: ${response_json}"
        exit 4
    fi
}

Disable_Subagent()
{
    LogVerbose ".. Disable_Subagent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    
    if [ -n "${subagent_id}" ]
    then
        request_body="${request_body}, \"subagentIds\": ["
        comma=
        set -- "$(echo "${subagent_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents/inventory/cluster/subagents/disable"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents/inventory/cluster/subagents/disable)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Disable_Subagent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Disable_Subagent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Disable_Subagent() failed: ${response_json}"
        exit 4
    fi
}

Reset_Subagent()
{
    LogVerbose ".. Reset_Subagent()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    
    if [ -n "${subagent_id}" ]
    then
        request_body="${request_body}, \"subagentId\": \"${subagent_id}\""
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents/inventory/cluster/subagent/reset"
    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents/inventory/cluster/subagent/reset)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Reset_Subagent() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Reset_Subagent() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Reset_Subagent() failed: ${response_json}"
        exit 4
    fi
}

Usage()
{
    >&"$1" echo ""
    >&"$1" echo "Usage: $(basename "$0") [Command] [Options] [Switches]"
    >&"$1" echo ""
    >&"$1" echo "  Commands:"
    >&"$1" echo "    terminate           --controller-id [--controller-url] [--switch-over]"
    >&"$1" echo "    restart             --controller-id [--controller-url] [--switch-over]"
    >&"$1" echo "    cancel              --controller-id [--controller-url]"
    >&"$1" echo "    cancel-restart      --controller-id [--controller-url]"
    >&"$1" echo "    switch-over         --controller-id"
    >&"$1" echo "    appoint-nodes       --controller-id"
    >&"$1" echo "    confirm-loss        --controller-id"
    >&"$1" echo "    check               --controller-id --controller-url"
    >&"$1" echo "    enable-agent        --controller-id --agent-id"
    >&"$1" echo "    disable-agent       --controller-id --agent-id"
    >&"$1" echo "    reset-agent         --controller-id --agent-id [--force]"
    >&"$1" echo "    switch-over-agent   --controller-id --agent-id"
    >&"$1" echo "    confirm-loss-agent  --controller-id --agent-id"
    >&"$1" echo "    enable-subagent     --controller-id --subagent-id"
    >&"$1" echo "    disable-subagent    --controller-id --subagent-id"
    >&"$1" echo "    reset-subagent      --controller-id --subagent-id [--force]"
    >&"$1" echo ""
    >&"$1" echo "  Options:"
    >&"$1" echo "    --url=<url>                        | required: JOC Cockpit URL"
    >&"$1" echo "    --user=<account>                   | required: JOC Cockpit user account"
    >&"$1" echo "    --password=<password>              | optional: JOC Cockpit password"
    >&"$1" echo "    --ca-cert=<path>                   | optional: path to CA Certificate used for JOC Cockpit login"
    >&"$1" echo "    --client-cert=<path>               | optional: path to Client Certificate used for login"
    >&"$1" echo "    --client-key=<path>                | optional: path to Client Key used for login"
    >&"$1" echo "    --timeout=<seconds>                | optional: timeout for request, default: ${timeout}"
    >&"$1" echo "    --controller-id=<id>               | required: Controller ID"
    >&"$1" echo "    --controller-url=<url>             | optional: Controller URL for connection test"
    >&"$1" echo "    --agent-id=<id[,id]>               | optional: Agent IDs"
    >&"$1" echo "    --subagent-id=<id[,id]>            | optional: Subagent ID"
    >&"$1" echo "    --audit-message=<string>           | optional: audit log message"
    >&"$1" echo "    --audit-time-spent=<number>        | optional: audit log time spent in minutes"
    >&"$1" echo "    --audit-link=<url>                 | optional: audit log link"
    >&"$1" echo "    --log-dir=<directory>              | optional: path to directory holding the script's log files"
    >&"$1" echo ""
    >&"$1" echo "  Switches:"
    >&"$1" echo "    -h | --help                        | displays usage"
    >&"$1" echo "    -v | --verbose                     | displays verbose output, repeat to increase verbosity"
    >&"$1" echo "    -p | --password                    | asks for password"
    >&"$1" echo "    -o | --switch-over                 | switches over the active role to the standby instance"
    >&"$1" echo "    -f | --force                       | forces reset on Agent"
    >&"$1" echo "    --show-logs                        | shows log output if --log-dir is used"
    >&"$1" echo "    --make-dirs                        | creates directories if they do not exist"
    >&"$1" echo ""
    >&"$1" echo "see https://kb.sos-berlin.com/x/9YZvCQ"
    >&"$1" echo ""
}

Arguments()
{
    args="$*"

    if [ -z "$1" ]
    then
        Usage 1
        exit
    fi

    case "$1" in
        terminate|restart|cancel|cancel-restart|switch-over|appoint-nodes|confirm-loss|check|enable-agent|disable-agent|reset-agent|confirm-loss-agent|switch-over-agent|enable-subagent|disable-subagent|reset-subagent) action=$1
                                    ;;
        -h|--help)                  Usage 1
                                    exit
                                    ;;
        *)                          Usage 2
                                    >&2 echo "unknown command: $1"
                                    exit 1
                                    ;;
    esac

    for option in "$@"
    do
        case "${option}" in
            --url=*)                joc_url=$(echo "${option}" | sed 's/--url=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --user=*)               joc_user=$(echo "${option}" | sed 's/--user=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --password=*)           joc_password=$(echo "${option}" | sed 's/--password=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --ca-cert=*)            joc_cacert=$(echo "${option}" | sed 's/--ca-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --client-cert=*)        joc_client_cert=$(echo "${option}" | sed 's/--client-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --client-key=*)         joc_client_key=$(echo "${option}" | sed 's/--client-key=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --timeout=*)            timeout=$(echo "${option}" | sed 's/--timeout=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-id=*)      controller_id=$(echo "${option}" | sed 's/--controller-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-url=*)     controller_url=$(echo "${option}" | sed 's/--controller-url=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --agent-id=*)           agent_id=$(echo "${option}" | sed 's/--agent-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --subagent-id=*)        subagent_id=$(echo "${option}" | sed 's/--subagent-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --audit-message=*)      audit_message=$(echo "${option}" | sed 's/--audit-message=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --audit-time-spent=*)   audit_time_spent=$(echo "${option}" | sed 's/--audit-time-spent=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --audit-link=*)         audit_link=$(echo "${option}" | sed 's/--audit-link=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --log-dir=*)            log_dir=$(echo "${option}" | sed 's/--log-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            # Switches
            -h|--help)              Usage 1
                                    exit
                                    ;;
            -v|--verbose)           verbose=$((verbose + 1))
                                    ;;
            -p|--password)          AskPassword
                                    ;;
            -s|--switch-over)       switch_over=true
                                    ;;
            -f|--force)             force=true
                                    ;;
            --make-dirs)            make_dirs=1
                                    ;;
            --show-logs)            show_logs=1
                                    ;;
            terminate|restart|cancel|cancel-restart|switch-over|appoint-nodes|confirm-loss|check|enable-agent|disable-agent|reset-agent|confirm-loss-agent|switch-over-agent|enable-subagent|disable-subagent|reset-subagent) action=$1
                                    ;;
            *)                      Usage 2
                                    >&2 echo "unknown option: ${option}"
                                    exit 1
                                    ;;
        esac
    done


    if ! command -v curl &> /dev/null
    then
        LogError "curl utility not found"
        exit 1
    fi

    if ! command -v jq &> /dev/null
    then
        LogError "jq utility not found"
        exit 1
    fi

    if [ -z "${joc_url}" ]
    then
        Usage 2
        LogError "JOC Cockpit URL not specified: --url=<url>"
        exit 1
    fi

    if [ -z "${joc_user}" ]
    then
        Usage 2
        LogError "JOC Cockpit user account not specified: --user=<account>"
        exit 1
    fi

    if [ -n "${joc_cacert}" ] && [ ! -f "${joc_cacert}" ]
    then
        Usage 2
        LogError "Root CA Certificate file not found: --cacert=${joc_cacert}"
        exit 1
    fi

    if [ -n "${joc_client_cert}" ] && [ ! -f "${joc_client_cert}" ]
    then
        LogError "Client Certificate file not found: --client-cert=${joc_client_cert}"
        Usage 2
        exit 1
    fi

    if [ -n "${joc_client_key}" ] && [ ! -f "${joc_client_key}" ]
    then
        Usage 2
        LogError "Client Private Key file not found: --client-key=${joc_client_key}"
        exit 1
    fi

    if [ ! "${action}" = "check" ] && [ -z "${controller_id}" ]
    then
        Usage 2
        LogError "Controller ID must be specified: --controller-id="
        exit 1
    fi

    if [ "${action}" = "check" ] && [ -z "${controller_url}" ]
    then
        Usage 2
        LogError "Command 'check' requires to specify the Controller instance URL: --controller-url="
        exit 1
    fi

    actions="|enable-agent|disable-agent|reset-agent|confirm-loss-agent|switch-over-agent|"
    if [[ "${actions}" == *"|${action}|"* ]] && [ -z "${agent_id}" ]
    then
        Usage 2
        LogError "Command '${action}' requires to specify the Agent ID: --agent-id="
        exit 1
    fi

    actions="|enable-subagent|disable-subagent|reset-subagent|"
    if [[ "${actions}" == *"|${action}|"* ]] && [ -z "${subagent_id}" ]
    then
        Usage 2
        LogError "Command '$action' requires to specify the Subagent ID: --subagent-id="
        exit 1
    fi

    if [ -n "${show_logs}" ] && [ -z "${log_dir}" ]
    then
        Usage 2
        LogError "Log directory not specified and --show-logs switch is present: --log-dir="
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${log_dir}" ] && [ ! -d "${log_dir}" ]
    then
        Usage 2
        LogError "Log directory not found and --make-dirs switch not present: --log-dir=${log_dir}"
        exit 1
    fi

    # initialize logging
    if [ -n "${log_dir}" ]
    then
        # create log directory if required
        if [ ! -d "${log_dir}" ] && [ -n "${make_dirs}" ]
        then
            mkdir -p "${log_dir}"
        fi
    
        log_file="${log_dir}"/operate-controller."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/operate-controller."${start_time}".log
        done
        
        touch "${log_file}"
    fi

    LogVerbose "-- begin of log --------------"
    LogVerbose "$0" "$(echo "${args}" | sed 's/--password=\([^--]*\)//')"
    LogVerbose "-- begin of output -----------"
}

# ------------------------------
# Main
# ------------------------------

Process()
{
    LogVerbose ".. Processing"
    Login

    case "${action}" in
        terminate)          Terminate_Controller
                            ;;
        restart)            Terminate_Restart_Controller
                            ;;
        cancel)             Cancel_Controller
                            ;;
        cancel-restart)     Cancel_Restart_Controller
                            ;;
        switch-over)        Switchover_Controller
                            ;;
        appoint-nodes)      Appoint_Nodes_Controller
                            ;;
        confirm-loss)       Confirm_Node_Loss_Controller
                            ;;
        check)              Check_Controller
                            ;;
        enable-agent)       Enable_Standalone_Agent
                            ;;
        disable-agent)      Disable_Standalone_Agent
                            ;;
        reset-agent)        Reset_Agent
                            ;;
        agent-confirm-loss) Confirm_Node_Loss_Agent
                            ;;
        agent-switch-over)  Agent_Switchover
                            ;;
        enable-subagent)    Enable_Subagent
                            ;;
        disable-subagent)   Disable_Subagent
                            ;;
        reset-subagent)     Reset_Subagent
                            ;;
    esac

    Logout
}

# ------------------------------
# Cleanup trap
# ------------------------------

End()
{
    if [ -n "${access_token}" ]
    then
        Logout
    fi

    if [ "$1" = "EXIT" ]
    then
        LogVerbose "-- end of log ----------------"

        if [ -n "${show_logs}" ] && [ -f "${log_file}" ]
        then
            cat "${log_file}"
        fi        
    fi

    unset joc_url
    unset joc_cacert
    unset joc_client_cert
    unset joc_client_key
    unset joc_user
    unset joc_password
    unset timeout

    unset make_dirs
    unset show_logs
    unset verbose
    unset log_dir

    unset controller_id
    unset controller_url
    unset agent_id
    unset subagent_id
    unset switch_over
    unset force

    unset audit_message
    unset audit_time_spent
    unset audit_link

    unset log_file
    unset start_time

    unset response_json
    unset access_token
    unset curl_options
    unset action

    set +e
}

# ------------------------------
# Enable trap and start
# ------------------------------

trap 'End EXIT' EXIT
trap 'End SIGTERM' TERM
trap 'End SIGINT' INT

Arguments "$@"
Process