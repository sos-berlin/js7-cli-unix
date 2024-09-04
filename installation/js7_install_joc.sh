#!/bin/sh

# ------------------------------------------------------------
# Company:  Software- und Organisations-Service GmbH
# Date:     2023-06-17
# Purpose:  download and extract JS7 JOC Cockpit, take backups and restart
# Platform: AIX, Linux, MacOS: bash, ksh, zsh, dash
# ------------------------------------------------------------
#
# Example:  ./js7_install_joc.sh --release=2.5.3 --setup-response="/home/sos/joc.response/joc_install.xml" --make-dirs 
#
#           downloads the indicated JOC Cockpit release and extracts the installer to the specified JOC Cockpit setup directory
#           runs the installer with the specified response file
#
# Example:  ./js7_install_joc.sh --tarball=/mnt/releases/scheduler_setups/2.5.3/js7_joc_linux.2.5.3.tar.gz --setup-response="/home/sos/joc.response/joc_install.xml"
#
#           extracts the installer tarball to the specified JOC Cockpit setup directory
#           runs the installer with the specified response file
#
# Example:  ./js7_install_joc.sh --tarball=/mnt/releases/scheduler_setups/2.5.3/js7_joc_linux.2.5.3.tar.gz --setup-response="/home/sos/joc.response/joc_install.xml" --restart
#
#           extracts the installer tarball to the specified JOC Cockpit setup directory
#           stops a running JOC Cockpit instance, runs the installer with the specified response file and starts JOC Cockpit
#
# Example:  ./js7_install_joc.sh --home=/home/sos/joc --tarball=./js7_joc.2.5.3-PATCH.API-1.JS-1984.tar.gz --patch=JS-1984 --patch-key=API-1 --restart
#
#           extracts the patch tarball to the specified JOC Cockpit home directory
#           stops a running JOC Cockpit instance, applies the patch and starts JOC Cockpit

set -e

# ------------------------------
# Initialize variables
# ------------------------------

real_path_prefix=
as_user=
as_api_server=
backup_dir=
deploy_dir=
exec_start=
exec_stop=
http_port=
http_port_default=4446
http_network_interface=
https_port=
https_network_interface=
java_home=
java_options=
systemd_service_dir=/usr/lib/systemd/system
systemd_service_file=
systemd_service_name=
systemd_service_selinux=
systemd_service_stop_timeout=60
uninstall_joc=
noinstall_joc=
noconfig_joc=
java_bin=
joc_home=
joc_data=
joc_cluster_id="joc"
joc_instance_id=0
joc_user=
home_owner=
home_owner_group=
data_owner=
data_owner_group=
force_sudo=
joc_security_level=
joc_hibernate_file=
joc_create_tables=
joc_jdbc_driver=
joc_title=
joc_ini=
joc_properties=
logo_file=
logo_height=
logo_position=
no_jetty=
keystore_file=
keystore_alias=
keystore_password=
client_keystore_file=
client_keystore_alias=
client_keystore_password=
truststore_file=
truststore_password=
cancel_joc=
license_key=
license_bin=
log_dir=
make_dirs=
make_service=
patch=
patch_key=
patch_jar=
port=
preserve_env=
release=
restart_joc=
return_values=
setup_dir=
tmp_setup_dir=
response_dir=
show_logs=
tarball=

backup_file=
base_dir=
command=
curl_output_file=
download_url=
exclude_file=
home_dir=
hostname=$(hostname)
log_file=
pid_file=
release_major=
release_minor=
release_maint=
return_code=-1
start_joc_output_file=
start_time=$(date +"%Y-%m-%dT%H-%M-%S")
stop_joc_output_file=
stop_option=
tar_dir=

Usage()
{
    >&2 echo ""
    >&2 echo "Usage: $(basename "$0") [Options] [Switches]"
    >&2 echo ""
    >&2 echo "  Installation Options:"
    >&2 echo "    --setup-dir=<directory>            | optional: directory to which the JOC Cockpit installer will be extracted"
    >&2 echo "    --response-dir=<directory>         | optional: setup response directory holds joc_install.xml and JDBC Drivers"
    >&2 echo "    --release=<release-number>         | optional: release number such as 2.2.3 for download if --tarball is not used"
    >&2 echo "    --tarball=<tar-gz-archive>         | optional: the path to a .tar.gz archive that holds the JOC Cockpit tarball,"
    >&2 echo "                                       |           if not specified the JOC Cockpit tarball will be downloaded from the SOS web site"
    >&2 echo "    --home=<directory>                 | optional: home directory of JOC Cockpit"
    >&2 echo "    --data=<directory>                 | optional: data directory of JOC Cockpit"
    >&2 echo "    --cluster-id=<identifier>          | optional: Cluster ID of the JOC Cockpit instance, default: joc"
    >&2 echo "    --instance-id=<number>             | optional: unique number of a JOC Cockpit instance in a cluster, range 0 to 99, default: 0"
    >&2 echo "    --user=<account>                   | optional: user account for JOC Cockpit service, default: current user"
    >&2 echo "    --home-owner=<account[:group]>     | optional: account and optionally group owning the home directory, requires root or sudo permissions"
    >&2 echo "    --data-owner=<account[:group]>     | optional: account and optionally group owning the data directory, requires root or sudo permissions"
    >&2 echo "    --patch=<issue-key>                | optional: identifies a patch from a Change Management issue key"
    >&2 echo "    --patch-key=<identifier>           | optional: specifies the patch type API or GUI and running number, API-1, API-2 etc."
    >&2 echo "    --patch-jar=<jar-file>             | optional: the path to a .jar file that holds the patch"
    >&2 echo "    --license-key=<key-file>           | optional: specifies the path to a license key file that will be installed"
    >&2 echo "    --license-bin=<binary-file>        | optional: specifies the path to the js7-license.jar binary file for licensed code to be installed"
    >&2 echo "                                       |           if not specified the file will be downloaded from the SOS web site"
    >&2 echo "    --backup-dir=<directory>           | optional: backup directory for existing JOC Cockpit home directory"
    >&2 echo "    --log-dir=<directory>              | optional: log directory for log output of this script"
    >&2 echo "    --exec-start=<command>             | optional: specifies the command to start JOC Cockpit, e.g. 'StartService'"
    >&2 echo "    --exec-stop=<command>              | optional: specifies the command to stop the JOC Cockpit, e.g. 'StopService'"
    >&2 echo "    --return-values=<file>             | optional: specifies a file that receives return values such as the path to a log file"
    >&2 echo ""
    >&2 echo "  Configuration Options:"
    >&2 echo "    --deploy-dir=<directory[,dir]>     | optional: deployment directories from which configuration files will be copied to <data>/resources/joc"
    >&2 echo "    --properties=<file>                | optional: specifies the joc.properties file that will be copied to <data>/resources/joc/"
    >&2 echo "    --ini=<ini-file[,ini-file]>        | optional: one or more Jetty config files http.ini, https.ini, ssl.ini etc. will be copied to <data>/start.d/"
    >&2 echo "    --title=<title>                    | optional: title of the JOC Cockpit instance in the GUI, default: joc_install.xml setting"
    >&2 echo "    --security-level=low|medium|high   | optional: security level of JOC Cockpit instance, default: joc_install.xml setting"
    >&2 echo "    --dbms-config=<hibernate-file>     | optional: DBMS Hibernate configuration file, default: joc_install.xml setting"
    >&2 echo "    --dbms-driver=<jdbc-driver-file>   | optional: DBMS JDBC Driver file, default: joc_install.xml setting"
    >&2 echo "    --dbms-init=byInstaller|byJoc|off  | optional: DBMS create objects by installer, on start-up or none, default: joc_install.xml setting"
    >&2 echo "    --http-port=<port>                 | optional: specifies the http port the JOC Cockpit will be operated for, default: ${http_port_default}"
    >&2 echo "                                                   port can be prefixed by network interface, e.g. localhost:4446"
    >&2 echo "    --https-port=<port>                | optional: specifies the https port the JOC Cockpit will be operated for, default: ${https_port}"
    >&2 echo "                                                   port can be prefixed by network interface, e.g. joc.example.com:4446"
    >&2 echo "    --keystore=<path>                  | optional: path to a PKCS12 keystore file that will be copied to <data>/resources/joc/"
    >&2 echo "    --keystore-password=<password>     | optional: password for access to keystore"
    >&2 echo "    --keystore-alias=<alias>           | optional: alias name for keystore entry"
    >&2 echo "    --client-keystore=<file>           | optional: path to a PKCS12 client keystore file that will be copied to <data>/resources/joc/"
    >&2 echo "    --client-keystore-password=<pass>  | optional: password for access to client keystore"
    >&2 echo "    --client-keystore-alias=<alias>    | optional: alias name for client keystore entry"
    >&2 echo "    --truststore=<path>                | optional: path to a PKCS12 truststore file that will be copied to <data>/resources/joc/"
    >&2 echo "    --truststore-password=<password>   | optional: password for access to truststore"
    >&2 echo "    --java-home=<directory>            | optional: Java Home directory for use with the Instance Start Script"
    >&2 echo "    --java-options=<options>           | optional: Java Options for use with the Instance Start Script"
    >&2 echo "    --service-dir=<directory>          | optional: systemd service directory, default: ${systemd_service_dir}"
    >&2 echo "    --service-file=<file>              | optional: path to a systemd service file that will be copied to <home>/jetty/bin/"
    >&2 echo "    --service-name=<name>              | optional: name of the systemd service to be created, default js7_joc"
    >&2 echo "    --service-stop-timeout=<seconds>   | optional: timeout of the systemd service to stop JOC Cockpitt, default ${systemd_service_stop_timeout}"
    >&2 echo "    --logo-file=<file-name>            | optional: name of a logo file (.png, .jfif etc.) in <data>/webapps/root/ext/images"
    >&2 echo "    --logo-height=<number>             | optional: height of the logo in pixel"
    >&2 echo "    --logo-position=<top|bottom>       | optional: position of the logo in the login window: top, bottom, default: bottom"
    >&2 echo ""
    >&2 echo "  Switches:"
    >&2 echo "    -h | --help                        | displays usage"
    >&2 echo "    -u | --as-user                     | installs configuration directories as current user, other directories as root using sudo"
    >&2 echo "    -E | --preserve-env                | preserves environment variables when switching to root using sudo -E"
    >&2 echo "    --force-sudo                       | forces use of sudo for operations on directories"
    >&2 echo "    --as-api-server                    | installs the API Server without GUI"
    >&2 echo "    --no-config                        | skips JOC Cockpit configuration changes"
    >&2 echo "    --no-install                       | skips JOC Cockpit installation, performs configuration changes only"
    >&2 echo "    --uninstall                        | uninstalls JOC Cockpit"
    >&2 echo "    --no-jetty                         | skips Jetty servlet container installation"
    >&2 echo "    --service-selinux                  | use SELinux version of systemd service file"
    >&2 echo "    --show-logs                        | shows log output of the script"
    >&2 echo "    --make-dirs                        | creates the specified directories if they do not exist"
    >&2 echo "    --make-service                     | creates the systemd service for JOC Cockpit"
    >&2 echo "    --restart                          | stops a running JOC Cockpit and starts JOC Cockpit after installation"
    >&2 echo "    --cancel                           | cancels a running JOC Cockpit if used with the --restart switch"
    >&2 echo ""
}

GetPid()
{
    port=""
    set -- "$(ps -ef | grep -E "\-Djetty.base=([^ ]+)" | grep -v "grep" | awk '{print $2}')"

    if [ -n "${http_port}" ] && [ -n "$1" ]
    then
        for pid in $@; do
            base_dir=$(ps -ef | grep -E "${pid}" | sed -n -e 's/.*-Djetty.base=\([^ ]\{1,\}\).*/\1/p' )

            if [ -f "${base_dir}"/start.d/ssl.ini ]
            then
                port=$( grep -E "^[^#]" "${base_dir}"/start.d/ssl.ini | grep -E "jetty.https.port" | cut -f2 -d"=")
            fi
            
            if [ -z "${port}" ] && [ -f "${base_dir}"/start.d/http.ini ]
            then
                port=$( grep -E "^[^#]" "${base_dir}"/start.d/http.ini | grep -E "jetty.http.port" | cut -f2 -d"=")
            fi
                
            if [ -z "${port}" ]
            then
                home_dir=$(ps -ef | grep -E "${pid}" | sed -n -e 's/.*-Djetty.base=\([^ ]\{1,\}\).*/\1/p' )
                if [ -f "${home_dir}"/etc/jetty-http.xml ]
                then
                    port=$(cat "${home_dir}"/etc/jetty-http.xml | sed -n -e 's/.*name="jetty.http.port" .*default="\([0-9]\{1,\}\)".*/\1/p')
                fi
            fi

            if [ -n "${port}" ] && [ "${http_port}" -eq "${port}" ]
            then
                pid_file=""
                if [ -f "${base_dir}"/joc.pid ]
                then
                    pid_file="${base_dir}/joc.pid"
                fi

                if [ -z "${pid_file}" ] && [ -f /var/run/joc.pid ]
                then
                    pid_file="/var/run/joc.pid"
                fi
                
                if [ -n "${pid_file}" ] && [ -f "${pid_file}" ]
                then
                    if [ "$(cat "${pid_file}")" -eq "${pid}" ]
                    then
                        echo "${pid}"
                        break
                    fi
                fi
            fi
        done
    else
        echo "$@"
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

StartJOC()
{
    if [ -n "${exec_start}" ]
    then
        Log ".. starting JOC Cockpit: ${exec_start}"
        ${exec_start}
    else
        if [ -n "${restart_joc}" ]
        then
            if [ -d "${joc_home}"/jetty/bin ]
            then
                if [ -f "${joc_home}"/jetty/bin/jetty.sh ]
                then
                    Log ".. starting JOC Cockpit: ${joc_home}/jetty/bin/jetty.sh start"

                    if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                    then
                        start_joc_output_file="/tmp/js7_install_jetty_start_$$.tmp"
                        touch "${start_joc_output_file}"
                        ( "${joc_home}/jetty/bin/jetty.sh" start > "${start_joc_output_file}" 2>&1 ) || ( LogError "$(cat ${start_joc_output_file})" && exit 5 )
                        Log "$(cat ${start_joc_output_file})"
                    else
                        "${joc_home}/jetty/bin/jetty.sh" start
                    fi
                else
                    LogError "cannot start JOC Cockpit, start script missing: ${joc_home}/jetty/bin/jetty.sh"
                fi
            else
                LogError "cannot start JOC Cockpit, directory missing: ${joc_home}/jetty/bin"
            fi
        fi
    fi
}

StopJOC()
{
    if [ -n "${exec_stop}" ]
    then
        Log ".. stopping JOC Cockpit: ${exec_stop}"
        if [ "$(echo "${exec_stop}" | tr '[:upper:]' '[:lower:]')" = "stopservice" ]
        then
            StopService
        else
            ${exec_stop}
        fi
    else
        if [ -n "${restart_joc}" ]
        then
            if [ -n "${cancel_joc}" ]
            then
                stop_option="cancel"
            else
                stop_option="stop"
            fi

            if [ -n "$(GetPid)" ]
            then
                if [ -d "${joc_home}"/jetty/bin ]
                then
                    if [ -f "${joc_home}"/jetty/bin/jetty.sh ]
                    then
                        Log ".. stopping JOC Cockpit: ${joc_home}/jetty/bin/jetty.sh ${stop_option}"

                        if [ -n "${log_file}" ] && [ -f "${log_file}" ]
                        then
                            stop_joc_output_file="/tmp/js7_install_joc_stop_$$.tmp"
                            touch "${stop_joc_output_file}"
                            ( "${joc_home}/jetty/bin/jetty.sh" ${stop_option} > "${stop_joc_output_file}" 2>&1 ) || ( LogError "$(cat ${stop_joc_output_file})" && exit 6 )
                            Log "$(cat ${stop_joc_output_file})"
                        else
                            "${joc_home}/jetty/bin/jetty.sh" ${stop_option}
                        fi
                    else
                        LogError "cannot stop JOC Cockpit, start script missing: ${joc_home}/jetty//bin/jetty.sh"
                    fi
                else
                    LogError "cannot stop JOC Cockpit, directory missing: ${joc_home}/jetty/bin"
                fi
            else
                Log ".. JOC Cockpit not running"
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
            --help|-h)              Usage
                                    exit
                                    ;;
            # Installation Options
            --real-path-prefix=*)   real_path_prefix=$(echo "${option}" | sed 's/--real-path-prefix=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --setup-dir=*)          setup_dir=$(echo "${option}" | sed 's/--setup-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --response-dir=*)       response_dir=$(echo "${option}" | sed 's/--response-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --home=*)               joc_home=$(echo "${option}" | sed 's/--home=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data=*)               joc_data=$(echo "${option}" | sed 's/--data=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --instance-id=*)        joc_instance_id=$(echo "${option}" | sed 's/--instance-id=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --user=*)               joc_user=$(echo "${option}" | sed 's/--user=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --home-owner=*)         home_owner=$(echo "${option}" | sed 's/--home-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --data-owner=*)         data_owner=$(echo "${option}" | sed 's/--data-owner=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --title=*)              joc_title=$(echo "${option}" | sed 's/--title=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --security-level=*)     joc_security_level=$(echo "${option}" | sed 's/--security-level=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --dbms-config=*)        joc_hibernate_file=$(echo "${option}" | sed 's/--dbms-config=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --dbms-init=*)          joc_create_tables=$(echo "${option}" | sed 's/--dbms-init=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --dbms-driver=*)        joc_jdbc_driver=$(echo "${option}" | sed 's/--dbms-driver=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --patch=*)              patch=$(echo "${option}" | sed 's/--patch=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --patch-key=*)          patch_key=$(echo "${option}" | sed 's/--patch-key=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --patch-jar=*)          patch_jar=$(echo "${option}" | sed 's/--patch-jar=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --release=*)            release=$(echo "${option}" | sed 's/--release=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --http-port=*)          http_port=$(echo "${option}" | sed 's/--http-port=//' | sed 's/^"//' | sed 's/"$//')
                                    if [ "${http_port#*:}" != "${http_port}" ]
                                    then
                                        http_network_interface=$(echo "${http_port}" | cut -d':' -f 1)
                                        http_port=$(echo "${http_port}" | cut -d':' -f 2)
                                    fi
                                    ;;
            --https-port=*)         https_port=$(echo "${option}" | sed 's/--https-port=//' | sed 's/^"//' | sed 's/"$//')
                                    if [ -z "${http_port}" ] && [ -z "${https_port}" ]
                                    then
                                        http_port=${http_port_default}
                                    fi
                                    ;;
            --license-key=*)        license_key=$(echo "${option}" | sed 's/--license-key=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --license-bin=*)        license_bin=$(echo "${option}" | sed 's/--license-bin=//' | sed 's/^"//' | sed 's/"$//')
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
            --tarball=*)            tarball=$(echo "${option}" | sed 's/--tarball=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            # Configuration Options
            --deploy-dir=*)         deploy_dir=$(echo "${option}" | sed 's/--deploy-dir=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --ini=*)                joc_ini=$(echo "${option}" | sed 's/--ini=//' | sed 's/^"//' | sed 's/"$//')
                                    ;;
            --properties=*)         joc_properties=$(echo "${option}" | sed 's/--properties=//' | sed 's/^"//' | sed 's/"$//' | sed -r 's/[,]+/ /g')
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
            --logo-file=*)          logo_file=$(echo "${option}" | sed 's/--logo-file=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --logo-height=*)        logo_height=$(echo "${option}" | sed 's/--logo-height=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            --logo-position=*)      logo_position=$(echo "${option}" | sed 's/--logo-position=//' | sed 's/^"//' | sed 's/"$//' | sed 's/^\(.*\)\/$/\1/')
                                    ;;
            # Switches
            --force-sudo)           force_sudo=1
                                    ;;
            --as-user|-u)           as_user=1
                                    ;;
            --preserve-env|-E)      preserve_env=1
                                    ;;
            --as-api-server)        as_api_server=1
                                    ;;
            --no-config)            noconfig_joc=1
                                    ;;
            --no-install)           noinstall_joc=1
                                    ;;
            --uninstall)            uninstall_joc=1
                                    ;;
            --no-jetty)             no_jetty=1
                                    ;;
            --service-selinux)      systemd_service_selinux=1
                                    ;;
            --show-logs)            show_logs=1
                                    ;;
            --make-dirs)            make_dirs=1
                                    ;;
            --make-service)         make_service=1
                                    ;;
            --restart)              restart_joc=1
                                    ;;
            --cancel|--kill)        cancel_joc=1
                                    ;;
            *)                      >&2 echo "unknown option: ${option}"
                                    Usage
                                    exit 1
                                    ;;
        esac
    done

    joc_home=$(GetDirectoryRealpath "${joc_home}")
    joc_data=$(GetDirectoryRealpath "${joc_data}")
    setup_dir=$(GetDirectoryRealpath "${setup_dir}")
    response_dir=$(GetDirectoryRealpath "${response_dir}")
    backup_dir=$(GetDirectoryRealpath "${backup_dir}")
    log_dir=$(GetDirectoryRealpath "${log_dir}")
    systemd_service_dir=$(GetDirectoryRealpath "${systemd_service_dir}")
    deploy_dir=$(GetDirectoryRealpath "${deploy_dir}")

    if [ -n "${response_dir}" ] && [ ! -d "${response_dir}" ]
    then
        LogError "JOC Cockpit response directory not found: --response-dir=$response_dir}"
        Usage
        exit 1
    fi

    if [ -z "${setup_dir}" ] && [ -z "${patch}" ] && [ -z "${noinstall_joc}" ] && [ -z "${uninstall_joc}" ]
    then
        setup_dir="/tmp/js7_install_joc_$$.setup"
        tmp_setup_dir=${setup_dir}
    fi

    if [ -z "${make_dirs}" ] && [ -n "${setup_dir}" ] && [ ! -d "${setup_dir}" ]
    then
        LogError "JOC Cockpit setup directory not found and -make-dirs switch not present: --setup-dir=${setup_dir}"
        Usage
        exit 1
    fi

    if [ -z "${joc_home}" ] && [ -n "${response_dir}" ] && [ -f "${response_dir}"/joc_install.xml ]
    then
        joc_home=$(< "${response_dir}"/joc_install.xml | sed -n -e 's/.*<installpath>\([^\<]\{1,\}\).*/\1/p')
    fi

    if [ -z "${joc_data}" ] && [ -n "${response_dir}" ] && [ -f "${response_dir}"/joc_install.xml ]
    then
        joc_data=$(< "${response_dir}"/joc_install.xml | sed -n -e 's/.*<entry[ ]+key[ ]*=[ ]*\"jettyBaseDir\"[ ]+value[ ]*=[ ]*\"\(.*\)\".*/\1/p')
    fi

    if [ -z "${make_dirs}" ] && [ -n "${backup_dir}" ] && [ ! -d "${backup_dir}" ]
    then
        LogError "Backup directory not found and -make-dirs switch not present: --backup-dir=${backup_dir}"
        Usage
        exit 1
    fi

    if [ -n "${backup_dir}" ] && [ ! -d "${joc_home}" ]
    then
        LogError "Home directory not found and --backup-dir option is present: --backup-dir=${backup_dir}"
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

    if [ -z "${make_dirs}" ] && [ -n "${log_dir}" ] && [ ! -d "${log_dir}" ]
    then
        LogError "Log directory not found and -make-dirs switch not present: --log-dir=${log_dir}"
        Usage
        exit 1
    fi

    if [ -z "${release}" ] && [ -z "${tarball}" ] && [ -z "${patch_jar}" ] && [ -z "${noinstall_joc}" ] && [ -z "${uninstall_joc}" ]
    then
        LogError "Release must be specified for installation if --tarball is not used: --release="
        Usage
        exit 1
    fi

    if [ -n "${tarball}" ] && [ ! -f "${tarball}" ]
    then
        LogError "tarball not found (*.tar.gz): --tarball=${tarball}"
        Usage
        exit 1
    fi

    if [ -n "${as_api_server}" ]
    then
        joc_cluster_id="api"
    fi

    if [ -n "${joc_security_level}" ]
    then
        joc_security_level=$(echo "${joc_security_level}" | tr '[:lower:]' '[:upper:]')
        if [ "${joc_security_level}" != "LOW" ] && [ "${joc_security_level}" != "MEDIUM" ] && [ "${joc_security_level}" != "HIGH" ]
        then
            LogError "Not an allowed security level '${joc_security_level}', use: --security-level=low|medium|high"
            Usage
            exit 1
        fi
    fi

    if [ -n "${joc_hibernate_file}" ] && [ ! "$(echo "${joc_hibernate_file}" | tr '[:lower:]' '[:upper:]')" = 'H2' ] && [ ! -f "${joc_hibernate_file}" ]
    then
        LogError "DBMS Hibernate configuration file not found: --dbms-config=${joc_hibernate_file}"
        Usage
        exit 1
    fi

    if [ -n "${joc_jdbc_driver}" ] && [ ! -f "${joc_jdbc_driver}" ]
    then
        LogError "DBMS JDBC Driver file not found: --dbms-driver=${joc_jdbc_driver}"
        Usage
        exit 1
    fi

    if [ -n "${joc_create_tables}" ]
    then
        joc_create_tables=$(echo "${joc_create_tables}" | tr '[:upper:]' '[:lower:]')
        if [ "${joc_create_tables}" != "byinstaller" ] && [ "${joc_create_tables}" != "byjoc" ] && [ "${joc_create_tables}" != "off" ]
        then
            LogError "Not an allowed option '${joc_create_tables}', use: --dbms-init=byInstaller|byJoc|off"
            Usage
            exit 1
        fi
        
        if [ "${joc_create_tables}" = "byinstaller" ]
        then
            joc_create_tables="byInstaller"
        fi

        if [ "${joc_create_tables}" = "byjoc" ]
        then
            joc_create_tables="byJoc"
        fi
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

    if [ -n "${patch}" ] && [ ! -d "${joc_home}" ]
    then
        LogError "JOC Cockpit home directory not found and --patch option is present: --home=${joc_home}"
        Usage
        exit 1
    fi

    if [ -n "${patch}" ] && [ -z "${patch_key}" ]
    then
        LogError "Patch issue specified and patch key is missing: --patch-key="
        Usage
        exit 1
    fi

    if [ -n "${patch_key}" ]
    then
        patch_key_type=$(echo "${patch_key}" | cut -d'-' -f 1)
        if [ ! "$(echo "${patch_key_type}" | tr '[:lower:]' '[:upper:]')" = 'API' ] && [ ! "$(echo "${patch_key_type}" | tr '[:lower:]' '[:upper:]')" = 'GUI' ]
        then
            LogError "Illegal patch key specified. Should be [API|GUI]-<number>, e.g. API-1, API-2: --patch-key="
            Usage
            exit 1
        fi
    fi

    if [ -n "${java_home}" ] && [ ! -d "${java_home}" ]
    then
        LogError "Java Home directory not found: --java-home=${java_home}"
        Usage
        exit 1
    fi

    if [ -n "${java_home}" ] && [ ! -f "${java_home}"/bin/java ]
    then
        LogError "Java binary ./bin/java not found from Java Home directory: --java-home=${java_home}/bin/java"
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

    if [ -n "${logo_file}" ] && [ ! -f "${logo_file}" ]
    then
        LogError "Logo file not found: --logo-file=${logo_file}"
        Usage
    fi

    if [ -n "${logo_file}" ] && [ -z "${logo_height}" ]
    then
        LogError "Logo height not specified, but log file is present: --logo-height="
        Usage
    fi

    if [ -n "${logo_position}" ]
    then
        if [ ! "${logo_position}" == "top" ] && [ ! "${logo_position}" == "bottom" ]
        then
            LogError "Logo position must be top or bottom: --logo-position=top|bottom"
            Usage
        fi
    fi

    if [ -n "${show_logs}" ] && [ -z "${log_dir}" ]
    then
        LogError "Log directory not specified and -show-logs switch is present: --log-dir="
        Usage
        exit 1
    fi

    if [ -n "${joc_ini}" ]
    then
        set -- "$(echo "${joc_ini}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            if [ ! -f "$i" ] 
            then
                LogError "Configuration file not found: --ini=$i"
                Usage
                exit 1
            fi
        done
    fi

    if [ -n "${joc_properties}" ] && [ ! -f "${joc_properties}" ]
    then
        LogError "Properties file not found (joc.properties): --properties=${joc_properties}"
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

    if [ -n "${noinstall_joc}" ] && [ -n "${tarball}${release}" ]
    then
        LogError "--noinstall switch present and options --tarball or --release specified: --noinstall"
        Usage
        exit 1
    fi

    if [ -n "${uninstall_joc}" ] && [ -n "${tarball}${release}" ]
    then
        LogError "--uninstall switch present and options --tarball or --release specified: --noinstall"
        Usage
        exit 1
    fi

    if [ -z "${https_port}" ] && [ -n "${keystore_file}" ]
    then
        LogError "--keystore option present and no --https-port option specified: --https-port"
        Usage
        exit 1
    fi


    if [ "${https_port#*:}" != "${https_port}" ]
    then
        https_network_interface=$(echo "${https_port}" | cut -d':' -f 1)
        https_port=$(echo "${https_port}" | cut -d':' -f 2)
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
    
        log_file="${log_dir}"/install_js7_joc."${hostname}"."${start_time}".log
        while [ -f "${log_file}" ]
        do
            sleep 1
            start_time=$(date +"%Y-%m-%dT%H-%M-%S")
            log_file="${log_dir}"/install_js7_joc."${hostname}"."${start_time}".log
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

    if [ -z "${joc_data}" ]
    then
        joc_data=${joc_home}
    fi

    joc_config="${joc_data}"/resources/joc

    systemd_service_name=${systemd_service_name:-js7_joc.service}
    if [ "${systemd_service_name%*.service}" = "${systemd_service_name}" ]
    then
        systemd_service_name="${systemd_service_name}".service
    fi

    if [ -n "${real_path_prefix}" ]
    then
        real_joc_home=${joc_home#"${real_path_prefix}"}
    else
        real_joc_home="${joc_home}"
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

            if [ -d "${joc_home}" ] && [ ! -w "${joc_home}" ]
            then
                use_forced_sudo="sudo"
            fi        

            if [ -d "${joc_data}" ] && [ ! -w "${joc_data}" ]
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

    if [ -z "${uninstall_joc}" ]
    then
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
                exit 2
            fi
            
            JAVA=${java_bin}
        fi
    fi

    # uninstall
    if [ -n "${uninstall_joc}" ]
    then
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
                    Log ".... systemd service command: $use_sudo systemctl stop ${systemd_service_name}"
                    (${use_sudo} systemctl stop "${systemd_service_name}" >/dev/null 2>&1) || rc=$?
                    if [ -z "${rc}" ]
                    then
                        Log ".... systemd service stopped: ${systemd_service_name}"
                    else
                        LogError "could not stop systemd service: ${systemd_service_name}"
                        exit 7
                    fi
    
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

        if [ -d "${joc_home}" ] && [ -h "${joc_home}"/jetty_base ]
        then
            ${use_forced_sudo} rm -f "${joc_home}"/jetty_base 
        fi

        if [ -d "${joc_data}" ] && [ -h "${joc_data}"/joc_home ]
        then
            ${use_forced_sudo} rm -f "${joc_data}"/joc_home 
        fi

        if [ -d "${joc_home}" ]
        then
            Log ".... removing home directory: ${joc_home}"
            ${use_forced_sudo} rm -fr "${joc_home}"
        fi

        if [ -d "${joc_data}" ]
        then
            Log ".... removing data directory: ${joc_data}"
            ${use_forced_sudo} rm -fr "${joc_data}"
        fi

        exit
    fi

    # download tarball if required
    if [ -z "${tarball}" ] && [ -n "${release}" ] && [ -z "${noinstall_joc}" ]
    then
        release_major=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\1/')
        release_minor=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\2/')
        release_maint=$(echo "${release}" | sed 's/^\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*[a-zA-Z0-9-]*\).*/\3/')

        if [ -n "${patch}" ]
        then
            tarball="js7_joc.${release}-PATCH.${patch_key}.${patch}.tar.gz"
            download_url="https://download.sos-berlin.com/patches/${release_major}.${release_minor}.${release_maint}-patch/${tarball}"
        else
            tarball="js7_joc_linux.${release}.tar.gz"

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
            curl_output_file="/tmp/js7_install_joc_curl_$$.tmp"
            touch "${curl_output_file}"
            ( curl "${download_url}" --output "${tarball}" --fail > "${curl_output_file}" 2>&1 ) || rc=$?; LogError "$(cat ${curl_output_file})"
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
    if [ -n "${backup_dir}" ] && [ -d "${joc_home}" ]
    then

        if [ -n "${make_dirs}" ] && [ -n "${backup_dir}" ] && [ ! -d "${backup_dir}" ]
        then
            Log "Creating backup directory: ${backup_dir}"
            mkdir -p "${backup_dir}"
        fi
    
        if ${use_forced_sudo} test -f "${joc_data}"/webapps/joc/version.json
        then
            # check existing version
            version=$(${use_forced_sudo} < "${joc_data}"/webapps/joc/version.json | sed -n -e 's/"version":[ ]*"\([^"]\{1,\}\).*/\1/p')
        fi
        if [ -z "${version}" ]
        then
            version="0.0.0"
        fi

        backup_file="${backup_dir}/backup_js7_joc.${hostname}.${version}.home.${start_time}.tar"
        Log ".. creating backup of home directory with file: ${backup_file}.gz"

        exclude_file="/tmp/js7_install_joc_exclude_$$.tmp"
        :> "${exclude_file}"
        Log ".... using exclude file: ${exclude_file}"

        if [ -d "${joc_data}"/logs ]
        then
            find "${joc_data}"/logs -print >> "${exclude_file}"
        fi

        joc_home_parent_dir=$(dirname "${joc_home}")
        joc_home_basename=$(basename "${joc_home}")
        
        if [ -n "${os_compat}" ]
        then
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} -C ${joc_home_parent_dir} ${joc_home_basename}"
            tar -X "${exclude_file}" -cpf "${backup_file}" -C "${joc_home_parent_dir}" "${joc_home_basename}"
            gzip "${backup_file}"
        else
            Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} ${joc_home_basename}"
            (
                cd "${joc_home_parent_dir}" || exit 2
                tar -X "${exclude_file}" -cpf "${backup_file}" "${joc_home_basename}"
            )
            gzip "${backup_file}"
        fi

        # caller should capture the path to the compressed backup file
        backup_file="${backup_file}.gz"

        if [ ! "${joc_home}" = "${joc_data}" ]
        then
            backup_file="${backup_dir}/backup_js7_joc.${hostname}.${version}.data.${start_time}.tar"
            Log ".. creating backup of data directory with file: ${backup_file}.gz"

            exclude_file="/tmp/js7_install_joc_data_exclude_$$.tmp"
            :> "${exclude_file}"
            Log ".... using exclude file: ${exclude_file}"

            if [ -d "${joc_data}"/logs ]
            then
                find "${joc_data}"/logs -print >> "${exclude_file}"
            fi

            joc_data_parent_dir=$(dirname "${joc_data}")
            joc_data_basename=$(basename "${joc_data}")
        
            if [ -n "${os_compat}" ]
            then
                Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} -C ${joc_data_parent_dir} ${joc_data_basename}"
                tar -X "${exclude_file}" -cpf "${backup_file}" -C "${joc_data_parent_dir}" "${joc_data_basename}"
                gzip "${backup_file}"
            else
                Log ".... using backup command: tar -X ${exclude_file} -cpf ${backup_file} ${joc_data_basename}"
                (
                    cd "${joc_data_parent_dir}" || exit 2
                    tar -X "${exclude_file}" -cpf "${backup_file}" "${joc_data_basename}"
                )
                gzip "${backup_file}"
            fi
        fi
    fi

    if [ -n "${tarball}" ]
    then
        # extract to temporary directory
        tar_dir="/tmp/js7_install_joc_$$.tmp"
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

        if [ -z "${patch}" ]
        then
            tar_root=$(ls "${tar_dir}")

            if [ "$(echo "${tar_root}" | wc -l)" -ne 1 ]
            then
                LogError "tarball not usable, it includes more than one top-level folder: ${tar_root}"
                exit 2
            fi
        fi
    fi

    StopJOC

    if [ -n "${patch}" ]
    then
        if [ "${patch_key_type}" = "API" ]
        then
            if [ -d "${joc_data}"/webapps/joc/WEB-INF/classes ]
            then
                # check security level
                if ${use_forced_sudo} test -f "${joc_data}"/webapps/joc/WEB-INF/classes/joc-settings.properties
                then
                    security_level=$(${use_forced_sudo} < "${joc_data}"/webapps/joc/WEB-INF/classes/joc-settings.properties | grep "security_level" | cut -d'=' -f2 | sed 's/^\s*//')
                    if [ -n "${security_level}" ]
                    then
                        echo "${patch}" | grep -i -q "${security_level}" || Log ".. non-matching security level '${security_level}' found: --patch=${patch}"
                    fi
                fi
    
                if [ -n "${tarball}" ]
                then
                    # copy to JOC Cockpit base directory
                    ChangeOwner "${tar_dir}"/. "${home_owner}" "${home_owner_group}"
                    Log ".. copying files from extracted tarball directory: ${tar_dir}/. to JOC Cockpit patch directory: ${joc_data}/webapps/joc/WEB-INF/classes"
                    ${use_forced_sudo} cp -p -R "${tar_dir:?}"/. "${joc_data}"/webapps/joc/WEB-INF/classes
                else
                    if [ -n "${patch_jar}" ]
                    then
                        Log ".. copying patch file: ${patch_jar} to JOC Cockpit patch directory: ${joc_data}/webapps/joc/WEB-INF/classes"
                        ${use_forced_sudo} cp -p "${patch_jar}" "${joc_data}"/webapps/joc/WEB-INF/classes
                    else
                        LogError "no --tarball and no --patch-jar option is present"
                        exit 2
                    fi
                fi
    
                command="${use_forced_sudo} $(command -v jar)"
                if [ -n "${command}" ]
                then
                    command="${command} -xf"
                else
                    command=$(command -v unzip)
                    if [ -z "${command}" ]
                    then
                        LogError "could not find extraction utility: jar, unzip"
                        exit 2
                    fi
                fi
                
                set -- "$(ls "${joc_data}"/webapps/joc/WEB-INF/classes/*.jar)"
                for jarFile in $@; do
                    Log ".... extracting patch .jar file: ${command} ${jarFile}"
                    (cd "${joc_data}"/webapps/joc/WEB-INF/classes && ${command} "${jarFile}")
                    Log ".... removing patch .jar file: rm -f ${jarFile}"
                    ${use_forced_sudo} rm -f "${jarFile}"
                done
    
                StartJOC
                return_code=0
                exit
            else
                LogError "JOC Cockpit patch directory not found: ${joc_data}/webapps/joc/WEB-INF/classes"
                exit 2
            fi
        fi

        if [ "${patch_key_type}" = "GUI" ]
        then
            if [ -d "${joc_data}"/webapps/joc ]
            then
                if [ -n "${tarball}" ]
                then
                    Log ".. removing existing files and directories in ${joc_data}/webapps/joc"
                    ${use_forced_sudo} find "${joc_data}"/webapps/joc -maxdepth 1 -type f -delete 
                        
                    if [ -d "${joc_data}"/webapps/joc/assets ]
                    then
                        ${use_forced_sudo} rm -fr "${joc_data}"/webapps/joc/assets
                    fi

                    if [ -d "${joc_data}"/webapps/joc/styles ]
                    then
                        ${use_forced_sudo} rm -fr "${joc_data}"/webapps/joc/styles
                    fi

                    # copy to JOC Cockpit base directory
                    ChangeOwner "${tar_dir}"/. "${home_owner}" "${home_owner_group}"
                    Log ".. copying files from extracted tarball directory: ${tar_dir}/. to JOC Cockpit patch directory: ${joc_data}/webapps/joc"
                    ${use_forced_sudo} cp -p -R "${tar_dir:?}"/. "${joc_data}"/webapps/joc
                fi

                StartJOC
                return_code=0
                exit
            else
                LogError "JOC Cockpit patch directory not found: ${joc_data}/webapps/joc"
                exit 2
            fi
        fi
    fi

    if [ -z "${patch}" ] && [ -z "${noinstall_joc}" ]
    then
        # create JOC Cockpit setup directory if required
        if [ ! -d "${setup_dir}" ] && [ -n "${make_dirs}" ]
        then
            Log ".. creating JOC Cockpit setup directory: ${setup_dir}"
            ${use_forced_sudo} mkdir -p "${setup_dir}"
        fi
    
        # copy to JOC Cockpit setup directory
        Log ".. copying files from extracted tarball directory: ${tar_dir}/${tar_root} to JOC Cockpit setup directory: ${setup_dir}"
        ChangeOwner "${tar_dir}"/. "${home_owner}" "${home_owner_group}"
        ${use_forced_sudo} cp -p -R "${tar_dir:?}"/"${tar_root}"/. "${setup_dir}"
        
        if [ -n "${response_dir}" ]
        then
            Log ".. copying installer response files from ${response_dir} to ${setup_dir}"
            ${use_forced_sudo} cp -p -R "${response_dir}"/* "${setup_dir}"/
        fi
    
        # update installer options
        ${use_forced_sudo} sed -i'' -e "s/<entry key=\"launchJetty\".*/$(echo "<entry key=\"launchJetty\" value=\"no\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        ${use_forced_sudo} sed -i'' -e "s/<entry key=\"withJocInstallAsDaemon\".*/$(echo "<entry key=\"withJocInstallAsDaemon\" value=\"no\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml

        if [ -n "${joc_home}" ]
        then
            Log ".. updating home directory in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<installpath>.*/$(echo "<installpath>${joc_home}</installpath>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_data}" ]
        then
            Log ".. updating data directory in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jettyBaseDir\".*/$(echo "<entry key=\"jettyBaseDir\" value=\"${joc_data}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${as_api_server}" ]
        then
            Log ".. updating API Server setting in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"asApiServer\".*/$(echo "<entry key=\"asApiServer\" value=\"yes\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_user}" ]
        then
            Log ".. updating run-time user account in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"runningUser\".*/<entry key=\"runningUser\" value=\"${joc_user}\"\/>/g" "${setup_dir}"/joc_install.xml
        else
            if [ -n "${response_dir}" ] && [ -f "${response_dir}"/joc_install.xml ]
            then
                joc_user=$(< "${response_dir}"/joc_install.xml | ${use_forced_sudo} sed -n -e 's/.*<entry[ ]*key[ ]*=[ ]*\"runningUser\"[ ]*value[ ]*=[ ]*\"\([^\"]\{1,\}\).*/\1/p')
            else
                joc_user=$(id -u -n -r)
            fi
        fi
    
        if [ -n "${joc_cluster_id}" ]
        then
            Log ".. updating Cluster ID in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jocClusterId\".*/$(echo "<entry key=\"jocClusterId\" value=\"${joc_cluster_id}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_instance_id}" ]
        then
            Log ".. updating Instance ID in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"ordering\".*/$(echo "<entry key=\"ordering\" value=\"${joc_instance_id}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_title}" ]
        then
            Log ".. updating title in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jocTitle\".*/$(echo "<entry key=\"jocTitle\" value=\"${joc_title}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_security_level}" ]
        then
            Log ".. updating security level in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"securityLevel\".*/$(echo "<entry key=\"securityLevel\" value=\"${joc_security_level}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${no_jetty}" ]
        then
            Log ".. updating use of Jetty Servlet Container in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"withJettyInstall\".*/$(echo "<entry key=\"withJettyInstall\" value=\"no\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -z "${make_service}" ]
        then
            Log ".. updating use of systemd service in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"withJocInstallAsDaemon\".*/$(echo "<entry key=\"withJocInstallAsDaemon\" value=\"no\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_hibernate_file}" ]
        then
            Log ".. updating DBMS Hibernate configuration file in response file ${setup_dir}/joc_install.xml"
            if [   "$(echo "${joc_hibernate_file}" | tr '[:lower:]' '[:upper:]')" = 'H2' ]
            then
                ${use_forced_sudo} sed -i'' -e "s/<entry key=\"databaseConfigurationMethod\".*/$(echo "<entry key=\"databaseConfigurationMethod\" value=\"h2\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
            else
                ${use_forced_sudo} sed -i'' -e "s/<entry key=\"hibernateConfFile\".*/$(echo "<entry key=\"hibernateConfFile\" value=\"${joc_hibernate_file}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
                ${use_forced_sudo} sed -i'' -e "s/<entry key=\"databaseDbms\".*/$(echo "<entry key=\"databaseDbms\" value=\"\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
    
                if grep 'H2Dialect' "${joc_hibernate_file}"
                then
                    ${use_forced_sudo} sed -i'' -e "s/<entry key=\"databaseConfigurationMethod\".*/<entry key=\"databaseConfigurationMethod\" value=\"h2\"\/>/g" "${setup_dir}"/joc_install.xml
                else
                    ${use_forced_sudo} sed -i'' -e "s/<entry key=\"databaseConfigurationMethod\".*/<entry key=\"databaseConfigurationMethod\" value=\"withHibernateFile\"\/>/g" "${setup_dir}"/joc_install.xml
                fi
            fi
        fi
    
        if [ -n "${joc_jdbc_driver}" ]
        then
            Log ".. updating DBMS JDBC Driver in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"connector\".*/$(echo "<entry key=\"connector\" value=\"${joc_jdbc_driver}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"internalConnector\".*/$(echo "<entry key=\"internalConnector\" value=\"no\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${joc_create_tables}" ]
        then
            Log ".. updating option to create tables in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"databaseCreateTables\".*/$(echo "<entry key=\"databaseCreateTables\" value=\"${joc_create_tables}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        Log ".. updating http port in response file ${setup_dir}/joc_install.xml"
        if [ -n "${http_port}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jettyPort\".*/<entry key=\"jettyPort\" value=\"${http_port}\"\/>/g" "${setup_dir}"/joc_install.xml
        else
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jettyPort\".*/<entry key=\"jettyPort\" value=\"${https_port}\"\/>/g" "${setup_dir}"/joc_install.xml
        fi
    
        if [ -n "${java_options}" ]
        then
            Log ".. updating Java options in response file ${setup_dir}/joc_install.xml"
            ${use_forced_sudo} sed -i'' -e "s/<entry key=\"jettyOptions\".*/$(echo "<entry key=\"jettyOptions\" value=\"${java_options}\"/>" | sed -e 's@/@\\\/@g')/g" "${setup_dir}"/joc_install.xml
        fi
    
        # run installer
        if [ -n "${as_user}" ]
        then
            user_option="-u"
        else
            user_option=""
        fi
    
        if [ -n "${preserve_env}" ]
        then
            user_option="${user_option} -E"
        fi
    
        result_log="${joc_data}/logs/install-result.log"
        if ${use_forced_sudo} test -f "${result_log}"
        then
            ${use_forced_sudo} rm "${result_log}"
        fi
    
        Log ".. running installer from JOC Cockpit setup directory: JAVA=${JAVA} && export JAVA && cd ${setup_dir} && ./setup.sh ${user_option} joc_install.xml"
        if [ -n "${use_forced_sudo}" ]
        then
            ( sudo sh -c "JAVA=${JAVA} && PATH=${JAVA_HOME}/bin:${PATH} && export JAVA PATH && cd ${setup_dir} && ./setup.sh ${user_option} joc_install.xml" || exit 8 )
        else
            ( JAVA="${JAVA}" && PATH=${JAVA_HOME}/bin:${PATH} && export JAVA PATH && cd "${setup_dir}" && "./setup.sh" ${user_option} joc_install.xml || exit 8 )
        fi
    
        if ! ${use_forced_sudo} test -f "${result_log}"
        then
            LogError "installation failed, result log is missing: ${result_log}"
            exit 9
        else
            return_code=$(${use_forced_sudo} grep 'return_code' "${result_log}" | cut -d'=' -f2)
            if [ "${return_code}" -ne 0 ]
            then
                LogError "installation failed, return code ${return_code} reported from result log: ${result_log}"
                exit 9
            fi
        fi
    fi

    if [ -n "${license_key}" ]
    then
        download_target="${joc_data}/lib/ext/joc/js7-license.jar"
        
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
                curl_output_file_license="/tmp/js7_install_joc_license_$$.tmp"
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

        if [ ! -d "${joc_data}"/resources/joc/license ]
        then
            ${use_forced_sudo} mkdir -p "${joc_data}"/resources/joc/license
        fi

        Log ".. copying license key file to: ${joc_data}/resources/joc/license/"
        ${use_forced_sudo} cp -p "${license_key}" "${joc_data}"/resources/joc/license/
    else
        if [ -n "${license_bin}" ]
        then
            download_target="${joc_data}/lib/ext/joc/js7-license.jar"

            Log ".. copying license binary file from: ${license_bin} to ${download_target}"
            ${use_forced_sudo} cp -p "${license_bin}" "${download_target}"
        fi
    fi

    # copy deployment directory
    if [ -n "${deploy_dir}" ] && [ -d "${joc_config}" ]
    then
        set -- "$(echo "${deploy_dir}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            if [ ! -d "$i" ] 
            then
                LogError "Deployment Directory not found: --deploy-dir=$i"
            else
                Log ".. deploying configuration from ${i} to JOC Cockpit configuration directory: ${joc_config}/"
                ${use_forced_sudo} cp -p -R "${i}"/. "${joc_config}"
            fi
        done
    fi

    # copy systemd service file
    use_service_file="${joc_home}"/jetty/bin/joc.service
    if [ -n "${systemd_service_file}" ]
    then
        Log ".. copying ${systemd_service_file} to ${use_service_file}"
        ${use_forced_sudo} cp -p "${systemd_service_file}" "${use_service_file}"
    fi

    # initialize SSL
    if [ -n "${https_port}" ]
    then
        Log ".. initializing Jetty SSL: ${JAVA} -jar ${joc_home}/jetty/start.jar -Djetty.home=${joc_home}/jetty -Djetty.base=${joc_data} --add-module=ssl,https"
        ( ${JAVA} -jar "${joc_home}/jetty/start.jar" -Djetty.home="${joc_home}/jetty" -Djetty.base="${joc_data}" --add-module=ssl,https || exit 8 )
  
        if ! ${use_forced_sudo} test -f "${joc_data}/start.d/https.ini"
        then
            if ${use_forced_sudo} test -f "${joc_data}/start.d/https.in~"
            then
                ${use_forced_sudo} mv "${joc_data}/start.d/https.in~" "${joc_data}/start.d/https.ini"
            else
                LogError "Jetty https.ini file not found for use of HTTPS connections"
            fi
        fi
  
        if ! ${use_forced_sudo} test -f "${joc_data}/start.d/ssl.ini"
        then
            if ${use_forced_sudo} test -f "${joc_data}/start.d/ssl.in~"
            then
                ${use_forced_sudo} mv "${joc_data}/start.d/ssl.in~" "${joc_data}/start.d/ssl.ini"
            else
                LogError "Jetty ssl.ini file not found for use of HTTPS connections"
            fi
        fi
    fi  

    # copy *.ini files
    if [ -n "${joc_ini}" ]
    then
        if [ ! -d "${joc_data}"/start.d ]
        then
            ${use_forced_sudo} mkdir -p "${joc_data}"/start.d 
        fi

        set -- "$(echo "${joc_ini}" | sed -r 's/[,]+/ /g')"
        for i in $@; do
            Log ".. copying .ini file ${i} to ${joc_data}/start.d/"
            ${use_forced_sudo} cp -p "${i}" "${joc_data}"/start.d/
        done
    fi

    # copy joc.properties
    if [ -n "${joc_properties}" ] && [ -d "${joc_data}"/resources/joc ]
    then
        use_properties_file="${joc_data}"/resources/joc/joc.properties
        Log ".. copying properties file ${joc_properties} to ${use_properties_file}"
        ${use_forced_sudo} cp -p "${joc_properties}" "${use_properties_file}"
    fi

    # copy keystore
    if [ -n "${keystore_file}" ] && [ -d "${joc_data}"/resources/joc ]
    then
        use_keystore_file="${joc_data}"/resources/joc/$(basename "${keystore_file}")
        Log ".. copying keystore file ${keystore_file} to ${use_keystore_file}"
        ${use_forced_sudo} cp -p "${keystore_file}" "${use_keystore_file}"
    fi

    # copy client keystore
    if [ -n "${client_keystore_file}" ] && [ -d "${joc_data}"/resources/joc ]
    then
        use_client_keystore_file="${joc_data}"/resources/joc/$(basename "${client_keystore_file}")
        Log ".. copying client keystore file ${client_keystore_file} to ${use_client_keystore_file}"
        ${use_forced_sudo} cp -p "${client_keystore_file}" "${use_client_keystore_file}"
    fi

    # copy truststore
    if [ -n "${truststore_file}" ] && [ -d "${joc_data}"/resources/joc ]
    then
        use_truststore_file="${joc_data}"/resources/joc/$(basename "${truststore_file}")
        Log ".. copying truststore file ${truststore_file} to ${use_truststore_file}"
        ${use_forced_sudo} cp -p "${truststore_file}" "${use_truststore_file}"
    fi

    # update Jetty start script
    use_start_script="${joc_home}"/jetty/bin/jetty.sh
    if [ -n "${os_compat}" ] && [ -z "${noinstall_joc}" ] && ${use_forced_sudo} test -f "${use_service_file}"
    then
        Log ".. updating JOC Cockpit start_script ${use_start_script}"
        
        if [ -n "${joc_user}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^JETTY_USER[ ]*=[ ]*.*/JETTY_USER=\"${joc_user}\"/g" "${use_start_script}"
            ${use_forced_sudo} sed -i'' -e "s/^JETTY_USER_HOME[ ]*=[ ]*.*/JETTY_USER_HOME=\"\$HOME\"/g" "${use_start_script}"
        fi
    fi

    # update systemd service file
    if [ -z "${systemd_service_file}" ] && [ -n "${os_compat}" ] && [ -z "${noinstall_joc}" ] && ${use_forced_sudo} test -f "${use_service_file}"
    then
        Log ".. updating JOC Cockpit systemd service file: ${use_service_file}"

        if [ -n "${real_path_prefix}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/$(echo "${real_path_prefix}" | sed -e 's@/@\\\/@g')//g" "${use_service_file}"
        fi

        if [ -n "${joc_user}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^User[ ]*=[ ]*.*/User=${joc_user}/g" "${use_service_file}"
        fi

        if [ -n "${systemd_service_selinux}" ]
        then
            line_no=$(< "${use_service_file}" sed -n '/^ExecStart/{=;q;}')
            if [ -n "${line_no}" ] && [ "${line_no}" -gt 0 ]
            then
                if [ -n "${pid_file_dir}" ]
                then
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${joc_user} ${pid_file_dir}" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${pid_file_dir}" "${use_service_file}"
                else
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/chown ${joc_user} ${real_joc_logs}" "${use_service_file}"
                    ${use_forced_sudo} sed -i'' "${line_no}a ExecStartPre=+/bin/mkdir -p ${real_joc_logs}" "${use_service_file}"
                fi
            fi

            ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "/bin/sh -c \"${real_joc_home}/jetty/bin/jetty.sh start\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "/bin/sh -c \"${real_joc_home}/jetty/bin/jetty.sh stop\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "/bin/sh -c \"${real_joc_home}/jetty/bin/jetty.sh restart\"" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^ExecStart[ ]*=[ ]*.*/ExecStart=$(echo "${real_joc_home}/jetty/bin/jetty.sh start" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecStop[ ]*=[ ]*.*/ExecStop=$(echo "${real_joc_home}/jetty/bin/jetty.sh stop" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^ExecReload[ ]*=[ ]*.*/ExecReload=$(echo "${real_joc_home}/jetty/bin/jetty.sh restart" | sed -e 's@/@\\\/@g')/g" "${use_service_file}"
        fi

        ${use_forced_sudo} sed -i'' -e "s/^StandardOutput[ ]*=[ ]*syslog+console/StandardOutput=journal+console/g" "${use_service_file}"
        ${use_forced_sudo} sed -i'' -e "s/^StandardError[ ]*=[ ]*syslog+console/StandardError=journal+console/g" "${use_service_file}"
        ${use_forced_sudo} sed -i'' -e "s/^TimeoutStopSec[ ]*=[ ]*.*/TimeoutStopSec=${systemd_service_stop_timeout}/g" "${use_service_file}"

        if [ -n "${java_home}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*Environment[ ]*=[ ]*\"JAVA_HOME.*/Environment=\"JAVA_HOME=$(echo "${java_home}" | sed -e 's@/@\\\/@g')\"/g" "${use_service_file}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*Environment[ ]*=[ ]*\"JAVA=.*/Environment=\"JAVA=$(echo "${java_home}"/bin/java | sed -e 's@/@\\\/@g')\"/g" "${use_service_file}"
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

    # update joc.properties
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${joc_config}"/joc.properties && [ -z "${noconfig_joc}" ]
    then
        if [ -n "${joc_cluster_id}" ]
        then
            Log ".. updating Cluster ID in ${joc_config}/joc.properties"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*cluster_id[ ]*=.*/$(echo "cluster_id = ${joc_cluster_id}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi
    
        if [ -n "${joc_instance_id}" ]
        then
            Log ".. updating Instance ID in ${joc_config}/joc.properties"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*ordering[ ]*=.*/$(echo "ordering = ${joc_instance_id}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi
    
        if [ -n "${joc_title}" ]
        then
            Log ".. updating title in ${joc_config}/joc.properties"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*title[ ]*=.*/$(echo "title = ${joc_title}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi    

        if [ -n "${keystore_file}" ] || [ -n "${keystore_password}" ] || [ -n "${keystore_alias}" ] || [ -n "${truststore_file}" ] || [ -n "${truststore_password}" ]
        then
            Log ".. updating JOC Cockpit configuration file: ${joc_config}/joc.properties"
        fi

        if [ -n "${keystore_file}" ] && ${use_forced_sudo} test -f "${keystore_file}" && [ -z "${client_keystore_file}" ]
        then
            Log ".... updating keystore file name: $(basename "${keystore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_path[ ]*=.*/$(echo "keystore_path = $(basename "${keystore_file}")" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_type[ ]*=.*/keystore_type = PKCS12/g" "${joc_config}"/joc.properties
        fi
        
        if [ -n "${keystore_password}" ] && [ -z "${client_keystore_password}" ]
        then
            Log ".... updating keystore password"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_password[ ]*=.*/$(echo "keystore_password = ${keystore_password}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*key_password[ ]*=.*/$(echo "key_password = ${keystore_password}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${keystore_alias}" ] && [ -z "${client_keystore_alias}" ]
        then
            Log ".... updating keystore alias name for key: ${keystore_alias}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_alias[ ]*=.*/keystore_alias = ${keystore_alias}/g" "${joc_config}"/joc.properties
        fi
        
        if [ -n "${client_keystore_file}" ] && ${use_forced_sudo} test -f "${client_keystore_file}"
        then
            Log ".... updating client keystore file name: $(basename "${client_keystore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_path[ ]*=.*/$(echo "keystore_path = $(basename "${client_keystore_file}")" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_type[ ]*=.*/keystore_type = PKCS12/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${client_keystore_password}" ]
        then
            Log ".... updating client keystore password"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_password[ ]*=.*/$(echo "keystore_password = ${client_keystore_password}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*key_password[ ]*=.*/$(echo "key_password = ${client_keystore_password}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${client_keystore_alias}" ]
        then
            Log ".... updating client keystore alias name for key: ${client_keystore_alias}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*keystore_alias[ ]*=.*/keystore_alias = ${client_keystore_alias}/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${truststore_file}" ] && ${use_forced_sudo} test -f "${truststore_file}"
        then
            Log ".... updating truststore file name: $(basename "${truststore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*truststore_path[ ]*=.*/$(echo "truststore_path = $(basename "${truststore_file}")" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*truststore_type[ ]*=.*/truststore_type = PKCS12/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${truststore_password}" ]
        then
            Log ".... updating truststore password"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*truststore_password[ ]*=.*/$(echo "truststore_password = ${truststore_password}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
        fi

        if [ -n "${logo_file}" ]
        then
            Log ".... updating custom logo settings"
            ${use_forced_sudo} mkdir -p "${joc_data}"/webapps/root/ext/images
            ${use_forced_sudo} cp "${logo_file}" "${joc_data}"/webapps/root/ext/images/
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*custom_logo_name[ ]*=.*/$(echo "custom_logo_name = $(basename ${logo_file})" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*custom_logo_height[ ]*=.*/$(echo "custom_logo_height = ${logo_height}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties

            if [ -n "${logo_position}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*custom_logo_position[ ]*=.*/$(echo "custom_logo_position = ${logo_position}" | sed -e 's@/@\\\/@g')/g" "${joc_config}"/joc.properties
            fi
        fi
    fi

    # update http.ini
    use_ini_file="${joc_data}"/start.d/http.ini
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_ini_file}" && [ -z "${noconfig_joc}" ]
    then
        Log ".. updating JOC Cockpit configuration file: ${use_ini_file}"
        if [ -n "${http_port}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module=http.*/--module=http/g" "${use_ini_file}"

            if [ -n "${http_network_interface}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.http.host=.*/jetty.http.host=${http_network_interface}/g" "${use_ini_file}"
            else
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.http.host=.*/# jetty.http.host=/g" "${use_ini_file}"
            fi

            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.http.port=.*/jetty.http.port=${http_port}/g" "${use_ini_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module=http.*/# --module=http/g" "${use_ini_file}"
        fi
    fi

    # update https.ini
    use_ini_file="${joc_data}"/start.d/https.ini
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_ini_file}" && [ -z "${noconfig_joc}" ]
    then
        Log ".. updating JOC Cockpit configuration file: ${use_ini_file}"
        if [ -n "${https_port}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module[ ]*=[ ]*https.*/--module=https/g" "${use_ini_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module[ ]*=[ ]*https.*/# --module=https/g" "${use_ini_file}"
        fi
    fi

    # update ssl.ini
    use_ini_file="${joc_data}"/start.d/ssl.ini
    if [ -n "${os_compat}" ] && ${use_forced_sudo} test -f "${use_ini_file}" && [ -z "${noconfig_joc}" ]
    then
        Log ".. updating JOC Cockpit configuration file: ${use_ini_file}"
        if [ -n "${https_port}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module[ ]*=[ ]*ssl.*/--module=ssl/g" "${use_ini_file}"
        else
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module[ ]*=[ ]*ssl.*/# --module=ssl/g" "${use_ini_file}"
        fi

        if [ -n "${https_port}" ]
        then
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*--module[ ]*=[ ]*ssl.*/--module=ssl/g" "${use_ini_file}"

            if [ -n "${https_network_interface}" ]
            then
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.ssl.host=.*/jetty.ssl.host=${https_network_interface}/g" "${use_ini_file}"
            else
                ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.ssl.host=.*/# jetty.ssl.host=/g" "${use_ini_file}"
            fi

            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.ssl.port=.*/jetty.ssl.port=${https_port}/g" "${use_ini_file}"
        fi

        if [ -n "${keystore_file}" ] && ${use_forced_sudo} test -f "${keystore_file}"
        then
            Log ".... updating keystore file name: $(basename "${keystore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.keyStorePath[ ]*=.*/$(echo "jetty.sslContext.keyStorePath=resources/joc/$(basename "${keystore_file}")" | sed -e 's@/@\\\/@g')/g" "${use_ini_file}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.keyStoreType[ ]*=.*/jetty.sslContext.keyStoreType=PKCS12/g" "${use_ini_file}"
        fi
        
        if [ -n "${keystore_password}" ]
        then
            Log ".... updating keystore password"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.keyStorePassword[ ]*=.*/$(echo "jetty.sslContext.keyStorePassword=${keystore_password}" | sed -e 's@/@\\\/@g')/g" "${use_ini_file}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.keyManagerPassword[ ]*=.*/$(echo "jetty.sslContext.keyManagerPassword=${keystore_password}" | sed -e 's@/@\\\/@g')/g" "${use_ini_file}"
        fi

        if [ -n "${truststore_file}" ] && ${use_forced_sudo} test -f "${truststore_file}"
        then
            Log ".... updating truststore file name: $(basename "${truststore_file}")"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.trustStorePath[ ]*=.*/$(echo "jetty.sslContext.trustStorePath=resources/joc/$(basename "${truststore_file}")" | sed -e 's@/@\\\/@g')/g" "${use_ini_file}"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.trustStoreType[ ]*=.*/jetty.sslContext.trustStoreType=PKCS12/g" "${use_ini_file}"
        fi

        if [ -n "${truststore_password}" ]
        then
            Log ".... updating truststore password"
            ${use_forced_sudo} sed -i'' -e "s/^[# ]*jetty.sslContext.trustStorePassword[ ]*=.*/$(echo "jetty.sslContext.trustStorePassword=${truststore_password}" | sed -e 's@/@\\\/@g')/g" "${use_ini_file}"
        fi
    fi

    # update jetty-ssl-context.xml
    use_xml_file="${joc_home}"/jetty/etc/jetty-ssl-context.xml
    if [ -n "${keystore_alias}" ] && ${use_forced_sudo} test -f "${use_xml_file}" && [ -z "${noconfig_joc}" ]
    then
        Log ".. updating JOC Cockpit configuration file: ${use_xml_file}"
        ${use_forced_sudo} sed -i'' -e "s/Property[ ]*name[ ]*=[ ]*\"jetty.sslContext.keystore.alias\"[ ]*default[ ]*=[ ]*\".*\"/Property name=\"jetty.sslContext.keystore.alias\" default=\"${keystore_alias}\"/g" "${use_xml_file}"
    fi

    if [ -n "${joc_home}" ] && [ -n "${home_owner}" ]
    then
        ChangeOwner "${joc_home}" "${home_owner}" "${home_owner_group}"
    fi

    if [ -n "${joc_data}" ] && [ -n "${data_owner}" ]
    then
        ChangeOwner "${joc_data}" "${data_owner}" "${data_owner_group}"
    fi

    if [ -n "${joc_data}" ] && [ -n "${data_owner}" ] && [ -L "${joc_data}"/logs ]
    then
        link_target=$(ls -l "${joc_data}"/logs | sed 's/^.* -> //')
        ChangeOwner "${link_target}" "${data_owner}" "${data_owner_group}"
    fi

    StartJOC
    return_code=0
}

# ------------------------------
# Cleanup temporary resources
# ------------------------------

End()
{
    if [ -n "${tmp_setup_dir}" ] && [ -d "${tmp_setup_dir}" ]
    then
        # Log ".. removing temporary setup directory: ${tmp_setup_dir}"
        ${use_forced_sudo} rm -fr "${tmp_setup_dir}"
    fi

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

    if [ -n "${start_joc_output_file}" ] && [ -f "${start_joc_output_file}" ]
    then
        # Log ".. removing temporary file: ${start_joc_output_file}"
        rm -f "${start_joc_output_file}"
    fi

    if [ -n "${stop_joc_output_file}" ] && [ -f "${stop_joc_output_file}" ]
    then
        # Log ".. removing temporary file: ${stop_joc_output_file}"
        rm -f "${stop_joc_output_file}"
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

    unset real_path_prefix
    unset as_user
    unset as_api_server
    unset backup_dir
    unset deploy_dir
    unset exec_start
    unset exec_stop
    unset http_port
    unset java_bin
    unset joc_home
    unset joc_data
    unset joc_cluster_id
    unset joc_instance_id
    unset joc_user
    unset home_owner
    unset home_owner_group
    unset data_owner
    unset data_owner_group
    unset force_sudo
    unset joc_security_level
    unset joc_title
    unset joc_hibernate_file
    unset joc_create_tables
    unset joc_jdbc_driver
    unset joc_ini
    unset joc_properties
    unset no_jetty
    unset keystore_file
    unset keystore_password
    unset keystore_alias
    unset client_keystore_file
    unset client_keystore_password
    unset client_keystore_alias
    unset truststore_file
    unset truststore_password
    unset logo_file
    unset logo_height
    unset logo_position
    unset cancel_joc
    unset log_dir
    unset make_dirs
    unset patch
    unset patch_key
    unset patch_jar
    unset port
    unset preserve_env
    unset release
    unset restart_joc
    unset return_values
    unset setup_dir
    unset tmp_setup_dir
    unset response_dir
    unset show_logs
    unset tarball
    unset uninstall_joc
    unset noinstall_joc
    unset noconfig_joc
    unset java_home
    unset java_options
    unset systemd_service_dir
    unset systemd_service_file
    unset systemd_service_name
    unset systemd_service_stop_timeout

    unset backup_file
    unset base_dir
    unset command
    unset curl_output_file
    unset download_url
    unset exclude_file
    unset home_dir
    unset hostname
    unset log_file
    unset pid_file
    unset release_major
    unset release_minor
    unset release_maint
    unset return_code
    unset start_joc_output_file
    unset start_time
    unset stop_joc_output_file
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
