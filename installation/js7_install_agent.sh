#!/bin/sh

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2023-06-17
# Purpose:  download and extract JS7 Agents, take backups and restart
# Platform: AIX, Linux, MacOS: bash, ksh, zsh, dash
# ------------------------------------------------------------
#
# Example:  ./js7_install_agent.sh --home=/home/sos/agent --release=2.5.3 --make-dirs
#
#           downloads the indicated Agent release and extracts to the specified Agent home directory
#
# Example:  ./js7_install_agent.sh --home=/home/sos/agent --tarball=/mnt/releases/scheduler_setups/2.5.3/js7_agent_unix.2.5.3.tar.gz --move-libs
#
#           extracts the indicated tarball to the specified Agent home directory
#           an existing lib directory is renamed and appended its release number

set -e

# ------------------------------
# Initialize variables
# ------------------------------

wait_agent=0
failover_agent=0
noinstall_agent=
noyade_agent=
useinstall_agent=
uninstall_agent=
uninstall_agent_home=
uninstall_agent_data=
real_path_prefix=
agent_home=
agent_data=
agent_config=
agent_logs=
agent_work=
agent_user=$(id -u -n -r)
home_owner=
home_owner_group=
data_owner=
data_owner_group=
force_sudo=
standby_director=
active_director=
license_key=
license_bin=
backup_dir=
log_dir=
deploy_dir=
exec_start=
exec_stop=
http_port=4445
http_network_interface=
https_port=
https_network_interface=
instance_script=
systemd_service_dir=/usr/lib/systemd/system
systemd_service_file=
systemd_service_name=
systemd_service_selinux=0
systemd_service_failover=0
systemd_service_stop_timeout=60
java_home=
java_options=
pid_file_dir=
pid_file_name=
agent_conf=
private_conf=
controller_id="controller"
controller_primary_cert=
controller_secondary_cert=
controller_primary_subject=
controller_secondary_subject=
agent_cluster_id=
director_primary_cert=
director_secondary_cert=
director_primary_subject=
director_secondary_subject=
keystore_file=
keystore_alias=
keystore_password=
client_keystore_file=
client_keystore_alias=
client_keystore_password=
truststore_file=
truststore_password=
cancel_agent=
make_service=
make_dirs=
move_libs=
patch=
patch_jar=
remove_journal=
release=
restart_agent=
return_values=
show_logs=
tarball=

backup_file=
curl_output_file=
download_url=
exclude_file=
hostname=$(hostname)
log_file=
release_major=
release_minor=
release_maint=
return_code=-1
start_agent_output_file=
start_time=$(date +"%Y-%m-%dT%H-%M-%S")
stop_agent_output_file=
stop_option=
tar_dir=

Usage()
{
    >&2 echo ""
    >&2 echo "Usage: $(basename "$0") [Options] [Switches]"
    >&2 echo ""
    >&2 echo "  Installation Options:"
    >&2 echo "    --home=<directory>                 | required: directory to which the Agent will be installed"
    >&2 echo "    --data=<directory>                 | optional: directory for Agent data files, default: <home>/var_${http_port}"
    >&2 echo "    --config=<directory>               | optional: directory from which the Agent reads configuration files, default: <data>/config"
    >&2 echo "    --logs=<directory>                 | optional: directory to which the Agent writes log files, default: <data>/logs"
    >&2 echo "    --work=<directory>                 | optional: working directory of the Agent, default: <data>"
    >&2 echo "    --user=<account>                   | optional: user account for Agent daemon, default: ${agent_user}"
    >&2 echo "    --home-owner=<account[:group]>     | optional: account and optionally group owning the home directory, requires root or sudo permissions"
    >&2 echo "    --data-owner=<account[:group]>     | optional: account and optionally group owning the data directory, requires root or sudo permissions"
    >&2 echo "    --release=<release-number>         | optional: release number such as 2.5.0 for download if --tarball is not used"
    >&2 echo "    --tarball=<tar-gz-archive>         | optional: the path to a .tar.gz archive that holds the Agent installation or patch tarball"
    >&2 echo "                                       |           if not specified the Agent tarball will be downloaded from the SOS web site"
    >&2 echo "    --patch=<issue-key>                | optional: identifies a patch from a Change Management issue key"
    >&2 echo "    --patch-jar=<jar-file>             | optional: the path to a .jar file that holds the patch"
    >&2 echo "    --license-key=<key-file>           | optional: specifies the path to a license key file to be installed"
    >&2 echo "    --license-bin=<binary-file>        | optional: specifies the path to the js7-license.jar binary file for licensed code to be installed"
    >&2 echo "                                       |           if not specified the file will be downloaded from the SOS web site"
    >&2 echo "    --http-port=<port>                 | optional: specifies the http port the Agent will be operated for, default: ${http_port}"
    >&2 echo "                                                   port can be prefixed by network interface, e.g. localhost:4445"
    >&2 echo "    --https-port=<port>                | optional: specifies the https port the Agent will be operated for"
    >&2 echo "                                                   port can be prefixed by network interface, e.g. batch.example.com:4445"
    >&2 echo "    --pid-file-dir=<directory>         | optional: directory to which the Agent writes its PID file, default: <data>/logs"
    >&2 echo "    --pid-file-name=<file-name>        | optional: file name used by the Agent to write its PID file, default: agent.pid"
    >&2 echo "    --instance-script=<file>           | optional: path to the Instance Start Script that will be copied to the Agent, default <home>/bin/<instance-script>"
    >&2 echo "    --backup-dir=<directory>           | optional: backup directory for existing Agent home directory"
    >&2 echo "    --log-dir=<directory>              | optional: log directory for log output of this script"
    >&2 echo "    --exec-start=<command>             | optional: command to start the Agent, e.g. 'StartService'"
    >&2 echo "    --exec-stop=<command>              | optional: command to stop the Agent, e.g. 'StopService'"
    >&2 echo "    --return-values=<file>             | optional: path to a file that holds return values such as the path to a log file"
    >&2 echo ""
    >&2 echo "  Configuration Options:"
    >&2 echo "    --deploy-dir=<dir>[,<dir>]          | optional: deployment directory from which configuration files are copied to the Agent"
    >&2 echo "    --agent-conf=<file>                 | optional: path to a configuration file that will be copied to <config>/agent.conf"
    >&2 echo "    --private-conf=<file>               | optional: path to a configuration file that will be copied to <config>/private/private.conf"
    >&2 echo "    --controller-id=<identifier>        | optional: Controller ID, default: ${controller_id}"
    >&2 echo "    --controller-primary-cert=<file>    | optional: path to Primary/Standalone Controller certificate file"
    >&2 echo "    --controller-secondary-cert=<file>  | optional: path to Secondary Controller certificate file"
    >&2 echo "    --controller-primary-subject=<id>   | optional: subject of Primary/Standalone Controller certificate"
    >&2 echo "    --controller-secondary-subject=<id> | optional: subject of Secondary Controller certificate"
    >&2 echo "    --agent-cluster-id=<identifier>     | optional: Agent Cluster ID"
    >&2 echo "    --director-primary-cert=<file>      | optional: path to Primary Director Agent certificate file"
    >&2 echo "    --director-secondary-cert=<file>    | optional: path to Secondary Director Agent certificate file"
    >&2 echo "    --director-primary-subject=<id>     | optional: subject of Primary Director Agent certificate"
    >&2 echo "    --director-secondary-subject=<id>   | optional: subject of Secondary Director Agent certificate"
    >&2 echo "    --keystore=<file>                   | optional: path to a PKCS12 keystore file that will be copied to <config>/private/"
    >&2 echo "    --keystore-password=<password>      | optional: password for access to keystore"
    >&2 echo "    --keystore-alias=<alias>            | optional: alias name for keystore entry"
    >&2 echo "    --client-keystore=<file>            | optional: path to a PKCS12 client keystore file that will be copied to <config>/private/"
    >&2 echo "    --client-keystore-password=<pass>   | optional: password for access to client keystore"
    >&2 echo "    --client-keystore-alias=<alias>     | optional: alias name for client keystore entry"
    >&2 echo "    --truststore=<file>                 | optional: path to a PKCS12 truststore file that will be copied to <config>/private/"
    >&2 echo "    --truststore-password=<password>    | optional: password for access to truststore"
    >&2 echo "    --java-home=<directory>             | optional: Java Home directory for use with the Instance Start Script"
    >&2 echo "    --java-options=<options>            | optional: Java Options for use with the Instance Start Script"
    >&2 echo "    --service-dir=<directory>           | optional: systemd service directory, default: ${systemd_service_dir}"
    >&2 echo "    --service-file=<file>               | optional: path to a systemd service file that will be copied to <home>/bin/"
    >&2 echo "    --service-name=<identifier>         | optional: name of the systemd service to be created, default js7_agent_<http-port>"
    >&2 echo "    --service-stop-timeout=<seconds>    | optional: timeout of the systemd service to stop the Agent, default ${systemd_service_stop_timeout}"
    >&2 echo ""
    >&2 echo "  Switches:"
    >&2 echo "    -h | --help                         | displays usage"
    >&2 echo "    --force-sudo                        | forces use of sudo for operations on directories"
    >&2 echo "    --active                            | makes Director Agent instance the default active node in an Agent Cluster"
    >&2 echo "    --standby                           | makes Director Agent instance the default standby node in an Agent Cluster"
    >&2 echo "    --no-yade                           | excludes YADE from Agent installation"
    >&2 echo "    --no-install                        | skips Agent installation, performs configuration updates only"
    >&2 echo "    --use-install                       | uses existing Agent installation, populates data directory and creates service"
    >&2 echo "    --uninstall                         | uninstalls Agent and removes <home> and <data> directories"
    >&2 echo "    --uninstall-home                    | uninstalls Agent and removes <home> directory only"
    >&2 echo "    --uninstall-data                    | uninstalls Agent and removes <data> directory only"
    >&2 echo "    --service-selinux                   | use SELinux version of systemd service file"
    >&2 echo "    --service-fail-over                 | apply fail-over option on Agent stop to systemd service file"
    >&2 echo "    --show-logs                         | shows log output of the script"
    >&2 echo "    --make-dirs                         | creates the specified directories if they do not exist"
    >&2 echo "    --make-service                      | creates the systemd service for the Agent"
    >&2 echo "    --move-libs                         | moves an existing Agent's lib directory instead of removing the directory"
    >&2 echo "    --remove-journal                    | removes an existing Agent's state directory that holds the journal files"
    >&2 echo "    --restart                           | stops a running Agent including tasks and starts the Agent after installation"
    >&2 echo "    --fail-over                         | performs fail-over in Agent Cluster if used with the --restart switch"
    >&2 echo "    --wait                              | waits for running tasks in Agent if used with the --restart switch"
    >&2 echo "    --cancel                            | cancels a running Agent if used with the --restart switch"
    >&2 echo ""
}

GetPid()
{
  if [ -n "${http_port}" ]
  then
      ps -ef | grep -E "js7\.agent\.main\.AgentMain.*--http-port=${http_port}" | grep -v "grep" | awk '{print $2}'
  else
      ps -ef | grep -E "js7\.agent\.main\.AgentMain.*" | grep -v "grep" | awk '{print $2}'
  fi
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

LogError()
{
    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
    then
        echo "[ERROR]" "$@" >> "${log_file}"
    fi
    
    >&2 echo "[ERROR]" "$@"
}

StartAgent()
{
    if [ -n "${exec_start}" ]
    then
        Log ".. starting Agent: ${exec_start}"
        ${exec_start}
    else
        if [ -n "${restart_agent}" ]
        then
            if [ -d "${agent_home}"/bin ]
            then
                if [ -f "${agent_home}"/bin/agent_"${http_port}".sh ]
                then
                    Log ".. starting Agent: ${agent_home}/bin/agent_${http_port}.sh start"
                
                    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                    then
                        start_agent_output_file="/tmp/js7_install_agent_start_$$.tmp"
                        touch "${start_agent_output_file}"
                        ( "${agent_home}/bin/agent_${http_port}.sh" start > "${start_agent_output_file}" 2>&1 ) || ( LogError "$(cat ${start_agent_output_file})" && exit 5 )
                        Log "$(cat ${start_agent_output_file})"
                    else
                        "${agent_home}/bin/agent_${http_port}.sh" start
                    fi
                else
                    if [ -f "${agent_home}"/bin/agent.sh ]
                    then
                        Log ".. starting Agent: ${agent_home}/bin/agent.sh start"

                        if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                        then
                            start_agent_output_file="/tmp/js7_install_agent_start_$$.tmp"
                            touch "${start_agent_output_file}"
                            ( "${agent_home}/bin/agent.sh" start > "${start_agent_output_file}" 2>&1 ) || ( LogError "$(cat ${start_agent_output_file})" && exit 5 )
                            Log "$(cat ${start_agent_output_file})"
                        else
                            "${agent_home}/bin/agent.sh" start
                        fi
                    else
                        LogError "could not start Agent, start script missing: ${agent_home}/bin/agent_${http_port}.sh, ${agent_home}/bin/agent.sh"
                    fi
                fi
            else
                LogError "could not start Agent, directory missing: ${agent_home}/bin"
            fi
        fi
    fi
}

StopAgent()
{
    if [ -n "${exec_stop}" ]
    then
        Log ".. stopping Agent: ${exec_stop}"
        if [ "$(echo "${exec_stop}" | tr '[:upper:]' '[:lower:]')" = "stopservice" ]
        then
            StopService
        else
            ${exec_stop}
        fi
    else
        if [ -n "${restart_agent}" ]
        then
            if [ -n "${cancel_agent}" ]
            then
                stop_option="cancel"
            else
                if [ "${wait_agent}" -gt 0 ]
                then
                    stop_option="stop --timeout=never"
                else
                    if [ "${failover_agent}" -gt 0 ]
                    then
                        stop_option="stop --fail-over"
                    else
                        stop_option="stop"
                    fi
                fi
            fi

            if [ -n "$(GetPid)" ]
            then
                if [ -d "${agent_home}"/bin ]
                then
                    if [ -f "${agent_home}"/bin/agent_"${http_port}".sh ]
                    then
                        Log ".. stopping Agent: ${agent_home}/bin/agent_${http_port}.sh ${stop_option}"

                        if [ -n "${log_file}" ] && [ -f "$|log_file{" ]
                        then
                            stop_agent_output_file="/tmp/js7_install_agent_stop_$$.tmp"
                            touch "${stop_agent_output_file}"
                            ( "${agent_home}/bin/agent_${http_port}.sh" ${stop_option} > "${stop_agent_output_file}" 2>&1 ) || ( LogError "$(cat ${stop_agent_output_file})" && exit 6 )
                            Log "$(cat ${stop_agent_output_file})"
                        else
                            "${agent_home}/bin/agent_${http_port}.sh" ${stop_option}
                        fi
                    else
                        if [ -f "${agent_home}"/bin/agent.sh ]
                        then
                            Log ".. stopping Agent: ${agent_home}/bin/agent.sh ${stop_option}"

                            if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                            then
                                stop_agent_output_file="/tmp/js7_install_agent_stop_$$.tmp"
                                touch "${stop_agent_output_file}"
                                ( "${agent_home}/bin/agent.sh" ${stop_option} > "${stop_agent_output_file}" 2>&1 ) || ( LogError "$(cat ${stop_agent_output_file})" && exit 6 )
                                Log "$(cat ${stop_agent_output_file})"
                            else
                                "${agent_home}/bin/agent.sh" ${stop_option}
                            fi
                        else
                            LogError "could not stop Agent, start script missing: ${agent_home}/bin/agent_${http_port}.sh, ${agent_home}/bin/agent.sh"
                        fi
                    fi
                else
                    LogError "could not stop Agent, directory missing: ${agent_home}/bin"
                fi
            else
                Log ".. Agent not running"
            fi
        fi
    fi
}

MakeService()
{
    use_systemd_service_file=$1

    if [ "$(id -u)" -eq 0 ]
    then
        use_sudo=""
    else
        use_sudo="sudo"
    fi

    rc=
    (${use_sudo} systemctl cat -- "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
    if [ -n "${rc}" ]
    then
        Log ".... adding systemd service: ${systemd_service_name}"
    else
        Log ".... updating systemd service: ${systemd_service_name}"
    fi

    Log ".... copying systemd service file ${use_systemd_service_file} to ${systemd_service_dir}/${systemd_service_name}"
    ${use_sudo} cp -p "${use_systemd_service_file}" "${systemd_service_dir}"/"${systemd_service_name}"

    Log ".... systemd service command: $use_sudo systemctl enable ${systemd_service_name}"
    rc=
    (${use_sudo} systemctl enable "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
    if [ -z "${rc}" ]
    then
        Log ".... systemd service enabled: ${systemd_service_name}"

        Log ".... systemd service command: $use_sudo systemctl daemon-reload"
        (${use_sudo} systemctl daemon-reload >/dev/null 2>&1) || rc=$?
        if [ -z "${rc}" ]
        then
            Log ".... systemd service configuration reloaded: ${systemd_service_name}"
        else
            LogError "could not reload systemd daemon configuration for service: ${systemd_service_name}"
            exit 7
        fi
    else
        LogError "could not enable systemd service: ${systemd_service_name}"
        exit 7
    fi
}

StartService()
{
    if [ "$(id -u)" -eq 0 ]
    then
        use_sudo=""
    else
        use_sudo="sudo"
    fi

    Log ".... systemd service command: $use_sudo systemctl start ${systemd_service_name}"
    (${use_sudo} systemctl start "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
    if [ -z "${rc}" ]
    then
        Log ".... systemd service started: ${systemd_service_name}"
    else
        LogError "could not start systemd service: ${systemd_service_name}"
        exit 7
    fi
}

StopService()
{
    if [ "$(id -u)" -eq 0 ]
    then
        use_sudo=""
    else
        use_sudo="sudo"
    fi

    rc=
    (${use_sudo} systemctl cat -- "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
    if [ -z "${rc}" ]
    then
        Log ".... systemd service command: $use_sudo systemctl stop ${systemd_service_name}"
        (${use_sudo} systemctl stop "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
        if [ -z "${rc}" ]
        then
            Log ".... systemd service stopped: ${systemd_service_name}"
        else
            LogError "could not stop systemd service: ${systemd_service_name}"
        fi
    fi
}

ChangeOwner()
{
    use_path=$1
    use_owner=$2
    use_owner_group=$3

    if [ -n "${use_path}" ] && [ -n "${use_owner}" ]
    then
        if [ -d "${use_path}" ] || [ -f "${use_path}" ]
        then
            if [ "$(id -u)" -eq 0 ]
            then
                use_sudo=""
            else
                use_sudo="sudo"
            fi
        
            rc=
            if [ -n "${use_owner_group}" ]
            then
                Log ".. changing ownership to ${use_owner}:${use_owner_group} for: ${use_path}"
                (${use_sudo} chown -R "${use_owner}":"${use_owner_group}" "${use_path}") || rc=$?
            else
                Log ".. changing ownership to ${use_owner} for: ${use_path}"
                (${use_sudo} chown -R "${use_owner}" "${use_path}") || rc=$?
            fi
    
            if [ -n "${rc}" ]
            then
                LogError "could not change ownership ${use_owner}:${use_owner_group} for: ${use_path}"
            fi
        fi
    fi
}

CreateExcludeFile()
{
    exclude_file=/tmp/js7_deploy_tarball_exclude_$$.tmp

    if [ -f "${exclude_file}" ]
    then
        rm -f "${exclude_file}"
    fi
    
    touch "${exclude_file}"

    for i in "$@"; do
        if [ -d "${i}" ]
        then
            find "$i" -print >> "${exclude_file}"
        fi
    done
    
    echo "${exclude_file}"
}

GetDirectoryRealpath()
{
    if [ -n "$1" ]
    then
        if [ -d "$1" ]
        then
            echo "$(cd "$(dirname "$1")" > /dev/null && pwd)/$(basename "$1")"
        else
            echo "$1"
        fi
    fi
}

# ------------------------------
# Process command line options
# ------------------------------

Arguments()
{
    args="$*"
    for option in "$@"
    do
        case "${option}" in
            -h|--help)              Usage
                                    exit
                                    ;;
            # Installation Options
            --real-path-prefix=*)   real_path_prefix=$(echo "${option}" | sed 's/--real-path-prefix=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --home=*)               agent_home=$(echo "${option}" | sed 's/--home=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data=*)               agent_data=$(echo "${option}" | sed 's/--data=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --config=*)             agent_config=$(echo "${option}" | sed 's/--config=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --logs=*)               agent_logs=$(echo "${option}" | sed 's/--logs=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --work=*)               agent_work=$(echo "${option}" | sed 's/--work=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --user=*)               agent_user=$(echo "${option}" | sed 's/--user=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --home-owner=*)         home_owner=$(echo "${option}" | sed 's/--home-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data-owner=*)         data_owner=$(echo "${option}" | sed 's/--data-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --release=*)            release=$(echo "${option}" | sed 's/--release=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --tarball=*)            tarball=$(echo "${option}" | sed 's/--tarball=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --patch=*)              patch=$(echo "${option}" | sed 's/--patch=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --patch-jar=*)          patch_jar=$(echo "${option}" | sed 's/--patch-jar=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --license-key=*)        license_key=$(echo "${option}" | sed 's/--license-key=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --license-bin=*)        license_bin=$(echo "${option}" | sed 's/--license-bin=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --http-port=*)          http_port=$(echo "${option}" | sed 's/--http-port=//' | sed 's/^"//' | sed 's/"$//')
                                    if [ "${http_port#*:}" != "${http_port}" ]
                                    then
                                        http_network_interface=$(echo "${http_port}" | cut -d':' -f 1)
                                        http_port=$(echo "${http_port}" | cut -d':' -f 2)
                                    fi
                                    ;;
            --https-port=*)         https_port=$(echo "${option}" | sed 's/--https-port=//' | sed 's/^"//' | sed 's/"$//')
                                    if [ "${https_port#*:}" != "${https_port}" ]
                                    then
                                        https_network_interface=$(echo "${https_port}" | cut -d':' -f 1)
                                        https_port=$(echo "${https_port}" | cut -d':' -f 2)
                                    fi
                                    ;;
            --instance-script=*)    instance_script=$(echo "${option}" | sed 's/--instance-script=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --pid-file-dir=*)       pid_file_dir=$(echo "${option}" | sed 's/--pid-file-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --pid-file-name=*)      pid_file_name=$(echo "${option}" | sed 's/--pid-file-name=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --java-home=*)          java_home=$(echo "${option}" | sed 's/--java-home=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --java-options=*)       java_options=$(echo "${option}" | sed 's/--java-options=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --backup-dir=*)         backup_dir=$(echo "${option}" | sed 's/--backup-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --log-dir=*)            log_dir=$(echo "${option}" | sed 's/--log-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --service-dir=*)        systemd_service_dir=$(echo "${option}" | sed 's/--service-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --service-file=*)       systemd_service_file=$(echo "${option}" | sed 's/--service-file=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --service-name=*)       systemd_service_name=$(echo "${option}" | sed 's/--service-name=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --service-stop-timeout=*)   systemd_service_stop_timeout=$(echo "${option}" | sed 's/--service-stop-timeout=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --exec-start=*)         exec_start=$(echo "${option}" | sed 's/--exec-start=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --exec-stop=*)          exec_stop=$(echo "${option}" | sed 's/--exec-stop=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --return-values=*)      return_values=$(echo "${option}" | sed 's/--return-values=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            # Configuration Options
            --deploy-dir=*)         deploy_dir=$(echo "${option}" | sed 's/--deploy-dir=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --agent-conf=*)         agent_conf=$(echo "${option}" | sed 's/--agent-conf=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --private-conf=*)       private_conf=$(echo "${option}" | sed 's/--private-conf=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-id=*)      controller_id=$(echo "${option}" | sed 's/--controller-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-primary-cert=*)   controller_primary_cert=$(echo "${option}" | sed 's/--controller-primary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-secondary-cert=*) controller_secondary_cert=$(echo "${option}" | sed 's/--controller-secondary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-primary-subject=*)   controller_primary_subject=$(echo "${option}" | sed 's/--controller-primary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-secondary-subject=*) controller_secondary_subject=$(echo "${option}" | sed 's/--controller-secondary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --agent-cluster-id=*)   agent_cluster_id=$(echo "${option}" | sed 's/--agent-cluster-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --director-primary-cert=*)   director_primary_cert=$(echo "${option}" | sed 's/--director-primary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --director-secondary-cert=*) director_secondary_cert=$(echo "${option}" | sed 's/--director-secondary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --director-primary-subject=*)   director_primary_subject=$(echo "${option}" | sed 's/--director-primary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --director-secondary-subject=*) director_secondary_subject=$(echo "${option}" | sed 's/--director-secondary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --keystore=*)           keystore_file=$(echo "${option}" | sed 's/--keystore=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --keystore-password=*)  keystore_password=$(echo "${option}" | sed 's/--keystore-password=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --keystore-alias=*)     keystore_alias=$(echo "${option}" | sed 's/--keystore-alias=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --client-keystore=*)    client_keystore_file=$(echo "${option}" | sed 's/--client-keystore=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --client-keystore-password=*) client_keystore_password=$(echo "${option}" | sed 's/--client-keystore-password=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --client-keystore-alias=*)    client_keystore_alias=$(echo "${option}" | sed 's/--client-keystore-alias=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --truststore=*)         truststore_file=$(echo "${option}" | sed 's/--truststore=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --truststore-password=*)  truststore_password=$(echo "${option}" | sed 's/--truststore-password=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            # Switches
            --force-sudo)           force_sudo=1
                                    ;;
            --active)               active_director=1
                                    ;;
            --standby)              standby_director=1
                                    ;;
            --no-yade)              noyade_agent=1
                                    ;;
            --no-install)           noinstall_agent=1
                                    ;;
            --use-install)          useinstall_agent=1
                                    ;;
            --uninstall-home)       uninstall_agent_home=1
                                    ;;
            --uninstall-data)       uninstall_agent_data=1
                                    ;;
            --uninstall)            uninstall_agent=1
                                    ;;
            --service-selinux)      systemd_service_selinux=1
                                    ;;
            --service-fail-over)    systemd_service_failover=1
                                    ;;
            --show-logs)            show_logs=1
                                    ;;
            --make-dirs)            make_dirs=1
                                    ;;
            --make-service)         make_service=1
                                    ;;
            --move-libs)            move_libs=1
                                    ;;
            --remove-journal)       remove_journal=1
                                    ;;
            --restart|--abort)      restart_agent=1
                                    ;;
            --fail-over)            failover_agent=1
                                    ;;
            --wait)                 wait_agent=1
                                    ;;
            --cancel|--kill)        cancel_agent=1
                                    ;;
            *)                      >&2 echo "unknown option: ${option}"
                                    Usage
                                    exit 1
                                    ;;
        esac
    done

    agent_home=$(GetDirectoryRealpath "${agent_home}")
    agent_data=$(GetDirectoryRealpath "${agent_data}")
    agent_config=$(GetDirectoryRealpath "${agent_config}")
    agent_logs=$(GetDirectoryRealpath "${agent_logs}")
    agent_work=$(GetDirectoryRealpath "${agent_work}")
    pid_file_dir=$(GetDirectoryRealpath "${pid_file_dir}")
    backup_dir=$(GetDirectoryRealpath "${backup_dir}")
    log_dir=$(GetDirectoryRealpath "${log_dir}")
    systemd_service_dir=$(GetDirectoryRealpath "${systemd_service_dir}")
    deploy_dir=$(GetDirectoryRealpath "${deploy_dir}")

    if [ "${useinstall_agent}" ]
    then
        noinstall_agent=1
    fi

    if [ -n "${uninstall_agent}" ]
    then
        uninstall_agent_home=1
        uninstall_agent_data=1
    fi

    if [ -n "${uninstall_agent_home}" ] || [ -n "${uninstall_agent_data}" ]
    then
        uninstall_agent=1
    fi

    if [ -z "${agent_home}" ]
    then
        LogError "Agent home directory must be specified: --home="
        Usage
        exit 1
    fi

    if [ -n "${uninstall_agent}" ] && [ -n "${agent_home}" ] && [ ! -d "${agent_home}" ]
    then
        LogError "Agent home directory not found and --uninstall switch is present: --home=${agent_home}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -z "${uninstall_agent}" ] && [ -n "${agent_home}" ] && [ ! -d "${agent_home}" ]
    then
        LogError "Agent home directory not found and --make-dirs switch not present: --home=${agent_home}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${agent_data}" ] && [ ! -d "${agent_data}" ]
    then
        LogError "Agent data directory not found and --make-dirs switch not present: --data=${agent_data}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${agent_config}" ] && [ ! -d "${agent_config}" ]
    then
        LogError "Agent configuration directory not found and --make-dirs switch not present: --config=${agent_config}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${agent_logs}" ] && [ ! -d "${agent_logs}" ]
    then
        LogError "Agent log directory not found and --make-dirs switch not present: --logs=${agent_logs}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${agent_work}" ] && [ ! -d "${agent_work}" ]
    then
        LogError "Agent working directory not found and --make-dirs switch not present: --work=${agent_work}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${pid_file_dir}" ] && [ ! -d "${pid_file_dir}" ]
    then
        LogError "Agent PID file directory not found and --make-dirs switch not present: --pid-file-dir=${pid_file_dir}"
        Usage
        exit 1
    fi

    if [ -n "${deploy_dir}" ]
    then
        set -- "$(echo "${deploy_dir}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            if [ ! -d "$i" ] 
            then
                LogError "Deployment Directory not found: --deploy-dir=$i"
                Usage
                exit 1
            fi
        done
    fi

    if [ -z "${make_dirs}" ] && [ -n "${backup_dir}" ] && [ ! -d "${backup_dir}" ]
    then
        LogError "Backup directory not found and --make-dirs switch not present: --backup-dir=${backup_dir}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${log_dir}" ] && [ ! -d "${log_dir}" ]
    then
        LogError "Log directory not found and --make-dirs switch not present: --log-dir=${log_dir}"
        Usage
        exit 1
    fi

    if [ -z "${release}" ] && [ -z "${tarball}" ] && [ -z "${patch_jar}" ] && [ -z "${uninstall_agent}" ] && [ -z "${noinstall_agent}" ]
    then
        LogError "Release must be specified if --tarball -or --patch-jar options are not specified and --noinstall or --uninstall switches are not present: --release="
        Usage
        exit 1
    fi

    if [ -n "${tarball}" ] && [ -n "${patch_jar}" ]
    then
        LogError "Only one of the --tarball and --patch-jar options can be used"
        Usage
        exit 1
    fi

    if [ -n "${tarball}" ] && [ ! -f "${tarball}" ]
    then
        LogError "Tarball not found (*.tar.gz): --tarball=${tarball}"
        Usage
        exit 1
    fi

    if [ -n "${patch_jar}" ] && [ ! -f "${patch_jar}" ]
    then
        LogError "Patch file not found (*.jar): --patch-jar=${patch_jar}"
        Usage
        exit 1
    fi

    if [ -n "${license_key}" ] && [ ! -f "${license_key}" ]
    then
        LogError "License key file not found: --license-key=${license_key}"
        Usage
        exit 1
    fi

    if [ -n "${license_key}" ] && [ -z "${license_bin}" ] && [ -z "${release}" ]
    then
        LogError "License key without license binary file specification requires release to be specified: --license-bin= or --release="
        Usage
        exit 1
    fi

    if [ -n "${license_bin}" ] && [ ! -f "${license_bin}" ]
    then
        LogError "License binary file not found: --license-bin=${license_bin}"
        Usage
        exit 1
    fi

    if [ -n "${patch}" ] && [ ! -d "${agent_home}" ]
    then
        LogError "Agent home directory not found and --patch option is present: --home=${agent_home}"
        Usage
        exit 1
    fi

    if [ -n "${show_logs}" ] && [ -z "${log_dir}" ]
    then
        LogError "Log directory not specified and --show-logs switch is present: --log-dir="
        Usage
        exit 1
    fi

    if [ -n "${instance_script}" ] && [ ! -f "${instance_script}" ]
    then
        LogError "Instance Start Script not found (*.sh): --instance-script=${instance_script}"
        Usage
        exit 1
    fi

    if [ -n "${make_service}" ] && [ -n "${systemd_service_dir}" ] && [ ! -d "${systemd_service_dir}" ]
    then
        LogError "systemd service directory not found: --service-dir=${systemd_service_dir}"
        Usage
        exit 1
    fi

    if [ -n "${systemd_service_file}" ] && [ ! -f "${systemd_service_file}" ]
    then
        LogError "systemd service file not found (*.service): --service-file=${systemd_service_file}"
        Usage
        exit 1
    fi

    if [ -n "${java_home}" ] && [ ! -d "${java_home}" ]
    then
        LogError "Java Home directory not found: --java-home=${java_home}"
        Usage
        exit 1
    fi

    if [ -n "${agent_conf}" ] && [ ! -f "${agent_conf}" ]
    then
        LogError "Agent configuration file not found (agent.conf): --agent-conf=${agent_conf}"
        Usage
        exit 1
    fi

    if [ -n "${private_conf}" ] && [ ! -f "${private_conf}" ]
    then
        LogError "Agent private configuration file not found (private.conf): --private-conf=${private_conf}"
        Usage
        exit 1
    fi

    if [ -n "${active_director}" ] && [ -n "${standby_director}" ]
    then
        LogError "Director Agent instance can be configured to be either active or standby, use --active or --standby"
        Usage
        exit 1
    fi

    if [ -n "${controller_primary_cert}" ] && [ ! -f "${controller_primary_cert}" ]
    then
        LogError "Primary/Standalone Controller certificate file not found: --controller-primary-cert=${controller_primary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${controller_secondary_cert}" ] && [ ! -f "${controller_secondary_cert}" ]
    then
        LogError "Secondary Controller certificate file not found: --controller-secondary-cert=${controller_secondary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${controller_primary_cert}" ] && [ -n "${controller_primary_subject}" ]
    then
        LogError "Only one of Primary/Standalone Controller certificate file or subject can be specified: --controller-primary-cert=${controller_primary_cert} --controller-primary-subject=${controller_primary_subject}"
        Usage
        exit 1
    fi

    if [ -n "${controller_secondary_cert}" ] && [ -n "${controller_secondary_subject}" ]
    then
        LogError "Only one of Secondary Controller certificate file or subject can be specified: --controller-secondary-cert=${controller_secondary_cert} --controller-secondary-subject=${controller_secondary_subject}"
        Usage
        exit 1
    fi

    if [ -n "${director_primary_cert}" ] && [ ! -f "${director_primary_cert}" ]
    then
        LogError "Primary Director Agent certificate file not found: --director-primary-cert=${director_primary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${director_secondary_cert}" ] && [ ! -f "${director_secondary_cert}" ]
    then
        LogError "Secondary Director Agent certificate file not found: --director-secondary-cert=${director_secondary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${keystore_file}" ] && [ ! -f "${keystore_file}" ]
    then
        LogError "Keystore file not found (https-keystore.p12): --keystore=${keystore_file}"
        Usage
        exit 1
    fi

    if [ -n "${client_keystore_file}" ] && [ ! -f "${client_keystore_file}" ]
    then
        LogError "Client Keystore file not found (https-client-keystore.p12): --client-keystore=${client_keystore_file}"
        Usage
        exit 1
    fi

    if [ -n "${truststore_file}" ] && [ ! -f "${truststore_file}" ]
    then
        LogError "Truststore file not found (https-truststore.p12): --truststore=${truststore_file}"
        Usage
        exit 1
    fi

    if [ -n "${noinstall_agent}" ] && [ -n "${tarball}${release}" ]
    then
        LogError "--noinstall switch present and options --tarball or --release specified: --noinstall"
        Usage
        exit 1
    fi

    if [ -n "${uninstall_agent}" ] && [ -n "${tarball}${release}" ]
    then
        LogError "--uninstall switch present and options --tarball or --release specified: --noinstall"
        Usage
        exit 1
    fi

    if [ -z "${https_port}" ] && [ -n "${keystore_file}" ]
    then
        LogError "--keystore option present and no -https-port option specified: --https-port"
        Usage
        exit 1
    fi

    if [ "${home_owner#*:}" != "${home_owner}" ]
    then
        home_owner_group=$(echo "${home_owner}" | cut -d':' -f 2)
        home_owner=$(echo "${home_owner}" | cut -d':' -f 1)
    else
        if [ -n "${home_owner}" ]
        then
            home_owner_group="${home_owner}"
        fi
    fi

    if [ "${data_owner#*:}" != "${data_owner}" ]
    then
        data_owner_group=$(echo "${data_owner}" | cut -d':' -f 2)
        data_owner=$(echo "${data_owner}" | cut -d':' -f 1)
    else
        if [ -n "${data_owner}" ]
        then
            data_owner_group="${data_owner}"
        fi
    fi

    # initialize logging
    if [ -n "${log_dir}" ]
    then
        # create log directory if required
        if [ ! -d "${log_dir}" ] && [ -n "${make_dirs}" ]
        then
            mkdir -p "${log_dir}"
        fi
    
        log_file="${log_dir}"/install_js7_agent."${hostname}"."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/install_js7_agent."${hostname}"."${start_time}".log
        done
        
        touch "${log_file}"
    fi

    Log "-- begin of log --------------"
    Log "$0" "${args}"
    Log "-- begin of output -----------"
}

# ------------------------------
# Perform installation
# ------------------------------

Process()
{
    # check operating system compatibility for tar and sed
    os_normal=$(uname -a | tr '[:upper:]' '[:lower:]')
    if [ -n "${os_normal##*sunos*}" ] && [ -n "${os_normal##*solaris*}" ]
    then
        os_compat=1
    else
        os_compat=""
    fi

    if [ -z "${os_normal##*aix*}" ]
    then
        os_compat=""
    fi

    if [ -z "${agent_data}" ]
    then
        agent_data="${agent_home}/var_${http_port}"
    fi
    
    if [ -z "${agent_config}" ]
    then
        agent_config="${agent_data}/config"
    fi

    if [ -z "${agent_logs}" ]
    then
        agent_logs="${agent_data}/logs"
    fi

    agent_state="${agent_data}/state"

    if [ -z "${agent_work}" ]
    then
        agent_work="${agent_data}/work"
    fi

    if [ -n "${real_path_prefix}" ]
    then
        real_agent_home=${agent_home#"${real_path_prefix}"}
        real_agent_data=${agent_data#"${real_path_prefix}"}
        real_agent_config=${agent_config#"${real_path_prefix}"}
        real_agent_logs=${agent_logs#"${real_path_prefix}"}
        real_agent_work=${agent_work#"${real_path_prefix}"}
    else
        real_agent_home="${agent_home}"
        real_agent_data="${agent_data}"
        real_agent_config="${agent_config}"
        real_agent_logs="${agent_logs}"
        real_agent_work="${agent_work}"
    fi

    systemd_service_name=${systemd_service_name:-js7_agent_${http_port}.service}
    if [ "${systemd_service_name%*.service}" = "${systemd_service_name}" ]
    then
        systemd_service_name="${systemd_service_name}".service
    fi

    if [ "$(id -u)" -eq 0 ]
    then
        use_sudo=""
        use_forced_sudo=""
    else
        use_sudo=""
        use_forced_sudo=""

        if [ -n "${force_sudo}" ]
        then
            use_sudo="sudo"
            use_forced_sudo="sudo"
        else
            if [ -n "${make_service}" ] || [ "$(echo "${exec_start}" | tr '[:upper:]' '[:lower:]')" = "startservice" ] || [ "$(echo "${exec_stop}" | tr '[:upper:]' '[:lower:]')" = "stopservice" ]
            then
                use_sudo="sudo"
            fi

            if [ -d "${agent_home}" ] && [ ! -w "${agent_home}" ]
            then
                use_forced_sudo="sudo"
            fi        

            if [ -d "${agent_data}" ] && [ ! -w "${agent_data}" ]
            then
                use_forced_sudo="sudo"
            fi        

            if [ -n "${home_owner}" ] || [ -n "${data_owner}" ]
            then
                use_forced_sudo="sudo"
            fi        
        fi

        if [ -n "${use_sudo}" ] || [ -n "${use_forced_sudo}" ]
        then
            rc=
            (sudo -v >/dev/null 2>&1) || rc=$?
            if [ -n "${rc}" ]
            then
                LogError "missing permissions to use sudo by account: $(id -u -n) required by use of --home-owner, --data-owner, --force-sudo or missing ownership of home or data directories"
                exit 4
            fi
        fi
    fi

    # uninstall
    if [ -n "${uninstall_agent}" ]
    then
        StopAgent

        if [ "$(id -u)" -eq 0 ] || [ -n "${use_sudo}" ] || [ -n "${use_forced_sudo}" ]
        then
            if [ -f "${systemd_service_dir}/${systemd_service_name}" ]
            then
                rc=
                (${use_sudo} systemctl cat -- "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
                if [ -n "${rc}" ]
                then
                    Log ".... skipping systemd service: ${systemd_service_name}"
                else
                    Log ".... systemd service command: $use_sudo systemctl disable ${systemd_service_name}"
                    (${use_sudo} systemctl disable "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
                    if [ -z "${rc}" ]
                    then
                        Log ".... systemd service disabled: ${systemd_service_name}"
                    else
                        LogError "could not disable systemd service: ${systemd_service_name}"
                        exit 7
                    fi
    
                    Log ".... removing systemd service: ${systemd_service_name}"
                    (${use_sudo} rm -f "${systemd_service_dir}/${systemd_service_name}" >/dev/null 2>&1) || rc=$?
                    if [ -z "${rc}" ]
                    then
                        Log ".... systemd service removed: ${systemd_service_name}"
                    else
                        LogError "could not remove systemd service: ${systemd_service_name}"
                        exit 7
                    fi
    
                    Log ".... systemd service command: $use_sudo systemctl daemon-reload"
                    (${use_sudo} systemctl daemon-reload >/dev/null 2>&1) || rc=$?
                    if [ -z "${rc}" ]
                    then
                        Log ".... systemd service configuration reloaded: ${systemd_service_name}"
                    else
                        LogError "could not reload systemd daemon configuration for service: ${systemd_service_name}"
                        exit 7
                    fi
                fi
            else
                Log ".... no systemd service file found: ${systemd_service_dir}/${systemd_service_name}" 
            fi
        fi

        if [ -d "${agent_home}" ]
        then
            if [ -n "${uninstall_agent_home}" ]
            then
                Log ".... removing home directory: ${agent_home}"
                ${use_forced_sudo} rm -fr "${agent_home}"
            else
                Log ".... preserving home directory: ${agent_home}"
            fi
        fi

        if [ -d "${agent_data}" ]
        then
            if [ -n "${uninstall_agent_data}" ]
            then
                Log ".... removing data directory: ${agent_data}"
                ${use_forced_sudo} rm -fr "${agent_data}"
            else
                Log ".... preserving data directory: ${agent_data}"
            fi
        fi

        if [ -d "${agent_config}" ]
        then
            if [ -n "${uninstall_agent_data}" ]
            then
                Log ".... removing config directory: ${agent_config}"
                ${use_forced_sudo} rm -fr "${agent_config}"
            else
                Log ".... preserving config directory: ${agent_config}"
            fi
        fi

        if [ -d "${agent_logs}" ]
        then
            if [ -n "${uninstall_agent_data}" ]
            then
                Log ".... removing logs directory: ${agent_logs}"
                ${use_forced_sudo} rm -fr "${agent_logs}"
            else
                Log ".... preserving logs directory: ${agent_logs}"
            fi
        fi

        exit
    fi

    # download tarball if required
    if [ -z "${tarball}" ] && [ -n "${release}" ] && [ -z "${noinstall_agent}" ]
    then
        release_major=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\1/')
        release_minor=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\2/')
        release_maint=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\3/')

        if [ -n "${patch}" ]
        then
            tarball="js7_agent.${release}-PATCH.${patch}.tar.gz"
            download_url="https://download.sos-berlin.com/patches/${release_major}.${release_minor}.${release_maint}-patch/${tarball}"
        else
            tarball="js7_agent_unix.${release}.tar.gz"

            if [ -n "$(echo "${release_maint}" | grep -E '(SNAPSHOT)|(RC[0-9]?)$')" ]
            then
                download_url="https://download.sos-berlin.com/JobScheduler.${release_major}.0/${tarball}"
            else
                download_url="https://download.sos-berlin.com/JobScheduler.${release_major}.${release_minor}/${tarball}"
            fi
        fi

        Log ".. downloading tarball from: ${download_url}"
        rc=0

        if [ -n "${log_file}" ] && [ -f "${log_file}" ]
        then
            curl_output_file="/tmp/js7_install_agent_curl_$$.tmp"
            touch "${curl_output_file}"
            ( curl "${download_url}" --output "${tarball}" --fail > "${curl_output_file}" 2>&1 ) || rc=$?; if [ "${rc}" -ne 0 ]; then LogError "$(cat ${curl_output_file})"; fi
        else
            ( curl "${download_url}" --output "${tarball}" --fail ) || rc=$?
        fi
        
        if [ "${rc}" -ne 0 ]
        then
            LogError "download failed for URL ${download_url}, exit code: ${rc}"
            exit 4
        fi
    else
        if [ -n "${tarball}" ]
        then
            Log ".. using tarball: ${tarball}"
        fi
    fi

    # take backup of existing installation directory
    if [ -n "${backup_dir}" ] && [ -d "${agent_home}" ]
    then

        if [ -n "${make_dirs}" ] && [ -n "${backup_dir}" ] && [ ! -d "${backup_dir}" ]
        then
            Log "Creating backup directory: ${backup_dir}"
            mkdir -p "${backup_dir}"
        fi
    
        if [ -f "${agent_home}"/.version ]
        then
            # check existing version
            version=$(awk -F "=" '/release/ {print $2}' "${agent_home}"/.version)
        else
            version="0.0.0"
        fi

        backup_file="${backup_dir}/backup_js7_agent.${hostname}.${version}.${start_time}.tar"
        Log ".. creating backup file: ${backup_file}.gz"

        exclude_file=$(CreateExcludeFile "${agent_home}"/var "${agent_home}"/var_"${http_port}")
        Log ".... using exclude file: ${exclude_file}"

        agent_home_parent_dir=$(dirname "${agent_home}")
        agent_home_basename=$(basename "${agent_home}")
        
        if [ -n "${os_compat}" ]
        then
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} -C ${agent_home_parent_dir} ${agent_home_basename}"
            tar -X "${exclude_file}" -cpf "${backup_file}" -C "${agent_home_parent_dir}" "${agent_home_basename}"
            gzip "${backup_file}"
        else
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} ${agent_home_basename}"
            (
                cd "${agent_home_parent_dir}" || exit 2
                tar -X "${exclude_file}" -cpf "${backup_file}" "${agent_home_basename}"
            )
            gzip "${backup_file}"
        fi

        # caller should capture the path to the zipped backup file
        backup_file="${backup_file}.gz"
    fi

    if [ -n "${tarball}" ]
    then
        # extract to temporary directory
        tar_dir="/tmp/js7_install_agent_$$.tmp"
        Log ".. extracting tarball to temporary directory: ${tar_dir}"
        mkdir -p "${tar_dir}"
        
        # non-Solaris environments can extract directly to the target path
        if [ -n "${os_compat}" ]
        then
            test -e "${tarball}" && gzip -c -d < "${tarball}" | tar -xpof - -C "${tar_dir}"
        else
            if [ "${tarball}" = "$(basename "${tarball}")" ]
            then
                tarball="$(pwd)/${tarball}"
            fi
            
            if [ ! -f "${tarball}" ]
            then
                LogError "This OS requires the tarball to be specified from an absolute path, use: --tarball=<absolute-path>"
            fi

            (
                cd "${tar_dir}" || exit 2
                test -e "${tarball}" && gzip -c -d < "${tarball}" | tar -xpof -
            )
        fi
    
        # check for a single top-level folder inside extracted tarball
        tar_root=$(ls "${tar_dir}")
        if [ "$(echo "${tar_root}" | wc -l)" -ne 1 ]
        then
            LogError "tarball not usable, it includes more than one top-level folder: ${tar_root}"
            exit 2
        fi
    fi

    StopAgent

    if [ -n "${patch}" ]
    then
        # copy to Agent home directoy
        if [ -n "${tarball}" ]
        then
            # do not overwrite an existing data directory
            if [ -d "${agent_data}"/state ] || [ -d "${agent_data}"/config ]
            then
                rm -fr "${tar_dir:?}"/"${tar_root}"/var
            fi

            if [ ! -d "${agent_home}"/lib/patches ]
            then
                Log ".. creating patch directory: ${agent_home}/lib/patches"
                ${use_forced_sudo} mkdir -p "${agent_home}"/lib/patches
            fi

            ChangeOwner "${tar_dir}"/"${tar_root}"/. "${home_owner}" "${home_owner_group}"
            if [ -d "${tar_dir}"/"${tar_root}"/lib/patches ]
            then
                ${use_forced_sudo} chmod o-rwx "${tar_dir}"/"${tar_root}"/lib/patches/*
                ${use_forced_sudo} chmod ug-x  "${tar_dir}"/"${tar_root}"/lib/patches/*
            fi

            Log ".. copying files from extracted tarball directory: ${tar_dir}/${tar_root} to Agent home: ${agent_home}"
            ${use_forced_sudo} cp -R "${tar_dir}"/"${tar_root}"/. "${agent_home}"
        else
            if [ -n "${patch_jar}" ]
            then
                if [ ! -d "${agent_home}"/lib/patches ]
                then
                    Log ".. creating patch directory: ${agent_home}/lib/patches"
                    ${use_forced_sudo} mkdir -p "${agent_home}"/lib/patches
                fi

                if [ -f "${agent_home}"/lib/patches/"$(basename "${patch_jar}")" ]
                then
                    ${use_forced_sudo} rm -f "${agent_home}"/lib/patches/"$(basename "${patch_jar}")"
                fi

                Log ".. copying patch file: ${patch_jar} to Agent patch directory: ${agent_home}/lib/patches"
                ${use_forced_sudo} cp -p "${patch_jar}" "${agent_home}"/lib/patches/
                ChangeOwner "${agent_home}/lib/patches/*" "${home_owner}" "${home_owner_group}"
                ${use_forced_sudo} chmod o-rwx "${agent_home}"/lib/patches/"$(basename "${patch_jar}")"
                ${use_forced_sudo} chmod ug-x  "${agent_home}"/lib/patches/"$(basename "${patch_jar}")"
            fi
        fi

        StartAgent
        return_code=0
        exit
    fi

    # create Agent home directory if required
    if [ -z "${noinstall_agent}" ] && [ ! -d "${agent_home}" ] && [ -n "${make_dirs}" ]
    then
        Log ".. creating Agent home directory: ${agent_home}"
        if [ -n "${use_forced_sudo}" ]
        then
            ${use_forced_sudo} sh -c "umask 0002; mkdir -p \"${agent_home}\""
        else
            ${use_forced_sudo} mkdir -p "${agent_home}"
        fi
    fi

    # create Agent data directory if required
    if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
    then
        if [ ! -d "${agent_data}" ] && [ -n "${make_dirs}" ]
        then
            Log ".. creating Agent data directory: ${agent_data}"
            if [ -n "${use_forced_sudo}" ]
            then
                ${use_forced_sudo} sh -c "umask 0002; mkdir -p \"${agent_data}\""
            else
                ${use_forced_sudo} mkdir -p "${agent_data}"
            fi
        fi
    fi

    # remove the Agent's journal if requested
    if [ -n "${remove_journal}" ]
    then
        if [ -d "${agent_data}"/state ]
        then
            Log ".. removing Agent journal from directory: ${agent_data}/state/*"
            ${use_forced_sudo} sh -c "rm -fr ${agent_data}/state/*"
        fi
    fi

    # preserve the Agent's lib/user_lib directory
    if [ -z "${noinstall_agent}" ] && [ -d "${agent_home}"/lib/user_lib ] && [ -n "$(ls -A "${agent_home}"/lib/user_lib)" ] && [ -z "${patch}" ]
    then
        Log ".. copying files to extracted tarball directory: ${tar_dir}/${tar_root}/ from Agent home: ${agent_home}/lib/user_lib"
        ${use_forced_sudo} cp -p -R "${agent_home}"/lib/user_lib "${tar_dir}"/"${tar_root}"/lib/
    fi

    # remove the Agent's yade directory
    if [ -z "${noinstall_agent}" ] && [ -d "${agent_home}"/yade ] && [ -z "${patch}" ]
    then
        Log ".. removing yade directory from Agent home: ${agent_home}/yade"
        ${use_forced_sudo} rm -fr "${agent_home}"/yade
    fi

    # remove patches from the Agent's patches directory
    if [ -z "${noinstall_agent}" ] && [ -d "${agent_home}"/lib/patches ] && [ -z "${patch}" ]
    then
        Log ".. removing patches from Agent patch directory: ${agent_home}/lib/patches"
        ${use_forced_sudo} sh -c "rm -fr ${agent_home}/lib/patches/*"
    fi

    # move or remove the Agent's lib directory
    if [ -z "${noinstall_agent}" ] && [ -d "${agent_home}"/lib ] && [ -z "${patch}" ]
    then
        if [ -z "${move_libs}" ]
        then
            ${use_forced_sudo} rm -fr "${agent_home:?}"/lib
        else
            # check existing version and lib directory copies
            if ${use_forced_sudo} test -f "${agent_home}"/.version
            then
                version=$(awk -F "=" '/release/ {print $2}' "${agent_home}"/.version)
            else
                version="0.0.0"
            fi
    
            while [ -d "${agent_home}/lib.${version}" ]
            do
                version="${version}-1"
            done
    
            Log ".. moving directory ${agent_home}/lib to: ${agent_home}/lib.${version}"
            ${use_forced_sudo} mv "${agent_home}"/lib "${agent_home}"/lib."${version}"
        fi
    fi    

    if [ -n "${tarball}" ]
    then
        # do not overwrite an existing data directory
        if [ -d "${agent_data}"/state ] || [ -d "${agent_data}"/config ]
        then
            rm -fr "${tar_dir:?}"/"${tar_root}"/var
        fi

        # remove YADE on request
        if [ -n "${noyade_agent}" ] && [ -d "${tar_dir}"/"${tar_root}"/yade ]
        then
            Log ".. removing YADE from Agent tarball directory: ${tar_dir}/${tar_root}/yade"
            rm -fr "${tar_dir:?}"/"${tar_root}"/yade
        fi

        # copy to Agent home directoy
        ChangeOwner "${tar_dir}"/"${tar_root}"/. "${home_owner}" "${home_owner_group}"
        Log ".. copying files from extracted tarball directory: ${tar_dir}/${tar_root} to Agent home: ${agent_home}"
        ${use_forced_sudo} cp -p -R "${tar_dir}"/"${tar_root}"/. "${agent_home}"
    fi
    
    # populate Agent data directory from configuration files and certificates
    if [ -z "${patch}" ] 
    then
        if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
        then
            if [ ! -d "${agent_data}"/config ] && [ ! -d "${agent_data}"/state ]
            then
                Log ".. creating Agent data directory: ${agent_data}"
                ${use_forced_sudo} mkdir -p "${agent_data}"
                Log ".. copying files to Agent data directory: ${agent_data}"
                ${use_forced_sudo} cp -p -R "${agent_home}"/var/. "${agent_data}"/
            fi
            
            if [ ! -f "${agent_config}"/agent.conf-example ] && [ -f "${agent_home}"/var/config/agent.conf-example ]
            then
                Log ".. copying agent.conf-example to Agent config directory: ${agent_config}"
                ${use_forced_sudo} cp -p "${agent_home}"/var/config/agent.conf-example "${agent_config}"/
            fi
        fi
    fi

    if [ -n "${license_key}" ]
    then
        download_target="${agent_home}/lib/user_lib/js7-license.jar"
        
        if [ ! -d "${agent_home}"/lib/user_lib ]
        then
            ${use_forced_sudo} mkdir -p "${agent_home}"/lib/user_lib
        fi

        if [ -z "${license_bin}" ]
        then
            release_major=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\1/')
            release_minor=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\2/')
            release_maint=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\3/')
    
            if [ -n "$(echo "${release_maint}" | grep -E '(SNAPSHOT)|(RC[0-9]?)$')" ]
            then
                download_url="https://download.sos-berlin.com/JobScheduler.${release_major}.0/js7-license.jar"
            else
                download_url="https://download.sos-berlin.com/JobScheduler.${release_major}.${release_minor}/js7-license.jar"
            fi
    
            Log ".. downloading license binary file from: ${download_url} to ${download_target}"
            rc=0
    
            if [ -n "${log_file}" ] && [ -f "${log_file}" ]
            then
                curl_output_file_license="/tmp/js7_install_agent_license_$$.tmp"
                touch "${curl_output_file_license}"
                (${use_forced_sudo} curl "${download_url}" --output "${download_target}" --fail > "${curl_output_file_license}" 2>&1) || rc=$?; if [ "${rc}" -ne 0 ]; then LogError "$(cat ${curl_output_file_license})"; fi
            else
                (${use_forced_sudo} curl "${download_url}" --output "${download_target}" --fail) || rc=$?
            fi
    
            if [ "${rc}" -ne 0 ]
            then
                LogError "download failed for URL ${download_url}, exit code: ${rc}"
                exit 4
            fi
        else
            Log ".. copying license binary file from: ${license_bin} to ${download_target}"
            ${use_forced_sudo} cp -p "${license_bin}" "${download_target}"
        fi

        if [ -n "${agent_data}" ]
        then
            if [ ! -d "${agent_data}"/config/license ]
            then
                ${use_forced_sudo} mkdir -p "${agent_data}"/config/license
            fi

            Log ".. copying license key file to: ${agent_data}/config/license/"
            ${use_forced_sudo} cp -p "${license_key}" "${agent_data}"/config/license/
        else
            if [ ! -d "${agent_home}"/var/config/license ]
            then
                ${use_forced_sudo} mkdir -p "${agent_home}"/var/config/license
            fi

            Log ".. copying license key file to: ${agent_home}/var/config/license/"
            ${use_forced_sudo} cp -p "${license_key}" "${agent_home}"/var/config/license/
        fi
    else
        if [ -n "${license_bin}" ]
        then
            download_target="${agent_home}/lib/user_lib/js7-license.jar"
        
            if [ ! -d "${agent_home}"/lib/user_lib ]
            then
                ${use_forced_sudo} mkdir -p "${agent_home}"/lib/user_lib
            fi

            Log ".. copying license binary file from: ${license_bin} to ${download_target}"
            ${use_forced_sudo} cp -p "${license_bin}" "${download_target}"
        fi
    fi

    if [ ! -d "${agent_config}"/private ]
    then
        ${use_forced_sudo} mkdir -p "${agent_config}"/private
    fi

    # copy deployment directory
    if [ -n "${deploy_dir}" ]
    then
        set -- "$(echo "${deploy_dir}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            if [ ! -d "$i" ] 
            then
                LogError "Deployment Directory not found: --deploy-dir=$i"
            else
                Log ".. deploying configuration from ${i} to Agent configuration directory: ${agent_config}/"
                ${use_forced_sudo} cp -p -R "${i}"/. "${agent_config}"/
            fi
        done
    fi

    # copy instance start script
    if [ -z "${instance_script}" ]
    then
        use_instance_script="${agent_home}"/bin/agent_"${http_port}".sh
        if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
        then
            if ! ${use_forced_sudo} test -f "${use_instance_script}" && ${use_forced_sudo} test -f "${agent_home}"/bin/agent_instance.sh-example
            then
                Log ".. copying Agent sample Instance Start Script ${agent_home}/bin/agent_instance.sh-example to ${use_instance_script}"
                ${use_forced_sudo} cp -p "${agent_home}"/bin/agent_instance.sh-example "${use_instance_script}"
            fi
        fi
    else
        use_instance_script="${agent_home}"/bin/$(basename "${instance_script}")
        Log ".. copying Agent Instance Start Script ${instance_script} to ${use_instance_script}"
        ${use_forced_sudo} cp -p "${instance_script}" "${use_instance_script}"
    fi

    # copy systemd service file
    use_service_file="${agent_home}"/bin/agent_"${http_port}".service
    if [ -z "${systemd_service_file}" ]
    then
        if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
        then
            if ${use_forced_sudo} test -f "${agent_home}"/bin/agent.service-example
            then
                Log ".. copying ${agent_home}/bin/agent.service-example to ${use_service_file}"
                ${use_forced_sudo} cp -p "${agent_home}"/bin/agent.service-example "${use_service_file}"
            fi
        fi
    else
        Log ".. copying ${systemd_service_file} to ${use_service_file}"
        ${use_forced_sudo} cp -p "${systemd_service_file}" "${use_service_file}"
    fi

    # copy agent.conf
    if [ ! -d "${agent_config}" ]
    then
        ${use_forced_sudo} mkdir -p "${agent_config}"
    fi

    if [ -n "${agent_conf}" ]
    then
        Log ".. copying Agent configuration ${agent_conf} to ${agent_config}/agent.conf"
        ${use_forced_sudo} cp -p "${agent_conf}" "${agent_config}"/agent.conf
    else
        if [ ! -f  "${agent_config}"/agent.conf ] && [ -f  "${agent_config}"/agent.conf-example ]
        then
            Log ".. copying Agent configuration ${agent_config}/agent.conf-example to ${agent_config}/agent.conf"
            ${use_forced_sudo} cp -p "${agent_config}"/agent.conf-example "${agent_config}"/agent.conf
        fi
    fi

    # copy private.conf
    if [ -n "${private_conf}" ]
    then
        if [ ! -d "${agent_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${agent_config}"/private
        fi
        Log ".. copying Agent private configuration ${private_conf} to ${agent_config}/private/private.conf"
        ${use_forced_sudo} cp -p "${private_conf}" "${agent_config}"/private/private.conf
    fi

    # copy keystore
    if [ -n "${keystore_file}" ]
    then
        if [ ! -d "${agent_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${agent_config}"/private
        fi
        use_keystore_file="${agent_config}"/private/$(basename "${keystore_file}")
        Log ".. copying keystore file ${keystore_file} to ${use_keystore_file}"
        ${use_forced_sudo} cp -p "${keystore_file}" "${use_keystore_file}"
    fi

    # copy client keystore
    if [ -n "${client_keystore_file}" ]
    then
        if [ ! -d "${agent_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${agent_config}"/private
        fi
        use_client_keystore_file="${agent_config}"/private/$(basename "${client_keystore_file}")
        Log ".. copying client keystore file ${client_keystore_file} to ${use_client_keystore_file}"
        ${use_forced_sudo} cp -p "${client_keystore_file}" "${use_client_keystore_file}"
    fi

    # copy truststore
    if [ -n "${truststore_file}" ]
    then
        if [ ! -d "${agent_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${agent_config}"/private
        fi
        use_truststore_file="${agent_config}"/private/$(basename "${truststore_file}")
        Log ".. copying truststore file ${truststore_file} to ${use_truststore_file}"
        ${use_forced_sudo} cp -p "${truststore_file}" "${use_truststore_file}"
    fi

    # update configuration items
    if [ -z "${os_compat}" ]
    then
        os_name=$(uname -a)
        Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        Log ".. For this OS changes have to be applied manually: ${os_name}"
    fi

    # update instance script
    if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
    then
        if ${use_forced_sudo} test -f "${use_instance_script}"
        then
            if [ -z "${os_compat}" ]
            then
                Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
                Log ".. Modify the following file: ${use_instance_script}"
                Log ".. Modify the following settings:"
            fi

            if [ -n "${os_compat}" ]
            then
                Log ".. updating Agent Instance Start Script: ${use_instance_script}"
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HOME=.*/$(echo "JS7_AGENT_HOME=${real_agent_home}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
            else
                Log ".. JS7_AGENT_HOME=${real_agent_home}"
            fi
    
            if [ -n "${agent_user}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_USER=.*/JS7_AGENT_USER=${agent_user}/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_USER=${agent_user}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_USER=.*/# JS7_AGENT_USER=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${http_port}" ]
            then
                if [ -n "${http_network_interface}" ]
                then
                    if [ -n "${os_compat}" ]
                    then
                        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTP_PORT=.*/JS7_AGENT_HTTP_PORT=${http_network_interface}:${http_port}/g" "${use_instance_script}"
                    else
                        Log ".. JS7_AGENT_HTTP_PORT=${http_network_interface}:${http_port}"
                    fi
                else
                    if [ -n "${os_compat}" ]
                    then
                        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTP_PORT=.*/JS7_AGENT_HTTP_PORT=${http_port}/g" "${use_instance_script}"
                    else
                        Log ".. JS7_AGENT_HTTP_PORT=${http_port}"
                    fi
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTP_PORT=.*/# JS7_AGENT_HTTP_PORT=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${https_port}" ]
            then
                if [ -n "${https_network_interface}" ]
                then
                    if [ -n "${os_compat}" ]
                    then
                        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTPS_PORT=.*/JS7_AGENT_HTTPS_PORT=${https_network_interface}:${https_port}/g" "${use_instance_script}"
                    else
                        Log ".. JS7_AGENT_HTTPS_PORT=${https_network_interface}:${https_port}"
                    fi
                else
                    if [ -n "${os_compat}" ]
                    then
                        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTPS_PORT=.*/JS7_AGENT_HTTPS_PORT=${https_port}/g" "${use_instance_script}"
                    else
                        Log ".. JS7_AGENT_HTTPS_PORT=${https_port}"
                    fi
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_HTTPS_PORT=.*/# JS7_AGENT_HTTPS_PORT=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${agent_data}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_DATA=.*/$(echo "JS7_AGENT_DATA=${real_agent_data}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_DATA=${real_agent_data}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_DATA=.*/# JS7_AGENT_DATA=/g" "${use_instance_script}"
                fi
            fi
            
            if [ -n "${agent_config}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_CONFIG_DIR=.*/$(echo "JS7_AGENT_CONFIG_DIR=${real_agent_config}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_CONFIG_DIR=${real_agent_config}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_CONFIG_DIR=.*/# JS7_AGENT_CONFIG_DIR=/g" "${use_instance_script}"
                fi
            fi
            
            if [ -n "${agent_logs}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_LOGS=.*/$(echo "JS7_AGENT_LOGS=${real_agent_logs}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_LOGS=${real_agent_logs}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_LOGS=.*/# JS7_AGENT_LOGS=/g" "${use_instance_script}"
                fi
            fi
            
            if [ -n "${agent_work}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_WORK_DIR=.*/$(echo "JS7_AGENT_WORK_DIR=${real_agent_work}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_WORK_DIR=${real_agent_work}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_WORK_DIR=.*/# JS7_AGENT_WORK_DIR=/g" "${use_instance_script}"
                fi
            fi
            
            if [ -n "${pid_file_dir}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_PID_FILE_DIR=.*/$(echo "JS7_AGENT_PID_FILE_DIR=${pid_file_dir}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_PID_FILE_DIR=${pid_file_dir}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_PID_FILE_DIR=.*/# JS7_AGENT_PID_FILE_DIR=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${pid_file_name}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_PID_FILE_NAME=.*/JS7_AGENT_PID_FILE_NAME=${pid_file_name}/g" "${use_instance_script}"
                else
                    Log ".. JS7_AGENT_PID_FILE_NAME=${pid_file_name}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_AGENT_PID_FILE_NAME=.*/# JS7_AGENT_PID_FILE_NAME=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${java_home}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_HOME=.*/$(echo "JAVA_HOME=${java_home}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JAVA_HOME=${java_home}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_HOME=.*/# JAVA_HOME=/g" "${use_instance_script}"
                fi
            fi
    
            if [ -n "${java_options}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_OPTIONS=.*/$(echo "JAVA_OPTIONS=\"${java_options}\"" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
                else
                    Log ".. JAVA_OPTIONS=\"${java_options}\""
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_OPTIONS=.*/# JAVA_OPTIONS=/g" "${use_instance_script}"
                fi
            fi

            if [ -z "${os_compat}" ]
            then
                Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"    
            fi
        fi
    
        # update systemd service file
        if [ -z "${noinstall_agent}" ] || [ -n "${useinstall_agent}" ]
        then
            if [ -z "${systemd_service_file}" ] && [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_service_file}"
            then
                Log ".. updating Agent systemd service file: ${use_service_file}"
        
                ${use_forced_sudo} sed -i'' -e "s/<JS7_AGENT_HTTP_PORT>/${http_port}/g" "${use_service_file}"
        
                use_pid_file_name=${pid_file_name:-agent.pid}
        
                if [ -n "${pid_file_dir}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/<JS7_AGENT_PID_FILE_DIR>/$(echo "${pid_file_dir}" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^PIDFile[ ]*=[ ]*.*/PIDFile=$(echo "${pid_file_dir}" | sed -e 's@/@\\\/@g')\/${use_pid_file_name}/g" "${use_service_file}"
                else
                    ${use_forced_sudo} sed -i'' -e "s/<JS7_AGENT_PID_FILE_DIR>/$(echo "${real_agent_logs}" | sed -e 's@\/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^PIDFile[ ]*=[ ]*.*/PIDFile=$(echo "${real_agent_logs}" | sed -e 's@/@\\\/@g')\/${use_pid_file_name}/g" "${use_service_file}"
                fi
        
                ${use_forced_sudo} sed -i'' -e "s/<JS7_AGENT_USER>/${agent_user}/g" "${use_service_file}"
                ${use_forced_sudo} sed -i'' -e "s/^User[ ]*=[ ]*.*/User=${agent_user}/g" "${use_service_file}"
                ${use_forced_sudo} sed -i'' -e "s/^TimeoutStopSec[ ]*=[ ]*.*/TimeoutStopSec=${systemd_service_stop_timeout}/g" "${use_service_file}"
                ${use_forced_sudo} sed -i'' -e "s/<INSTALL_PATH>/$(echo "${real_agent_home}" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"

                if [ "${systemd_service_failover}" -gt 0 ]
                then
                    service_stop_action="stop --fail-over"
                else
                    service_stop_action="stop"
                fi

                if [ "${systemd_service_selinux}" -gt 0 ]
                then
                    line_no=$(< "${use_service_file}" sed -n '/^ExecStart/{=;q;}')
                    if [ -n "${line_no}" ] && [ "${line_no}" -gt 0 ]
                    then
                        if [ -n "${pid_file_dir}" ]
                        then
                            ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${agent_user} ${pid_file_dir}" "${use_service_file}"
                            ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${pid_file_dir}" "${use_service_file}"
                        else
                            ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${agent_user} ${real_agent_logs}" "${use_service_file}"
                            ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${real_agent_logs}" "${use_service_file}"
                        fi
                    fi

                    ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "/bin/sh -c \"${real_agent_home}/bin/agent_${http_port}.sh start\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "/bin/sh -c \"${real_agent_home}/bin/agent_${http_port}.sh ${service_stop_action}\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "/bin/sh -c \"${real_agent_home}/bin/agent_${http_port}.sh restart\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                else
                    ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "${real_agent_home}/bin/agent_${http_port}.sh start" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "${real_agent_home}/bin/agent_${http_port}.sh stop ${service_stop_action}" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "${real_agent_home}/bin/agent_${http_port}.sh restart" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
                fi

                ${use_forced_sudo} sed -i'' -e "s/^StandardOutput[ ]*=[ ]*syslog+console/StandardOutput=journal+console/g" "${use_service_file}"
                ${use_forced_sudo} sed -i'' -e "s/^StandardError[ ]*=[ ]*syslog+console/StandardError=journal+console/g" "${use_service_file}"
        
                if [ -n "${java_home}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*Environment[ ]*=[ ]*\"JAVA_HOME.*/Environment=\"JAVA_HOME=$(echo "${java_home}" | sed -e 's@/@\\\/@g')\"/g" "${use_service_file}"
                fi
        
                if [ -n "${java_options}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*Environment[ ]*=[ ]*\"JAVA_OPTIONS.*/Environment=\"JAVA_OPTIONS=$(echo "${java_options}" | sed -e 's@/@\\\/@g')\"/g" "${use_service_file}"
                fi
            fi
        fi
    fi

    # make systemd service
    if [ -n "${make_service}" ]
    then
        MakeService "${use_service_file}"
    fi

    # update agent.conf
    if ${use_forced_sudo} test -f "${agent_config}"/agent.conf
    then
        if [ -z "${os_compat}" ]
        then
            Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            Log ".. Modify the following file: ${agent_config}/agent.conf"
            Log ".. Modify the following settings:"
        fi
        
        if [ -n "${standby_director}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".. updating Director Agent configuration to backup node: ${agent_config}/agent.conf"
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*/js7.journal.cluster.node.is-backup = yes/g" "${agent_config}"/agent.conf
            else
                Log ".. js7.journal.cluster.node.is-backup = yes"
            fi
        else
            if [ -n "${active_director}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    Log ".. updating Director Agent configuration to active node: ${agent_config}/agent.conf"
                    ${use_forced_sudo} sed -i'' -e "s/^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*/js7.journal.cluster.node.is-backup = no/g" "${agent_config}"/agent.conf
                else
                    Log ".. js7.journal.cluster.node.is-backup = no"
                fi
            fi
        fi

        if [ -z "${os_compat}" ]
        then
            Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"    
        fi
    fi
    
    # update private.conf
    if [ -n "${private_conf}${deploy_dir}" ] && ${use_forced_sudo} test -f "${agent_config}"/private/private.conf
    then
        if [ -n "${os_compat}" ]
        then
            Log ".. updating Agent configuration: ${agent_config}/private/private.conf"
        else
            Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            Log ".. Modify the following file: ${agent_config}/private/private.conf"
            Log ".. Modify the following settings:"
        fi

        if [ -n "${controller_id}" ]
        then
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{controller-id}}/${controller_id}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{controller-id}} => ${controller_id}"
            fi
        fi

        if [ -n "${controller_primary_subject}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating Primary/Standalone Controller distinguished name: ${controller_primary_subject}"
            fi

            if [ -n "${controller_secondary_subject}" ] || [ -n "${controller_secondary_cert}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}/$(echo "${controller_primary_subject}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{controller-primary-distinguished-name}} => ${controller_primary_subject}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}\",/$(echo "${controller_primary_subject}\"" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{controller-primary-distinguished-name}} => ${controller_primary_subject}"
                fi
            fi
        fi

        if [ -n "${controller_secondary_subject}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating Secondary Controller distinguished name: ${controller_secondary_subject}"
            fi

            if [ -n "${controller_primary_subject}" ] || [ -n "${controller_primary_cert}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{controller-secondary-distinguished-name}}/$(echo "${controller_secondary_subject}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{controller-secondary-distinguished-name}} => ${controller_secondary_subject}"
                fi
            fi
        fi

        dn=""
        if [ -n "${controller_primary_cert}" ] && ${use_forced_sudo} test -f "${controller_primary_cert}"
        then
            dn=$(openssl x509 -in "${controller_primary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            if [ -n "${os_compat}" ]
            then
                Log ".... updating Primary/Standalone Controller distinguished name: ${dn}"
            fi

            if [ -n "${controller_secondary_cert}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{controller-primary-distinguished-name}} => ${dn}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}\",/$(echo "${dn}\"" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{controller-primary-distinguished-name}} => ${dn}"
                fi
            fi
        else
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/\"{{controller-primary-distinguished-name}}\",//g" "${agent_config}"/private/private.conf
            fi
        fi

        if [ -n "${controller_secondary_cert}" ] && ${use_forced_sudo} test -f "${controller_secondary_cert}"
        then
            dn=$(openssl x509 -in "${controller_secondary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            if [ -n "${os_compat}" ]
            then
                Log ".... updating Secondary Controller distinguished name: ${dn}"
                ${use_forced_sudo} sed -i'' -e "s/{{controller-secondary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{controller-secondary-distinguished-name}} => ${dn}"
            fi
        else
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/\"{{controller-secondary-distinguished-name}}\"//g" "${agent_config}"/private/private.conf
            fi
        fi

        if [ -n "${agent_cluster_id}" ]
        then
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{agent-cluster-id}}/${agent_cluster_id}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{agent-cluster-id}} => ${agent_cluster_id}"
            fi

            # if [ -n "${active_director}" ] || [ -n "${standby_director}" ]
            # then
                # if [ -n "${os_compat}" ]
                # then
                #     ${use_forced_sudo} sed -i'' -e "s/permissions[ ]*=[ ]*\[[ ]*AgentDirector[ ]*\].*//g" "${agent_config}"/private/private.conf
                # else
                #     Log ".. permissions = [ AgentDirector ]"
                # fi
            # fi
        else
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{agent-cluster-id}}/agent-cluster/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{agent-cluster-id}} => agent-cluster"
            fi
        fi
        
        if [ -n "${director_primary_subject}" ]
        then
            Log ".... updating Primary Director Agent distinguished name: ${director_primary_subject}"

            if [ -n "${director_secondary_subject}" ] || [ -n "${director_secondary_cert}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{director-primary-distinguished-name}}/$(echo "${director_primary_subject}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{director-primary-distinguished-name}} => ${director_primary_subject}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{director-primary-distinguished-name}}\",/$(echo "${director_primary_subject}\"" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{director-primary-distinguished-name}} => ${director_primary_subject}"
                fi
            fi
        fi

        if [ -n "${director_secondary_subject}" ]
        then
            Log ".... updating Secondary Director Agent distinguished name: ${director_secondary_subject}"

            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{director-secondary-distinguished-name}}/$(echo "${director_secondary_subject}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{director-secondary-distinguished-name}} => ${director_secondary_subject}"
            fi
        fi

        if [ -n "${director_primary_cert}" ] && ${use_forced_sudo} test -f "${director_primary_cert}"
        then
            dn=$(openssl x509 -in "${director_primary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            Log ".... updating Primary Director Agent distinguished name: ${dn}"
            if [ -n "${director_secondary_cert}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{director-primary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{director-primary-distinguished-name}} => ${dn}"
                fi
            else
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{director-primary-distinguished-name}}\",/$(echo "${dn}\"" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{director-primary-distinguished-name}} => ${dn}"
                fi
            fi
        else
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/\"{{director-primary-distinguished-name}}\",//g" "${agent_config}"/private/private.conf
            fi
        fi

        if [ -n "${director_secondary_cert}" ] && ${use_forced_sudo} test -f "${director_secondary_cert}"
        then
            dn=$(openssl x509 -in "${director_secondary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            if [ -n "${os_compat}" ]
            then
                Log ".... updating Secondary Director Agent distinguished name: ${dn}"
                ${use_forced_sudo} sed -i'' -e "s/{{director-secondary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{director-secondary-distinguished-name}} => ${dn}"
            fi
        else
            if [ -n "${os_compat}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/\"{{director-secondary-distinguished-name}}\"//g" "${agent_config}"/private/private.conf
            fi
        fi

        if [ -n "${keystore_file}" ] && ${use_forced_sudo} test -f "${keystore_file}"
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating keystore file name: $(basename "${keystore_file}")"
                ${use_forced_sudo} sed -i'' -e "s/{{keystore-file}}/$(basename "${keystore_file}")/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{keystore-file}} => $(basename "${keystore_file}")"
            fi

            if [ -z "${client_keystore_file}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-file}}/$(basename "${keystore_file}")/g" "${agent_config}"/private/private.conf
                else
                Log ".. {{client-keystore-file}} => ${keystore_file}"
                fi
            fi
        fi

        if [ -n "${keystore_password}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating keystore password"
                ${use_forced_sudo} sed -i'' -e "s/{{keystore-password}}/${keystore_password}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{keystore-password}} => ${keystore_password}"
            fi

            if [ -z "${client_keystore_password}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-password}}/${keystore_password}/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{client-keystore-password}} => ${keystore_password}"
                fi
            fi
        fi

        if [ -n "${keystore_alias}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating keystore alias name for key: ${keystore_alias}"
                ${use_forced_sudo} sed -i'' -e  "s/#* *alias=\"{{keystore-alias}}\"/alias=\"{{keystore-alias}}\"/g" "${agent_config}"/private/private.conf
                ${use_forced_sudo} sed -i'' -e "s/{{keystore-alias}}/${keystore_alias}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{keystore-alias}} => ${keystore_alias}"
            fi

            if [ -z "${client_keystore_alias}" ]
            then
                if [ -n "${os_compat}" ]
                then
                    ${use_forced_sudo} sed -i'' -e "s/#* *alias=\"{{client-keystore-alias}}\"/alias=\"{{client-keystore-alias}}\"/g" "${agent_config}"/private/private.conf
                    ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-alias}}/${keystore_alias}/g" "${agent_config}"/private/private.conf
                else
                    Log ".. {{client-keystore-alias}} => ${keystore_alias}"
                fi
            fi
        fi

        if [ -n "${client_keystore_file}" ] && ${use_forced_sudo} test -f "${client_keystore_file}"
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating client keystore file name: $(basename "${client_keystore_file}")"
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-file}}/$(basename "${client_keystore_file}")/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{client-keystore-file}} => ${client_keystore_file}"
            fi
        fi

        if [ -n "${client_keystore_password}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating client keystore password"
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-password}}/${client_keystore_password}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{client-keystore-password}} => ${client_keystore_password}"
            fi
        fi

        if [ -n "${client_keystore_alias}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating client keystore alias name for key: ${client_keystore_alias}"
                ${use_forced_sudo} sed -i'' -e "s/#* *alias=\"{{client-keystore-alias}}\"/alias=\"{{client-keystore-alias}}\"/g" "${agent_config}"/private/private.conf
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-alias}}/${client_keystore_alias}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{client-keystore-alias}} => ${client_keystore_alias}"
            fi
        fi

        if [ -n "${truststore_file}" ] && ${use_forced_sudo} test -f "${truststore_file}"
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating truststore file name: $(basename "${truststore_file}")"
                ${use_forced_sudo} sed -i'' -e "s/{{truststore-file}}/$(basename "${truststore_file}")/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{truststore-file}} => $(basename "${truststore_file}")"
            fi
        fi

        if [ -n "${truststore_password}" ]
        then
            if [ -n "${os_compat}" ]
            then
                Log ".... updating truststore password"
                ${use_forced_sudo} sed -i'' -e "s/{{truststore-password}}/${truststore_password}/g" "${agent_config}"/private/private.conf
            else
                Log ".. {{truststore-password}} => ${truststore_password}"
            fi
        fi

        if [ -n "${os_compat}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/{{.*}}//g" "${agent_config}"/private/private.conf
        fi
        
        if [ -z "${os_compat}" ]
        then
            Log ".. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"    
        fi
    fi

    if [ -n "${agent_home}" ] && [ -n "${home_owner}" ]
    then
        ChangeOwner "${agent_home}" "${home_owner}" "${home_owner_group}"
    fi

    if [ -n "${agent_data}" ] && [ -n "${data_owner}" ]
    then
        ChangeOwner "${agent_data}"  "${data_owner}" "${data_owner_group}"
        ChangeOwner "${agent_logs}"  "${agent_user}"
        ChangeOwner "${agent_state}" "${agent_user}"
        ChangeOwner "${agent_work}"  "${agent_user}"
    fi

    StartAgent
    return_code=0
}

# ------------------------------
# Cleanup temporary resources
# ------------------------------

End()
{   
    if [ -n "${tar_dir}" ] && [ -d "${tar_dir}" ]
    then
        # Log ".. removing temporary directory: ${tar_dir}"
        ${use_forced_sudo} rm -fr "${tar_dir}"
    fi

    if [ -n "${curl_output_file}" ] && [ -f "${curl_output_file}" ]
    then
        # Log ".. removing temporary file: ${curl_output_file}"
        rm -f "${curl_output_file}"
    fi

    if [ -n "${exclude_file}" ] && [ -f "${exclude_file}" ]
    then
        # Log ".. removing temporary file: ${exclude_file}"
        rm -f "${exclude_file}"
    fi

    if [ -n "${start_agent_output_file}" ] && [ -f "${start_agent_output_file}" ]
    then
        # Log ".. removing temporary file: ${start_agent_output_file}"
        rm -f "${start_agent_output_file}"
    fi

    if [ -n "${stop_agent_output_file}" ] && [ -f "${stop_agent_output_file}" ]
    then
        # Log ".. removing temporary file: ${stop_agent_output_file}"
        rm -f "${stop_agent_output_file}"
    fi

    if [ "$1" = "EXIT" ]
    then
        if [ -n "${return_values}" ]
        then
            Log ".. writing return values to: ${return_values}"
            echo "log_file=${log_file}" > "${return_values}"
            echo "backup_file=${backup_file}" >> "${return_values}"
            echo "return_code=${return_code}" >> "${return_values}"
        fi

        Log "-- end of log ----------------"

        if [ -n "${show_logs}" ] && [ -f "${log_file}" ]
        then
            cat "${log_file}"
        fi        
    fi

    unset wait_agent
    unset real_path_prefix
    unset agent_home
    unset agent_data
    unset agent_config
    unset agent_logs
    unset agent_state
    unset agent_work
    unset agent_user
    unset home_owner
    unset home_owner_group
    unset data_owner
    unset data_owner_group
    unset force_sudo
    unset backup_dir
    unset log_dir
    unset deploy_dir
    unset exec_start
    unset exec_stop
    unset http_port
    unset http_network_interface
    unset https_port
    unset https_network_interface
    unset pid_file_dir
    unset pid_file_name
    unset noinstall_agent
    unset noyade_agent
    unset useinstall_agent
    unset uninstall_agent
    unset uninstall_agent_home
    unset uninstall_agent_data
    unset java_home
    unset java_options
    unset instance_script
    unset systemd_service_dir
    unset systemd_service_file
    unset systemd_service_name
    unset systemd_service_selinux
    unset systemd_service_failover
    unset systemd_service_stop_timeout
    unset agent_conf
    unset private_conf
    unset controller_id
    unset controller_primary_cert
    unset controller_secondary_cert
    unset controller_primary_subject
    unset controller_secondary_subject
    unset agent_cluster_id
    unset director_primary_cert
    unset director_secondary_cert
    unset director_primary_subject
    unset director_secondary_subject

    unset keystore_file
    unset keystore_alias
    unset keystore_password
    unset client_keystore_file
    unset client_keystore_alias
    unset client_keystore_password
    unset truststore_file
    unset truststore_password

    unset cancel_agent
    unset make_dirs
    unset make_service
    unset move_libs
    unset patch
    unset patch_jar
    unset release
    unset remove_journal
    unset restart_agent
    unset return_values
    unset show_logs
    unset tarball

    unset backup_file
    unset curl_output_file
    unset download_url
    unset exclude_file
    unset hostname
    unset log_file
    unset release_major
    unset release_minor
    unset release_maint
    unset return_code
    unset start_agent_output_file
    unset start_time
    unset stop_agent_output_file
    unset stop_option
    unset tar_dir
    unset os_compat
    unset os_normal

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
