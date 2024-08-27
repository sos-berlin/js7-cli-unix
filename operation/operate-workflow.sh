#!/bin/bash

set -e

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2024-08-24
# Purpose:  Operate Workflows, Jobs, Orders
# ------------------------------------------------------------
#
# Examples:
# ./operate-workflow.sh cancel-order --url=https://joc-2-0-primary.sos:7443 --user=root --password=root --controller-id=testsuite
#   --date-to=-2h --folder=/daily-plan/accounting,/daily-plan/invoicing --recursive
#    cancels scheduled orders recursively from a list of workflow folders that are overdue for more than 2 hours
#
# ./operate-workflow.sh cancel-order --url=https://joc-2-0-primary.sos:7443 --user=root --password=root --controller-id=testsuite
#   --date-to="$(TZ=Europe/London date --date="1 day ago" +'%Y-%m-%d')T23:59:59" --folder="/daily-plan/accounting,/daily-paln/invoicing" --recursive
#     cancels scheduled orders recursively that are overdue since end of the last day in the Europe/London time zone
#
# ./operate-workflow.sh cancel-order --url=https://joc-2-0-primary.sos:7443 --user=root -p --controller-id=testsuite
#       --order-name=".*due" --workflow="/daily-plan/accounting/Accounting-EOD,/daily-plan/invoicing/Invoicing-Reminders-EOD"
#    cancels orders scheduled for the indicated workflows with an order name ending in "due" that are overdue now
#
# ./operate-workflow.sh skip-job --url=https://joc-2-0-primary.sos:7443 --user=root --password=root --controller-id=testsuite --workflow=/ap/ap3jobs --label=job1,job2


# ------------------------------
# Global script variables
# ------------------------------

joc_url=
joc_user=
joc_password=
joc_cacert=
joc_client_cert=
joc_client_key=
controller_id=
timeout=15
make_dirs=
show_logs=
log_dir=
log_dir=
verbose=
action=

item=
start_time=$(date +"%Y-%m-%dT%H-%M-%S")
response_json=
access_token=

workflow=
order_id=
order_name=${USER}
block_position=
start_position=
end_position=
variable=
date_from=
date_to=
time_zone=
state=
folder=
recursive=false
label=
force=false
notice_board=
notice_id=
notice_lifetime=

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
    if [ -n "${verbose}" ]
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

Get_Timezone()
{
    if [ -z "${time_zone}" ]
    then
        if [ -n "${TZ}" ]
        then
            time_zone=${TZ}
        else
            if command -v timedatectl &> /dev/null
            then
                time_zone=$(timedatectl | grep -E -o  'Time zone: (.*)[ ]?.*\1' | cut -d' ' -f3)
                if [ ! "${time_zone}" = "$(timedatectl list-timezones | grep "${time_zone}")" ]
                then
                    time_zone=
                fi
            fi
        fi

        if [ -z "${time_zone}" ]
        then
            if [ -f /etc/timezone ]
            then
                time_zone=$(cat /etc/timezone)
            else
                if [ -f /etc/localtime ]
                then
                   full_info=$(readlink -f /etc/localtime)
                   zone_info="/usr/share/zoneinfo/"
                   time_zone=$(printf '%s' "${full_info//${zone_info}/}")
                fi
            fi
        fi

        if [ -z "${time_zone}" ]
        then
            LogError "could not determine system time zone, specify time zone using: --time-zone=<time-zone>"
            exit 1
        fi
    fi
}

Add_Order()
{
    LogVerbose ".. Add_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""
    request_body="${request_body}, \"orders\": [ {"

    if [ -n "${order_name}" ]
    then
        request_body="${request_body} \"orderName\": \"${order_name}\""
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowPath\": \"${workflow}\""
    fi

    if [ -n "${date_to}" ]
    then
        request_body="${request_body}, \"scheduledFor\": \"${date_to}\""
    fi

    if [ -n "${time_zone}" ]
    then
        request_body="${request_body}, \"timeZone\": \"${time_zone}\""
    fi

    if [ -n "${variable}" ]
    then
        request_body="${request_body}, \"arguments\": {"
        comma=
        set -- "$(echo "${variable}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i%-*}\": \"${i#*-}\""
            comma=,
        done
        request_body="${request_body} }"
    fi

    if [ -n "${block_position}" ]
    then
        request_body="${request_body}, \"blockPosition\": \"${block_position}\""
    fi

    if [ -n "${start_position}" ]
    then
        request_body="${request_body}, \"startPosition\": \"${start_position}\""
    fi

    if [ -n "${end_position}" ]
    then
        request_body="${request_body}, \"endPositions\": ["
        comma=
        set -- "$(echo "${end_position}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body}, \"forceJobAdmission\": ${force}"
    request_body="${request_body} } ] }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/add"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/add)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.orderIds[] // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Add_Order() did not find object: ${response_json}"
                exit 3
            else
                LogError "Add_Order() failed: ${response_json}"
                exit 4
            fi
        else
           Log "${ok}" 
        fi
    else
        LogError "Addl_Order() failed: ${response_json}"
        exit 4
    fi
}

Cancel_Order()
{
    LogVerbose ".. Cancel_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${order_id}" ]
    then
        request_body="${request_body}, \"orderIds\": ["
        comma=
        set -- "$(echo "${order_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowIds\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"path\": \"${i}\"}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${date_from}" ]
    then
        request_body="${request_body}, \"dateFrom\": \"${date_from}\""
    fi

    if [ -n "${date_to}" ]
    then
        request_body="${request_body}, \"dateTo\": \"${date_to}\""
    fi

    if [ -n "${time_zone}" ]
    then
        request_body="${request_body}, \"timeZone\": \"${time_zone}\""
    fi

    request_body="${request_body}, \"kill\": ${force}"
    request_body="${request_body}, \"deep\": ${recursive}"
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/cancel"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/cancel)
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
                LogWarning "Cancel_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Cancel_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Cancel_Order() failed: ${response_json}"
        exit 4
    fi
}

Suspend_Order()
{
    LogVerbose ".. Suspend_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${order_id}" ]
    then
        request_body="${request_body}, \"orderIds\": ["
        comma=
        set -- "$(echo "${order_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowIds\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"path\": \"${i}\"}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${date_from}" ]
    then
        request_body="${request_body}, \"dateFrom\": \"${date_from}\""
    fi

    if [ -n "${date_to}" ]
    then
        request_body="${request_body}, \"dateTo\": \"${date_to}\""
    fi

    if [ -n "${time_zone}" ]
    then
        request_body="${request_body}, \"timeZone\": \"${time_zone}\""
    fi

    request_body="${request_body}, \"kill\": ${force}"
    request_body="${request_body}, \"deep\": ${recursive}"
    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/suspend"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/suspend)
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
                LogWarning "Suspend_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Suspend_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Suspend_Order() failed: ${response_json}"
        exit 4
    fi
}

Resume_Order()
{
    LogVerbose ".. Resume_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${order_id}" ]
    then
        request_body="${request_body}, \"orderIds\": ["
        comma=
        set -- "$(echo "${order_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowIds\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"path\": \"${i}\"}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${label}" ]
    then
        request_body="${request_body}, \"position\": \"${label}\""
    fi

    if [ -n "${variable}" ]
    then
        request_body="${request_body}, \"arguments\": {"
        comma=
        set -- "$(echo "${variable}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i%-*}\": \"${i#*-}\""
            comma=,
        done
        request_body="${request_body} }"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/resume"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/resume)
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
                LogWarning "Resume_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Resume_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Resume_Order() failed: ${response_json}"
        exit 4
    fi
}

Letrun_Order()
{
    LogVerbose ".. Letrun_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${order_id}" ]
    then
        request_body="${request_body}, \"orderIds\": ["
        comma=
        set -- "$(echo "${order_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowIds\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"path\": \"${i}\"}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/continue"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/continue)
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
                LogWarning "Letrun_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Letrun_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Letrun_Order() failed: ${response_json}"
        exit 4
    fi
}

Confirm_Order()
{
    LogVerbose ".. Confirm_Order()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${order_id}" ]
    then
        request_body="${request_body}, \"orderIds\": ["
        comma=
        set -- "$(echo "${order_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowIds\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"path\": \"${i}\"}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${state}" ]
    then
        request_body="${request_body}, \"states\": ["
        comma=
        set -- "$(echo "${state}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/orders/confirm"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/orders/confirm)
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
                LogWarning "Confirm_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Confirm_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Confirm_Order() failed: ${response_json}"
        exit 4
    fi
}

Transfer_Order()
{
    LogVerbose ".. Transfer_Order()"
    Curl_Options

    LogVerbose ".. step 1: use /joc/api/workflow for a given workflow to retrieve path"

    if [ -n "${workflow}" ]
    then
        request_body="{ \"controllerId\": \"${controller_id}\""
        request_body="${request_body}, \"workflowId\": { \"path\": \"${workflow}\" }"
        request_body="${request_body} }"
    
        LogVerbose ".... request:"
        LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow"
    
        response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow)
        LogVerbose ".... response:"
        LogVerbose "${response_json}"
    
        if echo "${response_json}" | jq -e . >/dev/null 2>&1
        then
            workflowPath=$(echo "${response_json}" | jq -r '.workflow.path // empty' | sed 's/^"//' | sed 's/"$//')
            if [ -z "${workflowPath}" ]
            then
                error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
                if [ "${error_code}" = "JOC-400" ]
                then
                    LogWarning "Transfer_Order() did not find objects: ${response_json}"
                    exit 3
                else
                    LogError "Transfer_Order() failed: ${response_json}"
                    exit 4
                fi
            fi
        else
            LogError "Transfer_Order() failed: ${response_json}"
            exit 4
        fi
    fi

    LogVerbose ".. step 2: use /joc/api/workflows and specify folders property to receive workflow versions"

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    else
        request_body="${request_body}, \"folders\": [ {\"folder\": \"$(dirname ${workflowPath})\"} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflows"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflows)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"
    
    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        workflowVersionId=$(echo "${response_json}" | jq -r --arg workflowPath "${workflowPath}" '.workflows[] | select(.path == $workflowPath and .isCurrentVersion == false) | .versionId // empty' | sed 's/^"//' | sed 's/"$//')

        if [ -z "${workflowVersionId}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogWarning "Transfer_Order() did not find workflow: ${response_json}"
                exit 3
            else
                LogError "Transfer_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Transfer_Order() failed: ${response_json}"
        exit 4
    fi

    LogVerbose ".. step 3: transfer orders for workflow version"

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflowPath}" ]
    then
        request_body="${request_body}, \"workflowId\": { \"path\": \"${workflowPath}\", \"versionId\": \"${workflowVersionId}\" }"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow/transition"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow/transition)
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
                LogWarning "Transfer_Order() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Transfer_Order() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Transfer_Order() failed: ${response_json}"
        exit 4
    fi
}

Suspend_Workflow()
{
    LogVerbose ".. Suspend_Workflow()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowPaths\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflows/suspend"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflows/suspend)
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
                LogWarning "Suspend_Workflow() did not find object: ${response_json}"
                exit 3
            else
                LogError "Suspend_Workflow() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Suspend_Workflow() failed: ${response_json}"
        exit 4
    fi
}

Resume_Workflow()
{
    LogVerbose ".. Resume_Workflow()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowPaths\": ["
        comma=
        set -- "$(echo "${workflow}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflows/resume"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflows/resume)
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
                LogWarning "Resume_Workflow() did not find object: ${response_json}"
                exit 3
            else
                LogError "Resume_Workflow() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Resume_Workflow() failed: ${response_json}"
        exit 4
    fi
}

Stop_Job()
{
    LogVerbose ".. Stop_Job()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowId\": { \"path\": \"$workflow\" }"
    fi

    if [ -n "${label}" ]
    then
        request_body="${request_body}, \"positions\": ["
        comma=
        set -- "$(echo "${label}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow/stop"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow/stop)
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
                LogWarning "Stop_Job() did not find object: ${response_json}"
                exit 3
            else
                LogError "Stop_Job() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Stop_Job() failed: ${response_json}"
        exit 4
    fi
}

Unstop_Job()
{
    LogVerbose ".. Unstop_Job()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowId\": { \"path\": \"$workflow\" }"
    fi

    if [ -n "${label}" ]
    then
        request_body="${request_body}, \"positions\": ["
        comma=
        set -- "$(echo "${label}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow/unstop"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow/unstop)
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
                LogWarning "Unstop_Job() did not find object: ${response_json}"
                exit 3
            else
                LogError "Unstop_Job() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Unstop_Job() failed: ${response_json}"
        exit 4
    fi
}

Skip_Job()
{
    LogVerbose ".. Skip_Job()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowPath\": \"$workflow\""
    fi

    if [ -n "${label}" ]
    then
        request_body="${request_body}, \"labels\": ["
        comma=
        set -- "$(echo "${label}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow/skip"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow/skip)
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
                LogWarning "Skip_Job() did not find object: ${response_json}"
                exit 3
            else
                LogError "Skip_Job() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Skip_Job() failed: ${response_json}"
        exit 4
    fi
}

Unskip_Job()
{
    LogVerbose ".. Unskip_Job()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${workflow}" ]
    then
        request_body="${request_body}, \"workflowPath\": \"$workflow\""
    fi

    if [ -n "${label}" ]
    then
        request_body="${request_body}, \"labels\": ["
        comma=
        set -- "$(echo "${label}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/workflow/unskip"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/workflow/unskip)
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
                LogWarning "Unskip_Job() did not find object: ${response_json}"
                exit 3
            else
                LogError "Unskip_Job() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Unskip_Job() failed: ${response_json}"
        exit 4
    fi
}

Post_Notice()
{
    LogVerbose ".. Post_Notice()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${notice_id}" ]
    then
        request_body="${request_body}, \"noticeId\": \"${notice_id}\""
    fi

    if [ -n "${notice_board}" ]
    then
        request_body="${request_body}, \"noticeBoardPaths\": ["
        comma=
        set -- "$(echo "${notice_board}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${notice_lifetime}" ]
    then
        request_body="${request_body}, \"endOfLife\": \"${notice_lifetime}\""
    fi

    if [ -n "${time_zone}" ]
    then
        request_body="${request_body}, \"timeZone\": \"${time_zone}\""
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/notices/post"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/notices/post)
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
                LogWarning "Post_Notice() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Post_Notice() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Post_Notice() failed: ${response_json}"
        exit 4
    fi
}

Get_NoticeBoards()
{
    LogVerbose ".. Get_NoticeBoards()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${folder}" ]
    then
        request_body="${request_body}, \"folders\": ["
        comma=
        set -- "$(echo "${folder}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} {\"folder\": \"${i}\", \"recursive\": ${recursive}}"
            comma=,
        done
        request_body="${request_body} ]"
    fi

    if [ -n "${notice_board}" ]
    then
        request_body="${request_body}, \"noticeBoardPaths\": ["
        comma=
        set -- "$(echo "${notice_board}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/notice/boards"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/notice/boards)
    LogVerbose ".... response:"
    LogVerbose "${response_json}"

    if echo "${response_json}" | jq -e . >/dev/null 2>&1
    then
        ok=$(echo "${response_json}" | jq -r '.noticeBoards // empty' | sed 's/^"//' | sed 's/"$//')
        if [ -z "${ok}" ]
        then
            error_code=$(echo "${response_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
            if [ "${error_code}" = "JOC-400" ]
            then
                LogError "Get_NoticeBoards() did not find notice boards: ${response_json}"
                exit 2
            else
                LogError "Get_NoticeBoards() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Get_NoticeBoards() failed: ${response_json}"
        exit 4
    fi

    count_notice_boards=$(echo "${response_json}" | jq -r '.noticeBoards | length // empty' | sed 's/^"//' | sed 's/"$//')
    if [ -n "${count_notice_boards}" ]
    then
        if [ "${count_notice_boards}" -gt 0 ]
        then
            Log ".. ${count_notice_boards} notice boards found"
        else
            LogError "Get_NoticeBoards(): no notice boards found"
            exit 2
        fi
    else
        LogError "Get_NoticeBoards(): error occurred reading notice boards: ${response_json}"
        exit 4
    fi
}

Get_Notices()
{
    LogVerbose ".. Get_Notices()"
    Curl_Options

    count_notices=0
    while ifs=$'\t' read -r path; do
        if [ -n "${date_to}" ]
        then
            notices=($(echo "${response_json}" | jq --arg path "${path}" --arg date "${date_to}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | select(.|startswith($date)) | tojson] | join(" ")'))
        else
            if [ -n "${notice_id}" ]
            then
                notices=($(echo "${response_json}" | jq --arg path "${path}" --arg noticeId "${notice_id}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | select(. == $noticeId) | tojson] | join(" ")'))
            else
                notices=($(echo "${response_json}" | jq --arg path "${path}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | tojson] | join(" ")'))
            fi
        fi

        if [ -z "${notices}" ]
        then
            continue
        fi

        count=${#notices[@]}
        count_notices=$((count_notices + count))
        Log ".... Notice Board: ${path}: ${count} notices found: ${notices[*]}"
    done <<< "$(echo "${response_json}" | jq -r '.noticeBoards[] | [.path] | @tsv' )"

    if [ -n "${count_notices}" ]
    then
        if [ "${count_notices}" -gt 0 ]
        then
            Log ".. ${count_notices} notices found"
        else
            LogWarning "Get_Notices(): no notices found"
            exit 3
        fi
    else
        LogError "Get_Notices(): error occurred reading notices"
        exit 4
    fi
}

Delete_Notices()
{
    LogVerbose ".. Delete_Notices()"
    Curl_Options

    count_notices=0
    while ifs=$'\t' read -r path; do
        if [ -n "${date_to}" ]
        then
            notices=($(echo "${response_json}" | jq --arg path "${path}" --arg date "${date_to}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | select(.|startswith($date)) | tojson] | join(" ")'))
        else
            if [ -n "${notice_id}" ]
            then
                notices=($(echo "${response_json}" | jq --arg path "${path}" --arg noticeId "${notice_id}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | select(. == $noticeId) | tojson] | join(" ")'))
            else
                notices=($(echo "${response_json}" | jq --arg path "${path}" -r '.noticeBoards[] | select(.path == $path) | [.notices[].id | tojson] | join(" ")'))
            fi
        fi

        if [ -z "${notices}" ]
        then
            continue
        fi

        count=${#notices[@]}
        count_notices=$((count_notices + count))
        Log ".... Notice Board: ${path}: deleting ${count} notices: ${notices[*]}"
        request_body="{ \"controllerId\": \"${controller_id}\", \"noticeBoardPath\": \"${path}\", \"noticeIds\": [ "
        
        comma=
        for i in ${notices[@]}; do
            request_body="${request_body}${comma}$i"
            comma=,
        done
        
        request_body="${request_body} ] }"

        LogVerbose ".... request:"
        LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/notices/delete"
    
        response_notice_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/notices/delete)
        LogVerbose ".... response:"
        LogVerbose "${response_notice_json}"

        if echo "${response_notice_json}" | jq -e . >/dev/null 2>&1
        then
            ok=$(echo "${response_notice_json}" | jq -r '.ok // empty' | sed 's/^"//' | sed 's/"$//')
            if [ -z "${ok}" ]
            then
                error_code=$(echo "${response_notice_json}" | jq -r '.error.code // empty' | sed 's/^"//' | sed 's/"$//')
                if [ "${error_code}" = "JOC-400" ]
                then
                    LogWarning "Delete_Notices() could not find matching notices: ${response_notice_json}"
                    exit 3
                else
                    LogError "Delete_Notices() failed: ${response_notice_json}"
                    exit 4
                fi
            fi
        else
            LogError "Delete_Notices() failed: ${response_notice_json}"
            exit 4
        fi
    done <<< "$(echo "${response_json}" | jq -r '.noticeBoards[] | [.path] | @tsv' )"

    if [ -n "${count_notices}" ]
    then
        if [ "${count_notices}" -gt 0 ]
        then
            Log ".. ${count_notices} notices deleted"
        else
            LogWarning "Delete_Notices(): no notices found"
            exit 3
        fi
    else
        LogError "Delete_Notices(): error occurred reading notices"
        exit 4
    fi
}

Delete_Notice()
{
    LogVerbose ".. Delete_Notice()"
    Curl_Options

    request_body="{ \"controllerId\": \"${controller_id}\""

    if [ -n "${notice_board}" ]
    then
        request_body="${request_body}, \"noticeBoardPath\": \"${notice_board}\""
    fi

    if [ -n "${notice_id}" ]
    then
        request_body="${request_body}, \"noticeIds\": ["
        comma=
        set -- "$(echo "${notice_id}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            request_body="${request_body}${comma} \"${i}\""
            comma=,
        done
        request_body="${request_body} ]"
    fi

    request_body="${request_body} }"

    LogVerbose ".... request:"
    LogVerbose "curl ${curl_options[*]} -H \"X-Access-Token: ${access_token}\" -H \"Accept: application/json\" -H \"Content-Type: application/json\" -d ${request_body} ${joc_url}/joc/api/notices/delete"

    response_json=$(curl ${curl_options[@]} -H "X-Access-Token: ${access_token}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${request_body}" "${joc_url}"/joc/api/notices/delete)
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
                LogWarning "Delete_Notice() did not find objects: ${response_json}"
                exit 3
            else
                LogError "Delete_Notice() failed: ${response_json}"
                exit 4
            fi
        fi
    else
        LogError "Delete_Notice() failed: ${response_json}"
        exit 4
    fi
}

Usage()
{
    >&2 echo ""
    >&2 echo "Usage: $(basename "$0") [Command] [Options] [Switches]"
    >&2 echo ""
    >&2 echo "  Commands:"
    >&2 echo "    add-order         --workflow  [--date-to] [--order-name] [--block-position] [--start-position] [--end-position] [--variable] [--force]"
    >&2 echo "    cancel-order     [--workflow] [--folder] [--recursive] [--order-id] [--state] [--date-from] [--date-to] [--time-zone] [--force]"
    >&2 echo "    suspend-order    [--workflow] [--folder] [--recursive] [--order-id] [--state] [--date-from] [--date-to] [--time-zone] [--force]"
    >&2 echo "    resume-order     [--workflow] [--folder] [--recursive] [--order-id] [--state] [--label] [--variable]"
    >&2 echo "    confirm-order    [--workflow] [--folder] [--recursive] [--order-id] [--state]"
    >&2 echo "    letrun-order     [--workflow] [--folder] [--recursive] [--order-id] [--state]"
    >&2 echo "    transfer-order    --workflow] [--folder] [--recursive]"
    >&2 echo "    suspend-workflow  --workflow  [--folder] [--recursive]"
    >&2 echo "    resume-workflow   --workflow  [--folder] [--recursive]"
    >&2 echo "    stop-job          --workflow --label"
    >&2 echo "    unstop-job        --workflow --label"
    >&2 echo "    skip-job          --workflow --label"
    >&2 echo "    unskip-job        --workflow --label"
    >&2 echo "    post-notice       --notice-board  [--notice-id] [--notice-lifetime]"
    >&2 echo "    get-notice       [--notice-board] [--notice-id] [--folder] [--recursive] [--date-to]"
    >&2 echo "    delete-notice    [--notice-board] [--notice-id] [--folder] [--recursive] [--date-to]"
    >&2 echo ""
    >&2 echo "  Options:"
    >&2 echo "    --url=<url>                        | required: JOC Cockpit URL"
    >&2 echo "    --controller-id=<id>               | required: Controller ID"
    >&2 echo "    --user=<account>                   | required: JOC Cockpit user account"
    >&2 echo "    --password=<password>              | optional: JOC Cockpit password"
    >&2 echo "    --ca-cert=<path>                   | optional: path to CA Certificate used for JOC Cockpit login"
    >&2 echo "    --client-cert=<path>               | optional: path to Client Certificate used for login"
    >&2 echo "    --client-key=<path>                | optional: path to Client Key used for login"
    >&2 echo "    --timeout=<seconds>                | optional: timeout for request, default: ${timeout}"
    >&2 echo "    --order-name=<string>              | optional: name for order, default: ${order_name}"
    >&2 echo "    --block-position=<label>           | optional: label for block instruction that holds start position"
    >&2 echo "    --start-position=<label>           | optional: label from which the order will be started"
    >&2 echo "    --end-position=<label[,label]>     | optional: list of labels before which the order will terminate"
    >&2 echo "    --variable=<key=value[,key=value]> | optional: list of variables holding key/value pairs"
    >&2 echo "    --date-from=<date>                 | optional: order past scheduled date"
    >&2 echo "    --date-to=<date>                   | optional: order scheduled date or notice date, default: now"
    >&2 echo "    --time-zone=<tz>                   | optional: time zone for dates, default: ${time_zone}"
    >&2 echo "                                                   see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    >&2 echo "    --state=<state[,state]>            | optional: list of states limiting orders to be processed such as"
    >&2 echo "                                                   SCHEDULED, INPROGRESS, RUNNING, SUSPENDED, WAITING, FAILED"
    >&2 echo "    --folder=<path[,path]>             | optional: list of folders holding workflows, orders, notice boards"
    >&2 echo "    --workflow=<name[,name]>           | optional: list of workflow names"
    >&2 echo "    --order-id=<id[,id]>               | optional: list of order identifiers"
    >&2 echo "    --label=<label[,label]>            | optional: list of labels for jobs"
    >&2 echo "    --notice-board=<name[,name]>       | optional: list of notice boards"
    >&2 echo "    --notice-id=<id>                   | optional: notice identifier, default: ${notice_id}"
    >&2 echo "    --notice-lifetime=<period>         | optional: lifetime for notice"
    >&2 echo "    --log-dir=<directory>              | optional: path to directory holding the script's log files"
    >&2 echo ""
    >&2 echo "  Switches:"
    >&2 echo "    -h | --help                        | displays usage"
    >&2 echo "    -v | --verbose                     | displays verbose output"
    >&2 echo "    -p | --password                    | asks for password"
    >&2 echo "    -r | --recursive                   | specifies folders to be looked up recursively"
    >&2 echo "    -f | --force                       | specifies forced start or termination of jobs"
    >&2 echo "    --show-logs                        | shows log output if --log-dir is used"
    >&2 echo "    --make-dirs                        | creates directories if they do not exist"
    >&2 echo ""
}

Arguments()
{
    args="$*"
    Get_Timezone

    case "$1" in
        add-order|cancel-order|suspend-order|resume-order|confirm-order|letrun-order|conf-order|transfer-order|stop-job|unstop-job|skip-job|unskip-job|suspend-workflow|resume-workflow|post-notice|get-notice|delete-notice) action=$1
                                    ;;
        *)                          >&2 echo "unknown command: $1"
                                    Usage
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
            --controller-id=*)      controller_id=$(echo "${option}" | sed 's/--controller-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --timeout=*)            timeout=$(echo "${option}" | sed 's/--timeout=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --order-id=*)           order_id=$(echo "${option}" | sed 's/--order-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --order-name=*)         order_name=$(echo "${option}" | sed 's/--order-name=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --block-position=*)     block_position=$(echo "${option}" | sed 's/--block-position=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --start-position=*)     start_position=$(echo "${option}" | sed 's/--start-position=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --end-position=*)       end_position=$(echo "${option}" | sed 's/--end-position=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --variable=*)           variable=$(echo "${option}" | sed 's/--variable=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --date-from=*)          date_from=$(echo "${option}" | sed 's/--date-from=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --date-to=*)            date_to=$(echo "${option}" | sed 's/--date-to=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --time-zone=*)          time_zone=$(echo "${option}" | sed 's/--time-zone=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --state=*)              state=$(echo "${option}" | sed 's/--state=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --folder=*)             folder=$(echo "${option}" | sed 's/--folder=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --workflow=*)           workflow=$(echo "${option}" | sed 's/--workflow=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --label=*)              label=$(echo "${option}" | sed 's/--label=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --notice-board=*)       notice_board=$(echo "${option}" | sed 's/--notice-board=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --notice-id=*)          notice_id=$(echo "${option}" | sed 's/--notice-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --notice-lifetime=*)    notice_lifetime=$(echo "${option}" | sed 's/--notice-lifetime=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --log-dir=*)            log_dir=$(echo "${option}" | sed 's/--log-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            # Switches
            -h|--help)              Usage
                                    exit
                                    ;;
            -v|--verbose)           verbose=1
                                    ;;
            -p|--password)          AskPassword
                                    ;;
            -r|--recursive)         recursive=true
                                    ;;
            -f|--force)             force=true
                                    ;;
            --make-dirs)            make_dirs=1
                                    ;;
            --show-logs)            show_logs=1
                                    ;;
            add-order|cancel-order|suspend-order|resume-order|confirm-order|letrun-order|transfer-order|stop-job|unstop-job|skip-job|unskip-job|suspend-workflow|resume-workflow|post-notice|get-notice|delete-notice)
                                    ;;
            *)                      >&2 echo "unknown option: ${option}"
                                    Usage
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
        LogError "JOC Cockpit URL not specified: --url=<url>"
        Usage
        exit 1
    fi

    if [ -z "${controller_id}" ]
    then
        LogError "Controller ID must be specified: --controller-id=<identifier>"
        Usage
        exit 1
    fi

    if [ -z "${joc_user}" ]
    then
        LogError "JOC Cockpit user account not specified: --user=<account>"
        Usage
        exit 1
    fi

    if [ -n "${joc_cacert}" ] && [ ! -f "${joc_cacert}" ]
    then
        LogError "Root CA Certificate file not found: --cacert=${joc_cacert}"
        Usage
        exit 1
    fi

    if [ -n "${joc_client_cert}" ] && [ ! -f "${joc_client_cert}" ]
    then
        LogError "Client Certificate file not found: --client-cert=${joc_client_cert}"
        Usage
        exit 1
    fi

    if [ -n "${joc_client_key}" ] && [ ! -f "${joc_client_key}" ]
    then
        LogError "Client Private Key file not found: --client-key=${joc_client_key}"
        Usage
        exit 1
    fi

    actions="add-order|transfer-order|stop-job|unstop-job|skip-job|unskip-job|suspend-workflow|resume-workflow"
    if [ "${actions#*"$action"}" != "$actions" ] && [ -z "${workflow}" ]
    then
        LogError "Workflow not specified: --workflow="
        Usage
        exit 1
    fi

    actions="cancel-order|suspend-order|resume-order|letrun-order"
    if [ "${actions#*"$action"}" != "$actions" ] && [ -z "${workflow}" ] && [ -z "${folder}" ]
    then
        LogError "Command ${action} requires to specify the workflow or folder: --workflow= or --folder="
        Usage
        exit 1
    fi

    if [ "${action}" = "add-order" ] && [ -z "${order_name}" ]
    then
        LogError "Command add-order requires to specify the order name: --order-name="
        Usage
        exit 1
    fi

    actions="stop-job|unstop-job|skip-job|unskip-job"
    if [ "${actions#*"$action"}" != "$actions" ] && [ -z "${label}" ]
    then
        LogError "Command ${action} requires to specify the label: --label="
        Usage
        exit 1
    fi

    if [ "${action}" = "post-notice" ] && [ -z "${notice_board}" ]
    then
        LogError "Command post-notice requires to specify the notice board: --notice-board="
        Usage
        exit 1
    fi

    actions="get-notice|delete-notice"
    if [ "${actions#*"$action"}" != "$actions" ] && [ -z "${notice_board}" ] && [ -z "${folder}" ]
    then
        LogError "Command ${action} requires to specify the notice board or folder: --notice-board= or --folder="
        Usage
        exit 1
    fi

    if [ -n "${show_logs}" ] && [ -z "${log_dir}" ]
    then
        LogError "Log directory not specified and --show-logs switch is present: --log-dir="
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${log_dir}" ] && [ ! -d "${log_dir}" ]
    then
        LogError "Log directory not found and --make-dirs switch not present: --log-dir=${log_dir}"
        Usage
        exit 1
    fi

    if [ "${action}" = "add-order" ] && [ -z "${date_to}" ]
    then
        date_to=now
    fi

    if [ "${action}" = "post-notice" ] && [ -z "${notice_id}" ]
    then
        notice_id=$(date +"%Y-%m-%d")
    fi

    # initialize logging
    if [ -n "${log_dir}" ]
    then
        # create log directory if required
        if [ ! -d "${log_dir}" ] && [ -n "${make_dirs}" ]
        then
            mkdir -p "${log_dir}"
        fi
    
        log_file="${log_dir}"/operate-workflow."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/operate-workflow."${start_time}".log
        done
        
        touch "${log_file}"
    fi

    Log "-- begin of log --------------"
    Log "$0" "$(echo "${args}" | sed 's/--password=\([^--]*\)//')"
    Log "-- begin of output -----------"
}

# ------------------------------
# Main
# ------------------------------

Process()
{
    LogVerbose ".. Processing"
    Login

    case "${action}" in
        add-order)          Add_Order
                            ;;
        cancel-order)       Cancel_Order
                            ;;
        suspend-order)      Suspend_Order
                            ;;
        resume-order)       Resume_Order
                            ;;
        letrun-order)       Letrun_Order
                            ;;
        confirm-order)      Confirm_Order
                            ;;
        transfer-order)     Transfer_Order
                            ;;
        suspend-workflow)   Suspend_Workflow
                            ;;
        resume-workflow)    Resume_Workflow
                            ;;
        stop-job)           Stop_Job
                            ;;
        unstop-job)         Unstop_Job
                            ;;
        skip-job)           Skip_Job
                            ;;
        unskip-job)         Unskip_Job
                            ;;
        post-notice)        Post_Notice
                            ;;
        get-notice)         Get_NoticeBoards
                            Get_Notices
                            ;;
        delete-notice)      if [ -n "${notice_board}" ] && [ -n "${notice_id}" ]
                            then
                                Delete_Notice
                            else
                                Get_NoticeBoards
                                if [ "${count_notice_boards}" -gt 0 ]
                                then
                                    Delete_Notices
                                fi
                            fi
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
        Log "-- end of log ----------------"

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
    unset controller_id
    unset timeout

    unset make_dirs
    unset show_logs
    unset verbose
    unset log_dir

    unset workflow
    unset order_id
    unset label
    unset order_name
    unset block_position
    unset start_position
    unset end_position
    unset variable
    unset date_from
    unset date_to
    unset time_zone
    unset full_info
    unset zone_info
    unset state
    unset folder
    unset notice_id
    unset notice_board
    unset notice_lifetime

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
