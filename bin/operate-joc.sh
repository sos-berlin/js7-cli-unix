#!/bin/bash

set -e

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2024-08-24
# Purpose:  Status Operations on JOC Cockpit
# ------------------------------------------------------------
#
# Examples, see https://kb.sos-berlin.com/x/-YZvCQ

# request_options=(--url=http://localhost:4446 --user=root --password=root)  
#
# check license
# ./operate-joc.sh check-license "${request_options[@]}"
#

# ------------------------------
# Global script variables
# ------------------------------

script_home=$(dirname "$(cd "$(dirname "$0")" >/dev/null && pwd)")

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
whatif_shutdown=
validity_days=60
service_type=
member_id=
version=
agent_id=
settings=
json=0

agent_id=
agent_state=
agent_cluster=0
no_hidden=false

key_file=
cert_file=
key_password=
in=
infile=
outfile=
java_home=
java_bin=
java_lib="${script_home}"/lib

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
        IFS= read -r joc_password; rc=$? 2> /dev/tty
        echo > /dev/tty
        printf '%s\n' "${joc_password}"
        exit "$rc"
    )"
}

AskKeyPassword() {
    key_password="$(
        exec < /dev/tty || exit
        tty_config=$(stty -g) || exit
        trap 'stty "$tty_config"' EXIT INT TERM
        stty -echo || exit
        printf 'Keystore/Key Password: ' > /dev/tty
        IFS= read -r key_password; rc=$? 2> /dev/tty
        echo > /dev/tty
        printf '%s\n' "${key_password}"
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

    curl_log_options=("${curl_options[@]}")

    if [ -n "${joc_user}" ] && [ -n "${joc_password}" ]
    then
        curl_options+=(--user "${joc_user}":"${joc_password}")
        curl_log_options+=(--user "${joc_user}:********")
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
    LogVerbose "curl ${curl_log_options[*]} -H "Accept: application/json" -H "Content-Type: application/json" ${joc_url}/joc/api/authentication/login"
    response_json=$(curl "${curl_options[@]}" -H "Accept: application/json" -H "Content-Type: application/json" "${joc_url}"/joc/api/authentication/login)
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
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" ${joc_url}/joc/api/authentication/logout"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" "${joc_url}"/joc/api/authentication/logout)
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

Get_Settings()
{
    LogVerbose ".. Get_Settings()"
    Curl_Options

    request_body="{}"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/settings"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/settings)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.configuration // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Get_Settings() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Get_Settings() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Get_Settings() failed: ${response_json}"
        exit 4
    fi
    
    echo "${response_json}" | jq -r '.configuration.configurationItem // empty'
}

Store_Settings()
{
    LogVerbose ".. Store_Settings()"
    Curl_Options

    request_body="{ \"configurationItem\": $(echo "${settings}" | jq -c | jq -RM)"

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/settings/store"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/settings/store)
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
                LogWarning "Store_Settings() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Store_Settings() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Store_Settings() failed: ${response_json}"
        exit 4
    fi
}

Switch_Over()
{
    LogVerbose ".. Switch_Over()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\"" 
    
    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/components"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/components)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.jocs // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Switch_Over() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Switch_Over() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Switch_Over() failed: ${response_json}"
        exit 4
    fi

    member_id=$(echo "$response_json" | jq -r '.jocs[] | select(.clusterNodeState.severity == 1) | .memberId // empty')
    
    if [ -z "${member_id}" ]
    then
        LogError "Switch_Over() failed, no standby JOC Cockpit instance found: ${response_json}"
        exit 4
    fi
    
    request_body="{ \"memberId\": \"${member_id}\""

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/joc/cluster/switch_member"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/joc/cluster/switch_member)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.state // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Switch_Over() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Switch_Over() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Switch_Over() failed: ${response_json}"
        exit 4
    fi
}

Restart_Service()
{
    LogVerbose ".. Restart_Service()"
    Curl_Options

    request_body="{"

    if [ -n "${service_type}" ]
    then
        request_body="${request_body} \"type\": \"${service_type}\""
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/joc/cluster/restart"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/joc/cluster/restart)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.state // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Restart_Service() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Restart_Service() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Restart_Service() failed: ${response_json}"
        exit 4
    fi
}

Run_Service()
{
    LogVerbose ".. Run_Service()"
    Curl_Options

    request_body="{"

    if [ -n "${service_type}" ]
    then
        request_body="${request_body} \"type\": \"${service_type}\""
    fi

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/joc/cluster/run"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/joc/cluster/run)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.state // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Run_Service() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Run_Service() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Run_Service() failed: ${response_json}"
        exit 4
    fi
}

Check_License()
{
    LogVerbose ".. Check_License()"
    Curl_Options

    LogVerbose ".... check license for validity period of ${validity_days} days"
    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" ${joc_url}/joc/api/joc/license"

    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" "${joc_url}"/joc/api/joc/license)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r ".type // empty" | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            LogError "Check_License() license check failed: ${response_json}"
            exit 4
        else
            license_type=$(echo "${response_json}" | jq -r '.type // empty' | sed 's/^"//' | sed 's/"$//')
            license_valid=$(echo "${response_json}" | jq -r '.valid // empty' | sed 's/^"//' | sed 's/"$//')
            license_valid_from=$(echo "${response_json}" | jq -r '.validFrom // empty' | sed 's/^"//' | sed 's/"$//')
            license_valid_until=$(echo "${response_json}" | jq -r '.validUntil // empty' | sed 's/^"//' | sed 's/"$//')

            Log ".... License type: ${license_type}"
            if [ -n "${license_valid}" ]
            then
                Log ".... License valid: ${license_valid}"
            else
                Log ".... License valid: not applicable"
                
                LogError "Check_License() license check failed: license check not applicable for open source license"
                exit 2                
            fi

            Log ".... License valid from: ${license_valid_from}"
            Log ".... License valid until: ${license_valid_until}"

            if [ -n "${license_valid_until}" ]
            then
                current_date=$(TZ=UTC date +%s)
                license_date=$(TZ=UTC date -d"${license_valid_until}" +%s)
                license_period=$(( license_date - current_date ))
                if (( license_period < 1 ))
                then
                    LogError "Check_License() license check failed: license expired on ${license_valid_until}"
                    exit 2
                else
                    ms_period=$(( validity_days * 86400 ))
                    ms_period=$(( license_period - ms_period ))
                    if (( ms_period < 1 )) 
                    then
                        Log "Check_License() license check warning: license will expire on ${license_valid_until}"
                        exit 3
                    fi
                fi
            fi
        fi
    else
        LogError "Check_License() license check failed: ${response_json}"
        exit 4
    fi
}

Status()
{
    raw=$1
    LogVerbose ".. Status()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\"" 
    
    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/controller/components"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/controller/components)    
    LogVerbose ".... response:"
    
    if [ "${raw}" -eq 1 ]
    then
        Log "${response_json}"
    else
        LogVerbose "${response_json}"
    fi

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.jocs // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Status() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Status() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Status() failed: ${response_json}"
        exit 4
    fi
}

Status_Agent()
{
    raw=$1
    LogVerbose ".. Status_Agent()"
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

    if [ -n "${agent_state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${agent_state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body}, \"onlyVisibleAgents\": ${no_hidden}"

    Audit_Log_Request
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/agents"
    response_json_agent=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/agents)    
    LogVerbose ".... response:"
    LogVerbose "${response_json_agent}"

    if echo "${response_json_agent}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json_agent}" | jq -r '.agents // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json_agent}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Status_Agent() could not perform operation: ${response_json_agent}"
                exit 3
            else
                LogError "Status_Agent() failed: ${response_json_agent}"
                exit 4
            fi
        fi
    else
        LogError "Status_Agent() failed: ${response_json_agent}"
        exit 4
    fi

    if [ "${agent_cluster}" -eq 1 ]
    then
        response_json_agent=$(echo "${response_json_agent}" |  jq -r '.agents[] | select(.clusterState.severity != null) | { "agents": [.] } // empty' | jq -c)
    fi

    if [ "${raw}" -eq 1 ]
    then
        Log "${response_json_agent}"
    fi
}

Health_Check_Database()
{
    LogVerbose ".. Health_Check_Database()"

    database_dbms=$(echo "${response_json}" | jq -r '.database.dbms // empty')
    database_version=$(echo "${response_json}" | jq -r '.database.version // empty')
    component_state_text=$(echo "${response_json}" | jq -r '.database.componentState._text // empty')
    component_state_severity=$(echo "${response_json}" | jq -r '.database.componentState.severity // empty')
    connection_state_text=$(echo "${response_json}" | jq -r '.database.connectionState._text // empty')
    connection_state_severity=$(echo "${response_json}" | jq -r '.database.connectionState.severity // empty')

    Log "Database: ${database_dbms} ${database_version}"
    Log "    Component State    : ${component_state_text} (${component_state_severity})"
    Log "    Connection State   : ${connection_state_text} (${connection_state_severity})"

    if [ "${component_state_severity}" -eq 1 ]
    then
        LogWarning "Unhealthy Component State: ${component_state_text} ($component_state_severity)"
        count_unhealthy=$((count_unhealthy+1))
    fi

    if [ "${component_state_severity}" -gt 1 ]
    then
        LogError "Fatal Component State: ${component_state_text} ($component_state_severity)"
        count_fatal=$((count_fatal+1))
    fi

    if [ "${connection_state_severity}" -gt 1 ]
    then
        LogWarning "Unhealthy Connection State: $database_connection_state_severity} ($connection_state_severity)"
        count_unhealthy=$((count_unhealthy+1))
    fi

    if [ "${connection_state_severity}" -gt 1 ]
    then
        LogError "Fatal Connection State: $database_connection_state_severity} ($connection_state_severity)"
        count_fatal=$((count_fatal+1))
    fi
}

Health_Check_JOC()
{
    LogVerbose ".. Health_Check_JOC()"
    count_joc=$(echo "${response_json}" | jq '.jocs | length // empty')

    for ((i=0; i<"${count_joc}"; i++)); do
        survey_date=$(echo "${response_json}" | jq -r '.deliveryDate // empty')
        host=$(echo "${response_json}" | jq -r '.jocs['$i'].host // empty')
        url=$(echo "${response_json}" | jq -r '.jocs['$i'].url // empty')
        title=$(echo "${response_json}" | jq -r '.jocs['$i'].title // empty')
        current=$(echo "${response_json}" | jq -r '.jocs['$i'].current // empty')
        cluster_node_state_text=$(echo "${response_json}" | jq -r '.jocs['$i'].clusterNodeState._text // empty')
        cluster_node_state_severity=$(echo "${response_json}" | jq -r '.jocs['$i'].clusterNodeState.severity // empty')
        component_state_text=$(echo "${response_json}" | jq -r '.jocs['$i'].componentState._text // empty')
        component_state_severity=$(echo "${response_json}" | jq -r '.jocs['$i'].componentState.severity // empty')
        connection_state_text=$(echo "${response_json}" | jq -r '.jocs['$i'].connectionState._text // empty')
        connection_state_severity=$(echo "${response_json}" | jq -r '.jocs['$i'].connectionState.severity // empty')

        Log "JOC Cockpit: ${title}, URL: ${url}, Date: ${survey_date}"
        Log "    Cluster Node State: ${cluster_node_state_text} ($cluster_node_state_severity)"
        Log "    Component State:    ${component_state_text} (${component_state_severity})"
        Log "    Connection State:   ${connection_state_text} (${connection_state_severity})"

        if [ "${cluster_node_state_severity}" -eq 0 ]
        then
            count_active_joc=$((count_active_joc+1))
        fi

        if [ "${cluster_node_state_severity}" -gt 1 ]
        then
            LogWarning "Unhealthy Cluster Node State: ${cluster_node_state_text} ($cluster_node_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi

        if [ "${component_state_severity}" -gt 0 ]
        then
            LogWarning "Unhealthy Component State: ${component_state_text} ($component_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi

        if [ "${connection_state_severity}" -gt 0 ]
        then
            LogWarning "Unhealthy Connection State: ${connection_state_severity} ($connection_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi
        
        if [ -n "${whatif_shutdown}" ]
        then
            host_found=0
            replacement_found=0
            set -- "$(echo "${whatif_shutdown}" | sed -r 's/[,]+/ /g')"
            for h in $@; do
                if [ "$h" = "$host" ]
                then
                    host_found=$((host_found+1))
                    for ((j=0; j<"${count_joc}"; j++)); do
                        if [ "$i" -ne "$j" ]
                        then
                            other_host=$(echo "${response_json}" | jq -r '.jocs['$j'].host // empty')
                            if [[ ! " ${*} " =~ [[:space:]]${other_host}[[:space:]] ]]
                            then
                                other_cluster_node_state_severity=$(echo "${response_json}" | jq -r '.jocs['$j'].clusterNodeState.severity // empty')
                                if [ "${other_cluster_node_state_severity}" -eq 0 ] || [ "${other_cluster_node_state_severity}" -eq 1 ]
                                then
                                    replacement_found=$((replacement_found+1))
                                    break
                                fi
                            fi
                        fi
                    done
                    break
                fi
            done
            
            if [ "${host_found}" -gt 0 ] && [ "${replacement_found}" -lt "${host_found}" ]
            then
                count_whatif=$((count_whatif+1))
                LogWarning "What if host is shutdown: ${whatif_shutdown}: failure"
            else
                Log "    What if host is shutdown: ${whatif_shutdown}: ok"
             fi
        fi
    done

    cluster_state_text=$(echo "${response_json}" | jq -r '.clusterState._text // empty')
    cluster_state_severity=$(echo "${response_json}" | jq -r '.clusterState.severity // empty')

    if [ -n "${cluster_state_text}" ]
    then
        if [ "${cluster_state_severity}" -eq 0 ]
        then
            Log "JOC Cockpit Cluster State: ${cluster_state_text} (${cluster_state_severity})"
        else
            LogWarning "JOC Cockpit Cluster State: ${cluster_state_text} (${cluster_state_severity})"
        fi
    fi

    if [ "${count_active_joc}" -eq 0 ]
    then
        LogError "Fatal JOC Cockpit Cluster State: no active JOC Cockpit instance found"
    fi
}

Health_Check_Controller()
{
    LogVerbose ".. Health_Check_Controller()"
    count_controller=$(echo "${response_json}" | jq '.controllers | length // empty')

    for ((i=0; i<"${count_controller}"; i++)); do
        survey_date=$(echo "${response_json}" | jq -r '.controllers['$i'].surveyDate // empty')
        host=$(echo "${response_json}" | jq -r '.controllers['$i'].host // empty')
        url=$(echo "${response_json}" | jq -r '.controllers['$i'].url // empty')
        title=$(echo "${response_json}" | jq -r '.controllers['$i'].title // empty')
        role=$(echo "${response_json}" | jq -r '.controllers['$i'].role // empty')
        controller_controller_id=$(echo "${response_json}" | jq -r '.controllers['$i'].controllerId // empty')
        is_coupled=$(echo "${response_json}" | jq -r '.controllers['$i'].isCoupled // empty')
        cluster_node_state_text=$(echo "${response_json}" | jq -r '.controllers['$i'].clusterNodeState._text // empty')
        cluster_node_state_severity=$(echo "${response_json}" | jq -r '.controllers['$i'].clusterNodeState.severity // empty')
        component_state_text=$(echo "${response_json}" | jq -r '.controllers['$i'].componentState._text // empty')
        component_state_severity=$(echo "${response_json}" | jq -r '.controllers['$i'].componentState.severity // empty')
        connection_state_text=$(echo "${response_json}" | jq -r '.controllers['$i'].connectionState._text // empty')
        connection_state_severity=$(echo "${response_json}" | jq -r '.controllers['$i'].connectionState.severity // empty')

        Log "${role} Controller: ${title}, ID: ${controller_controller_id}, URL: ${url}, is coupled: ${is_coupled}, Date: ${survey_date}"
        Log "    Cluster Node State: ${cluster_node_state_text} ($cluster_node_state_severity)"
        Log "    Component State:    ${component_state_text} (${component_state_severity})"
        Log "    Connection State:   ${connection_state_text} (${connection_state_severity})"

        if [ "${cluster_node_state_severity}" -eq 0 ]
        then
            count_active_controller=$((count_active_controller+1))
        fi

        if [ "${cluster_node_state_severity}" -gt 1 ]
        then
            LogWarning "Unhealthy Cluster Node State: ${cluster_node_state_text} ($cluster_node_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi

        if [ "${component_state_severity}" -gt 0 ]
        then
            LogWarning "Unhealthy Component State: ${component_state_text} ($component_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi

        if [ "${connection_state_severity}" -gt 0 ]
        then
            LogWarning "Unhealthy Connection State: ${connection_state_severity} ($connection_state_severity)"
            count_unhealthy=$((count_unhealthy+1))
        fi
        
        if [ -n "${whatif_shutdown}" ]
        then
            host_found=0
            replacement_found=0
            set -- "$(echo "${whatif_shutdown}" | sed -r 's/[,]+/ /g')"
            for h in $@; do
                if [ "$h" = "$host" ]
                then
                    host_found=$((host_found+1))
                    for ((j=0; j<"${count_controller}"; j++)); do
                        if [ "$i" -ne "$j" ]
                        then
                            other_host=$(echo "${response_json}" | jq -r '.controllers['$j'].host // empty')
                            if [[ ! " ${*} " =~ [[:space:]]${other_host}[[:space:]] ]]
                            then
                                other_cluster_node_state_severity=$(echo "${response_json}" | jq -r '.controllers['$j'].clusterNodeState.severity // empty')
                                if [ "${other_cluster_node_state_severity}" -eq 0 ] || [ "${other_cluster_node_state_severity}" -eq 1 ]
                                then
                                    replacement_found=$((replacement_found+1))
                                    break
                                fi
                            fi
                        fi
                    done
                    break
                fi
            done
            
            if [ "${host_found}" -gt 0 ] && [ "${replacement_found}" -lt "${host_found}" ]
            then
                count_whatif=$((count_whatif+1))
                LogWarning "What if host is shutdown: ${whatif_shutdown}: failure"
            else
                Log "    What if host is shutdown: ${whatif_shutdown}: ok"
             fi
        fi
    done

    if [ "${count_active_controller}" -eq 0 ]
    then
        count_fatal=$((count_fatal+1))
        LogWarning "Fatal Controller Cluster State: no active Controller instance found"
    fi
}

Health_Check_Agent()
{
    LogVerbose ".. Health_Check_Agent()"

    count_agent=$(echo "${response_json_agent}" | jq '.agents | length // empty')

    for ((i=0; i<"${count_agent}"; i++)); do
        agent_survey_date=$(echo "${response_json_agent}" | jq -r '.surveyDate // empty')
        agent_controller_id=$(echo "${response_json_agent}" | jq -r '.agents['$i'].controllerId // empty')
        agent_agent_id=$(echo "${response_json_agent}" | jq -r '.agents['$i'].agentId // empty')
        agent_name=$(echo "${response_json_agent}" | jq -r '.agents['$i'].agentName // empty')

        length=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents | length // empty')
        if [ "${length}" -eq 0 ]
        then
            role=STANDALONE
            agent_host=$(echo "${response_json_agent}" | jq -r '.agents['$i'].url // empty' | cut -d'/' -f3 | cut -d':' -f1)
            agent_url=$(echo "${response_json_agent}" | jq -r '.agents['$i'].url // empty')
            agent_disabled=$(echo "${response_json_agent}" | jq -r '.agents['$i'].disabled // empty')
            agent_component_state_text=$(echo "${response_json_agent}" | jq -r '.agents['$i'].state._text // empty')
            agent_component_state_severity=$(echo "${response_json_agent}" | jq -r '.agents['$i'].state.severity // empty')

            Log "${role} Agent: ${agent_name}, ID: ${agent_agent_id}, URL: ${agent_url}, Controller ID: ${agent_controller_id,}, Disabled: ${agent_disabled}, Date: ${agent_survey_date}"
            Log "    Component State:    ${agent_component_state_text} (${agent_component_state_severity})"

            if [ "${agent_component_state_severity}" -gt 0 ]
            then
                LogWarning "Fatal Component State: ${agent_component_state_text} ($agent_component_state_severity)"
                count_fatal=$((count_fatal+1))
            fi
        else
            role=CLUSTER
            agent_cluster_primary_component_state_text=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").state._text // empty')
            agent_cluster_primary_component_state_severity=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").state.severity // empty')
            agent_cluster_primary_node_state_text=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").clusterNodeState._text // empty')
            agent_cluster_primary_node_state_severity=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").clusterNodeState.severity // empty')
            agent_cluster_primary_subagent_id=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").subagentId // empty')
            agent_cluster_primary_url=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").url // empty')
            agent_cluster_primary_host=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "PRIMARY_DIRECTOR").url // empty' | cut -d'/' -f3 | cut -d':' -f1)

            agent_cluster_secondary_component_state_text=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").state._text // empty')
            agent_cluster_secondary_component_state_severity=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").state.severity // empty')
            agent_cluster_secondary_node_state_text=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").clusterNodeState._text // empty')
            agent_cluster_secondary_node_state_severity=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").clusterNodeState.severity // empty')
            agent_cluster_secondary_subagent_id=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").subagentId // empty')
            agent_cluster_secondary_url=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").url // empty')
            agent_cluster_secondary_host=$(echo "${response_json_agent}" | jq -r '.agents['$i'].subagents[] | select(.isDirector == "SECONDARY_DIRECTOR").url // empty' | cut -d'/' -f3 | cut -d':' -f1)

            Log "${role} Agent: ${agent_name}, ID: ${agent_agent_id}, Controller ID: ${agent_controller_id}, Date: ${agent_survey_date}"
            Log "  PRIMARY DIRECTOR:     Subagent ID: ${agent_cluster_primary_subagent_id}, URL: ${agent_cluster_primary_url}"
            Log "    Cluster Node State: ${agent_cluster_primary_node_state_text} ($agent_cluster_primary_node_state_severity)"
            Log "    Component State:    ${agent_cluster_primary_component_state_text} (${agent_cluster_primary_component_state_severity})"
            Log "  SECONDARY DIRECTOR:   Subagent ID: ${agent_cluster_secondary_subagent_id}, URL: ${agent_cluster_secondary_url}"
            Log "    Cluster Node State: ${agent_cluster_secondary_node_state_text} ($agent_cluster_secondary_node_state_severity)"
            Log "    Component State:    ${agent_cluster_secondary_component_state_text} (${agent_cluster_secondary_component_state_severity})"

            if [ "${agent_cluster_primary_node_state_severity}" -gt 0 ] && [ "${agent_cluster_secondary_node_state_severity}" -gt 0 ]
            then
                LogWarning "Fatal Agent Cluster State: no active Director Agent instance found"
                count_fatal=$((count_fatal+1))
            fi

            if [ "${agent_cluster_primary_node_state_severity}" -gt 1 ]
            then
                LogWarning "Unhealthy Agent Cluster Primary Director Node State: ${agent_cluster_primary_node_state_text} ($agent_cluster_primary_node_state_severity)"
                count_unhealthy=$((count_unhealthy+1))
            fi

            if [ "${agent_cluster_primary_component_state_severity}" -gt 0 ]
            then
                LogWarning "Unhealthy Component State: ${agent_cluster_primary_component_state_text} ($agent_cluster_primary_component_state_severity)"
                count_unhealthy=$((count_unhealthy+1))
            fi
        
            if [ "${agent_cluster_secondary_node_state_severity}" -gt 1 ]
            then
                LogWarning "Unhealthy Agent Cluster Secondary Director Node State: ${agent_cluster_secondary_node_state_text} ($agent_cluster_secondary_node_state_severity)"
                count_unhealthy=$((count_unhealthy+1))
            fi

            if [ "${agent_cluster_secondary_component_state_severity}" -gt 0 ]
            then
                LogWarning "Unhealthy Component State: ${agent_cluster_secondary_component_state_text} ($agent_cluster_secondary_component_state_severity)"
                count_unhealthy=$((count_unhealthy+1))
            fi        

            agent_cluster_controller_active=$(echo "${response_json}" | jq -r --arg agent_controller_id "$agent_controller_id" '.controllers[] | select(.controllerId == $agent_controller_id) | select(.clusterNodeState.severity == 0) // empty')
            if [ -z "${agent_cluster_controller_active}" ]
            then
                count_fatal=$((count_fatal+1))
                LogWarning "Fatal Agent Cluster State: no active Controller instance found"
            fi

            if [ -n "${whatif_shutdown}" ]
            then
                host_found=0
                set -- "$(echo "${whatif_shutdown}" | sed -r 's/[,]+/ /g')"
                for h in $@; do
                    if [ "$h" = "${agent_cluster_primary_host}" ] 
                    then
                        host_found=$((host_found+1))

                        if [ "${agent_cluster_secondary_node_state_severity}" -gt 1 ]
                        then
                            host_found=$((host_found+1))
                        fi

                        if [ "${agent_cluster_primary_node_state_severity}" -gt 0 ] && [ "${agent_cluster_secondary_node_state_severity}" -gt 0 ]
                        then
                            host_found=$((host_found+1))
                        fi
                    fi    

                    if [ "$h" = "${agent_cluster_secondary_host}" ]
                    then
                        host_found=$((host_found+1))

                        if [ "${agent_cluster_primary_node_state_severity}" -gt 1 ]
                        then
                            host_found=$((host_found+1))
                        fi

                        if [ "${agent_cluster_primary_node_state_severity}" -gt 0 ] && [ "${agent_cluster_secondary_node_state_severity}" -gt 0 ]
                        then
                            host_found=$((host_found+1))
                        fi
                    fi    
                done                

                if [ "${host_found}" -gt 1 ] 
                then
                    LogWarning "What if host is shutdown: ${whatif_shutdown}: failure"
                    count_whatif=$((count_whatif+1))
                else
                    Log "  What if host is shutdown: ${whatif_shutdown}: ok"
                fi
            fi
        fi
    done
}

Health_Check()
{
    LogVerbose ".. Health_Check()"
    Status 0
    Status_Agent 0

    count_active_joc=0
    count_active_controller=0

    count_fatal=0
    count_unhealthy=0
    count_whatif=0

    # simulate JOC Cockpit standby instances
    #     response_json=$(echo "$response_json" | jq '.jocs[0].clusterNodeState.severity = 1')
    #     response_json=$(echo "$response_json" | jq '.jocs[1].clusterNodeState.severity = 1')
    # simulate Controller standby instances
    #   response_json=$(echo "$response_json" | jq '.controllers[0].clusterNodeState.severity = 1')
    #   response_json=$(echo "$response_json" | jq '.controllers[1].clusterNodeState.severity = 1')
    # simulate Agent standby instances
    #   response_json_agent=$(echo "$response_json_agent" | jq '.agents[2].subagents[0].clusterNodeState.severity = 1')
    #   response_json_agent=$(echo "$response_json_agent" | jq '.agents[2].subagents[1].clusterNodeState.severity = 1')

    Health_Check_Database
    Health_Check_JOC
    Health_Check_Controller
    Health_Check_Agent

    if [ -n "${whatif_shutdown}" ]
    then
        if [ "${count_fatal}" -gt 0 ]
        then
            LogWarning "health check identified ${count_fatal} fatal problems"
        else
            if [ "${count_unhealthy}" -gt 0 ]
            then
                LogWarning "health check identified ${count_unhealthy} non-fatal problems"
            fi
        fi

        if [ "${count_whatif}" -gt 0 ]
        then
            LogError "health check identified ${count_whatif} problems if host is shutdown: ${whatif_shutdown}"
            exit 3
        else
            Log "health check identified no problem if host is shutdown: ${whatif_shutdown}"
        fi
    else
        if [ "${count_fatal}" -gt 0 ]
        then
            LogError "health check identified ${count_fatal} fatal problems"
            exit 2
        else
            if [ "${count_unhealthy}" -gt 0 ]
            then
                LogWarning "health check identified ${count_unhealthy} non-fatal problems"
                exit 3
            fi
        fi
    fi
}    

Version()
{
    LogVerbose ".. Version()"
    Curl_Options

    request_body="{"
    request_comma=

    if [ -n "${controller_id}" ]
    then
        request_body="${request_body}${request_comma} \"controllerIds\": ["
        request_comma=,
        comma=
        set -- "$(echo "${controller_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${agent_id}" ]
    then
        request_body="${request_body}${request_comma} \"agentIds\": ["
        request_comma=,
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
    LogVerbose "curl ${curl_log_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/joc/versions"
    response_json=$(curl "${curl_options[@]}" -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/joc/versions)    
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.jocVersion // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Version() could not perform operation: ${response_json}"
                exit 3
            else
                LogError "Version() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Version() failed: ${response_json}"
        exit 4
    fi

    if [ "${json}" -eq 0 ]
    then
        if [ -n "${agent_id}" ]
        then
            version=$(echo "${response_json}" | jq -r '.agentVersions[0].version // empty')
        else
            if [ -n "${controller_id}" ]
            then
                version=$(echo "${response_json}" | jq -r '.controllerVersions[0].version // empty')
            else
                version=$(echo "${response_json}" | jq -r '.jocVersion // empty')
            fi
         fi
         
         Log "${version}"
    else
        Log "${response_json}"
    fi
}

Encrypt()
{
    in_string="$1"
    in_file="$2"

    java_options=(--cert="${cert_file}")

    if [ -n "${in_string}" ]
    then
        java_options+=(--in="${in_string}")
    fi

    if [ -n "${in_file}" ]
    then
        java_options+=(--infile="${in_file}")
    fi

    if [ -n "${outfile}" ]
    then
        java_options+=(--outfile="${outfile}")
    fi

    printf "enc:"
    "${JAVA}" -classpath "${java_lib}/patches/*:${java_lib}/sos/*:${java_lib}/3rd-party/*:${java_lib}/stdout" com.sos.commons.encryption.executable.Encrypt "${java_options[@]}"
}

Decrypt()
{
    in_string="$1"
    in_file="$2"

    java_options=(--key="${key_file}")

    if [ -n "${key_password}" ]
    then
        java_options+=(--key-password="${key_password}")
    fi

    if [ -n "${in_string}" ]
    then
        java_options+=(--in="${in_string}")
    fi

    if [ -n "${in_file}" ]
    then
        java_options+=(--infile="${in_file}")
    fi

    if [ -n "${outfile}" ]
    then
        java_options+=(--outfile="${outfile}")
    fi

    "${JAVA}" -classpath "${java_lib}/patches/*:${java_lib}/sos/*:${java_lib}/3rd-party/*:${java_lib}/stdout" com.sos.commons.encryption.executable.Decrypt "${java_options[@]}"
}

Usage()
{
    >&"$1" echo ""
    >&"$1" echo "Usage: $(basename "$0") [Command] [Options] [Switches]"
    >&"$1" echo ""
    >&"$1" echo "  Commands:"
    >&"$1" echo "    status              --controller-id"
    >&"$1" echo "    status-agent        --controller-id  [--agent-id] [--agent-state] [--agent-cluster] [--no-hidden]"
    >&"$1" echo "    health-check        --controller-id  [--agent-id] [--agent-state] [--agent-cluster] [--no-hidden] [--whatif-shutdown]"
    >&"$1" echo "    version            [--controller-id] [--agent-id] [--json]"
    >&"$1" echo "    switch-over         --controller-id"
    >&"$1" echo "    restart-service     --service-type"
    >&"$1" echo "    run-service         --service-type"
    >&"$1" echo "    check-license      [--validity-days]"
    >&"$1" echo "    get-settings"
    >&"$1" echo "    store-settings      --settings"
    >&"$1" echo "    encrypt             --in [--infile --outfile] --cert [--java-home] [--java-lib]"
    >&"$1" echo "    decrypt             --in [--infile --outfile] --key [--key-password] [--java-home] [--java-lib]"
    >&"$1" echo ""
    >&"$1" echo "  Options:"
    >&"$1" echo "    --url=<url>                        | required: JOC Cockpit URL"
    >&"$1" echo "    --user=<account>                   | required: JOC Cockpit user account"
    >&"$1" echo "    --password=<password>              | optional: JOC Cockpit password"
    >&"$1" echo "    --ca-cert=<path>                   | optional: path to CA Certificate used for JOC Cockpit login"
    >&"$1" echo "    --client-cert=<path>               | optional: path to Client Certificate used for login"
    >&"$1" echo "    --client-key=<path>                | optional: path to Client Key used for login"
    >&"$1" echo "    --timeout=<seconds>                | optional: timeout for request, default: ${timeout}"
    >&"$1" echo "    --controller-id=<id>               | optional: Controller ID"
    >&"$1" echo "    --agent-id=<id[,id]>               | optional: Agent ID"
    >&"$1" echo "    --agent-state=<state[,state]>      | optional: Agent state filters such as"
    >&"$1" echo "                                                   COUPLED, RESETTING, RESET, INITIALISED, COUPLINGFAILED, SHUTDOWN"
    >&"$1" echo "    --service-type=<identifier>        | optional: service for restart such as cluster, history, dailyplan, cleanup, monitor"
    >&"$1" echo "    --validity-days=<number>           | optional: number of days for validity of license, default: ${validity_days}"
    >&"$1" echo "    --settings=<json>                  | optional: settings to be stored from JSON"
    >&"$1" echo "    --whatif-shutdown=<host[,host]>    | optional: health status if hosts will be shutdown"
    >&"$1" echo "    --key=<path>                       | optional: path to private key file in PEM format"
    >&"$1" echo "    --key-password=<password>          | optional: password for private key file"
    >&"$1" echo "    --cert=<path>                      | optional: path to certificate file in PEM format"
    >&"$1" echo "    --in=<string>                      | optional: input string for encryption/decryption"
    >&"$1" echo "    --infile=<path>                    | optional: input file for encryption/decryption"
    >&"$1" echo "    --outfile=<path>                   | optional: output file for encryption/decryption"
    >&"$1" echo "    --java-home=<directory>            | optional: Java Home directory for encryption/decryption, default: ${JAVA_HOME}"
    >&"$1" echo "    --java-lib=<directory>             | optional: Java library directory for encryption/decryption, default: ${java_lib}"
    >&"$1" echo "    --audit-message=<string>           | optional: audit log message"
    >&"$1" echo "    --audit-time-spent=<number>        | optional: audit log time spent in minutes"
    >&"$1" echo "    --audit-link=<url>                 | optional: audit log link"
    >&"$1" echo "    --log-dir=<directory>              | optional: path to directory holding the script's log files"
    >&"$1" echo ""
    >&"$1" echo "  Switches:"
    >&"$1" echo "    -h | --help                        | displays usage"
    >&"$1" echo "    -v | --verbose                     | displays verbose output, repeat to increase verbosity"
    >&"$1" echo "    -p | --password                    | asks for password"
    >&"$1" echo "    -k | --key-password                | asks for key password"
    >&"$1" echo "    -j | --json                        | returns version information in JSON format"
    >&"$1" echo "    --agent-cluster                    | filters non-clustered Agents"
    >&"$1" echo "    --no-hidden                        | filters hidden Agents"
    >&"$1" echo "    --show-logs                        | shows log output if --log-dir is used"
    >&"$1" echo "    --make-dirs                        | creates directories if they do not exist"
    >&"$1" echo ""
    >&"$1" echo "see https://kb.sos-berlin.com/x/QoiOCQ"
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
        status|status-agent|health-check|switch-over|restart-service|run-service|get-settings|store-settings|check-license|version|encrypt|decrypt) action=$1
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
            --agent-id=*)           agent_id=$(echo "${option}" | sed 's/--agent-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --agent-state=*)        agent_state=$(echo "${option}" | sed 's/--agent-state=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --settings=*)           settings=$(echo "${option}" | sed 's/--settings=//')
                                    ;;
            --service-type=*)       service_type=$(echo "${option}" | sed 's/--service-type=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --validity-days=*)      validity_days=$(echo "${option}" | sed 's/--validity-days=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --whatif-shutdown=*)    whatif_shutdown=$(echo "${option}" | sed 's/--whatif-shutdown=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --key=*)                key_file=$(echo "${option}" | sed 's/--key=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --cert=*)               cert_file=$(echo "${option}" | sed 's/--cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --key-password=*)       key_password=$(echo "${option}" | sed 's/--key-password=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --in=*)                 in=$(echo "${option}" | sed 's/--in=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --infile=*)             infile=$(echo "${option}" | sed 's/--infile=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --outfile=*)            outfile=$(echo "${option}" | sed 's/--outfile=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --java-home=*)          java_home=$(echo "${option}" | sed 's/--java-home=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --java-lib=*)           java_lib=$(echo "${option}" | sed 's/--java-lib=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
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
            -k|--key-password)      AskKeyPassword
                                    ;;
            -l|--json)              json=1
                                    ;;
            --agent-cluster)        agent_cluster=1
                                    ;;
            --no-hidden)            no_hidden=true
                                    ;;
            --make-dirs)            make_dirs=1
                                    ;;
            --show-logs)            show_logs=1
                                    ;;
            status|status-agent|health-check|switch-over|restart-service|run-service|get-settings|store-settings|check-license|version|encrypt|decrypt) action=$1
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

    actions="|encrypt|decrypt|"
    if [[ "${actions}" != *"|${action}|"* ]]
    then
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
    fi

    actions="|status|status-agent|health-check|switch-over|"
    if [[ "${actions}" == *"|${action}|"* ]] && [ -z "${controller_id}" ]
    then
        Usage 2
        LogError "Controller ID must be specified: --controller-id="
        exit 1
    fi

    actions="|restart-service|run-service|"
    if [[ "${actions}" == *"|${action}|"* ]] && [ -z "${service_type}" ]
    then
        Usage 2
        LogError "Action '${action}' requires to specify the service type: --service-type=cluster|history|dailyplan|cleanup|monitor"
        exit 1
    fi

    if [ "${action}" = "check-license" ] && [ -z "${validity_days}" ]
    then
        Usage 2
        LogError "Action 'check-license' requires to specify the number of days required for license validity: --validity-days="
        exit 1
    fi

    if [ "${action}" = "store-settings" ] && [ -z "${settings}" ]
    then
        Usage 2
        LogError "Action 'store-settings' requires to specify settings: --settings="
        exit 1
    fi

    actions="|encrypt|decrypt|"
    if [[ "${actions}" == *"|${action}|"* ]] || [[ "${joc_password}" == enc:* ]] || [[ "${key_password}" == enc:* ]]
    then
        if [ "${action}" = "encrypt" ] || [ "${action}" = "decrypt" ]
        then
            if [ -z "${in}" ] && [ -z "${infile}" ]
            then
                Usage 2
                LogError "Action '${action}' requires input string or input file to be specified: : --in= or --infile="
                exit 1
            fi
    
            if [ -n "${in}" ] && [ -n "${infile}" ]
            then
                Usage 2
                LogError "Action '${action}' requires one of input string or input file to be specified: : --in= or --infile="
                exit 1
            fi
        fi

        if [ "${action}" = "encrypt" ]
        then
            if [ -z "${cert_file}" ]
            then
                Usage 2
                LogError "Action '${action}' requires certificate file to be specified: --cert="
                exit 1
            fi

            if [ ! -f "${cert_file}" ]
            then
                Usage 2
                LogError "Certificate file not found: --cert=${cert_file}"
                exit 1
            fi
        fi

        if [ "${action}" = "decrypt" ]
        then
            if [ -z "${key_file}" ]
            then
                Usage 2
                LogError "Action '${action}' requires key file to be specified: --key="
                exit 1
            fi

            if [ ! -f "${key_file}" ]
            then
                Usage 2
                LogError "Key file not found: --key=${key_file}"
                exit 1
            fi
        fi

        if [ -z "${java_lib}" ]
        then
            Usage 2
            LogError "Action '${action}' requires Java encryption library directory to be specified: --java-lib="
            exit 1
        fi

        if [ ! -d "${java_lib}" ]
        then
            Usage 2
            LogError "Java encryption library directory not found: --java-lib=${java_lib}"
            exit 1
        fi

        if [ -n "${java_home}" ] && [ ! -d "${java_home}" ]
        then
            Usage 2
            LogError "Java Home directory not found: --java-home=${java_home}"
            exit 1
        fi
    
        if [ -n "${java_home}" ] && [ ! -f "${java_home}"/bin/java ]
        then
            Usage 2
            LogError "Java binary ./bin/java not found from Java Home directory: --java-home=${java_home}"
            exit 1
        fi
    
        JAVA="${JAVA_HOME}"/bin/
        if [ -n "${java_home}" ]
        then
            JAVA_HOME=${java_home}
            JAVA=${java_home}/bin/java
        else
            java_bin=$(which java 2>/dev/null || echo "")
            test -n "${JAVA_HOME}" && test -x "${JAVA_HOME}/bin/java" && java_bin="${JAVA_HOME}/bin/java"
            if [ -z "${java_bin}" ]
            then
                LogError "could not identify Java environment, please set JAVA_HOME variable"
                Usage 2
                exit 1
            fi
            
            JAVA=${java_bin}
        fi

        if [[ "${joc_password}" == enc:* ]]
        then
            joc_password=$(Decrypt "${joc_password}")
        fi

        if [[ "${key_password}" == enc:* ]]
        then
            key_password=$(Decrypt "${key_password}")
        fi
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
    
        log_file="${log_dir}"/operate-joc."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/operate-joc."${start_time}".log
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

    actions="|encrypt|decrypt|"
    if [[ "${actions}" != *"|${action}|"* ]]
    then
        Login
    fi

    case "${action}" in
        status)             Status 1
                            ;;
        status-agent)       Status_Agent 1
                            ;;
        health-check)       Health_Check
                            ;;
        switch-over)        Switch_Over
                            ;;
        restart-service)    Restart_Service
                            ;;
        run-service)        Run_Service
                            ;;
        check-license)      Check_License
                            ;;
        get-settings)       Get_Settings
                            ;;
        store-settings)     Store_Settings
                            ;;
        version)            Version
                            ;;
        encrypt)            LogVerbose ".. Encrypt()"
                            LogVerbose ".... running: ${JAVA} -classpath ${java_lib}/patches/*:${java_lib}/sos/*:${java_lib}/3rd-party/*:${java_lib}/stdout com.sos.commons.encryption.executable.Encrypt"
                            Encrypt "${in}" "${infile}"
                            ;;
        decrypt)            LogVerbose ".. Decrypt()"
                            LogVerbose ".... running: ${JAVA} -classpath ${java_lib}/patches/*:${java_lib}/sos/*:${java_lib}/3rd-party/*:${java_lib}/stdout com.sos.commons.encryption.executable.Decrypt"
                            Decrypt "${in}" "${infile}"
                            ;;
    esac

    actions="|encrypt|decrypt|"
    if [[ "${actions}" != *"|${action}|"* ]]
    then
        Logout
    fi
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

    unset whatif_shutdown
    unset validity_days
    unset license_type
    unset license_valid
    unset license_valid_from
    unset license_valid_until
    unset license_date
    unset license_period
    unset current_date
    unset ms_period
    unset service_type
    unset member_id
    unset version
    unset agent_id
    unset settings
    unset json

    unset agent_id
    unset agent_state
    unset agent_cluster
    unset no_hidden

    unset cert_file
    unset key_file
    unset key_password
    unset in
    unset infile
    unset outfile
    unset java_home
    unset java_bin
    unset java_lib

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
