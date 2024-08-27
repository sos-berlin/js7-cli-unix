<#
.SYNOPSIS
Installs, updates, patches or uninstalls a JS7 Agent on Windows and Unix platforms supporting PowerShell 5.1, 6, 7

.DESCRIPTION
The Agent Installation Script can be used to automate installing, updating, patching and uninstalling Agents.

The script offers the installation options and configuration options available from the Agent's graphical installer.

For download see https://kb.sos-berlin.com/display/JS7/JS7+-+Download

.PARAMETER HomeDir
Specifies the directory in which the Agent should be installed.

.PARAMETER Data
Specifies the directory in which Agent data such as configuration files should be stored.
By default the <home>/var_<http-port> directory is used, see -HomeDir and -HttpPort parameters.

.PARAMETER Config
Specifies the directory from which the Agent reads configuration files.

By default the <data>/config directory is used, see -Data parameter.

.PARAMETER Logs
Specifies the directory to which the Agent stores log files.
By default the <data>/logs directory is used, see -Data parameter.

.PARAMETER Work
Specifies the working directory of the Agent.
By default the <data>/work directory is used, see -Data parameter.

.PARAMETER User
Specifies the user account for the Agent daemon in Unix environments.
By default the account of the user running the Agent Installation Script is used.

For Windows the -User parameter is informative. The -ServiceCredentials parameter can be used to
specify credentials for the Windows Service account that the Agent is operated for.

.PARAMETER Release
Specifies a release number of the JS7 Agent such as 2.3.1 to be used.

The release will be downloaded from the SOS web site if the -Tarball parameter is not used.

.PARAMETER Tarball
Optionally specifies the path to a .zip or .tar.gz file that holds the Agent installation files.
If this parameter is not used the installer tarball will be downloaded from the SOS web site for the release indicated with the -Release parameter.

Users can check if the connection to a specific URL is bypassed or is using a proxy with a command such as:
([System.Net.WebRequest]::GetSystemWebproxy()).IsBypassed("https://download.sos-berlin.com")

For use with PowerShell 7 users can specify environment variables to perform download using a proxy:

* HTTP_PROXY - proxy for HTTP requests
* HTTPS_PROXY - proxy for HTTPS requests
* ALL_PROXY - proxy for both HTTP and HTTPS
* NO_PROXY - proxy exclusion address list

.PARAMETER Patch
A patch is identified by an issue key and a specific release in the SOS Change Management System.

For example the -Patch JS-1984 -Release 2.2.3 parameters will download an (empty) sample patch from the SOS web site:

For Unix and Windows the download file is https://download.sos-berlin.com/patches/2.2.3-patch/js7_agent.2.2.3-PATCH.JS-1984.tar.gz

Patches can be individually downloaded and can be made available from the -Tarball parameter.

For example the -Patch JS-1984 -Tarball /tmp/js7_agent.2.2.3-PATCH.JS-1984.tar.gz parameters will apply the patch from the downloaded file.

Patches are added to the Agent's <home>/lib/patches directory.
Note that patches will be removed when updating the Agent installation later on.

To apply patches the Agent has to be restarted. The -Restart or -ExecStart, -ExecStop parameters can be used for automated restart.

.PARAMETER PatchJar
Opetionally specifies the path to a .jar file that holds a patch.

The patch .jar file has to be downloaded individually and will be copied to the Agent's <home>/lib/patches directory.

.PARAMETER LicenseKey
Specifies the path to a license key file (*.pem, *.crt) for use with a commercial license.
A license key file is required should JS7 cluster operations for JOC Cockpit, Controller or Agents be used.

The license key file activates the licensed binary code that implements cluster operations, see -LicenseBin parameter.

.PARAMETER LicenseBin
Specifies the path to a license binary file (*.jar) that implements cluster operations.

Use of licensed binary code is activated by a license key file, see -LicenseKey.

.PARAMETER InstanceScript
Specifies the path to an Instance Start Script that acts as a template and that is copied to the 'bin' directory.

Users are free to choose any name for the Instance Start Script template. In the target directory the file name agent_<http-port>.sh|.cmd will be used.

The script has to be executable for the Agent daemon or Windows Service, see -User parameter.
Permissions of the script are not changed by the Installation Script.
The Installation Script will perform replacements in the Instance Start Script template for known placeholders such as <JS7_AGENT_USER>,
for details see ./bin/agent_instance.sh-example and .\bin\agent_instance.cmd-example.

.PARAMETER BackupDir
If a backup directory is specified then an Agent's existing home and data directories will be added to backup files in this directory.
The backup file type is .tar.gz for Unix and Windows.

File names are created according to the pattern:

* backup_js7_agent.<hostname>.<release>.home.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.tar.gz|.tar.gz
* backup_js7_agent.<hostname>.<release>.data.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.tar.gz|.tar.gz

For example: backup_js7_agent.centostest_primary.2.3.1.home.2022-03-19T20-50-45.tar.gz

.PARAMETER LogDir
If a log directory is specified then the Installation Script will log information about processing steps to a log file in this directory.
File names are created according to the pattern: install_js7_agent.<hostname>.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.log
For example: install_js7_agent.centostest_primary.2022-03-19T20-50-45.log

.PARAMETER ExecStart
This parameter can be used should the Agent be started after installation.
For example, when using systemd for Unix or using Windows Services then the -ExecStart "StartService" parameter value
will start the Agent service provided that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStart "sudo systemctl start js7_agent_4445".

For Unix systemd service files see the 'JS7 - systemd Service Files for automated Startup and Shutdown with Unix Systems' article.
This parameter is an alternative to use of the -Restart switch which will start the Agent from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ExecStop
This parameter can be used should the Agent be stopped before installation.
For example, when using Unix systemd or Windows Services then
the -ExecStop "StopService" parameter value will stop the Agent service provided
that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStop "sudo systemctl stop js7_agent_4445".
This parameter is an alternative to use of the -Restart switch which stops the Agent from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ReturnValues
Optionally specifies the path to a file to which return values will be added in the format <name>=<key>. For example:

log_file=install_js7_agent.centostest_primary.2022-03-20T04-54-31.log
backup_file=backup_js7_agent.centostest_primary.2.3.1.2022-03-20T04-54-31.tar.gz

An existing file will be overwritten. It is recommended to use a unique file name such as /tmp/return.$PID.properties.
A value from the file can be retrieved like this:

* Unix
** backup=$(cat /tmp/return.$$.properties | grep "backup_file" | cut -d'=' -f2)
* Windows
** $backup = ( Get-Content /tmp/return.$PID.properties | Select-String "^backup_file[ ]*=[ ]*(.*)" ).Matches.Groups[1].value

.PARAMETER DeployDir
Specifies the path to a deployment directory that holds configuration files and sub-directories that will be copied to the <config> directory.
A deployment directory allows to manage central copies of configuration files such as agent.conf, private.conf, log4j2.xml etc.

Use of a deployment directory has lower precedence as files can be overwritten by individual parameters such as -AgentConf, -PrivateConf etc.

.PARAMETER AgentConf
Specifies the path to a configuration file for global Agent configuration items. The file will be copied to the <config>/agent.conf file.

Any path to a file can be used as a value of this parameter, however, the target file name agent.conf will be used.

.PARAMETER PrivateConf
Specifies the path to a configuration file for private Agent configuration items. The file will be copied to the <config>/private/private.conf file.

Any path to a file can be used as a value of this parameter, however, the target file name private.conf will be used.

.PARAMETER ControllerId
Specifies the Controller ID, a unique identifier of the Controller installation. Agents will be dedicated to the Controller with the given Controller ID.
The Controller ID is used in the Agent's private.conf file to specify which Controller can access a given Agent.

.PARAMETER ControllerPrimaryCert
Specifies the path to the SSL/TLS certificate of the Primary Controller instance.
The Installation Script extracts the distinguished name from the given certificate and adds it to the Agent's private.conf file
to allow HTTPS connections from the given Controller using mutual authentication without the need for passwords.

.PARAMETER ControllerSecondaryCert
Corresponds to the -ControllerPrimaryCert parameter and is used for the Secondary Controller instance.

.PARAMETER AgentClusterId
Specifies the Agent Cluster ID, a unique identifier of the Agent Cluster. This is not the Primary/Secondary Director Agent ID.

Subagents will be dedicated to the Agent Cluster with the given Agent Cluster ID.
The Agent Cluster ID is used in the Agent's private.conf file to specify which pairing Director Agent instance in can access the given Director Agent instance.

.PARAMETER DirectorPrimaryCert
Specifies the path to the SSL/TLS certificate of the Primary Director Agent instance.
The Installation Script extracts the distinguished name from the given certificate and adds it to the Agent's private.conf file
to allow HTTPS connections from the given Director Agent instance using mutual authentication without the need for passwords.

.PARAMETER DirectorSecondaryCert
Corresponds to the -DirectorPrimaryCert parameter and is used for the Secondary Director Agent instance.

.PARAMETER HttpPort
Specifies the HTTP port that the Agent is operated for. The default value is 4445.
The Agent by default makes use of a configuration directory ./var_<http-port> that will be excluded from a backup taken with the -BackupDir parameter.

In addition the HTTP port is used to identify the Agent Instance Start Script typically available from the ./bin/agent_<http-port>.sh|.cmd script
and to specify the value of the JS7_AGENT_HTTP_PORT environment variable in the script.

The port can be prefixed by the network interface, for example localhost:4445.
When used with the -Restart switch the HTTP port is used to identify if the Agent is running.

.PARAMETER HttpsPort
Specifies the HTTPS port that the Agent is operated for. The HTTPS port is specified in the Agent Instance Start Script typically available
from the ./bin/agent_<http-port>.sh|.cmd script with the environment variable JS7_AGENT_HTTPS_PORT.

Use of HTTPS requires a keystore and truststore to be present, see -Keystore and -Truststore parameters.
The port can be prefixed by the network interface, for example batch.example.com:4445.

.PARAMETER PidFileDir
Specifies the directory to which the Agent stores its PID file. By default the <data>/logs directory is used.
When using SELinux then it is recommended to specify the /var/run directory, see the 'JS7 - How to install for SELinux' article.

.PARAMETER PidFileName
Specifies the name of the PID file in Unix environments. By default the file name agent.pid is used.
The PID file is created in the directory specified by the -PidFileDir parameter.

.PARAMETER Keystore
Specifies the path to a PKCS12 keystore file that holds the private key and certificate for HTTPS connections to the Agent.
Users are free to specify any file name, typically the name https-keystore.p12 is used. The keystore file will be copied to the <config>/private directory.

If a keystore file is made available then the Agent's <config>/private/private.conf file has to hold a reference to the keystore location and optionally the keystore password.
It is therefore recommended to use the -PrivateConf parameter to deploy an individual private.conf file that holds settings related to a keystore.
For automating the creation of keystores see the 'JS7 - How to add SSL TLS Certificates to Keystore and Truststore' article.

.PARAMETER KeystorePassword
Specifies the password for access to the keystore from a secure string. Use of a keystore password is required.

The are a number of ways how to specify secure strings, for example:

-KeystorePassword ( 'secret' | ConvertTo-SecureString -AsPlainText -Force )

.PARAMETER KeyAlias
If a keystore holds more than one private key, for example if separate pairs of private keys/certificates for server authentication and client authentication exist, then it is not determined which private key/certificate will be used.

The alias name of a given private key/certificate is specified when the entry is added to the keystore. The alias name allows to indicate a specific private key/certificate to be used.

.PARAMETER ClientKeystore
Use of this parameter is optional. It can be used if separate certificates for Server Authentication and Client Authentication are used.

The Client Authentication private key and certificate can be added to a client keystore. The location and configuration of a client keystore correspond to the -Keystore parameter.

.PARAMETER ClientKeystorePassword

Specifies the password for access to the client keystore. Use of a client keystore password is required if a client keystore is used.

Consider explanations for the -KeystorePassword parameter.

.PARAMETER ClientKeystoreAlias
If a client keystore holds more than one private key, for example if a number of private keys/certificates for client authentication exist, then it is not determined which private key/certificate will be used.

Consider explanations for the -KeyAlias parameter.

.PARAMETER Truststore
Specifies the path to a PKCS12 truststore file that holds the certificate(s) for HTTPS connections to the Agent using mutual authentication .
Users are free to specify any file name, typically the name https-truststore.p12 is used. The truststore file will be copied to the <config>/private directory.

If a truststore file is made available then the Agent's <config>/private/private.conf file has to hold a reference to the truststore location and optionally the truststore password.
It is therefore recommended to use the -PrivateConf parameter to deploy an individual private.conf file that holds settings related to a truststore.
For automating the creation of truststores see the 'JS7 - How to add SSL TLS Certificates to Keystore and Truststore' article.

.PARAMETER TruststorePassword
Specifies the password for access to the truststore from a secure string.
Use of a password is recommended: it is not primarily intended to protect access to the truststore, but to ensure integrity.
The password is intended to allow verification that truststore entries have been added using the same password.

The are a number of ways how to specify secure strings, for example:

-TruststorePassword ( 'secret' | ConvertTo-SecureString -AsPlainText -Force )

.PARAMETER JavaHome
Specifies the Java home directory that will be made available to the Agent from the JAVA_HOME environment variable
specified with the Agent Instance Start Script typically available from the ./bin/agent_<http-port>.sh|.cmd script.

.PARAMETER JavaOptions
Specifies the Java options that will be made available to the Agent from the JAVA_OPTIONS environment variable specified with the Agent Instance Start Script typically available from the ./bin/agent_<http-port>.sh|.cmd script.

Java options can be used for example to specify Java heap space settings for the Agent.
If more than one Java option is used then the value has to be quoted, for example -JavaOptions "-Xms256m -Xmx512m".

.PARAMETER StopTimeout
Specifies the timeout in seconds for which the Installation Script will wait for the Agent to terminates, for example if jobs are running.
If this timeout is exceeded then the Agent will be killed. A timeout is not applicable when used with the -Abort or -Kill parameters.

.PARAMETER ServiceDir
For Unix environments specifies the systemd service directory to which the Agent's service file will be copied if the -MakeService switch is used.
By default the /usr/lib/systemd/system directory will be used. Users can specify an alternative location.

.PARAMETER ServiceFile
For Unix environments specifies the path to a systemd service file that acts as a template and that will be copied to the Agent's <home>/bin directory.
Users are free to choose any file name as a template for the service file. The resulting service file name will be agent_<http-port>.service.
The Installation Script will perform replacements in the service file to update paths and the port to be used, for details see ./bin/agent.service-example.

.PARAMETER ServiceName
For Unix environments specifies the name of the systemd service that will be created if the -MakeService switch is used.
By default the service name js7_agent_<http-port> will be used.

For Windows the service name is not specified, instead the service name js7_agent_<http-port> will be used.

.PARAMETER ServiceCredentials
In Windows environments the credentials for the Windows service account can be specified for which the Agent should be operated.

A credentials object can be created in a number of ways, for example:

$cred = ( New-Object -typename System.Management.Automation.PSCredential -ArgumentList '.\sos', ( 'secret' | ConvertTo-SecureString -AsPlainText -Force) )

The first argument '.\sos' specifies the user account, the second argument 'secret' specifies the password of the Windows Service account.
Consider that the user account is specified from a local account using the .\ prefix or from a domain account using account@domain.

.PARAMETER ServiceStartMode
For Windows environemnts one of the following start modes can be set when used with the -ServiceCredentials parameter:

* System
* Automatic
* Manual
* Disabled

By default automatic start is used.

.PARAMETER ServiceDisplayName
For Windows environments allows to specify the display name of the Agent's Windows Service.

.PARAMETER Active
This setting is used for Director Agents only. It specifies that the Director Agent instance should act as the active node in a Director Agent Cluster during initial operation.

This setting is not required for installation of a Primary Director Agent in an Agent Cluster. It can be used to revert a Secondary Director Agent to a Primary Director Agent.

.PARAMETER Standby
This setting is used for Director Agents only. It specifies that the Director Agent instance should act as the standby node in a Director Agent Cluster during initial operation.

This setting is required when installing a Secondary Director Agent instance in an Agent Cluster.

.PARAMETER NoYade
Excludes the YADE file transfer utility from Agent installation.

YADE is available from the yade sub-directory of the Agent's <home> directory.
If this switch is used then an existing yade sub-directory will be removed and
YADE will not be copied from the installation tarball to the Agent's <home> directory.

.PARAMETER NoInstall
Specifies if the Installation Script should be used to update configuration items without changes to the binary files of the installation.
In fact no installation is performed but configuration changes as for example specified with the -Keystore parameter will be applied.

.PARAMETER UseInstall
Resuses an existing Agent installation. No installation files are specified as with the -Release or -Tarball parameters.

Instead, the new Agent's data directory and the respective service will be created.

.PARAMETER Uninstall
Uninstalls the Agent including the steps to stop and remove a running Agent service and to remove the <home> and <data> directories.

.PARAMETER UninstallHome
Uninstalls the Agent but preservers the Agent's <data> directory.

.PARAMETER UninstallData
Uninstalls the Agent but preservers the Agent's <home> directory.

.PARAMETER ShowLogs
Displays the log output created by the Installation Script if the -LogDir parameter is used.

.PARAMETER MakeDirs
If directories are missing that are indicated with the -HomeDir, -BackupDir or -LogDir parameters then they will be created.

.PARAMETER MakeService
Specifies that for Unix environments a systemd service should be created, for Windows environments a Windows Service should be created.
In Unix environments the service name will be created from the -ServiceName parameter value or from its default value.

.PARAMETER MoveLibs
For an existing Agent installation the lib sub-directory includes .jar files that carry the release number in their file names.
If replaced by a newer version the lib directory has to be moved or removed.
This switch tries to move the directory to a previous version number as indicated from the .version file in the Agent's home directory,
for example to rename lib to lib.2.3.1.

Files in the lib/user_lib sub-directory are preserved.

.PARAMETER RemoveJournal
If Agents have been installed for the wrong operating mode (standalone, clustered) then the Agent's journal in the <data>/state directory can be removed.
This operation removes any information such as orders submitted to an Agent and requires the Agent to be re-registered to a Controller.

.PARAMETER Restart
Stops a running Agent before installation and starts the Agent after installation using the Agent's Instance Start Script.
This switch can be used with the -Abort and -Kill switches to control the way how the Agent is terminated.
This switch is ignored if the -ExecStart or -ExecStop parameters are used.

.PARAMETER Abort
Aborts a running Agent and kills any running tasks including child processes if used with the -Restart switch.
Aborting an Agent includes to terminate the Agent in an orderly manner which allows to close journal files consistently.

.PARAMETER Kill
Kills a running Agent and any running tasks if used with the -Restart switch.
This includes killing child processes of running tasks.

Killing an Agent prevents journal files from being closed in an orderly manner.

.EXAMPLE
Install-JS7Agent.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\agent" -Data "C:\ProgramData\sos-berlin.com\js7\agent_4445" -Release 2.5.1 -HttpPort 4445 -MakeDirs

Downloads and installs the Agent release to the indicated location.

.EXAMPLE
Install-JS7Agent.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\agent" -Data "C:\ProgramData\sos-berlin.com\js7\agent_4445" -Tarball /tmp/js7_agent_windows.2.5.1.zip -BackupDir /tmp/backups -LogDir /tmp/logs -HttpPort 4445 -MakeDirs

Applies the Agent release from a tarball and installs to the indicated locations. A backup is taken and log files are created.

.EXAMPLE
Install-JS7Agent.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\agent" -Data "C:\ProgramData\sos-berlin.com\js7\agent_4445" -Tarball /tmp/js7_agent_windows.2.5.1.zip -HttpPort localhost:4445 -HttpsPort apmacwin:4445 -JavaHome "C:\Program Files\Java\jdk-11.0.12+7-jre" -JavaOptions "-Xms100m -Xmx256m" -MakeDirs

Applies the Agent release from a tarball and installs to the indicated locations. HTTP and HTTPS port are the same using different network interfaces. The location of Java and Java Options are indicated.

#>

[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HomeDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Data,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Config,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Logs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Work,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $User,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Release,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Tarball,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Patch,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $PatchJar,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $LicenseKey,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $LicenseBin,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstanceScript,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BackupDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $LogDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExecStart,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExecStop,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ReturnValues,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $DeployDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AgentConf,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $PrivateConf,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ControllerId = 'controller',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AgentClusterId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HttpPort = '4445',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HttpsPort,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $PidFileDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $PidFileName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ControllerPrimaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ControllerSecondaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DirectorPrimaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DirectorSecondaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Keystore,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Security.SecureString] $KeystorePassword,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $KeyAlias,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ClientKeystore,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Security.SecureString] $ClientKeystorePassword,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ClientKeyAlias,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Truststore,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Security.SecureString] $TruststorePassword,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JavaHome,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JavaOptions,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $StopTimeout,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceDir = '/usr/lib/systemd/system',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceFile,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ServiceCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('System','Automatic','Manual','Disabled')]
    [string] $ServiceStartMode = 'Automatic',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceDisplayName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Active,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Standby,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoYade,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoInstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseInstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Uninstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UninstallHome,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UninstallData,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ShowLogs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $MakeDirs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $MakeService,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $MoveLibs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $RemoveJournal,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Restart,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Abort,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Kill
)

Begin
{
    switch ([System.Environment]::OSVersion.Platform)
    {
        'Win32NT' {
            New-Variable -Option Constant -Name IsWindows -Value $True -ErrorAction SilentlyContinue
            New-Variable -Option Constant -Name IsLinux  -Value $false -ErrorAction SilentlyContinue
            New-Variable -Option Constant -Name IsMacOs  -Value $false -ErrorAction SilentlyContinue
         }
    }

    # argument defaults
    if ( !$User )
    {
        $script:User = if ( $env:USERNAME ) { $env:USERNAME } else { $env:USER }
    }

    if ( $HttpPort -and $HttpPort.IndexOf(':') -gt 0 )
    {
        $script:HttpNetworkInterface = $HttpPort.Substring( 0, $HttpPort.IndexOf(':') )
        $script:HttpPort = $HttpPort.Substring( $HttpPort.IndexOf(':') + 1 )
    }

    if ( $HttpsPort -and $HttpsPort.IndexOf(':') -gt 0 )
    {
        $script:HttpsNetworkInterface = $HttpsPort.Substring( 0, $HttpsPort.IndexOf(':') )
        $script:HttpsPort = $HttpsPort.Substring( $HttpsPort.IndexOf(':') + 1 )
    }

    if ( $isWindows )
    {
        $script:ServiceNameDefault = "js7_agent_$($HttpPort)"
        if ( !$ServiceName )
        {
            $script:ServiceName = $ServiceNameDefault
        }
    } else {
        $script:ServiceNameDefault = "js7_agent_$($HttpPort).service"
        if ( !$ServiceName )
        {
            $script:ServiceName = $ServiceNameDefault
        } else {
            if ( $ServiceName.IndexOf( '.service' ) -lt 0 )
            {
                $script:ServiceName = "$($script:ServiceName).service"
            }
        }
    }

    if ( $UseInstall )
    {
        $script:NoInstall = $UseInstall
    }

    if ( $Uninstall )
    {
        $script:UninstallHome = $Uninstall
        $script:UninstallData = $Uninstall
    } elseif ( $UninstallHome -or $UninstallData ) {
        $script:Uninstall = $true
    }

    # nop operations to work around ScriptAnalyzer bugs
    $script:ServiceDir = $ServiceDir
    $script:ExecStart = $ExecStart
    $script:ExecStop = $ExecStop
    $script:ReturnValues = $ReturnValues
    $script:StopTimeout = $StopTimeout
    $script:ShowLogs = $ShowLogs
    $script:Restart = $Restart
    $script:Abort = $Abort
    $script:Kill = $Kill

    # default variables
    $script:hostname = if ( $env:COMPUTERNAME ) { $env:COMPUTERNAME } else { $env:HOSTNAME }
    $script:startTime = Get-Date
    $script:logFile = $null

    if ( $isWindows )
    {
        $script:osPlatform = 'windows'
    } else {
        $script:osPlatform = 'unix'
    }
}

Process
{
    # inline functions

    function Out-LogInfo( [string] $Message )
    {
        if ( $logFile )
        {
            $Message | Out-File $logFile -Append
        }

        if ( !$ShowLogs )
        {
            Write-Output $Message
        }
    }

    function Out-LogError( [string] $Message )
    {
        if ( $logFile )
        {
            "[ERROR] $($Message)" | Out-File $logFile -Append
        }

        if ( !$ShowLogs )
        {
            Write-Error $Message
        }
    }

    function Out-LogVerbose( [string] $Message )
    {
       if ( $logFile )
        {
            "[VERBOSE] $($Message)" | Out-File $logFile -Append
        }

        if ( !$ShowLogs )
        {
            Write-Verbose $Message
        }
    }

    function Out-LogDebug( [string] $Message )
    {
       if ( $logFile )
        {
            "[DEBUG] $($Message)" | Out-File $logFile -Append
        }

        if ( !$ShowLogs )
        {
            Write-Debug $Message
        }
    }

    function Get-PID()
    {
        if ( $isWindows )
        {
            if ( $HttpPort )
            {
                ( Get-Process -Name $ServiceName -ErrorAction silentlycontinue ).length
            } else {
                ( Get-Process -Name "js7_agent_*" -ErrorAction silentlycontinue ).length
            }
        } else {
            if ( $HttpPort )
            {
                sh -c "ps -ef | grep -E ""js7\.agent\.main\.AgentMain.*--http-port=$($HttpPort)"" | grep -v ""grep"" | awk '{print $2}'"
            } else {
                sh -c "ps -ef | grep -E ""js7\.agent\.main\.AgentMain.*"" | grep -v ""grep"" | awk '{print $2}'"
            }
        }
    }

    function Start-AgentBasic()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $Restart -or $ExecStart -eq 'StartService' )
            {
                $service = Get-Service -Name $ServiceName -ErrorAction silentlycontinue

                if ( $service )
                {
                    if ( $service.Status -ne 'running' )
                    {
                        if ( $PSCmdlet.ShouldProcess( 'Start-AgentBasic', 'start service' ) )
                        {
                            Out-LogInfo ".. starting Agent Windows Service (Start-AgentBasic): $($ServiceName)"
                            Start-Service -Name $ServiceName | Out-Null
                        }
                    }
                } else {
                    if ( !$MakeService )
                    {
                        Out-LogError ".. Agent Windows Service not found and -MakeService switch not present (Start-AgentBasic): $($ServiceName)"
                    } else {
                        Out-LogError ".. Agent Windows Service not found (Start-AgentBasic): $($ServiceName)"
                    }
                }
            }
        } else {
            if ( $ExecStart )
            {
                Out-LogInfo ".. starting Agent: $($ExecStart)"
                if ( $ExecStart -eq 'StartService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStart, 'start service' ) )
                    {
                        Start-AgentService
                    }
                } else {
                    sh -c "$($ExecStart)"
                }
            } else {
                if ( $Restart )
                {
                    if ( Test-Path -Path "$($HomeDir)/bin" -PathType container )
                    {
                        if ( Test-Path -Path "$($HomeDir)/bin/agent_$($HttpPort).sh" -PathType leaf)
                        {
                            Out-LogInfo ".. starting Agent: $($HomeDir)/bin/agent_$($HttpPort).sh start"

                            if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                            {
                                $startAgentOutputFile = "/tmp/js7_install_agent_start_$($PID).tmp"
                                New-Item $startAgentOutputFile -ItemType file
                                sh -c "( ""$($HomeDir)/bin/agent_$($HttpPort).sh"" start > ""$($startAgentOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startAgentOutputFile))"" && exit 5 )"
                                Out-LogInfo Get-Content -Path $startAgentOutputFile
                            } else {
                                sh -c "$($HomeDir)/bin/agent_$($HttpPort).sh start"
                            }
                        } else {
                            if ( Test-Path -Path "$($HomeDir)/bin/agent.sh" -PathType leaf )
                            {
                                Out-LogInfo ".. starting Agent: $($HomeDir)/bin/agent.sh start"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $startAgentOutputFile = "/tmp/js7_install_agent_start_$($PID).tmp"
                                    New-Item $startAgentOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/bin/agent.sh"" start > ""$($startAgentOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startAgentOutputFile))"" && exit 5 )"
                                    Out-LogInfo Get-Content -Path $startAgentOutputFile
                                } else {
                                    sh -c "$($HomeDir)/bin/agent.sh start"
                                }
                            } else {
                                Out-LogError "could not start Agent, start script missing: $($HomeDir)/bin/agent_$($HttpPort).sh, $($HomeDir)/bin/agent.sh"
                            }
                        }
                    } else {
                        Out-LogError "could not start Agent, directory missing: $($HomeDir)/bin"
                    }
                }
            }
        }
    }

    function Stop-AgentBasic()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $Restart -or $ExecStop -eq 'StopService' )
            {
                $service = Get-Service -Name $ServiceName -ErrorAction silentlycontinue

                if ( $service )
                {
                    if ( $service.Status -eq 'running' )
                    {
                        if ( $PSCmdlet.ShouldProcess( 'Stop-AgentBasic', 'stop service' ) )
                        {
                            Out-LogInfo ".. stopping Agent Windows Service (Stop-AgentBasic): $($ServiceName)"
                            Stop-Service -Name $ServiceName -Force | Out-Null
                            Start-Sleep -Seconds 3
                        }
                    }
                } else {
                    Out-LogInfo ".. Agent Windows Service not found (Stop-AgentBasic): $($ServiceName)"
                }
            }
        } else {
            if ( $ExecStop )
            {
                Out-LogInfo ".. stopping Agent: $($ExecStop)"
                if ( $ExecStop -eq 'StopService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStop, 'stop service' ) )
                    {
                        Stop-AgentService
                    }
                } else {
                    sh -c "$($ExecStop)"
                }
            } else {
                if ( $Restart )
                {
                    if ( $Kill )
                    {
                        $stopOption = 'kill'
                    } else {
                        if ( $Abort )
                        {
                            $stopOption = 'abort'
                        } else {
                            $stopOption = 'stop'
                            if ( $StopTimeout )
                            {
                                $stopOption = "$($stopOption) --timeout=$($StopTimeout)"
                            }
                        }
                    }

                    if ( Get-PID )
                    {
                        if ( Test-Path -Path "$($HomeDir)/bin" -PathType container )
                        {
                            if ( Test-Path -Path "$($HomeDir)/bin/agent_$($HttpPort).sh" -PathType leaf )
                            {
                                Out-LogInfo ".. stopping Agent: $($HomeDir)/bin/agent_$($HttpPort).sh $($stopOption)"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $stopAgentOutputFile = "/tmp/js7_install_agent_stop_$($PID).tmp"
                                    New-Item $stopAgentOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/bin/agent_$($HttpPort).sh"" $($stopOption) > ""$($stopAgentOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopAgentOutputFile))"" && exit 6 )"
                                    Out-LogInfo Get-Content -Path $stopAgentOutputFile
                                } else {
                                    sh -c "$($HomeDir)/bin/agent_$($HttpPort).sh $($stopOption)"
                                }
                            } else {
                                if ( Test-Path -Path "$($HomeDir)/bin/agent.sh" )
                                {
                                    Out-LogInfo ".. stopping Agent: $($HomeDir)/bin/agent.sh $($stopOption)"

                                    if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                    {
                                        $stopAgentOutputFile = "/tmp/js7_install_agent_stop_$($PID).tmp"
                                        New-Item -Path $stopAgentOutputFile -ItemType file
                                        sh -c "( ""$($HomeDir)/bin/agent.sh"" $($stopOption) > ""$($stopAgentOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopAgentOutputFile))"" && exit 6 )"
                                        Out-LogInfo Get-Content -Path $stopAgentOutputFile
                                    } else {
                                        sh -c "$($HomeDir)/bin/agent.sh $($stopOption)"
                                    }
                                } else {
                                    Out-LogError "could not stop Agent, start script missing: $($HomeDir)/bin/agent_$($HttpPort).sh, $($HomeDir)/bin/agent.sh"
                                }
                            }
                        } else {
                            Out-LogError "could not stop Agent, directory missing: $($HomeDir)/bin"
                        }
                    } else {
                        Out-LogInfo ".. Agent not started"
                    }
                }
            }
        }
    }

    function Register-Service( [string] $useSystemdServiceFile )
    {
        if ( $isWindows )
        {
            if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
            {
                Out-LogInfo ".... removing Agent Windows Service using command: cmd.exe /S /C ""$($HomeDir)/bin/agent_$($HttpPort).cmd"" remove-service"
                cmd.exe /S /C """$($HomeDir)/bin/agent_$($HttpPort).cmd"" remove-service"
            }

            Out-LogInfo ".... installing Agent Windows Service using command: cmd.exe /S /C ""$($HomeDir)\bin\agent_$($HttpPort).cmd"" install-service"
            cmd.exe /S /C """$($HomeDir)\bin\agent_$($HttpPort).cmd"" install-service"
        } else {
            $id = sh -c "id -u"
            if ( $id -eq 0 )
            {
                $useSudo = ''
            } else {
                $useSudo = 'sudo'
            }

            $rc = $null
            $rc = sh -c "($($useSudo) systemctl cat -- ""$($ServiceName)"" >/dev/null 2>&1) || rc=$?"
            if ( $rc )
            {
                Out-LogInfo ".. adding systemd service: $($ServiceName)"
            } else {
                Out-LogInfo ".. updating systemd service: $($ServiceName)"
            }

            Out-LogInfo ".... copying systemd service file $($useSystemdServiceFile) to $($ServiceDir)/$($ServiceName)"
            sh -c "$($useSudo) cp -p ""$($useSystemdServiceFile)"" ""$($ServiceDir)/$($ServiceName)"""

            Out-LogInfo ".... systemd service command: $($useSudo) systemctl enable $($ServiceName)"
            $rc = $null
            sh -c "($($useSudo) systemctl enable ""$($ServiceName)"" >/dev/null 2>&1) || rc=$?"
            if ( !$rc )
            {
                Out-LogInfo ".... systemd service enabled: $($ServiceName)"

                Out-LogInfo ".... systemd service command: $($useSudo) systemctl daemon-reload"
                $rc = sh -c "($($useSudo) systemctl daemon-reload >/dev/null 2>&1) || rc=$?"
                if ( !$rc )
                {
                    Out-LogInfo ".... systemd service configuration reloaded: $($ServiceName)"
                } else {
                    Out-LogError "could not reload systemd daemon configuration for service: $($ServiceName)"
                }
            } else {
                Out-LogError "could not enable systemd service: $($ServiceName)"
            }
        }
    }

    function Start-AgentService()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Start-AgentService', 'start service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Start-Service -Name $ServiceName | Out-Null
                } else {
                    Out-LogInfo "Agent Windows Service not found: $($ServiceName)"
                }
            }
        } else {
            $id = sh -c "id -u"
            if ( $id -eq 0 )
            {
                $useSudo = ''
            } else {
                $useSudo = 'sudo'
            }

            Out-LogInfo ".... systemd service command: $($useSudo) systemctl start $($ServiceName)"
            $rc = sh -c "($($useSudo) systemctl start ""$($ServiceName)"" >/dev/null 2>&1) || rc=$?"
            if ( !$rc )
            {
                Out-LogInfo ".... systemd service started: $($ServiceName)"
            } else {
                Out-LogError "could not start systemd service: $($ServiceName)"
            }
        }
    }

    function Stop-AgentService()
    {
        [cmdletbinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Stop-AgentService', 'stop service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Stop-Service -Name $ServiceName -ErrorAction silentlycontinue | Out-Null
                    Start-Sleep -Seconds 3
                } else {
                    Out-LogInfo "Agent Windows Service not found (Stop-AgentService): $($ServiceName)"
                }
            }
        } else {
            $id = sh -c "id -u"
            if ( $id -eq 0 )
            {
                $useSudo = ''
            } else {
                $useSudo = 'sudo'
            }

            $rc = sh -c "($($useSudo) systemctl cat -- ""$($ServiceName)"" >/dev/null 2>&1) || rc=`$?"
            if ( !$rc )
            {
                Out-LogInfo ".... systemd service command: $($useSudo) systemctl stop $($ServiceName)"
                $rc = sh -c "($($useSudo) systemctl stop ""$($ServiceName)"" >/dev/null 2>&1) || rc=`$?"
                if ( !$rc )
                {
                    Out-LogInfo ".... systemd service stopped: $($ServiceName)"
                } else {
                    Out-LogError "could not stop systemd service: $($ServiceName)"
                }
            }
        }
    }

    function Test-Arguments()
    {
        if ( !$HomeDir )
        {
            Out-LogError "Agent home directory has to be specified: -HomeDir"
            return 1
        }

        if ( $Uninstall -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Agent home directory not found and -Uninstall switch is present: -HomeDir $HomeDir"
            return 1
        }

        if ( !$MakeDirs -and !$Uninstall -and $HomeDir -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Agent home directory not found and -MakeDirs switch not present: -HomeDir $HomeDir"
            return 1
        }

        if ( !$MakeDirs -and $Data -and !(Test-Path -Path $Data -PathType container) )
        {
            Out-LogError "Agent data directory not found and -MakeDirs switch not present: -Data $Data"
            return 1
        }

        if ( !$MakeDirs -and $Config -and !(Test-Path -Path $Config -PathType container) )
        {
            Out-LogError "Agent configuration directory not found and -MakeDirs switch not present: -Config $Config"
            return 1
        }

        if ( !$MakeDirs -and $Logs -and !(Test-Path -Path $Logs -PathType container) )
        {
            Out-LogError "Agent log directory not found and -MakeDirs switch not present: -Logs $Logs"
            return 1
        }

        if ( !$MakeDirs -and $Work -and !(Test-Path -Path $Work -PathType container) )
        {
            Out-LogError "Agent working directory not found and -MakeDirs switch not present: -Work $Work"
            return 1
        }

        if ( !$MakeDirs -and $PidFileDir -and !(Test-Path -Path $PidFileDir -PathType container) )
        {
            Out-LogError "Agent PID file directory not found and -MakeDirs switch not present: -PidFileDir $PidFileDir"
            return 1
        }

        if ( $DeployDir )
        {
            foreach( $directory in $DeployDir )
            {
                if ( !(Test-Path -Path $directory -PathType container) )
                {
                    Out-LogError "Deployment Directory not found: -DeployDir $($directory)"
                    return 1
                }
            }
        }

        if ( !$MakeDirs -and $BackupDir -and !(Test-Path -Path $BackupDir -PathType container) )
        {
            Out-LogError "Agent backup directory not found and -MakeDirs switch not present: -BackupDir $BackupDir"
            return 1
        }

        if ( !$MakeDirs -and $LogDir -and !(Test-Path -Path $LogDir -PathType container) )
        {
            Out-LogError "Agent log directory not found and -MakeDirs switch not present: -LogDir $LogDir"
            return 1
        }

        if ( !$Release -and !$Tarball -and !$PatchJar -and !$NoInstall -and !$Uninstall )
        {
            Out-LogError "Release must be specified if -Tarball or -PatchJar options are not specified and -NoInstall or -Uninstall switches are not present: -Release"
            return 1
        }

        if ( $Tarball -and !(Test-Path -Path $Tarball -PathType leaf) )
        {
            Out-LogError "Tarball not found (*.zip):: -Tarball $Tarball"
            return 1
        }

        if ( $Tarball -and $Tarball.IndexOf('installer') -ge -0 )
        {
            Out-LogError "Probably wrong tarball in use: js7_agent_windows_installer.<release>.zip, instead use js7_agent_windows.<release>.zip: -Tarball $Tarball"
            return 1
        }

        if ( $Patch -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Agent home directory not found and -Patch option is present: -HomeDir $HomeDir"
            return 1
        }

        if ( $PatchJar -and !(Test-Path -Path $PatchJar -PathType leaf) )
        {
            Out-LogError "Patch file not found (*.jar): -PatchJar $PatchJar"
            return 1
        }

        if ( $LicenseKey -and !(Test-Path -Path $LicenseKey -PathType leaf) )
        {
            Out-LogError "License key file not found: -LicenseKey $LicenseKey"
            return 1
        }

        if ( $LicenseKey -and !$LicenseBin -and !$Release )
        {
            Out-LogError "License key without license binary file specification requires release to be specified: -LicenseBin or -Release"
            return 1
        }

        if ( $LicenseBin -and !(Test-Path -Path $LicenseBin -PathType leaf) )
        {
            Out-LogError "License binary file not found: -LicenseBin $LicenseBin"
            return 1
        }

        if ( $ShowLogs -and !$LogDir )
        {
            Out-LogError "Log directory not specified and -ShowLogs switch is present: -LogDir"
            return 1
        }

        if ( $InstanceScript -and !(Test-Path -Path $InstanceScript -PathType leaf) )
        {
            Out-LogError "Instance Start Script not found (.sh|.cmd): -InstanceScript $InstanceScript"
            return 1
        }

        if ( $JavaHome -and !(Test-Path -Path $JavaHome -PathType container) )
        {
            Out-LogError "Java Home directory not found: -JavaHome $JavaHome"
            return 1
        }

        if ( $JavaHome -and !(Get-Command "$($JavaHome)/bin/java" -ErrorAction silentlycontinue) )
        {
            Out-LogError "Java binary ./bin/java not found from Java Home directory: -JavaHome $JavaHome"
            return 1
        }

        if  ( !$JavaHome )
        {
            if ( $env:JAVA_HOME )
            {
                $java = (Get-Command "$($env:JAVA_HOME)/bin/java" -ErrorAction silentlycontinue)
            } else {
                $java = (Get-Command "java" -ErrorAction silentlycontinue)
            }

            if ( !$java )
            {
                Out-LogError "Java home not specified and no JAVA_HOME environment variable in place: -JavaHome"
                return 1
            }
        }

        if ( $AgentConf -and !(Test-Path -Path $AgentConf -PathType leaf) )
        {
            Out-LogError "Agent configuration file not found (agent.conf): -AgentConf $AgentConf"
            return 1
        }

        if ( $PrivateConf -and !(Test-Path -Path $PrivateConf -PathType leaf) )
        {
            Out-LogError "Agent private configuration file not found (private.conf): -PrivateConf $PrivateConf"
            return 1
        }

        if ( $Active -and $Standby )
        {
            Out-LogError "Director Agent instance can be configured to be either active or standby, use -Active or -Standby"
            return 1
        }

        if ( $ControllerPrimaryCert -and !(Test-Path -Path $ControllerPrimaryCert -PathType leaf) )
        {
            Out-LogError "Primary/Standalone Controller certificate file not found: -ControllerPrimaryCert $ControllerPrimaryCert"
            return 1
        }

        if ( $ControllerSecondaryCert -and !(Test-Path -Path $ControllerSecondaryCert -PathType leaf) )
        {
            Out-LogError "Secondary Controller certificate file not found: -ControllerSecondaryCert $ControllerSecondaryCert"
            return 1
        }

        if ( $DirectorPrimaryCert -and !(Test-Path -Path $DirectorPrimaryCert -PathType leaf) )
        {
            Out-LogError "Primary Directory Agent certificate file not found: -DirectorPrimaryCert $DirectorPrimaryCert"
            return 1
        }

        if ( $DirectorSecondaryCert -and !(Test-Path -Path $DirectorSecondaryCert -PathType leaf) )
        {
            Out-LogError "Secondary Director Agent certificate file not found: -DirectorSecondaryCert $DirectorSecondaryCert"
            return 1
        }

        if ( $Keystore -and !(Test-Path -Path $Keystore -PathType leaf) )
        {
            Out-LogError "Keystore file not found (https-keystore.p12): -Keystore $Keystore"
            return 1
        }

        if ( $Truststore -and !(Test-Path -Path $Truststore -PathType leaf) )
        {
            Out-LogError "Truststore file not found (https-truststore.p12): -Truststore $Truststore"
            return 1
        }

        if ( !$isWindows -and $MakeService -and $ServiceDir -and !(Test-Path -Path $ServiceDir -PathType container) )
        {
            Out-LogError "systemd service directory not found and -MakeService switch present: -ServiceDir $ServiceDir"
            return 1
        }

        if ( !$isWindows -and $MakeService -and $ServiceFile -and !(Test-Path -Path $ServiceFile -PathType leaf) )
        {
            Out-LogError "systemd service file not found and -MakeService switch present: -ServiceFile $ServiceFile"
            return 1
        }

        if ( $NoInstall -and ( $Tarball -or -$Release) )
        {
            Out-LogError "-NoInstall switch present and options -Tarball or -Release specified: -NoInstall"
            return 1
        }

        if ( $Uninstall -and ( $Tarball -or -$Release) )
        {
            Out-LogError "-Uninstall switch present and options -Tarball or -Release specified: -Uninstall"
            return 1
        }

        if ( $HttpsPort -and !$ControllerId )
        {
            Out-LogError "Use of HTTPS port requires to specify Controller ID: -ControllerId"
            return 1
        }

        if ( !$HttpsPort -and $Keystore )
        {
            Out-LogError "-Keystore option present and no -HttpsPort option specified: -HttpsPort"
            return 1
        }

        if ( $isWindows -and $ServiceName -ne $ServiceNameDefault )
        {
            Out-LogError "Argument -ServiceName not applicable for Windows platform"
            return 1
        }

        if ( $isWindows -and $ServiceFile )
        {
            Out-LogError "Argument -ServiceFile not applicable for Windows platform"
            return 1
        }

        if ( !$isWindows -and $ServiceCredentials )
        {
            Out-LogError "Argument -ServiceCredentials not applicable for Unix platforms"
            return 1
        }

        if ( $isWindows -and ( $MakeService -or $Uninstall -or $Restart -or $ExecStart -eq 'StartService' -or $ExecStop -eq 'StopService' ) -and !(hasAdministratorRole) )
        {
            Out-LogError "Operation requires administrative permissions: -MakeService, -Uninstall, -Restart, -ExecStart, -ExecStop"
            return 1
        }

        return 0
    }

    function isPowerShellVersion( [int] $Major=-1, [int] $Minor=-1, [int] $Patch=-1 )
    {
        $rc = $false

        if ( $Major -gt -1 )
        {
            if ( $PSVersionTable.PSVersion.Major -eq $Major )
            {
                if ( $Minor -gt -1 )
                {
                    if ( $PSVersionTable.PSVersion.Minor -eq $Minor )
                    {
                        if ( $Patch -gt - 1 )
                        {
                            if ( $PSVersionTable.PSVersion.Patch -ge $Patch )
                            {
                                $rc = $true
                            }
                        } else {
                            $rc = $true
                        }
                    } elseif ( $PSVersionTable.PSVersion.Minor -gt $Minor ) {
                        $rc = $true
                    } else {
                        $rc = $true
                    }
                } else {
                    $rc = $true
                }
            } elseif ( $PSVersionTable.PSVersion.Major -gt $Major ) {
                $rc = $true
            }
        }

        $rc
    }

    function hasAdministratorRole()
    {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Final()
    {
        if ( $tarDir -and (Test-Path -Path $tarDir -PathType container) )
        {
            Remove-Item -Path $tarDir -Recurse -Force
        }

        if ( $startAgentOutputFile -and (Test-Path -Path $startAgentOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($startAgentOutputFile)"
            Remove-Item -Path $startAgentOutputFile -Force
        }

        if ( $stopAgentOutputFile -and (Test-Path -Path $stopAgentOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($stopAgentOutputFile)"
            Remove-Item -Path $stopAgentOutputFile -Force
        }

        if ( $ReturnValues )
        {
            Out-LogInfo ".. writing return values to: $($ReturnValues)"
            "log_file=$($logFile)" | Out-File $ReturnValues
            "backup_file=$($backupFile)" | Out-File $ReturnValues -Append
            "return_code=$($returnCode)" | Out-File $ReturnValues -Append
        }

        Out-LogInfo "-- end of log ----------------"

        if ( $ShowLogs -and (Test-Path -Path $logFile -PathType leaf) )
        {
            Get-Content -Path $logFile
        }
    }

    # ------------------------------
    # Main
    # ------------------------------

    if ( Test-Arguments -ne 0 )
    {
        return 1
    }

    if ( $LogDir )
    {
        if ( $MakeDirs -and !(Test-Path -Path $LogDir -PathType container) )
        {
            New-Item -Path $LogDir -ItemType directory | Out-Null
        }

        $logFile = "$($LogDir)/install_js7_agent.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
        while ( Test-Path -Path $logFile -PathType leaf )
        {
            Start-Sleep -Seconds 1
            $script:startTime = Get-Date
            $script:logFile = "$($LogDir)/install_js7_agent.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
        }

        New-Item $logFile -ItemType file | Out-Null
    }

    Out-LogInfo "-- begin of log --------------"
    # Get the command name
    $commandName = $PSCmdlet.MyInvocation.InvocationName
    # Get the list of parameters for the command
    $parameterList = (Get-Command -Name $commandName).Parameters
    # Grab each parameter value, using Get-Variable
    foreach ($parameter in $parameterList.Keys) {
        $variable = Get-Variable -Name $parameter -ErrorAction SilentlyContinue
        if ( $variable.value )
        {
            Out-LogInfo ".. Argument: $($variable.name) = $($variable.value)"
        }
    }
    Out-LogInfo "-- begin of output -----------"


    if ( !$Data )
    {
        $script:Data = "$($HomeDir)/var_$($HttpPort)"
    }

    if ( !$Config )
    {
        $script:Config = "$($Data)/config"
    }

    if ( !$Logs )
    {
        $script:Logs = "$($Data)/logs"
    }

    if ( !$Work )
    {
        $script:Work = "$($Data)/work"
    }

    try
    {
        if ( $Uninstall -or $UninstallHome -or $UninstallData )
        {
            Stop-AgentBasic

            if ( $isWindows )
            {
                if ( Test-Path -Path "$($HomeDir)/Uninstaller)/uninstaller.jar" -PathType leaf )
                {
                    if ( $JavaHome )
                    {
                        $java = "$($JavaHome)/bin/java"
                    } else {
                        $java = "java"
                    }

                    Out-LogInfo ".... running uninstaller: cmd.exe /C ""$($java)"" ""$($HomeDir)/Uninstaller/uninstaller.jar"" -c -f"
                    cmd.exe /C """$($java)""" -jar """$($HomeDir)/Uninstaller/uninstaller.jar""" -c (if ( $UninstallData ) { '-f' })
                } else {
                    if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                    {
                        Out-LogInfo ".... removing Windows Service using command: cmd.exe /S /C ""$($HomeDir)\bin\agent_$($HttpPort).cmd"" remove-service"
                        cmd.exe /S /C """$($HomeDir)\bin\agent_$($HttpPort).cmd"" remove-service"

                        for( $i=1; $i -le 20; $i++ )
                        {
                            $service = Get-Service -Name $ServiceName -ErrorAction silentlycontinue
                            if ( !$service -or $service.Status -eq 'stopped' )
                            {
                                break
                            }

                            Start-Sleep -Seconds 1
                        }
                    } else {
                        Out-LogInfo ".... Windows service not found: $($ServiceName)"
                    }
                }
            } else {
                if ( Test-Path -Path "$($ServiceDir)/$($ServiceName)" -PathType leaf )
                {
                    $id = sh -c "id -u"
                    if ( $id -eq 0 )
                    {
                        $useSudo = ''
                    } else {
                        $useSudo = 'sudo'
                    }

                    $rc = $null
                    $rc = sh -c "($($useSudo) ls -la ""$($ServiceName)"" >/dev/null 2>&1) || rc=$?"

                    $rc = sh -c "($($useSudo) systemctl disable ""$($ServiceName)"" >/dev/null 2>&1) || rc=$?"
                    if ( $rc )
                    {
                        Out-LogInfo ".... disabling systemd service: $($ServiceName) reports exit code $($rc)"
                    } else {
                        Out-LogInfo ".... disabling systemd service: $($ServiceName)"
                    }

                    Out-LogInfo ".... removing systemd service file: $($ServiceDir)/$($ServiceName)"
                    $rc = sh -c "($($useSudo) rm -f -r ""$($ServiceDir)/$($ServiceName)"" >/dev/null 2>&1) || rc=$?"
                    if ( $rc )
                    {
                        Out-LogInfo ".... could not remove systemd service file: $($ServiceDir)/$($ServiceName)"
                    }

                    $rc = sh -c "($($useSudo) systemctl daemon-reload >/dev/null 2>&1) || rc=$?"
                    if ( $rc )
                    {
                        Out-LogInfo ".... reloading systemd daemon reports exit code $($rc)"
                    } else {
                        Out-LogInfo ".... reloading systemd daemon"
                    }
                } else {
                    Out-LogInfo "no systemd service file found: $($ServiceDir)/$($ServiceName)"
                }
            }

            if ( Test-Path -Path $HomeDir -PathType container )
            {
                if ( $UninstallHome )
                {
                    Out-LogInfo ".... removing home directory: $($HomeDir)"
                    Remove-Item -Path $HomeDir -Recurse -Force
                } else {
                    Out-LogInfo ".... preserving home directory for remaining Agents: $($HomeDir)"
                }
            }

            if ( Test-Path -Path $Data -PathType container )
            {
                if ( $UninstallData )
                {
                    Out-LogInfo ".... removing data directory: $($Data)"
                    Remove-Item -Path $Data -Recurse -Force
                } else {
                    Out-LogInfo ".... preserving data directory for remaining Agents: $($DataDir)"
                }
            }

            if ( Test-Path -Path $Config -PathType container )
            {
                if ( $UninstallData )
                {
                    Out-LogInfo ".... removing config directory: $($Config)"
                    Remove-Item -Path $Config -Recurse -Force
                } else {
                    Out-LogInfo ".... preserving config directory for remaining Agents: $($Config)"
                }
            }

            if ( Test-Path -Path $Logs -PathType container )
            {
                if ( $UninstallData )
                {
                    Out-LogInfo ".... removing logs directory: $($Logs)"
                    Remove-Item -Path $Logs -Recurse -Force
                } else {
                    Out-LogInfo ".... preserving logs directory for remaining Agents: $($Logs)"
                }
            }

            Out-LogInfo "-- end of log ----------------"
            return
        }

        # download tarball
        if ( !$Tarball -and $Release -and !$NoInstall )
        {
            $Match = $Release | Select-String "^([0-9]*)[.]([0-9]*)[.]([a-zA-Z0-9]*)"
            if ( !$Match -or $Match.Matches.Groups.length -le 3 )
            {
                throw "wrong format for release number, use <major>.<minor>.<maintenance>"
            }

            $releaseMajor = $Match.Matches.Groups[1].value
            $releaseMinor = $Match.Matches.Groups[2].value
            $releaseMaint = $Match.Matches.Groups[3].value

            if ( $Patch )
            {
                $Tarball = "js7_agent.$($Release)-PATCH.$($Patch).tar.gz"
                $downloadUrl = "https://download.sos-berlin.com/patches/$($releaseMajor).$($releaseMinor).$($releaseMaint)-patch/$($Tarball)"
            } else {
                if ( $isWindows )
                {
                    $Tarball = "js7_agent_windows.$($Release).zip"
                } else {
                    $Tarball = "js7_agent_unix.$($Release).tar.gz"
                }

                $Match = $releaseMaint | Select-String "(SNAPSHOT)|(RC[0-9]?)$"
                if ( !$Match -or $Match.Matches.Groups.length -le 1 )
                {
                    $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).$($releaseMinor)/$($Tarball)"
                } else {
                    $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).0/$($Tarball)"
                }
            }

            Out-LogInfo ".. downloading tarball from: $($downloadUrl)"
            Invoke-WebRequest -Uri $downloadUrl -Outfile $Tarball
        }

        # extract tarball
        if ( $Tarball )
        {
            if ( $isWindows )
            {
                $tarDir = "$($env:TEMP)/js7_install_agent_$($PID).tmp"
            } else {
                $tarDir = "/tmp/js7_install_agent_$($PID).tmp"
            }

            if ( !(Test-Path -Path $tarDir -PathType container) )
            {
                New-Item -Path $tarDir -ItemType directory | Out-Null
            }

            Out-LogInfo ".. extracting tarball to temporary directory: $($tarDir)"
            if ( $isWindows )
            {
                if ( $Patch )
                {
                    cmd.exe /C "cd $($tarDir) && tar.exe -xf $((Get-ChildItem -Path $Tarball).FullName)"
                } else {
                    Expand-Archive -Path $Tarball -DestinationPath $tarDir -Force
                }
            } else {
                sh -c "test -e ""$($Tarball)"" && gzip -c -d < ""$($Tarball)"" | tar -xf - -C ""$($tarDir)"""
            }

            $tarRoot = (Get-ChildItem -Path $tarDir -Directory).Name
        }

        Stop-AgentBasic

        # take backup of existing installation directory
        if ( $BackupDir -and $HomeDir )
        {
            if ( $MakeDirs -and !(Test-Path -Path $BackupDir -PathType container) )
            {
                New-Item -Path $BackupDir -ItemType directory | Out-Null
            }

            $version = '0.0.0'
            if ( Test-Path -Path "$($HomeDir)/.version" -PathType leaf )
            {
                $Match = Get-Content "$($HomeDir)/.version" | Select-String "^release[ ]*=[ ]*(.*)$"
                if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                {
                    $version = $Match.Matches.Groups[1].value
                }

                $backupFile = "$($BackupDir)/backup_js7_agent.$($hostname).$($version).home.$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').tar.gz"
                if ( Test-Path -Path $backupFile -PathType leaf )
                {
                    Remove-Item -Path $backupFile -Force
                }

                Out-LogInfo ".. creating backup file: $($backupFile) from home directory $($HomeDir)"
                if ( $isWindows )
                {
                    cmd.exe /C "cd ""$(Split-Path -Path $HomeDir -Parent)"" && tar.exe -czf ""$($backupFile)"" ""$(Split-Path -Path $HomeDir -Leaf)"""
                } else {
                    $backupFile = $backupFile.Substring( 0, $backupFile.Length-3)
                    sh -c "cd ""$(Split-Path -Path $HomeDir -Parent)"" && tar -cpf ""$($backupFile)"" ""$(Split-Path -Path $HomeDir -Leaf)"" && gzip ""$($backupFile)"""
                }

                if ( $HomeDir -ne $Data -and (Test-Path -Path $Data -PathType container) )
                {
                    $backupFile = "$($BackupDir)/backup_js7_agent.$($hostname).$($version).data.$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').tar.gz"
                    if ( Test-Path -Path $backupFile -PathType leaf )
                    {
                        Remove-Item -Path $backupFile -Force
                    }

                    Out-LogInfo ".. creating backup file: $($backupFile) from data directory $($Data)"
                    if ( $isWindows )
                    {
                        cmd.exe /C "cd ""$(Split-Path -Path $Data -Parent)"" && tar.exe -czf ""$($backupFile)"" ""$(Split-Path -Path $Data -Leaf)"""
                    } else {
                        $backupFile = $backupFile.Substring( 0, $backupFile.Length-3)
                        sh -c "cd ""$(Split-Path -Path $Data -Parent)"" && tar -cpf ""$($backupFile)"" ""$(Split-Path -Path $Data -Leaf)"" && gzip ""$($backupFile)"""
                    }
                }
            }
        }

        if ( $Patch )
        {
            if ( $Tarball )
            {
                # copy to Agent patch directoy
                if ( Test-Path -Path "$($tarDir)/$($tarRoot)/lib/patches" -PathType container )
                {
                    Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot)/lib/patches to Agent patch directory: $($HomeDir)/lib/patches"
                    Copy-Item -Path "$($tarDir)/$($tarRoot)/lib/patches/*" -Destination "$($HomeDir)/lib/patches" -Recurse -Force
                } else {
                    Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot) to Agent patch directory: $($HomeDir)/lib/patches"
                    Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination "$($HomeDir)/lib/patches" -Recurse -Force
                }
            } elseif ( $PatchJar ) {
                Out-LogInfo ".. copying patch .jar file: $($PatchJar) to Agent patch directory: $($HomeDir)/lib/patches"
                Copy-Item -Path $PatchJar -Destination "$($HomeDir)/lib/patches" -Recurse -Force
            }

            Start-AgentBasic
            Out-LogInfo "-- end of log ----------------"
            return
        }

        if ( !$NoInstall -or $UseInstall )
        {
            # create Agent home directory if required
            if ( !(Test-Path -Path $HomeDir -PathType container) )
            {
                Out-LogInfo ".. creating Agent home directory: $($HomeDir)"
                New-Item -Path $HomeDir -ItemType directory | Out-Null
            }

            # create Agent data directory if required
            if ( !(Test-Path -Path $Data -PathType container) )
            {
                Out-LogInfo ".. creating Agent data directory: $($Data)"
                New-Item -Path $Data -ItemType directory | Out-Null
            }

            # create Agent config directory if required
            if ( !(Test-Path -Path $Config -PathType container) )
            {
                Out-LogInfo ".. creating Agent config directory: $($Config)"
                New-Item -Path $Config -ItemType directory | Out-Null
            }
        }

        # remove the Agent's journal if requested
        if ( $RemoveJournal -and (Test-Path -Path "$($Data)/state" -PathType container) )
        {
            Out-LogInfo ".. removing Agent journal from directory: $($Data)/state/*"
            Remove-Item -Path "$($Data)/state/*" -Recurse -Force
        }

        # preserve the Agent's lib/user_lib directory
        if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib/user_lib") )
        {
            Out-LogInfo ".. copying files to extracted tarball directory: $($tarDir)/$($tarRoot) from Agent home: $($HomeDir)/lib/user_lib"
            Copy-Item -Path "$($HomeDir)/lib/user_lib/*" -Destination "$($tarDir)/$($tarRoot)/lib/user_lib" -Recurse
        }

        # remove the Agent's YADE directory
        if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/yade") )
        {
            Out-LogInfo ".. removing yade sub-directory from Agent home: $($HomeDir)/yade"
            Remove-Item -Path "$($HomeDir)/yade" -Recurse -Force
        }

        # remove the Agent's patches directory
        if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib/patches") )
        {
            Out-LogInfo ".. removing patches from Agent patch directory: $($HomeDir)/lib/patches"
            Remove-Item -Path "$($HomeDir)/lib/patches/*" -Recurse -Force
        }

        # move or remove the Agent's lib directory
        if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib" -PathType container) )
        {
            if ( !$MoveLibs )
            {
                Remove-Item -Path "$($HomeDir)/lib" -Recurse -Force
            } else {
                # check existing version and lib directory copies
                if ( Test-Path -Path "$($HomeDir)/.version" -PathType leaf )
                {
                    $Match = Get-Content "$($HomeDir)/.version" | Select-String "^release[ ]*=[ ]*(.*)$"
                    if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                    {
                        $version = $Match.Matches.Groups[1].value
                    } else {
                        $version = '0.0.0'
                    }
                } else {
                    $version = '0.0.0'
                }

                while ( Test-Path -Path "$($HomeDir)/lib/$($version)" )
                {
                    $version = "$(version)-1"
                }

                Out-LogInfo ".. moving directory $($HomeDir)/lib to: $($HomeDir)/lib.$($version)"
                Move-Item -Path "$($HomeDir)/lib" -Destination "$($HomeDir)/lib.$($version)" -Force
            }
        }

        if ( $Tarball )
        {
            # do not overwrite an existing data directory
            if ( (Test-Path -Path "$($Data)/state" -PathType container) -or (Test-Path -Path "$($Data)/config/*" -PathType leaf) )
            {
                if ( Test-Path -Path "$($tarDir)/$($tarRoot)/var" -PathTyp container )
                {
                    Out-LogInfo ".. preventing configuration data from being copied to existing data directory: $($Data)"
                    Remove-Item -Path "$($tarDir)/$($tarRoot)/var" -Recurse -Force
                }

                if ( $NoYade -and (Test-Path -Path "$($tarDir)/$($tarRoot)/yade" -PathTyp container) )
                {
                    Out-LogInfo ".. removing YADE from Agent tarball directory:: $($tarDir)/$($tarRoot)/yade"
                    Remove-Item -Path "$($tarDir)/$($tarRoot)/yade" -Recurse -Force
                }
            }

            # copy to Agent home directoy
            Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot) to Agent home: $($HomeDir)"
            Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination $HomeDir -Recurse -Force
        }

        # populate Agent data directory from configuration files and certificates
        if ( (!$NoInstall -or $UseInstall) -and !(Test-Path -Path "$($Data)/state" -PathType container) -and (Test-Path -Path "$($HomeDir)/var" -PathType container) )
        {
            Out-LogInfo ".. copying writable files from $($HomeDir)/var/* to Agent data directory: $($Data)"
            Copy-Item -Path "$($HomeDir)/var/*" -Destination $Data -Exclude (Get-ChildItem -Path $Data -File -Directory -attributes !reparsepoint | Get-ChildItem -Recurse)  -Recurse -Force

            if ( $Config -and $Config -ne "$($Data)/config" -and (Test-Path -Path "$($HomeDir)/var/config" -PathType container) )
            {
                Out-LogInfo ".. copying writable files to Agent config directory: $($Config)"
                Copy-Item -Path "$($HomeDir)/var/config/*" -Destination $Config -Exclude (Get-ChildItem -Path $Config -File -Directory | Get-ChildItem -Recurse) -Recurse -Force
            }
        }

        # copy license key and license binary file
        if ( $LicenseKey )
        {
            if ( !(Test-Path -Path "$($HomeDir)/lib/user_lib" -PathType container) )
            {
                New-Item -Path "$($HomeDir)/lib/user_lib" -ItemType directory | Out-Null
            }

            if ( !$LicenseBin )
            {
                $Match = $Release | Select-String "^([0-9]*)[.]([0-9]*)[.]([a-zA-Z0-9]*)"
                if ( !$Match -or $Match.Matches.Groups.length -le 3 )
                {
                    throw "wrong format for release number, use <major>.<minor>.<maintenance>"
                }

                $releaseMajor = $Match.Matches.Groups[1].value
                $releaseMinor = $Match.Matches.Groups[2].value
                $releaseMaint = $Match.Matches.Groups[3].value

                $Match = $releaseMaint | Select-String "(SNAPSHOT)|(RC[0-9]?)$"
                if ( !$Match -or $Match.Matches.Groups.length -le 1 )
                {
                    $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).$($releaseMinor)/js7-license.jar"
                } else {
                    $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).0/js7-license.jar"
                }

                Out-LogInfo ".. downloading binary license file from: $($downloadUrl)"
                Invoke-WebRequest -Uri $downloadUrl -Outfile "$($HomeDir)/lib/user_lib/js7-license.jar"
            } else {
                Copy-Item -Path $LicenseBin -Destination "$($HomeDir)/lib/user_lib/js7-license.jar" -Force
            }

            if ( $Config )
            {
                if ( !(Test-Path -Path "$($Config)/license" -PathType container) )
                {
                    New-Item -Path "$($Config)/license" -ItemType directory | Out-Null
                }

                Out-LogInfo ".. copying license key file to: $($Config)/license"
                Copy-Item -Path $LicenseKey -Destination "$($Config)/license" -Force
            } else {
                if ( !(Test-Path -Path "$($HomeDir)/var/config/license" -PathType container) )
                {
                    New-Item -Path "$($HomeDir)/var/config/license" -ItemType directory | Out-Null
                }

                Out-LogInfo ".. copying license key file to: $($HomeDir)/var/config/license"
                Copy-Item -Path $LicenseKey -Destination "$($HomeDir)/var/config/license" -Force
            }
        }

        # copy deployment directory
        if ( $DeployDir -and (Test-Path -Path $Config -PathType container) )
        {
            foreach( $directory in $DeployDir )
            {
                if ( !(Test-Path -Path $directory -PathType container) )
                {
                    Out-LogError "Deployment Directory not found: -DeployDir $($directory)"
                } else {
                    Out-LogInfo ".. deploying configuration from $($directory) to Agent configuration directory: $($Config)"
                    Copy-Item -Path "$($directory)/*" -Destination $Config -Recurse -Force
                }
            }
        }

        # copy instance start script
        if ( !$InstanceScript )
        {
            if ( $isWindows )
            {
                $useInstanceScript = "$($HomeDir)/bin/agent_$($HttpPort).cmd"
                $useInstanceTemplate = "$($HomeDir)/bin/agent_instance.cmd-example"
            } else {
                $useInstanceScript = "$($HomeDir)/bin/agent_$($HttpPort).sh"
                $useInstanceTemplate = "$($HomeDir)/bin/agent_instance.sh-example"
            }

            if ( (!$NoInstall -or $UseInstall) -and !(Test-Path -Path $useInstanceScript -PathType leaf) -and (Test-Path -Path $useInstanceTemplate -PathType leaf) )
            {
                Out-LogInfo ".. copying sample Agent Instance Start Script $($useInstanceScript)-example to $($useInstanceScript)"
                Copy-Item -Path $useInstanceTemplate -Destination $useInstanceScript -Force
            }
        } else {
            $useInstanceScript = "$($HomeDir)/bin/$(Split-Path $InstanceScript -Leaf)"
            Out-LogInfo ".. copying Agent Instance Start Script $($InstanceScript) to $($useInstanceScript)"
            Copy-Item -Path $InstanceScript -Destination $useInstanceScript -Force
        }

        # copy systemd service file
        $useServiceFile = "$($HomeDir)/bin/agent_$($HttpPort).service"
        if ( !$isWindows )
        {
            if ( $ServiceFile )
            {
                Out-LogInfo ".. copying $($ServiceFile) to $($useServiceFile)"
                Copy-Item -Path $ServiceFile -Destination $useServiceFile -Force
            } elseif ( !(Test-Path -Path $useServiceFile -PathType leaf) ) {
                if ( (!$NoInstall -or $UseInstall) -and (Test-Path -Path "$($HomeDir)/bin/agent.service-example" -PathType leaf) )
                {
                    Out-LogInfo ".. copying $($HomeDir)/bin/agent.service-example to $($useServiceFile)"
                    Copy-Item -Path "$($HomeDir)/bin/agent.service-example" -Destination $useServiceFile -Force
                }
            }
        }

        # copy agent.conf
        if ( $AgentConf )
        {
            if ( !(Test-Path -Path $Config -PathType container) )
            {
                New-Item -Path $Config -ItemType directory | Out-Null
            }

            Out-LogInfo ".. copying Agent configuration $($AgentConf) to $($Config)/agent.conf"
            Copy-Item -Path $AgentConf -Destination "$($Config)/agent.conf" -Force
        }

        # copy private.conf
        if ( $PrivateConf )
        {
            if ( !(Test-Path -Path "$($Config)/private" -PathType container) )
            {
                New-Item -Path "$($Config)/private" -ItemType directory | Out-Null
            }

            Out-LogInfo ".. copying Agent private configuration $($PrivateConf) to $($Config)/private/private.conf"
            Copy-Item -Path $PrivateConf -Destination "$($Config)/private/private.conf" -Force
        }

        # copy keystore
        if ( $Keystore )
        {
            if ( !(Test-Path -Path "$($Config)/private" -PathType container) )
            {
                New-Item -Path "$($Config)/private" -ItemType directory | Out-Null
            }

            $useKeystoreFile = "$($Config)/private/$(Split-Path $Keystore -Leaf)"
            Out-LogInfo ".. copying keystore file $($Keystore) to $($useKeystoreFile)"
            Copy-Item -Path $Keystore -Destination $useKeystoreFile -Force
        }

        # copy truststore
        if ( $Truststore )
        {
            if ( !(Test-Path -Path "$($Config)/private" -PathType container) )
            {
                New-Item -Path "$($Config)/private" -ItemType directory | Out-Null
            }

            $useTruststoreFile = "$($Config)/private/$(Split-Path $Truststore -Leaf)"
            Out-LogInfo ".. copying truststore file $($Truststore) to $($useTruststoreFile)"
            Copy-Item -Path $Truststore -Destination $useTruststoreFile -Force
        }

        # update configuration items

        # update instance script
        if ( (!$NoInstall -or $UseInstall) -and (Test-Path -Path $useInstanceScript -PathType leaf) )
        {
            Out-LogInfo ".. updating Agent Instance Start Script: $($useInstanceScript)"

            if ( $isWindows )
            {
                $setVar = 'set '
                $remVar = 'rem set '
            } else {
                $setVar = ''
                $remVar = '# '
            }

            ((Get-Content -Path $useInstanceScript) -replace "^[#remREMsetSET ]*JS7_AGENT_HOME[ ]*=.*", "$($setVar)JS7_AGENT_HOME=$($HomeDir)") | Set-Content -Path $useInstanceScript

            if ( $User )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_USER[ ]*=.*', "$($setVar)JS7_AGENT_USER=$($User)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_USER[ ]*=.*', "$($remVar)JS7_AGENT_USER=") | Set-Content -Path $useInstanceScript
            }

            if ( $HttpPort )
            {
                if ( $HttpNetworkInterface )
                {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_HTTP_PORT[ ]*=.*', "$($setVar)JS7_AGENT_HTTP_PORT=$($HttpNetworkInterface):$($HttpPort)") | Set-Content -Path $useInstanceScript
                } else {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_HTTP_PORT[ ]*=.*', "$($setVar)JS7_AGENT_HTTP_PORT=$($HttpPort)") | Set-Content -Path $useInstanceScript
                }
            } else {
                ((Get-Content -Path $useInstanceScript) -replace "^[#remREMsetSET ]*JS7_AGENT_HTTP_PORT[ ]*=.*", "$($remVar)JS7_AGENT_HTTP_PORT=") | Set-Content -Path $useInstanceScript
            }

            if ( $HttpsPort )
            {
                if ( $HttpsNetworkInterface )
                {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_HTTPS_PORT[ ]*=.*', "$($setVar)JS7_AGENT_HTTPS_PORT=$($HttpsNetworkInterface):$($HttpsPort)") | Set-Content -Path $useInstanceScript
                } else {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_HTTPS_PORT[ ]*=.*', "$($setVar)JS7_AGENT_HTTPS_PORT=$($HttpsPort)") | Set-Content -Path $useInstanceScript
                }
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_HTTPS_PORT[ ]*=.*', "$($remVar)JS7_AGENT_HTTPS_PORT=") | Set-Content -Path $useInstanceScript
            }

            if ( $Data )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_DATA[ ]*=.*', "$($setVar)JS7_AGENT_DATA=$($Data)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_DATA[ ]*=.*', "$($remVar)JS7_AGENT_DATA=") | Set-Content -Path $useInstanceScript
            }

            if ( $Config )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_CONFIG_DIR[ ]*=.*', "$($setVar)JS7_AGENT_CONFIG_DIR=$($Config)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_CONFIG_DIR[ ]*=.*', "$($remVar)JS7_AGENT_CONFIG_DIR=") | Set-Content -Path $useInstanceScript
            }

            if ( $Logs )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_LOGS[ ]*=.*', "$($setVar)JS7_AGENT_LOGS=$($Logs)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_LOGS[ ]*=.*', "$($remVar)JS7_AGENT_LOGS=") | Set-Content -Path $useInstanceScript
            }

            if ( $Work )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_WORK[ ]*=.*', "$($setVar)JS7_AGENT_WORK=$($Work)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_WORK[ ]*=.*', "$($remVar)JS7_AGENT_WORK=") | Set-Content -Path $useInstanceScript
            }

            if ( $PidFileDir )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_PID_FILE_DIR[ ]*=.*', "$($setVar)JS7_AGENT_PID_FILE_DIR=$($PidFileDir)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_PID_FILE_DIR[ ]*=.*', "$($remVar)JS7_AGENT_PID_FILE_DIR=") | Set-Content -Path $useInstanceScript
            }

            if ( $PidFileName )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_PID_FILE_NAME[ ]*=.*', "$($setVar)JS7_AGENT_PID_FILE_NAME=$($PidFileName)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_AGENT_PID_FILE_NAME[ ]*=.*', "$($remVar)JS7_AGENT_PID_FILE_NAME=") | Set-Content -Path $useInstanceScript
            }

            if ( $JavaHome )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JAVA_HOME[ ]*=.*', "$($setVar)JAVA_HOME=$($JavaHome)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JAVA_HOME[ ]*=.*', "$($remVar)JAVA_HOME=") | Set-Content -Path $useInstanceScript
            }

            if ( $JavaOptions )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JAVA_OPTIONS[ ]*=.*', "$($setVar)JAVA_OPTIONS=$($JavaOptions)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JAVA_OPTIONS[ ]*=.*', "$($remVar)JAVA_OPTIONS=") | Set-Content -Path $useInstanceScript
            }
        }

        # update systemd service file
        if ( !$isWindows -and (!$NoInstall -or $UseInstall) -and (Test-Path -Path $useServiceFile -PathType leaf) )
        {
            Out-LogInfo ".. updating Agent systemd service file: $($useServiceFile)"

            ((Get-Content -Path $useServiceFile) -replace '<JS7_AGENT_HTTP_PORT>', "$($HttpPort)") | Set-Content -Path $useServiceFile

            $usePidFileName = if ( $PidFileName ) { $PidFileName } else { 'agent.pid' }

            if ( $PidFileDir )
            {
                ((Get-Content -Path $useServiceFile) -replace '<JS7_AGENT_PID_FILE_DIR>', "$($PidFileDir)") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($PidFileDir)") | Set-Content -Path $useServiceFile
            } else {
                ((Get-Content -Path $useServiceFile) -replace '<JS7_AGENT_PID_FILE_DIR>', "$($Data)/logs") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($Data)/logs/$($usePidFileName)") | Set-Content -Path $useServiceFile
            }

            ((Get-Content -Path $useServiceFile) -replace '<JS7_AGENT_USER>', "$($User)") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^User[ ]*=[ ]*.*', "User=$($User)") | Set-Content -Path $useServiceFile

            ((Get-Content -Path $useServiceFile) -replace '<INSTALL_PATH>', "$($HomeDir)") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecStart[ ]*=[ ]*.*', "ExecStart=$($HomeDir)/bin/agent_$($HttpPort).sh start") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecStop[ ]*=[ ]*.*', "ExecStop=$($HomeDir)/bin/agent_$($HttpPort).sh stop") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecReload[ ]*=[ ]*.*', "ExecReload=$($HomeDir)/bin/agent_$($HttpPort).sh restart") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardOutput[ ]*=[ ]*syslog\+console', "StandardOutput=journal+console") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardError[ ]*=[ ]*syslog\+console', "StandardError=journal+console") | Set-Content -Path $useServiceFile

            if ( $JavaHome )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_HOME[ ]*=.*', "Environment=""JAVA_HOME=$($JavaHome)""") | Set-Content -Path $useServiceFile
            }

            if ( $JavaOptions )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_OPTIONS[ ]*=.*', "Environment=""JAVA_OPTIONS=$($JavaOptions)""") | Set-Content -Path $useServiceFile
            }
        }

        # update agent.conf
        $useAgentConfigFile = "$($Config)/agent.conf"

        if ( $Standby )
        {
            if ( Test-Path -Path $useAgentConfigFile -PathType leaf )
            {
                Out-LogInfo ".. updating Agent configuration: $($useAgentConfigFile)"

                ((Get-Content -Path $useAgentConfigFile) -replace '^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*', 'js7.journal.cluster.node.is-backup = yes') | Set-Content -Path $useAgentConfigFile
            }
        } elseif ( $Active ) {
            if ( Test-Path -Path $useAgentConfigFile -PathType leaf )
            {
                Out-LogInfo ".. updating Agent configuration: $($useAgentConfigFile)"

                ((Get-Content -Path $useAgentConfigFile) -replace '^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*', '# js7.journal.cluster.node.is-backup = no') | Set-Content -Path $useAgentConfigFile
            }
        }

        # update private.conf
        $usePrivateConfigFile = "$($Config)/private/private.conf"

        if ( Test-Path -Path $usePrivateConfigFile -PathType leaf )
        {
            Out-LogInfo ".. updating Agent configuration: $($usePrivateConfigFile)"

            if ( $ControllerId )
            {
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{controller-id}}', "$($ControllerId)") | Set-Content -Path $usePrivateConfigFile
            }

            $dn = ''
            if ( $ControllerPrimaryCert -and (Test-Path -Path $ControllerPrimaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $ControllerPrimaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($ControllerPrimaryCert)"" -noout -nameopt RFC2253 -subject"

                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Primary/Standalone Controller distinguished name: $($dn)"
                if ( $ControllerSecondaryCert )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{controller-primary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
                } else {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{controller-primary-distinguished-name}}",', "$($dn)`"") | Set-Content -Path $usePrivateConfigFile
                }
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '^.*{{controller-primary-distinguished-name}}.*$', '') | Set-Content -Path $usePrivateConfigFile
            }

            if ( $ControllerSecondaryCert -and (Test-Path -Path $ControllerSecondaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $ControllerSecondaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($ControllerSecondaryCert)"" -noout -nameopt RFC2253 -subject"

                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Secondary Controller distinguished name: $($dn)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{controller-secondary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '^.*{{controller-secondary-distinguished-name}}.*$', '') | Set-Content -Path $usePrivateConfigFile
            }

            if ( $AgentClusterId )
            {
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{agent-cluster-id}}', "$($AgentClusterId)") | Set-Content -Path $usePrivateConfigFile
                if ( $Active -or $Standby )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace 'permissions[ ]*=[ ]*\[[ ]*AgentDirector[ ]*\]', "") | Set-Content -Path $usePrivateConfigFile
                }
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{agent-cluster-id}}', "agent-cluster") | Set-Content -Path $usePrivateConfigFile                
            }

            $dn = ''
            if ( $DirectorPrimaryCert -and (Test-Path -Path $DirectorPrimaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $DirectorPrimaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($DirectorPrimaryCert)"" -noout -nameopt RFC2253 -subject"

                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Primary Director Agent distinguished name: $($dn)"
                if ( $DirectorSecondaryCert )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{director-primary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
                } else {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{director-primary-distinguished-name}}",', "$($dn)`"") | Set-Content -Path $usePrivateConfigFile
                }
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '"{{director-primary-distinguished-name}}",', '') | Set-Content -Path $usePrivateConfigFile
            }

            if ( $DirectorSecondaryCert -and (Test-Path -Path $DirectorSecondaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $DirectorSecondaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($DirectorSecondaryCert)"" -noout -nameopt RFC2253 -subject"

                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Secondary Director Agent distinguished name: $($dn)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{director-secondary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '"{{director-secondary-distinguished-name}}"', '') | Set-Content -Path $usePrivateConfigFile
            }

            if ( $Keystore -and (Test-Path -Path $Keystore -PathType leaf) )
            {
                Out-LogInfo ".... updating keystore file name: $(Split-Path $Keystore -Leaf)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{keystore-file}}', "$(Split-Path $Keystore -Leaf)") | Set-Content -Path $usePrivateConfigFile
                if ( !$ClientKeystore )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-keystore-file}}', "$(Split-Path $Keystore -Leaf)") | Set-Content -Path $usePrivateConfigFile
                }
            }

            if ( $KeystorePassword )
            {
                Out-LogInfo ".... updating keystore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $KeystorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{keystore-password}}', "$($result)") | Set-Content -Path $usePrivateConfigFile
                if ( !$ClientKeystorePassword )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-keystore-password}}', "$($result)") | Set-Content -Path $usePrivateConfigFile
                }
            }

            if ( $KeyAlias )
            {
                Out-LogInfo ".... updating key alias name for key: $($KeyAlias)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{key-alias}}', "$($KeyAlias)") | Set-Content -Path $usePrivateConfigFile
                if ( !$ClientKeyAlias )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-key-alias}}', "$($KeyAlias)") | Set-Content -Path $usePrivateConfigFile
                }
            }

            if ( $ClientKeystore -and (Test-Path -Path $ClientKeystore -PathType leaf) )
            {
                Out-LogInfo ".... updating client keystore file name: $(Split-Path $ClientKeystore -Leaf)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-keystore-file}}', "$(Split-Path $ClientKeystore -Leaf)") | Set-Content -Path $usePrivateConfigFile
            }

            if ( $ClientKeystorePassword )
            {
                Out-LogInfo ".... updating client keystore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $ClientKeystorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-keystore-password}}', "$($result)") | Set-Content -Path $usePrivateConfigFile
            }

            if ( $ClientKeyAlias )
            {
                Out-LogInfo ".... updating client key alias name for key: $($ClientKeyAlias)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{client-key-alias}}', "$($ClientKeyAlias)") | Set-Content -Path $usePrivateConfigFile
            }

            if ( $Truststore -and (Test-Path -Path $Truststore -PathType leaf) )
            {
                Out-LogInfo ".... updating truststore file name: $(Split-Path $Truststore -Leaf)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{truststore-file}}', "$(Split-Path $Truststore -Leaf)") | Set-Content -Path $usePrivateConfigFile
            }

            if ( $TruststorePassword )
            {
                Out-LogInfo ".... updating truststore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $TruststorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{truststore-password}}', "$($result)") | Set-Content -Path $usePrivateConfigFile
            }

            ((Get-Content -Path $usePrivateConfigFile) -replace '{{.*}}', '') | Set-Content -Path $usePrivateConfigFile
        }

        # make systemd service or Windows service
        if ( $MakeService )
        {
            Register-Service $useServiceFile
        }

        if ( $isWindows -and $ServiceCredentials )
        {
            Out-LogInfo ".... setting Windows Service properties"
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $ServiceCredentials.Password )
            $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )

            $rc = ( Get-CimInstance -ClassName Win32_Service -Filter "Name='$($ServiceName)'" | Invoke-CimMethod -Name Change -Arguments @{StartName="$($ServiceCredentials.UserName)";StartPassword="$($result)";StartMode="$($ServiceStartMode)"} ).ReturnValue
            if ( $rc )
            {
                throw "setting Windows Service properties failed, return code: $($rc)"
            }
        }

        if ( $isWindows -and $ServiceDisplayName )
        {
            $rc = ( Get-CimInstance -ClassName Win32_Service -Filter "Name='$($ServiceName)'" | Invoke-CimMethod -Name Change -Arguments @{DisplayName="$($ServiceDisplayName)"} ).ReturnValue
            if ( $rc )
            {
                throw "failed to update Windows Service properties, return code: $($rc)"
            }
        }

        Start-AgentBasic
        $returnCode = 0

        Final
    } catch {
        Final
        $message = $_.Exception | Format-List -Force | Out-String
        Out-LogError "Exception occurred in line number $($_.InvocationInfo.ScriptLineNumber)`n$($message)"
    }
}

End
{
    Out-LogVerbose ".. processing completed"
}

# SIG # Begin signature block
# MIInpAYJKoZIhvcNAQcCoIInlTCCJ5ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDODr4k1vxFHc4g
# vXNyAmyq03AGADl8w9zhdDfDSI1EX6CCII4wggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYcMIIEBKADAgECAhAz1wio
# kUBTGeKlu9M5ua1uMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAs
# BgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBFViBSMzYwggGi
# MA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQC70f4et0JbePWQp64sg/GNIdMw
# hoV739PN2RZLrIXFuwHP4owoEXIEdiyBxasSekBKxRDogRQ5G19PB/YwMDB/NSXl
# wHM9QAmU6Kj46zkLVdW2DIseJ/jePiLBv+9l7nPuZd0o3bsffZsyf7eZVReqskmo
# PBBqOsMhspmoQ9c7gqgZYbU+alpduLyeE9AKnvVbj2k4aOqlH1vKI+4L7bzQHkND
# brBTjMJzKkQxbr6PuMYC9ruCBBV5DFIg6JgncWHvL+T4AvszWbX0w1Xn3/YIIq62
# 0QlZ7AGfc4m3Q0/V8tm9VlkJ3bcX9sR0gLqHRqwG29sEDdVOuu6MCTQZlRvmcBME
# Jd+PuNeEM4xspgzraLqVT3xE6NRpjSV5wyHxNXf4T7YSVZXQVugYAtXueciGoWnx
# G06UE2oHYvDQa5mll1CeHDOhHu5hiwVoHI717iaQg9b+cYWnmvINFD42tRKtd3V6
# zOdGNmqQU8vGlHHeBzoh+dYyZ+CcblSGoGSgg8sCAwEAAaOCAWMwggFfMB8GA1Ud
# IwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBSBMpJBKyjNRsjE
# osYqORLsSKk/FDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAaBgNVHSAEEzARMAYGBFUdIAAwBwYFZ4EMAQMw
# SwYDVR0fBEQwQjBAoD6gPIY6aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdSb290UjQ2LmNybDB7BggrBgEFBQcBAQRvMG0wRgYI
# KwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0Nv
# ZGVTaWduaW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBfNqz7+fZyWhS38Asd3tj9lwHS
# /QHumS2G6Pa38Dn/1oFKWqdCSgotFZ3mlP3FaUqy10vxFhJM9r6QZmWLLXTUqwj3
# ahEDCHd8vmnhsNufJIkD1t5cpOCy1rTP4zjVuW3MJ9bOZBHoEHJ20/ng6SyJ6UnT
# s5eWBgrh9grIQZqRXYHYNneYyoBBl6j4kT9jn6rNVFRLgOr1F2bTlHH9nv1HMePp
# GoYd074g0j+xUl+yk72MlQmYco+VAfSYQ6VK+xQmqp02v3Kw/Ny9hA3s7TSoXpUr
# OBZjBXXZ9jEuFWvilLIq0nQ1tZiao/74Ky+2F0snbFrmuXZe2obdq2TWauqDGIgb
# MYL1iLOUJcAhLwhpAuNMu0wqETDrgXkG4UGVKtQg9guT5Hx2DJ0dJmtfhAH2KpnN
# r97H8OQYok6bLyoMZqaSdSa+2UA1E2+upjcaeuitHFFjBypWBmztfhj24+xkc6Zt
# CDaLrw+ZrnVrFyvCTWrDUUZBVumPwo3/E3Gb2u2e05+r5UWmEsUUWlJBl6MGAAjF
# 5hzqJ4I8O9vmRsTvLQA1E802fZ3lqicIBczOwDYOSxlP0GOabb/FKVMxItt1UHeG
# 0PL4au5rBhs+hSMrl8h+eplBDN1Yfw6owxI9OjWb4J0sjBeBVESoeh2YnZZ/WVim
# VGX/UUIL+Efrz/jlvzCCBuwwggTUoAMCAQICEDAPb6zdZph0fKlGNqd4LbkwDQYJ
# KoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5
# MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBO
# ZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0
# aG9yaXR5MB4XDTE5MDUwMjAwMDAwMFoXDTM4MDExODIzNTk1OVowfTELMAkGA1UE
# BhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2Fs
# Zm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0aWdv
# IFJTQSBUaW1lIFN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAyBsBr9ksfoiZfQGYPyCQvZyAIVSTuc+gPlPvs1rAdtYaBKXOR4O168TM
# STTL80VlufmnZBYmCfvVMlJ5LsljwhObtoY/AQWSZm8hq9VxEHmH9EYqzcRaydvX
# XUlNclYP3MnjU5g6Kh78zlhJ07/zObu5pCNCrNAVw3+eolzXOPEWsnDTo8Tfs8Vy
# rC4Kd/wNlFK3/B+VcyQ9ASi8Dw1Ps5EBjm6dJ3VV0Rc7NCF7lwGUr3+Az9ERCleE
# yX9W4L1GnIK+lJ2/tCCwYH64TfUNP9vQ6oWMilZx0S2UTMiMPNMUopy9Jv/TUyDH
# YGmbWApU9AXn/TGs+ciFF8e4KRmkKS9G493bkV+fPzY+DjBnK0a3Na+WvtpMYMyo
# u58NFNQYxDCYdIIhz2JWtSFzEh79qsoIWId3pBXrGVX/0DlULSbuRRo6b83XhPDX
# 8CjFT2SDAtT74t7xvAIo9G3aJ4oG0paH3uhrDvBbfel2aZMgHEqXLHcZK5OVmJyX
# nuuOwXhWxkQl3wYSmgYtnwNe/YOiU2fKsfqNoWTJiJJZy6hGwMnypv99V9sSdvqK
# QSTUG/xypRSi1K1DHKRJi0E5FAMeKfobpSKupcNNgtCN2mu32/cYQFdz8HGj+0p9
# RTbB942C+rnJDVOAffq2OVgy728YUInXT50zvRq1naHelUF6p4MCAwEAAaOCAVow
# ggFWMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQa
# ofhhGSAPw0F3RSiO0TVfBhIEVTAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgw
# BgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
# UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGow
# aDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVz
# dFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBtVIGlM10W4bVTgZF13wN6Mgst
# JYQRsrDbKn0qBfW8Oyf0WqC5SVmQKWxhy7VQ2+J9+Z8A70DDrdPi5Fb5WEHP8ULl
# EH3/sHQfj8ZcCfkzXuqgHCZYXPO0EQ/V1cPivNVYeL9IduFEZ22PsEMQD43k+Thi
# vxMBxYWjTMXMslMwlaTW9JZWCLjNXH8Blr5yUmo7Qjd8Fng5k5OUm7Hcsm1BbWfN
# yW+QPX9FcsEbI9bCVYRm5LPFZgb289ZLXq2jK0KKIZL+qG9aJXBigXNjXqC72NzX
# StM9r4MGOBIdJIct5PwC1j53BLwENrXnd8ucLo0jGLmjwkcd8F3WoXNXBWiap8k3
# ZR2+6rzYQoNDBaWLpgn/0aGUpk6qPQn1BWy30mRa2Coiwkud8TleTN5IPZs0lpoJ
# X47997FSkc4/ifYcobWpdR9xv1tDXWU9UIFuq/DQ0/yysx+2mZYm9Dx5i1xkzM3u
# J5rloMAMcofBbk1a0x7q8ETmMm8c6xdOlMN4ZSA7D0GqH+mhQZ3+sbigZSo04N6o
# +TzmwTC7wKBjLPxcFgCo0MR/6hGdHgbGpm0yXbQ4CStJB6r97DDa8acvz7f9+tCj
# hNknnvsBZne5VhDhIG7GrrH5trrINV0zdo7xfCAMKneutaIChrop7rRaALGMq+P5
# CslUXdS5anSevUiumDCCBvUwggTdoAMCAQICEDlMJeF8oG0nqGXiO9kdItQwDQYJ
# KoZIhvcNAQEMBQAwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFu
# Y2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSUwIwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIENBMB4XDTIz
# MDUwMzAwMDAwMFoXDTM0MDgwMjIzNTk1OVowajELMAkGA1UEBhMCR0IxEzARBgNV
# BAgTCk1hbmNoZXN0ZXIxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UE
# AwwjU2VjdGlnbyBSU0EgVGltZSBTdGFtcGluZyBTaWduZXIgIzQwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQCkkyhSS88nh3akKRyZOMDnDtTRHOxoywFk
# 5IrNd7BxZYK8n/yLu7uVmPslEY5aiAlmERRYsroiW+b2MvFdLcB6og7g4FZk7aHl
# gSByIGRBbMfDCPrzfV3vIZrCftcsw7oRmB780yAIQrNfv3+IWDKrMLPYjHqWShkT
# XKz856vpHBYusLA4lUrPhVCrZwMlobs46Q9vqVqakSgTNbkf8z3hJMhrsZnoDe+7
# TeU9jFQDkdD8Lc9VMzh6CRwH0SLgY4anvv3Sg3MSFJuaTAlGvTS84UtQe3LgW/0Z
# ux88ahl7brstRCq+PEzMrIoEk8ZXhqBzNiuBl/obm36Ih9hSeYn+bnc317tQn/oY
# JU8T8l58qbEgWimro0KHd+D0TAJI3VilU6ajoO0ZlmUVKcXtMzAl5paDgZr2YGaQ
# WAeAzUJ1rPu0kdDF3QFAaraoEO72jXq3nnWv06VLGKEMn1ewXiVHkXTNdRLRnG/k
# Xg2b7HUm7v7T9ZIvUoXo2kRRKqLMAMqHZkOjGwDvorWWnWKtJwvyG0rJw5RCN4gg
# hKiHrsO6I3J7+FTv+GsnsIX1p0OF2Cs5dNtadwLRpPr1zZw9zB+uUdB7bNgdLRFC
# U3F0wuU1qi1SEtklz/DT0JFDEtcyfZhs43dByP8fJFTvbq3GPlV78VyHOmTxYEsF
# T++5L+wJEwIDAQABo4IBgjCCAX4wHwYDVR0jBBgwFoAUGqH4YRkgD8NBd0UojtE1
# XwYSBFUwHQYDVR0OBBYEFAMPMciRKpO9Y/PRXU2kNA/SlQEYMA4GA1UdDwEB/wQE
# AwIGwDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1Ud
# IARDMEEwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2Vj
# dGlnby5jb20vQ1BTMAgGBmeBDAEEAjBEBgNVHR8EPTA7MDmgN6A1hjNodHRwOi8v
# Y3JsLnNlY3RpZ28uY29tL1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5jcmwwdAYI
# KwYBBQUHAQEEaDBmMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnNlY3RpZ28uY29t
# L1NlY3RpZ29SU0FUaW1lU3RhbXBpbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6
# Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBMm2VY+uB5z+8V
# wzJt3jOR63dY4uu9y0o8dd5+lG3DIscEld9laWETDPYMnvWJIF7Bh8cDJMrHpfAm
# 3/j4MWUN4OttUVemjIRSCEYcKsLe8tqKRfO+9/YuxH7t+O1ov3pWSOlh5Zo5d7y+
# upFkiHX/XYUWNCfSKcv/7S3a/76TDOxtog3Mw/FuvSGRGiMAUq2X1GJ4KoR5qNc9
# rCGPcMMkeTqX8Q2jo1tT2KsAulj7NYBPXyhxbBlewoNykK7gxtjymfvqtJJlfAd8
# NUQdrVgYa2L73mzECqls0yFGcNwvjXVMI8JB0HqWO8NL3c2SJnR2XDegmiSeTl9O
# 048P5RNPWURlS0Nkz0j4Z2e5Tb/MDbE6MNChPUitemXk7N/gAfCzKko5rMGk+al9
# NdAyQKCxGSoYIbLIfQVxGksnNqrgmByDdefHfkuEQ81D+5CXdioSrEDBcFuZCkD6
# gG2UYXvIbrnIZ2ckXFCNASDeB/cB1PguEc2dg+X4yiUcRD0n5bCGRyoLG4R2fXto
# T4239xO07aAt7nMP2RC6nZksfNd1H48QxJTmfiTllUqIjCfWhWYd+a5kdpHoSP7I
# VQrtKcMf3jimwBT7Mj34qYNiNsjDvgCHHKv6SkIciQPc9Vx8cNldeE7un14g5glq
# fCsIo0j1FfwET9/NIRx65fWOGtS5QDCCBw4wggV2oAMCAQICEEsPjYLws3ayl7bq
# 2k6m1OwwDQYJKoZIhvcNAQELBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWdu
# aW5nIENBIEVWIFIzNjAeFw0yMzA1MzAwMDAwMDBaFw0yNjA1MjkyMzU5NTlaMIHU
# MRIwEAYDVQQFEwlIUkIgMjEwMTUxEzARBgsrBgEEAYI3PAIBAxMCREUxHTAbBgNV
# BA8TFFByaXZhdGUgT3JnYW5pemF0aW9uMQswCQYDVQQGEwJERTEPMA0GA1UECAwG
# QmVybGluMTUwMwYDVQQKDCxTT1MgU29mdHdhcmUtIHVuZCBPcmdhbmlzYXRpb25z
# LVNlcnZpY2UgR21iSDE1MDMGA1UEAwwsU09TIFNvZnR3YXJlLSB1bmQgT3JnYW5p
# c2F0aW9ucy1TZXJ2aWNlIEdtYkgwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQC+bdbrA0vOV3MN3CIFQ72+N1fcvYYkZ/HFp6Z2K1vCnEufNdtJ9K0Qlz1v
# LBSb5uFKn9cbNbF5Jsga3XdKf0QWik5FrbknG7ADzFMQ7Esz8ISWA/9o37+uXmwf
# NqklEXzuJ3vIhe+VnHGK4A9m+mRNz8dZLP8h9s08O1Y0mGYI6WIYlHdteYU8cMMN
# +Wt9jkv3+/bDItREQvKnFUGLncBptm62IBrjQtKqi9Wd1thDypB91b1BVEkMXSEM
# xDzGa7fWQHqYswJcr/1GbsXZiK/Q0y+DiHeqHeRX6QsfMRxogx4FC75W0I+8wSfx
# qFFHDzRuWHtXZ/05fcZHJifQNB+Mxl0aOmaPg/TGV2rwZ7Y9Wb6sJQl4lJBRiw7W
# suEzIECgyX7PqqHBa7GHlwlolqsNC8tamLGuKwD4Ak0lSeI/JdOv51lNK+e3b10b
# fQLropGyQUpYO4HOOtoCveRRZAAnmRLobUpK7J1vGBaT30yO36JocsoOWx4kSpch
# 6tx4K+wvPD405iwDkA4R0LP44It2jBAzR603BaBwZWJkG7J1Pc69DzDlCV0kRdT7
# CHtr778Pa6X77i6G1DdtYNbKTbhIpfo6yoMWBysXFar5UlZ+UiEqoUD2ERmy3mTy
# AdmTJecPs+VsIOh6q3aw9TKJkpD8FjcRI40oNz4dloswbYBGNwIDAQABo4IB1jCC
# AdIwHwYDVR0jBBgwFoAUgTKSQSsozUbIxKLGKjkS7EipPxQwHQYDVR0OBBYEFERw
# dtX4uyEUabKIjTaacdJMUNmCMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMEkGA1UdIARCMEAwNQYMKwYBBAGyMQECAQYB
# MCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMAcGBWeBDAED
# MEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGln
# b1B1YmxpY0NvZGVTaWduaW5nQ0FFVlIzNi5jcmwwewYIKwYBBQUHAQEEbzBtMEYG
# CCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWND
# b2RlU2lnbmluZ0NBRVZSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5z
# ZWN0aWdvLmNvbTBIBgNVHREEQTA/oBwGCCsGAQUFBwgDoBAwDgwMREUtSFJCIDIx
# MDE1gR9hbmRyZWFzLnB1ZXNjaGVsQHNvcy1iZXJsaW4uY29tMA0GCSqGSIb3DQEB
# CwUAA4IBgQBkFbBArVXN1J6JvNSE1815N7PTepzK7MsSFwU7RaWtSqv6EWY4S92L
# h2ZgN5EqYvDYztE76SNeyhP5RAfLZvKsSwDkwkO5dgrJAG3M+SyBSg28/n5uveBm
# ngKfNimsROOf1fnrI4t+g/FSrcsAwAWq02QA18aSH0OfvbCzctHc6QsFHFK8NFAK
# 6G+ja6JvBep0vX3AaA/IS8f1iMGcoaSmBpirRIaRe5bCuyMVNv7fTedzc3yfr5kr
# jESnWbtbqADcfT15FqJYoZn0fyfNh6GCzO6JGRm4TM098egzp9LYq/pgjiHIJPIj
# ANZ8ZLnD4lgR2GJ9y8T/Gn6IEpNdR8ZOZvWR73a6rB2VN9JX+xEc5u8wo2hMbHU/
# 9RrVCZTcrQ6yUMitCbYj9wscbmaxofGxTjUU6Qx5K339WoP1xj2UfsiwloKpjtyY
# KDy0QJD5SCCRJGvuDA7kaN+js0605EigGJuLhgPcWnJXRqI63uGl4Eip3UkgRa0P
# UalQDsDqqoMxggZsMIIGaAIBATBrMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2ln
# bmluZyBDQSBFViBSMzYCEEsPjYLws3ayl7bq2k6m1OwwDQYJYIZIAWUDBAIBBQCg
# gYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQgcoon84JXhuzWyYW8aySl+3ccvmqwETFjdDaaoKEjn/4wDQYJKoZIhvcN
# AQEBBQAEggIAhIr1EtVI7RUxXydM9N1C8RuV0AeAsJaHx/sRyczmb35ynQQp9F+2
# c0xSnR7e9hJ9inj751GxkkjgDaJ9WVqB7iq0IGDGOY9WFxonQq5ixgBJgWRh8SBG
# UZ+IxJ/rKm/WAu/vT3JkDb4dd+7MvGADG25fUVi0b0W4KcX7hdx4TYMMPfBEYbly
# MkveeVfNrjckHeIqCOjfYeueeEoLd153/go6t0o9CVFV8DxDqgzk+DxzX6o5tACL
# LWSDwZG+2wQtutPEgmV7sS5Nf7KKBfBYYQWB0Q6rSdxYMG6SxWhLPVG6cOdkudzf
# 8SRdo7PxsZkY6bvGa/XrxA7PBS35q721FkzQxzO8Y2hqz6KVrk8fp3Wa7Ltd7zJU
# JSt/9v3pnwjZ4YqWS/KWAIIfUYlUB2Yn1mD75csMNoue82w+FNjpliAMTlMiyjSz
# cRSDlBmYPjk8itrnLooBJU1UM9ztOqpW6snxjMGzmg0dsGf4ilmUaaQDHUAuKq/L
# 7s7h3wMX0OMGcJ8lTVeRBCMyIElzS0QtMgdQJPkMFaUYUjzdNXuJS9QHyaRKISF3
# 1PSl38KTQGsTavdSB4HnuK86KNdJYE0RO8nY8fCGrn5n7k+IzMNpRLS6rBEkTL+M
# PJSOOaCJ9APOGxTmGgCrMrkW+Yd5mT7u+nN/RX/fX1nIaKMKoybpxSWhggNLMIID
# RwYJKoZIhvcNAQkGMYIDODCCAzQCAQEwgZEwfTELMAkGA1UEBhMCR0IxGzAZBgNV
# BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSUwIwYDVQQDExxTZWN0aWdvIFJTQSBUaW1lIFN0
# YW1waW5nIENBAhA5TCXhfKBtJ6hl4jvZHSLUMA0GCWCGSAFlAwQCAgUAoHkwGAYJ
# KoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjQwNDIzMTk1
# MTQ3WjA/BgkqhkiG9w0BCQQxMgQwTk3By3D1MEZRwqr2eGsgSNeKwEXwktGwqgA1
# UzHKfW8k9qQ4VDzWWD+7j55q9MZ9MA0GCSqGSIb3DQEBAQUABIICAAvN7gpaAPzc
# hOOksMGyrFi/vXuEgPHadAiWfqwgx+6+h1DWevbJvi4cUPZVrvWpMfXOOJq54oTi
# MvfzojWYiHAcPUnBKaHRPSB+w4/2N6XNTCGzxrBcpjB3WJlaBEQsXMbhv2fkdFOl
# M3/UmmVPYlTjp0Nb5kz/ArjJ3ir8lenefACG+pUW7+YLJm8KebRwpbBOMXEILm0P
# +kDBtx7coom/c+GwCK3nzYfpD8fPos39O4/APwYaTKRHsIQLRc8oJTSuRzqcVrxW
# MTPuyu8WXdPlpKEMbvIh7kbhBewqPxkCi0E9xfaX/8tsgo9MXdtqQZBEpjp0f+6K
# Bdt9eUKKMVzbq9HfMoz/6ioUhJD5yybC50KCGNnsVJu39k0x7mcv5DSxZiMFIpxM
# xHxAYOgG8RWIdhy7dc3OryRicrEN1GUqIr7izvozY3g2NmtGvNddUu8aIBABSu3i
# rlieLWwxZJk22PidfurLBuWsu+jxfZiKnYhiooNYTTSqPXgLF3Sdxt8rhSIOPpB8
# IuUWj2J4seMIEiOPigMnfiDWIQwwiSD1HRZBwz7J+Y+yfIMDIFy24WSwMt1fdRxy
# hnBDCaHvwHP0Wobn+HbU3JRhndUk7G1prqGdFMgHTdduh9P+ygcxXPLOMpFk1Pdu
# rfItfJGRfXC1uQRjec9MV4xCIgWAzVOu
# SIG # End signature block
