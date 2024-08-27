#!/bin/sh

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2023-06-17
# Purpose:  download and extract JS7 Controller, take backups and restart
# Platform: AIX, Linux, MacOS: bash, ksh, zsh, dash
# ------------------------------------------------------------
#
# Example:  ./js7_install_controller.sh --home=/home/sos/controller --release=2.2.3 --make-dirs
#
#           downloads the indicated Controller release and extracts to the specified Controller home directory
#
# Example:  ./js7_install_controller.sh --home=/home/sos/controller --tarball=/mnt/releases/scheduler_setups/2.2.3/js7_controller_unix.2.2.3.tar.gz --move-libs
#
#           extracts the indicated tarball to the specified Controller home directory
#           an existing lib directory is renamed and appended its release number

set -e

# ------------------------------
# Initialize variables
# ------------------------------

abort_controller=
uninstall_controller=
noinstall_controller=
real_path_prefix=
controller_home=
controller_data=
controller_config=
controller_logs=
controller_id=controller
controller_user=$(id -u -n -r)
home_owner=
home_owner_group=
data_owner=
data_owner_group=
force_sudo=
standby_controller=
active_controller=
backup_dir=
deploy_dir=
exec_start=
exec_stop=
http_port=4444
http_network_interface=
https_port=
https_network_interface=
instance_script=
systemd_service_dir=/usr/lib/systemd/system
systemd_service_file=
systemd_service_name=
systemd_service_selinux=
java_home=
java_options=
pid_file_dir=
pid_file_name=
controller_conf=
private_conf=
controller_primary_cert=
controller_secondary_cert=
controller_primary_subject=
controller_secondary_subject=
joc_primary_cert=
joc_secondary_cert=
joc_primary_subject=
joc_secondary_subject=
keystore_file=
keystore_alias=
keystore_password=
client_keystore_file=
client_keystore_alias=
client_keystore_password=
truststore_file=
truststore_password=
kill_controller=
license_key=
license_bin=
log_dir=
make_dirs=
make_service=
move_libs=
patch=
patch_jar=
release=
remove_journal=
restart_controller=
return_values=
show_logs=
tarball=

backup_file=
download_url=
exclude_file=
hostname=$(hostname)
log_file=
release_major=
release_minor=
release_maint=
return_code=-1
start_controller_output_file=
start_time=$(date +"%Y-%m-%dT%H-%M-%S")
stop_controller_output_file=
stop_option=
tar_dir=

Usage()
{
    >&2 echo ""
    >&2 echo "Usage: $(basename "$0") [Options] [Switches]"
    >&2 echo ""
    >&2 echo "  Installation Options:"
    >&2 echo "    --home=<directory>                  | required: directory to which the Controller will be be installed"
    >&2 echo "    --data=<directory>                  | optional: directory for Controller data files, default:  <home>/var"
    >&2 echo "    --config=<directory>                | optional: directory from which the Controller reads configuration files, default: <data>/config"
    >&2 echo "    --logs=<directory>                  | optional: directory to which the Controller writes log files, default: <data>/logs"
    >&2 echo "    --user=<account>                    | optional: user account for Controller daemon, default: ${controller_user}"
    >&2 echo "    --home-owner=<account[:group]>      | optional: account and optionally group owning the home directory, requires root or sudo permissions"
    >&2 echo "    --data-owner=<account[:group]>      | optional: account and optionally group owning the data directory, requires root or sudo permissions"
    >&2 echo "    --controller-id=<identifier>        | optional: Controller ID, default: ${controller_id}"
    >&2 echo "    --release=<release-number>          | optional: release number such as 2.2.3 for download if --tarball is not used"
    >&2 echo "    --tarball=<tar-gz-archive>          | optional: the path to a .tar.gz archive that holds the Controller installation or patch tarball"
    >&2 echo "                                        |           if not specified the Controller tarball will be downloaded from the SOS web site"
    >&2 echo "    --patch=<issue-key>                 | optional: identifies a patch from a Change Management issue key"
    >&2 echo "    --patch-jar=<jar-file>              | optional: the path to a .jar file that holds the patch"
    >&2 echo "    --license-key=<key-file>            | optional: specifies the path to a license key file to be installed"
    >&2 echo "    --license-bin=<binary-file>         | optional: specifies the path to the js7-license.jar binary file for licensed code to be installed"
    >&2 echo "                                        |           if not specified the file will be downloaded from the SOS web site"
    >&2 echo "    --http-port=<port>                  | optional: specifies the http port the Controller will be operated for, default: ${http_port}"
    >&2 echo "                                                    port can be prefixed by network interface, e.g. localhost:4444"
    >&2 echo "    --https-port=<port>                 | optional: specifies the https port the Controller will be operated for"
    >&2 echo "                                                    port can be prefixed by network interface, e.g. batch.example.com:4444"
    >&2 echo "    --pid-file-dir=<directory>          | optional: directory to which the Controller writes its PID file, default: <data>/logs"
    >&2 echo "    --pid-file-name=<file-name>         | optional: file name used by the Controller to write its PID file, default: controller.pid"
    >&2 echo "    --instance-script=<file>            | optional: path to the Instance Start Script that will be copied to the Controller, default <home>/bin/<instance-script>"
    >&2 echo "    --backup-dir=<directory>            | optional: backup directory for existing Controller home directory"
    >&2 echo "    --log-dir=<directory>               | optional: log directory for log output of this script"
    >&2 echo "    --exec-start=<command>              | optional: specifies the command to start the Controller, e.g. 'StartService'"
    >&2 echo "    --exec-stop=<command>               | optional: specifies the command to stop the Controller, e.g. 'StopService'"
    >&2 echo "    --return-values=<file>              | optional: specifies a file that receives return values such as the path to a log file"
    >&2 echo ""
    >&2 echo "  Configuration Options:"
    >&2 echo "    --deploy-dir=<directory>            | optional: deployment directory from which configuration files are copied to the Controller"
    >&2 echo "    --controller-conf=<file>            | optional: path to a configuration file that will be copied to <config>/controller.conf"
    >&2 echo "    --private-conf=<file>               | optional: path to a configuration file that will be copied to <config>/private/private.conf"
    >&2 echo "    --controller-primary-cert=<file>    | optional: path to Primary Controller certificate file"
    >&2 echo "    --controller-secondary-cert=<file>  | optional: path to Secondary Controller certificate file"
    >&2 echo "    --controller-primary-subject=<id>   | optional: subject of Primary Controller certificate"
    >&2 echo "    --controller-secondary-subject=<id> | optional: subject of Secondary Controller certificate"
    >&2 echo "    --joc-primary-cert=<file>           | optional: path to Primary/Standalone JOC Cockpit certificate file"
    >&2 echo "    --joc-secondary-cert=<file>         | optional: path to Secondary JOC Cockpit certificate file"
    >&2 echo "    --joc-primary-subject=<id>          | optional: subject of Primary/Standalone JOC Cockpit certificate"
    >&2 echo "    --joc-secondary-subject=<id>        | optional: subject of Secondary JOC Cockpit certificate"
    >&2 echo "    --keystore=<file>                   | optional: path to a PKCS12 keystore file that will be copied to <config>/private/"
    >&2 echo "    --keystore-password=<password>      | optional: password for access to keystore"
    >&2 echo "    --keystore-alias=<alias>            | optional: alias name for keystore entry"
    >&2 echo "    --client-keystore=<file>            | optional: path to a PKCS12 client keystore file that will be copied to <config>/private/"
    >&2 echo "    --client-keystore-password=<pass>   | optional: password for access to client keystore"
    >&2 echo "    --client-keystore-alias=<alias>     | optional: alias name for client keystore entry"
    >&2 echo "    --truststore=<file>                 | optional: path to a PKCS12 truststore file that will be copied to <config>/private/"
    >&2 echo "    --truststore-password=<password>    | optional: password for access to truststore"
    >&2 echo "    --java-options=<options>            | optional: Java Options for use with the Instance Start Script"
    >&2 echo "    --java-home=<directory>             | optional: Java Home directory for use with the Instance Start Script"
    >&2 echo "    --service-dir=<directory>           | optional: systemd service directory, default: ${systemd_service_dir}"
    >&2 echo "    --service-file=<file>               | optional: path to a systemd service file that will be copied to <home>/bin/"
    >&2 echo "    --service-name=<identifier>         | optional: name of the systemd service to be created, default js7_controller_<controller-id>"
    >&2 echo ""
    >&2 echo "  Switches:"
    >&2 echo "    -h | --help                         | displays usage"
    >&2 echo "    --force-sudo                        | forces use of sudo for operations on directories"
    >&2 echo "    --active                            | makes Controller instance the default active node in a Controller Cluster"
    >&2 echo "    --standby                           | makes Controller instance the default standby node in a Controller Cluster"
    >&2 echo "    --no-install                        | skips Controller installation, performs configuration updates only"
    >&2 echo "    --uninstall                         | uninstalls Controller"
    >&2 echo "    --service-selinux                   | use SELinux version of systemd service file"
    >&2 echo "    --show-logs                         | shows log output of the script"
    >&2 echo "    --make-dirs                         | creates the specified directories if they do not exist"
    >&2 echo "    --make-service                      | creates the systemd service for the Controller"
    >&2 echo "    --move-libs                         | moves an existing Controller's lib directory instead of removing the directory"
    >&2 echo "    --remove-journal                    | removes an existing Controller's state directory that holds the journal"
    >&2 echo "    --restart                           | stops a running Controller and starts the Controller after installation"
    >&2 echo "    --abort                             | aborts a running Controller if used with the --restart switch"
    >&2 echo "    --kill                              | kills a running Controller if used with the --restart switch"
    >&2 echo ""
}

GetPid()
{
  if [ -n "${http_port}" ]
  then
      ps -ef | grep -E "js7\.controller\.ControllerMain.*--http-port=${http_port}" | grep -v "grep" | awk '{print $2}'
  else
      ps -ef | grep -E "js7\.controller\.ControllerMain.*" | grep -v "grep" | awk '{print $2}'
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
    
        echo "[ERROR]" "$@"
}

StartController()
{
    if [ -n "${exec_start}" ]
    then
        Log ".. starting Controller: ${exec_start}"
        ${exec_start}
    else
        if [ -n "${restart_controller}" ]
        then
            if [ -d "${controller_home}"/bin ]
            then
                if [ -f "${controller_home}"/bin/controller_instance.sh ]
                then
                    Log ".. starting Controller: ${controller_home}/bin/controller_instance.sh start"

                    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                    then
                        start_controller_output_file="/tmp/js7_install_controller_start_$$.tmp"
                        touch "${start_controller_output_file}"
                        ( "${controller_home}/bin/controller_instance.sh" start > "${start_controller_output_file}" 2>&1 ) || ( LogError "$(cat ${start_controller_output_file})" && exit 5 )
                        Log "$(cat ${start_controller_output_file})"
                    else
                        "${controller_home}/bin/controller_instance.sh" start
                    fi
                else
                    if [ -f "${controller_home}"/bin/controller.sh ]
                    then
                        Log ".. starting Controller: ${controller_home}/bin/controller.sh start"

                        if [ -n "${log_file}" ] && [ -f "$|log_file{" ]
                        then
                            start_controller_output_file="/tmp/js7_install_controller_start_$$.tmp"
                            touch "${start_controller_output_file}"
                            ( "${controller_home}/bin/controller.sh" start > "${start_controller_output_file}" 2>&1 ) || ( LogError "$(cat ${start_controller_output_file})" && exit 5 )
                            Log "$(cat ${start_controller_output_file})"
                        else
                            "${controller_home}/bin/controller.sh" start
                        fi
                    else
                        LogError "could not start Controller, start script missing: ${controller_home}/bin/controller_instance.sh, ${controller_home}/bin/controller.sh"
                    fi
                fi
            else
                LogError "could not start Controller, directory missing: ${controller_home}/bin"
            fi
        fi
    fi
}

StopController()
{
    if [ -n "${exec_stop}" ]
    then
        Log ".. stopping Controller: ${exec_stop}"
        if [ "$(echo "${exec_stop}" | tr '[:upper:]' '[:lower:]')" = "stopservice" ]
        then
            StopService
        else
            ${exec_stop}
        fi
    else
        if [ -n "${restart_controller}" ]
        then
            if [ -n "${kill_controller}" ]
            then
                stop_option="kill"
            else
                if [ -n "${abort_controller}" ]
                then
                    stop_option="abort"
                else
                    stop_option="stop"
                fi
            fi
        
            if [ -n "$(GetPid)" ]
            then
                if [ -d "${controller_home}"/bin ]
                then
                    if [ -f "${controller_home}"/bin/controller_instance.sh ]
                    then
                        Log ".. stopping Controller: ${controller_home}/bin/controller_instance.sh ${stop_option}"

                        if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                        then
                            stop_controller_output_file="/tmp/js7_install_controller_stop_$$.tmp"
                            touch "${stop_controller_output_file}"
                            ( "${controller_home}/bin/controller_instance.sh" ${stop_option} > "${stop_controller_output_file}" 2>&1 ) || ( LogError "$(cat ${stop_controller_output_file})" && exit 6 )
                            Log "$(cat ${stop_controller_output_file})"
                        else
                            "${controller_home}/bin/controller_instance.sh" ${stop_option}
                        fi
                    else
                        if [ -f "${controller_home}"/bin/controller.sh ]
                        then
                            Log ".. stopping Controller: ${controller_home}/bin/controller.sh ${stop_option}"

                            if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                            then
                                stop_controller_output_file="/tmp/js7_install_controller_stop_$$.tmp"
                                touch "${stop_controller_output_file}"
                                ( "${controller_home}/bin/controller.sh" ${stop_option} > "${stop_controller_output_file}" 2>&1 ) || ( LogError "$(cat ${stop_controller_output_file})" && exit 6 )
                                Log "$(cat ${stop_controller_output_file})"
                            else
                                "${controller_home}/bin/controller.sh" ${stop_option}
                            fi
                        else
                            LogError "could not stop Controller, start script missing: ${controller_home}/bin/controller_instance.sh, ${controller_home}/bin/controller.sh"
                        fi
                    fi
                else
                    LogError "could not stop Controller, directory missing: ${controller_home}/bin"
                fi
            else
                Log ".. Controller not running"
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
            exit 7
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
            --home=*)               controller_home=$(echo "${option}" | sed 's/--home=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data=*)               controller_data=$(echo "${option}" | sed 's/--data=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --config=*)             controller_config=$(echo "${option}" | sed 's/--config=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --logs=*)               controller_logs=$(echo "${option}" | sed 's/--logs=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --user=*)               controller_user=$(echo "${option}" | sed 's/--user=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --home-owner=*)         home_owner=$(echo "${option}" | sed 's/--home-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data-owner=*)         data_owner=$(echo "${option}" | sed 's/--data-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-id=*)      controller_id=$(echo "${option}" | sed 's/--controller-id=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
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
            --exec-start=*)         exec_start=$(echo "${option}" | sed 's/--exec-start=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --exec-stop=*)          exec_stop=$(echo "${option}" | sed 's/--exec-stop=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --return-values=*)      return_values=$(echo "${option}" | sed 's/--return-values=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            # Configuration Options
            --deploy-dir=*)         deploy_dir=$(echo "${option}" | sed 's/--deploy-dir=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --controller-conf=*)    controller_conf=$(echo "${option}" | sed 's/--controller-conf=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --private-conf=*)       private_conf=$(echo "${option}" | sed 's/--private-conf=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-primary-cert=*)   controller_primary_cert=$(echo "${option}" | sed 's/--controller-primary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-secondary-cert=*) controller_secondary_cert=$(echo "${option}" | sed 's/--controller-secondary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-primary-subject=*)   controller_primary_subject=$(echo "${option}" | sed 's/--controller-primary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --controller-secondary-subject=*) controller_secondary_subject=$(echo "${option}" | sed 's/--controller-secondary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --joc-primary-cert=*)   joc_primary_cert=$(echo "${option}" | sed 's/--joc-primary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --joc-secondary-cert=*) joc_secondary_cert=$(echo "${option}" | sed 's/--joc-secondary-cert=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --joc-primary-subject=*)   joc_primary_subject=$(echo "${option}" | sed 's/--joc-primary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --joc-secondary-subject=*) joc_secondary_subject=$(echo "${option}" | sed 's/--joc-secondary-subject=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
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
            --active)               active_controller=1
                                    ;;
            --standby)              standby_controller=1
                                    ;;
            --no-install)           noinstall_controller=1
                                    ;;
            --uninstall)            uninstall_controller=1
                                    ;;
            --service-selinux)      systemd_service_selinux=1
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
            --restart)              restart_controller=1
                                    ;;
            --abort)                abort_controller=1
                                    ;;
            --kill)                 kill_controller=1
                                    ;;
            *)                      >&2 echo "unknown option: ${option}"
                                    Usage
                                    exit 1
                                    ;;
        esac
    done

    controller_home=$(GetDirectoryRealpath "${controller_home}")
    controller_data=$(GetDirectoryRealpath "${controller_data}")
    controller_config=$(GetDirectoryRealpath "${controller_config}")
    controller_logs=$(GetDirectoryRealpath "${controller_logs}")
    backup_dir=$(GetDirectoryRealpath "${backup_dir}")
    log_dir=$(GetDirectoryRealpath "${log_dir}")
    systemd_service_dir=$(GetDirectoryRealpath "${systemd_service_dir}")
    deploy_dir=$(GetDirectoryRealpath "${deploy_dir}")

    if [ -z "${controller_home}" ]
    then
        LogError "Controller home directory must be specified: --home="
        Usage
        exit 1
    fi

    if [ -n "${uninstall_controller}" ] && [ ! -d "${controller_home}" ]
    then
        LogError "Controller home directory not found and --uninstall switch is present: --home=${controller_home}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -z "${uninstall_controller}" ] && [ -n "${controller_home}" ] && [ ! -d "${controller_home}" ]
    then
        LogError "Controller home directory not found and -make-dirs switch not present: --home=${controller_home}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${controller_data}" ] && [ ! -d "${controller_data}" ]
    then
        LogError "Controller data directory not found and -make-dirs switch not present: --data=${controller_data}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${controller_config}" ] && [ ! -d "${controller_config}" ]
    then
        LogError "Controller configuration directory not found and --make-dirs switch not present: --config=${controller_config}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${controller_logs}" ] && [ ! -d "${controller_logs}" ]
    then
        LogError "Controller log directory not found and --make-dirs switch not present: --logs=${controller_logs}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${pid_file_dir}" ] && [ ! -d "${pid_file_dir}" ]
    then
        LogError "Controller PID file directory not found and --make-dirs switch not present: --pid-file-dir=${pid_file_dir}"
        Usage
        exit 1
    fi

    if [ -n "${deploy_dir}" ] && [ ! -d "${deploy_dir}" ]
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
        LogError "Backup directory not found and -make-dirs switch not present: --backup-dir=${backup_dir}"
        Usage
        exit 1
    fi

    if [ -z "${make_dirs}" ] && [ -n "${log_dir}" ] && [ ! -d "${log_dir}" ]
    then
        LogError "Log directory not found and -make-dirs switch not present: --log-dir=${log_dir}"
        Usage
        exit 1
    fi

    if [ -z "${release}" ] && [ -z "${tarball}" ] && [ -z "${patch_jar}" ] && [ -z "${uninstall_controller}" ] && [ -z "${noinstall_controller}" ]
    then
        LogError "Release must be specified if --tarball or -patch-jar options are not specified and --noinstall or --uninstall switches are not present: --release="
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

    if [ -n "${patch}" ] && [ ! -d "${controller_home}" ]
    then
        LogError "Controller home directory not found and --patch option is present: --home=${controller_home}"
        Usage
        exit 1
    fi

    if [ -n "${show_logs}" ]  && [ -z "${log_dir}" ]
    then
        LogError "Log directory not specified and -show-logs switch is present: --log-dir="
        Usage
        exit 1
    fi

    if [ -n "${instance_script}" ] && [ ! -f "${instance_script}" ]
    then
        LogError "Instance Start Script not found (*.sh): --instance-script=${instance_script}"
        Usage
        exit 1
    fi

    if [ -n "${java_home}" ] && [ ! -d "${java_home}" ]
    then
        LogError "Java Home directory not found: --java-home=${java_home}"
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

    if [ -n "${controller_conf}" ] && [ ! -f "${controller_conf}" ]
    then
        LogError "Controller configuration file not found (controller.conf): --controller-conf=${controller_conf}"
        Usage
        exit 1
    fi

    if [ -n "${private_conf}" ] && [ ! -f "${private_conf}" ]
    then
        LogError "Controller private configuration file not found (private.conf): --private-conf=${private_conf}"
        Usage
        exit 1
    fi

    if [ -n "${active_controller}" ] && [ -n "${standby_controller}" ]
    then
        LogError "Controller instance can be configured to be either active or standby, use --active or --standby"
        Usage
        exit 1
    fi

    if [ -n "${controller_primary_cert}" ] && [ ! -f "${controller_primary_cert}" ]
    then
        LogError "Primary Controller certificate file not found: --controller-primary-cert=${controller_primary_cert}"
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
        LogError "Only one of Primary Controller certificate file or subject can be specified: --controller-primary-cert=${controller_primary_cert} --controller-primary-subject=${controller_primary_subject}"
        Usage
        exit 1
    fi

    if [ -n "${controller_secondary_cert}" ] && [ -n "${controller_secondary_subject}" ]
    then
        LogError "Only one of Secondary Controller certificate file or subject can be specified: --controller-secondary-cert=${controller_secondary_cert} --controller-secondary-subject=${controller_secondary_subject}"
        Usage
        exit 1
    fi

    if [ -n "${joc_primary_cert}" ] && [ ! -f "${joc_primary_cert}" ]
    then
        LogError "Primary/Standalone JOC Cockpit certificate file not found: --joc-primary-cert=${joc_primary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${joc_secondary_cert}" ] && [ ! -f "${joc_secondary_cert}" ]
    then
        LogError "Secondary JOC Cockpit certificate file not found: --joc-secondary-cert=${joc_secondary_cert}"
        Usage
        exit 1
    fi

    if [ -n "${joc_primary_cert}" ] && [ -n "${joc_primary_subject}" ]
    then
        LogError "Only one of Primary JOC Cockpit certificate file or subject can be specified: --joc-primary-cert=${joc_primary_cert} --joc-primary-subject=${joc_primary_subject}"
        Usage
        exit 1
    fi

    if [ -n "${joc_secondary_cert}" ] && [ -n "${joc_secondary_subject}" ]
    then
        LogError "Only one of Secondary JOC Cockpit certificate file or subject can be specified: --joc-secondary-cert=${joc_secondary_cert} --joc-secondary-subject=${joc_secondary_subject}"
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

    if [ -n "${noinstall_controller}" ] && [ -n "${tarball}${release}" ]
    then
        LogError "--noinstall switch present and options --tarball or --release specified: --noinstall"
        Usage
        exit 1
    fi

    if [ -n "${uninstall_controller}" ] && [ -n "${tarball}${release}" ]
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

        log_file="${log_dir}"/install_js7_controller."${hostname}"."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/install_js7_controller."${hostname}"."${start_time}".log
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

    if [ -z "${controller_data}" ]
    then
        controller_data="${controller_home}/var"
    fi

    if [ -z "${controller_config}" ]
    then
        controller_config="${controller_data}/config"
    fi

    if [ -z "${controller_logs}" ]
    then
        controller_logs="${controller_data}/logs"
    fi

    controller_state="${controller_data}/state"

    if [ -n "${real_path_prefix}" ]
    then
        real_controller_home=${controller_home#"${real_path_prefix}"}
        real_controller_data=${controller_data#"${real_path_prefix}"}
        real_controller_config=${controller_config#"${real_path_prefix}"}
        real_controller_logs=${controller_logs#"${real_path_prefix}"}
    else
        real_controller_home="${controller_home}"
        real_controller_data="${controller_data}"
        real_controller_config="${controller_config}"
        real_controller_logs="${controller_logs}"
    fi

    systemd_service_name=${systemd_service_name:-js7_controller_${controller_id}.service}
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

            if [ -d "${controller_home}" ] && [ ! -w "${controller_home}" ]
            then
                use_forced_sudo="sudo"
            fi        

            if [ -d "${controller_data}" ] && [ ! -w "${controller_data}" ]
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
    if [ -n "${uninstall_controller}" ]
    then
        StopController

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

        if [ -d "${controller_home}" ]
        then
            Log ".... removing home directory: ${controller_home}"
            ${use_forced_sudo} rm -fr "${controller_home}"
        fi

        if [ -d "${controller_data}" ]
        then
            Log ".... removing data directory: ${controller_data}"
            ${use_forced_sudo} rm -fr "${controller_data}"
        fi

        if [ -d "${controller_config}" ]
        then
            Log ".... removing config directory: ${controller_config}"
            ${use_forced_sudo} rm -fr "${controller_config}"
        fi

        if [ -d "${controller_logs}" ]
        then
            Log ".... removing logs directory: ${controller_logs}"
            ${use_forced_sudo} rm -fr "${controller_logs}"
        fi

        exit
    fi

    # download tarball if required
    if [ -z "${tarball}" ] && [ -n "${release}" ] && [ -z "${noinstall_controller}" ]
    then
        release_major=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\1/')
        release_minor=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\2/')
        release_maint=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\3/')

        if [ -n "${patch}" ]
        then
            tarball="js7_controller.${release}-PATCH.${patch}.tar.gz"
            download_url="https://download.sos-berlin.com/patches/${release_major}.${release_minor}.${release_maint}-patch/${tarball}"
        else
            tarball="js7_controller_unix.${release}.tar.gz"

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
            curl_output_file="/tmp/js7_install_controller_curl_$$.tmp"
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
    if [ -n "${backup_dir}" ] && [ -d "${controller_home}" ]
    then

        if [ -n "${make_dirs}" ] && [ -n "${backup_dir}" ] && [ ! -d "${backup_dir}" ]
        then
            Log "Creating backup directory: ${backup_dir}"
            mkdir -p "${backup_dir}"
        fi

        if ${use_forced_sudo} test -f "${controller_home}"/.version
        then
            # check existing version
            version=$(awk -F "=" '/release/ {print $2}' "${controller_home}"/.version)
        else
            version="0.0.0"
        fi

        backup_file="${backup_dir}/backup_js7_controller.${hostname}.${version}.${start_time}.tar"
        Log ".. creating backup with file: ${backup_file}.gz"

        exclude_file=$(CreateExcludeFile "${controller_home}"/var)
        Log ".... using exclude file: ${exclude_file}"

        controller_home_parent_dir=$(dirname "${controller_home}")
        controller_home_basename=$(basename "${controller_home}")
        
        if [ -n "${os_compat}" ]
        then
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} -C ${controller_home_parent_dir} ${controller_home_basename}"
            tar -X "${exclude_file}" -cpf "${backup_file}" -C "${controller_home_parent_dir}" "${controller_home_basename}"
            gzip "${backup_file}"
        else
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} ${controller_home_basename}"
            (
                cd "${controller_home_parent_dir}" || exit 2
                tar -X "${exclude_file}" -cpf "${backup_file}" "${controller_home_basename}"
            )
            gzip "${backup_file}"
        fi

        # caller should capture the path to the zipped backup file
        backup_file="${backup_file}.gz"
    fi

    if [ -n "${tarball}" ]
    then
        # extract to temporary directory
        tar_dir="/tmp/js7_install_controller_$$.tmp"
        Log ".. extracting tarball to temporary directory: ${tar_dir}"
        mkdir -p "${tar_dir}"
        
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
    
        # check top-level folder inside extracted tarball
        tar_root=$(ls "${tar_dir}")
        if [ "$(echo "${tar_root}" | wc -l)" -ne 1 ]
        then
            LogError "tarball not usable, it includes more than one top-level folder: ${tar_root}"
            exit 2
        fi
    fi

    StopController

    if [ -n "${patch}" ]
    then
        if [ -n "${tarball}" ]
        then
            # do not overwrite an existing data directory
            if [ -d "${controller_data}"/state ]
            then
                rm -fr "${tar_dir:?}"/"${tar_root}"/var
            fi

            if [ ! -d "${controller_home}"/lib/patches ]
            then
                Log ".. creating patch directory: ${controller_home}/lib/patches"
                ${use_forced_sudo} mkdir -p "${controller_home}"/lib/patches
            fi

            # copy to Controller home directory
            ChangeOwner "${tar_dir}"/"${tar_root}"/. "${home_owner}" "${home_owner_group}"
            if [ -d "${tar_dir}"/"${tar_root}"/lib/patches ]
            then
                ${use_forced_sudo} chmod o-rwx "${tar_dir}"/"${tar_root}"/lib/patches/*
                ${use_forced_sudo} chmod ug-x  "${tar_dir}"/"${tar_root}"/lib/patches/*
            fi

            Log ".. copying files from extracted tarball directory: ${tar_dir}/${tar_root} to Controller home: ${controller_home}"
            ${use_forced_sudo} cp -R "${tar_dir}"/"${tar_root}"/. "${controller_home}"
        else
            if [ -n "${patch_jar}" ]
            then
                if [ ! -d "${controller_home}"/lib/patches ]
                then
                    Log ".. creating patch directory: ${controller_home}/lib/patches"
                    ${use_forced_sudo} mkdir -p "${controller_home}"/lib/patches
                fi

                if [ -f "${controller_home}"/lib/patches/"$(basename "${patch_jar}")" ]
                then
                    ${use_forced_sudo} rm -f "${controller_home}"/lib/patches/"$(basename "${patch_jar}")"
                fi

                Log ".. copying patch file: ${patch_jar} to Controller patch directory: ${controller_home}/lib/patches"
                ${use_forced_sudo} cp -p "${patch_jar}" "${controller_home}"/lib/patches/
                ChangeOwner "${controller_home}/lib/patches/*" "${home_owner}" "${home_owner_group}"
                ${use_forced_sudo} chmod o-rwx "${controller_home}"/lib/patches/"$(basename "${patch_jar}")"
                ${use_forced_sudo} chmod ug-x  "${controller_home}"/lib/patches/"$(basename "${patch_jar}")"
            fi
        fi

        StartController
        return_code=0
        exit
    fi

    # create Controller home directory if required
    if [ ! -d "${controller_home}" ] && [ -n "${make_dirs}" ]
    then
        Log ".. creating Controller home directory: ${controller_home}"
        if [ -n "${use_forced_sudo}" ]
        then
            ${use_forced_sudo} sh -c "umask 0002; mkdir -p \"${controller_home}\""
        else
            ${use_forced_sudo} mkdir -p "${controller_home}"
        fi
    fi

    # create Controller data directory if required
    if [ ! -d "${controller_data}" ] && [ -n "${make_dirs}" ]
    then
        Log ".. creating Controller data directory: ${controller_data}"
        if [ -n "${use_forced_sudo}" ]
        then
            ${use_forced_sudo} sh -c "umask 0002; mkdir -p \"${controller_data}\""
        else
            ${use_forced_sudo} mkdir -p "${controller_data}"
        fi
    fi

    # remove the Controller's journal if requested
    if [ -n "${remove_journal}" ]
    then
        if [ -d "${controller_data}"/state ]
        then
            Log ".. removing Controller journal from directory: ${controller_data}/state/*"
            ${use_forced_sudo} sh -c "rm -fr ${controller_data}/state/*"
        fi
    fi

    # preserve the Controller's lib/user_lib directory
    if [ -d "${controller_home}"/lib/user_lib ] && [ -n "$(ls -A "${controller_home}"/lib/user_lib)" ] && [ -z "${patch}" ]  && [ -z "${noinstall_controller}" ]
    then
        Log ".. copying files to extracted tarball directory: ${tar_dir}/${tar_root}/ from Controller home: ${controller_home}/lib/user_lib"
        ${use_forced_sudo} cp -p -R "${controller_home}"/lib/user_lib "${tar_dir}"/"${tar_root}"/lib/
    fi

    # remove patches from the Controller's patches directory
    if [ -d "${controller_home}"/lib/patches ] && [ -z "${patch}" ] && [ -z "${noinstall_controller}" ]
    then
        Log ".. removing patches from Controller patch directory: ${controller_home}/lib/patches"
        ${use_forced_sudo} sh -c "rm -fr ${controller_home}/lib/patches/*"
    fi

    # move or remove the Controller's lib directory
    if [ -d "${controller_home}"/lib ] && [ -z "${patch}" ] && [ -z "${noinstall_controller}" ]
    then
        if [ -z "${move_libs}" ]
        then
            ${use_forced_sudo} rm -fr "${controller_home:?}"/lib
        else
            # check existing version and lib directory copies
            if [ -f "${controller_home}"/.version ]
            then
                version=$(awk -F "=" '/release/ {print $2}' "${controller_home}"/.version)
            else
                version="0.0.0"
            fi
    
            while [ -d "${controller_home}/lib.${version}" ]
            do
                version="${version}-1"
            done

            Log ".. moving directory ${controller_home}/lib to: ${controller_home}/lib.${version}"
            ${use_forced_sudo} mv "${controller_home}"/lib "${controller_home}"/lib."${version}"
        fi
    fi

    if [ -n "${tarball}" ]
    then
        # do not overwrite an existing data directory
        if [ -d "${controller_data}"/state ]
        then
            ${use_forced_sudo} rm -fr "${tar_dir:?}"/"${tar_root}"/var
        fi

        # copy to Controller home directory
        ChangeOwner "${tar_dir}"/"${tar_root}"/. "${home_owner}" "${home_owner_group}"
        Log ".. copying files from extracted tarball directory: ${tar_dir}/${tar_root} to Controller home: ${controller_home}"
        ${use_forced_sudo} cp -p -R "${tar_dir}"/"${tar_root}"/. "${controller_home}"
    fi

    # populate Controller data directory from configuration files and certificates
    if [ -z "${noinstall_controller}" ] && [ -z "${patch}" ] 
    then
        if [ ! -d "${controller_data}"/config ] && [ ! -d "${controller_data}"/state ]
        then
            Log ".. creating Controller data directory: ${controller_data}"
            ${use_forced_sudo} mkdir -p "${controller_data}"
        fi

        # copy to Controller data directory
        if [ "${controller_home}"/var != "${controller_data}" ] && [ ! -d "${controller_data}"/state ]
        then
            ${use_forced_sudo} sh -c "mv -f ${controller_home}/var/* ${controller_data}/"
            ${use_forced_sudo} rm -fr "${controller_home:?}"/var
        fi

        if [ ! -f "${controller_config}"/controller.conf-example ] && [ -f "${controller_home}"/var/config/controller.conf-example ]
        then
            Log ".. copying controller.conf-example to Controller config directory: ${controller_config}"
            ${use_forced_sudo} cp -p "${controller_home}"/var/config/controller.conf-example "${controller_config}"/
        fi
    fi

    if [ -n "${license_key}" ]
    then
        download_target="${controller_home}/lib/user_lib/js7-license.jar"
        
        if [ ! -d "${controller_home}"/lib/user_lib ]
        then
            ${use_forced_sudo} mkdir -p "${controller_home}"/lib/user_lib
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
                curl_output_file_license="/tmp/js7_install_controller_license_$$.tmp"
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

        if [ -n "${controller_data}" ]
        then
            if [ ! -d "${controller_data}"/config/license ]
            then
                ${use_forced_sudo} mkdir -p "${controller_data}"/config/license
            fi

            Log ".. copying license key file to: ${controller_data}/config/license/"
            ${use_forced_sudo} cp -p "${license_key}" "${controller_data}"/config/license/
        else
            if [ ! -d "${controller_home}"/var/config/license ]
            then
                ${use_forced_sudo} mkdir -p "${controller_home}"/var/config/license
            fi

            Log ".. copying license key file to: ${controller_home}/var/config/license/"
            ${use_forced_sudo} cp -p "${license_key}" "${controller_home}"/var/config/license/
        fi
    else
        if [ -n "${license_bin}" ]
        then
            download_target="${controller_home}/lib/user_lib/js7-license.jar"
        
            if [ ! -d "${controller_home}"/lib/user_lib ]
            then
                ${use_forced_sudo} mkdir -p "${controller_home}"/lib/user_lib
            fi

            Log ".. copying license binary file from: ${license_bin} to ${download_target}"
            ${use_forced_sudo} cp -p "${license_bin}" "${download_target}"
        fi
    fi

    if [ ! -d "${controller_config}"/private ]
    then
        ${use_forced_sudo} mkdir -p "${controller_config}"/private
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
                Log ".. deploying configuration from ${i} to Controller configuration directory: ${controller_config}/"
                ${use_forced_sudo} cp -p -R "${i}"/. "${controller_config}"/
            fi
        done
    fi

    # copy instance start script
    if [ -z "${instance_script}" ]
    then
        use_instance_script="${controller_home}"/bin/controller_instance.sh
        if [ -z "${noinstall_controller}" ] && ! ${use_forced_sudo} test -f "${use_instance_script}" && ${use_forced_sudo} test -f "${controller_home}"/bin/controller_instance.sh-example
        then
            Log ".. copying ${controller_home}/bin/controller_instance.sh-example to ${use_instance_script}"
            ${use_forced_sudo} cp -p "${controller_home}"/bin/controller_instance.sh-example "${use_instance_script}"
        fi
    else
        use_instance_script="${controller_home}"/bin/$(basename "${instance_script}")
        Log ".. copying ${instance_script} to ${use_instance_script}"
        ${use_forced_sudo} cp -p "${instance_script}" "${use_instance_script}"
    fi

    # copy systemd service file
    use_service_file="${controller_home}"/bin/controller.service
    if [ -z "${systemd_service_file}" ]
    then
        if [ -z "${noinstall_controller}" ] && ${use_forced_sudo} test -f "${controller_home}"/bin/controller.service-example
        then
            Log ".. copying ${controller_home}/bin/controller.service-example to ${use_service_file}"
            ${use_forced_sudo} cp -p "${controller_home}"/bin/controller.service-example "${use_service_file}"
        fi
    else
        Log ".. copying ${systemd_service_file} to ${use_service_file}"
        ${use_forced_sudo} cp -p "${systemd_service_file}" "${use_service_file}"
    fi

    # copy controller.conf
    if [ -n "${controller_conf}" ]
    then
        if [ ! -d "${controller_config}" ]
        then
            ${use_forced_sudo} mkdir -p "${controller_config}"
        fi
        Log ".. copying Controller configuration ${controller_conf} to ${controller_config}/controller.conf"
        ${use_forced_sudo} cp -p "${controller_conf}" "${controller_config}"/controller.conf
    else
        if ! ${use_forced_sudo} test -f "${controller_config}"/controller.conf
        then
            if ${use_forced_sudo} test -f "${controller_config}"/controller.conf-example
            then
                ${use_forced_sudo} cp -p "${controller_config}"/controller.conf-example "${controller_config}"/controller.conf
            else
            ls -a "${controller_config}"/controller.conf-example
                LogError "could not find file ${controller_config}/controller.conf-example to provide controller.conf"
                exit 8
            fi
        fi    
    fi

    # copy private.conf
    if [ -n "${private_conf}" ]
    then
        if [ ! -d "${controller_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${controller_config}"/private
        fi
        Log ".. copying Controller private configuration ${private_conf} to ${controller_config}/private/private.conf"
        ${use_forced_sudo} cp -p "${private_conf}" "${controller_config}"/private/private.conf
    fi

    # copy keystore
    if [ -n "${keystore_file}" ]
    then
        if [ ! -d "${controller_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${controller_config}"/private
        fi
        use_keystore_file="${controller_config}"/private/$(basename "${keystore_file}")
        Log ".. copying keystore file ${keystore_file} to ${use_keystore_file}"
        ${use_forced_sudo} cp -p "${keystore_file}" "${use_keystore_file}"
    fi

    # copy client keystore
    if [ -n "${client_keystore_file}" ]
    then
        if [ ! -d "${controller_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${controller_config}"/private
        fi
        use_client_keystore_file="${controller_config}"/private/$(basename "${client_keystore_file}")
        Log ".. copying client keystore file ${client_keystore_file} to ${use_client_keystore_file}"
        ${use_forced_sudo} cp -p "${client_keystore_file}" "${use_client_keystore_file}"
    fi

    # copy truststore
    if [ -n "${truststore_file}" ]
    then
        if [ ! -d "${controller_config}"/private ]
        then
            ${use_forced_sudo} mkdir -p "${controller_config}"/private
        fi
        use_truststore_file="${controller_config}"/private/$(basename "${truststore_file}")
        Log ".. copying truststore file ${truststore_file} to ${use_truststore_file}"
        ${use_forced_sudo} cp -p "${truststore_file}" "${use_truststore_file}"
    fi

    # update configuration items

    # update instance start script
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_instance_script}" && [ -z "${noinstall_controller}" ]
    then
        Log ".. updating Controller Intance Start Script: ${use_instance_script}"
        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HOME=.*/$(echo "JS7_CONTROLLER_HOME=${real_controller_home}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"

        if [ -z "${controller_id}" ]
        then
            if ${use_forced_sudo} test -f "${controller_home}"/bin/controller_instance.sh
            then
                controller_id=$(grep -E '^JS7_CONTROLLER_ID=' "${use_instance_script}" | cut -d = -f 2)
            fi

            if [ -z "${controller_id}" ]
            then
                controller_id="controller"
            fi
        fi

        ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_ID=.*/$(echo "JS7_CONTROLLER_ID=${controller_id}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"

        if [ -n "${controller_user}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_USER=.*/JS7_CONTROLLER_USER=${controller_user}/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_USER=.*/# JS7_CONTROLLER_USER=/g" "${use_instance_script}"
        fi

        if [ -n "${http_port}" ]
        then
            if [ -n "${http_network_interface}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTP_PORT=.*/JS7_CONTROLLER_HTTP_PORT=${http_network_interface}:${http_port}/g" "${use_instance_script}"
            else
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTP_PORT=.*/JS7_CONTROLLER_HTTP_PORT=${http_port}/g" "${use_instance_script}"
            fi
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTP_PORT=.*/# JS7_CONTROLLER_HTTP_PORT=/g" "${use_instance_script}"
        fi

        if [ -n "${https_port}" ]
        then
            if [ -n "${https_network_interface}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTPS_PORT=.*/JS7_CONTROLLER_HTTPS_PORT=${https_network_interface}:${https_port}/g" "${use_instance_script}"
            else
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTPS_PORT=.*/JS7_CONTROLLER_HTTPS_PORT=${https_port}/g" "${use_instance_script}"
            fi
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_HTTPS_PORT=.*/# JS7_CONTROLLER_HTTPS_PORT=/g" "${use_instance_script}"
        fi

        if [ -n "${controller_data}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_DATA=.*/$(echo "JS7_CONTROLLER_DATA=${real_controller_data}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_DATA=.*/# JS7_CONTROLLER_DATA=/g" "${use_instance_script}"
        fi
        
        if [ -n "${controller_config}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_CONFIG_DIR=.*/$(echo "JS7_CONTROLLER_CONFIG_DIR=${real_controller_config}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_CONFIG_DIR=.*/# JS7_CONTROLLER_CONFIG_DIR=/g" "${use_instance_script}"
        fi
        
        if [ -n "${controller_logs}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_LOGS=.*/$(echo "JS7_CONTROLLER_LOGS=${real_controller_logs}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_LOGS=.*/# JS7_CONTROLLER_LOGS=/g" "${use_instance_script}"
        fi
        
        if [ -n "${pid_file_dir}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_PID_FILE_DIR=.*/$(echo "JS7_CONTROLLER_PID_FILE_DIR=${pid_file_dir}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_PID_FILE_DIR=.*/# JS7_CONTROLLER_PID_FILE_DIR=/g" "${use_instance_script}"
        fi

        if [ -n "${pid_file_name}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_PID_FILE_NAME=.*/JS7_CONTROLLER_PID_FILE_NAME=${pid_file_name}/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JS7_CONTROLLER_PID_FILE_NAME=.*/# JS7_CONTROLLER_PID_FILE_NAME=/g" "${use_instance_script}"
        fi

        if [ -n "${java_home}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_HOME=.*/$(echo "JAVA_HOME=${java_home}" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_HOME=.*/# JAVA_HOME=/g" "${use_instance_script}"
        fi

        if [ -n "${java_options}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_OPTIONS=.*/$(echo "JAVA_OPTIONS=\"${java_options}\"" | sed -e 's@/@\\\/@g')/g" "${use_instance_script}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*JAVA_OPTIONS=.*/# JAVA_OPTIONS=/g" "${use_instance_script}"
        fi
    fi

    # update systemd service file
    if [ -z "${systemd_service_file}" ] && [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_service_file}" && [ -z "${noinstall_controller}" ]
    then
        Log ".. updating Controller systemd service file: ${use_service_file}"

        if [ -z "${controller_id}" ]
        then
            controller_id=$(grep -E '^JS7_CONTROLLER_ID=' "${controller_home}"/bin/controller_instance.sh | cut -d = -f 2)

            if [ -z "${controller_id}" ]
            then
                controller_id="controller"
            fi
        fi

        ${use_forced_sudo} sed -i'' -e "s/<JS7_CONTROLLER_ID>/${controller_id}/g" "${use_service_file}"
        ${use_forced_sudo} sed -i'' -e "s/<JS7_CONTROLLER_HTTP_PORT>/${http_port}/g" "${use_service_file}"

        use_pid_file_name=${pid_file_name:-controller.pid}

        if [ -n "${pid_file_dir}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/<JS7_CONTROLLER_PID_FILE_DIR>/$(echo "${pid_file_dir}" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^PIDFile[ ]*=[ ]*.*/PIDFile=$(echo "${pid_file_dir}" | sed -e 's@/@\\\/@g')\/${use_pid_file_name}/g" "${use_service_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/<JS7_CONTROLLER_PID_FILE_DIR>/$(echo "${real_controller_logs}" | sed -e 's@\/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^PIDFile[ ]*=[ ]*.*/PIDFile=$(echo "${real_controller_logs}" | sed -e 's@/@\\\/@g')\/${use_pid_file_name}/g" "${use_service_file}"
        fi

        ${use_forced_sudo} sed -i'' -e "s/<JS7_CONTROLLER_USER>/${controller_user}/g" "${use_service_file}"
        ${use_forced_sudo} sed -i'' -e "s/^User[ ]*=[ ]*.*/User=${controller_user}/g" "${use_service_file}"
        ${use_forced_sudo} sed -i'' -e "s/<INSTALL_PATH>/$(echo "${real_controller_home}" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"

        if [ -n "${systemd_service_selinux}" ]
        then
            line_no=$(< "${use_service_file}" sed -n '/^ExecStart/{=;q;}')
            if [ -n "${line_no}" ] && [ "${line_no}" -gt 0 ]
            then
                if [ -n "${pid_file_dir}" ]
                then
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${controller_user} ${pid_file_dir}" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${pid_file_dir}" "${use_service_file}"
                else
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${controller_user} ${real_controller_logs}" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${real_controller_logs}" "${use_service_file}"
                fi
            fi

            ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "/bin/sh -c \"${real_controller_home}/bin/controller_instance.sh start\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "/bin/sh -c \"${real_controller_home}/bin/controller_instance.sh stop\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "/bin/sh -c \"${real_controller_home}/bin/controller_instance.sh restart\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "${real_controller_home}/bin/controller_instance.sh start" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "${real_controller_home}/bin/controller_instance.sh stop" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "${real_controller_home}/bin/controller_instance.sh restart" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
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

    # make systemd service
    if [ -n "${make_service}" ]
    then
        MakeService "${use_service_file}"
    fi

    # update controller.conf
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${controller_config}"/controller.conf
    then
        if [ -n "${standby_controller}" ]
        then
            Log ".. updating Controller configuration to backup node: ${controller_config}/controller.conf"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*/js7.journal.cluster.node.is-backup = yes/g" "${controller_config}"/controller.conf
        else
            if [ -n "${active_controller}" ]
            then
                Log ".. updating Controller configuration to active node: ${controller_config}/controller.conf"
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*/js7.journal.cluster.node.is-backup = no/g" "${controller_config}"/controller.conf
            fi
        fi
    fi

    # update private.conf
    if [ -n "${os_compat}" ] && [ -n "${private_conf}${deploy_dir}" ] && ${use_forced_sudo} test -f "${controller_config}"/private/private.conf
    then
        Log ".. updating Controller configuration: ${controller_config}/private/private.conf"

        if [ -n "${controller_id}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/{{controller-id}}/${controller_id}/g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${controller_primary_subject}" ]
        then
            Log ".... updating Primary Controller distinguished name: ${controller_primary_subject}"

            if [ -n "${controller_secondary_subject}" ] || [ -n "${controller_secondary_cert}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}/$(echo "${controller_primary_subject}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            else
                ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}\",/$(echo "${controller_primary_subject}\"" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            fi
        fi

        if [ -n "${controller_secondary_subject}" ]
        then
            Log ".... updating Secondary Controller distinguished name: ${controller_secondary_subject}"
            ${use_forced_sudo} sed -i'' -e "s/{{controller-secondary-distinguished-name}}/$(echo "${controller_secondary_subject}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
        fi

        dn=""
        if [ -n "${controller_primary_cert}" ] && ${use_forced_sudo} test -f "${controller_primary_cert}"
        then
            dn=$(openssl x509 -in "${controller_primary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            Log ".... updating Primary Controller distinguished name: ${dn}"
            if [ -n "${controller_secondary_cert}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            else
                ${use_forced_sudo} sed -i'' -e "s/{{controller-primary-distinguished-name}}\",/$(echo "${dn}\"" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            fi
        else
            ${use_forced_sudo} sed -i'' -e "s/\"{{controller-primary-distinguished-name}}\",//g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${controller_secondary_cert}" ] && ${use_forced_sudo} test -f "${controller_secondary_cert}"
        then
            dn=$(openssl x509 -in "${controller_secondary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            Log ".... updating Secondary Controller distinguished name: ${dn}"
            ${use_forced_sudo} sed -i'' -e "s/{{controller-secondary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
        else
            ${use_forced_sudo} sed -i'' -e "s/\"{{controller-secondary-distinguished-name}}\"//g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${joc_primary_subject}" ]
        then
            Log ".... updating Primary/Standalone JOC Cockpit distinguished name: ${joc_primary_subject}"

            if [ -n "${joc_secondary_subject}" ] || [ -n "${joc_secondary_cert}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{joc-primary-distinguished-name}}/$(echo "${joc_primary_subject}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            else
                ${use_forced_sudo} sed -i'' -e "s/{{joc-primary-distinguished-name}}\",/$(echo "${joc_primary_subject}\"" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            fi
        fi

        if [ -n "${joc_secondary_subject}" ]
        then
            Log ".... updating Secondary JOC Cockpit distinguished name: ${joc_secondary_subject}"
            ${use_forced_sudo} sed -i'' -e "s/{{joc-secondary-distinguished-name}}/$(echo "${joc_secondary_subject}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
        fi

        dn=""
        if [ -n "${joc_primary_cert}" ] && ${use_forced_sudo} test -f "${joc_primary_cert}"
        then
            dn=$(openssl x509 -in "${joc_primary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            Log ".... updating Primary/Standalone JOC Cockpit distinguished name: ${dn}"
            if [ -n "${joc_secondary_cert}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{joc-primary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            else
                ${use_forced_sudo} sed -i'' -e "s/{{joc-primary-distinguished-name}}\",/$(echo "${dn}\"" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
            fi
        else
            ${use_forced_sudo} sed -i'' -e "s/\"{{joc-primary-distinguished-name}}\",//g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${joc_secondary_cert}" ] && ${use_forced_sudo} test -f "${joc_secondary_cert}"
        then
            dn=$(openssl x509 -in "${joc_secondary_cert}" -noout -nameopt RFC2253 -subject)
            dn=${dn#"subject:"}
            dn=${dn#"subject="}
            dn=${dn#" "}

            Log ".... updating Secondary JOC Cockpit distinguished name: ${dn}"
            ${use_forced_sudo} sed -i'' -e "s/{{joc-secondary-distinguished-name}}/$(echo "${dn}" | sed -e 's@/@\\\/@g')/g" "${controller_config}"/private/private.conf
        else
            ${use_forced_sudo} sed -i'' -e "s/\"{{joc-secondary-distinguished-name}}\"//g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${keystore_file}" ] && ${use_forced_sudo} test -f "${keystore_file}"
        then
            Log ".... updating keystore file name: $(basename "${keystore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/{{keystore-file}}/$(basename "${keystore_file}")/g" "${controller_config}"/private/private.conf
            if [ -z "${client_keystore_file}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-file}}/$(basename "${keystore_file}")/g" "${controller_config}"/private/private.conf
            fi
        fi

        if [ -n "${keystore_password}" ]
        then
            Log ".... updating keystore password"
            ${use_forced_sudo} sed -i'' -e "s/{{keystore-password}}/${keystore_password}/g" "${controller_config}"/private/private.conf
            if [ -z "${client_keystore_password}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-password}}/${keystore_password}/g" "${controller_config}"/private/private.conf
            fi
        fi

        if [ -n "${keystore_alias}" ]
        then
            Log ".... updating keystore alias name for key: ${keystore_alias}"
            ${use_forced_sudo} sed -i'' -e  "s/#* *alias=\"{{keystore-alias}}\"/alias=\"{{keystore-alias}}\"/g" "${controller_config}"/private/private.conf
            ${use_forced_sudo} sed -i'' -e "s/{{keystore-alias}}/${keystore_alias}/g" "${controller_config}"/private/private.conf

            if [ -z "${client_keystore_alias}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/#* *alias=\"{{client-keystore-alias}}\"/alias=\"{{client-keystore-alias}}\"/g" "${controller_config}"/private/private.conf
                ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-alias}}/${keystore_alias}/g" "${controller_config}"/private/private.conf
            fi
        fi

        if [ -n "${client_keystore_file}" ] && ${use_forced_sudo} test -f "${client_keystore_file}"
        then
            Log ".... updating client keystore file name: $(basename "${client_keystore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-file}}/$(basename "${client_keystore_file}")/g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${client_keystore_password}" ]
        then
            Log ".... updating client keystore password"
            ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-password}}/${client_keystore_password}/g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${client_keystore_alias}" ]
        then
            Log ".... updating client keystore alias name for key: ${client_keystore_alias}"
            ${use_forced_sudo} sed -i'' -e "s/#* *alias=\"{{client-keystore-alias}}\"/alias=\"{{client-keystore-alias}}\"/g" "${controller_config}"/private/private.conf
            ${use_forced_sudo} sed -i'' -e "s/{{client-keystore-alias}}/${client_keystore_alias}/g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${truststore_file}" ] && ${use_forced_sudo} test -f "${truststore_file}"
        then
            Log ".... updating truststore file name: $(basename "${truststore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/{{truststore-file}}/$(basename "${truststore_file}")/g" "${controller_config}"/private/private.conf
        fi

        if [ -n "${truststore_password}" ]
        then
            Log ".... updating truststore password"
            ${use_forced_sudo} sed -i'' -e "s/{{truststore-password}}/${truststore_password}/g" "${controller_config}"/private/private.conf
        fi

        ${use_forced_sudo} sed -i'' -e "s/{{.*}}//g" "${controller_config}"/private/private.conf
    fi

    if [ -n "${controller_home}" ] && [ -n "${home_owner}" ]
    then
        ChangeOwner "${controller_home}" "${home_owner}" "${home_owner_group}"
    fi

    if [ -n "${controller_data}" ] && [ -n "${data_owner}" ]
    then
        ChangeOwner "${controller_data}"  "${data_owner}" "${data_owner_group}"
        ChangeOwner "${controller_logs}"  "${controller_user}"
        ChangeOwner "${controller_state}" "${controller_user}"
    fi

    StartController
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

    if [ -n "${curl_output_file_license}" ] && [ -f "${curl_output_file_license}" ]
    then
        # Log ".. removing temporary file: ${curl_output_file_license}"
        rm -f "${curl_output_file_license}"
    fi

    if [ -n "${exclude_file}" ] && [ -f "${exclude_file}" ]
    then
        # Log ".. removing temporary file: ${exclude_file}"
        rm -f "${exclude_file}"
    fi

    if [ -n "${start_controller_output_file}" ] && [ -f "${start_controller_output_file}" ]
    then
        # Log ".. removing temporary file: ${start_controller_output_file}"
        rm -f "${start_controller_output_file}"
    fi

    if [ -n "${stop_controller_output_file}" ] && [ -f "${stop_controller_output_file}" ]
    then
        # Log ".. removing temporary file: ${stop_controller_output_file}"
        rm -f "${stop_controller_output_file}"
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

    unset abort_controller
    unset real_path_prefix
    unset controller_home
    unset controller_data
    unset controller_config
    unset controller_logs
    unset controller_id
    unset controller_user
    unset home_owner
    unset home_owner_group
    unset data_owner
    unset data_owner_group
    unset force_sudo

    unset standby_controller
    unset active_controller
    unset backup_dir
    unset deploy_dir
    unset exec_start
    unset exec_stop
    unset http_port
    unset http_network_interface
    unset https_port
    unset https_network_interface
    unset pid_file_dir
    unset pid_file_name
    unset uninstall_controller
    unset noinstall_controller
    unset java_home
    unset java_options
    unset instance_script
    unset systemd_service_dir
    unset systemd_service_file
    unset systemd_service_name
    unset controller_conf
    unset private_conf
    unset controller_primary_cert
    unset controller_secondary_cert
    unset controller_primary_subject
    unset controller_secondary_subject
    unset joc_primary_cert
    unset joc_secondary_cert
    unset joc_primary_subject
    unset joc_secondary_subject

    unset keystore_file
    unset keystore_alias
    unset keystore_password
    unset client_keystore_file
    unset client_keystore_alias
    unset client_keystore_password
    unset truststore_file
    unset truststore_password

    unset kill_controller
    unset license_key
    unset license_bin
    unset log_dir
    unset make_dirs
    unset make_service
    unset move_libs
    unset patch
    unset patch_jar
    unset release
    unset remove_journal
    unset restart_controller
    unset return_values
    unset show_logs
    unset tarball

    unset backup_file
    unset download_url
    unset download_target
    unset exclude_file
    unset hostname
    unset log_file
    unset release_major
    unset release_minor
    unset release_maint
    unset return_code
    unset start_controller_output_file
    unset start_time
    unset stop_controller_output_file
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
