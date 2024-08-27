<#
.SYNOPSIS
Installs, updates, patches or uninstalls a JS7 Controller on Windows and Unix platforms supporting PowerShell 5.1, 6, 7

.DESCRIPTION
The Controller Installation Script can be used to automate installing, updating, patching and uninstalling Controller instances.

The script offers the installation options and configuration options available from the Controller's graphical installer.

For download see https://kb.sos-berlin.com/display/JS7/JS7+-+Download

.PARAMETER HomeDir
Specifies the directory in which the Controller should be installed.

.PARAMETER Data
Specifies the directory in which Controller data such as configuration files should be stored.
By default the <home>/var_<http-port> directory is used, see -HomeDir and -HttpPort parameters.

.PARAMETER Config
Specifies the directory from which the Controller reads configuration files.

By default the <data>/config directory is used, see -Data parameter.

.PARAMETER Logs
Specifies the directory to which the Controller stores log files.
By default the <data>/logs directory is used, see -Data parameter.

.PARAMETER Work
Specifies the working directory of the Controller.
By default the <data>/work directory is used, see -Data parameter.

.PARAMETER User
Specifies the user account for the Controller daemon.
By default the account of the user running the Installation Script is used.

.PARAMETER Release
Specifies a release number for the JS7 Controller such as 2.3.1 to be used.

The release will be downloaded from the SOS web site if the -Tarball parameter is not used.

.PARAMETER Tarball
Optionally specifies the path to a .zip or .tar.gz file that holds the Controller installation files.
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

For example the -Patch JS-1984 -Release 2.2.3 parameters will download an (empty) sample patch from the SOS web site
for the respective operating system that the the cmdlet is operated for:

* For Unix the download file is https://download.sos-berlin.com/JobScheduler.2.2/js7_controller_unix.2.2.3.JS-1984.tar.gz
* For windows the downloaded file is https://download.sos-berlin.com/JobScheduler.2.2/js7_controller_windows.2.2.3.JS-1984.zip

Patches can be individually downloaded and they can be made available from the -Tarball parameter.

For example the -Patch JS-1984 -Tarball /tmp/js7_controller_windows.2.2.3.JS-1984.zip parameters will apply the patch from the downloaded file.

Patches are added to the Controller's <home>/lib/patches directory.
Note that patches will be removed when updating the Controller installation later on.

To apply patches the Controller has to be restarted. The -Restart or -ExecStart, -ExecStop parameters can be used for automated restart.

.PARAMETER Jar
Opetionally specifies the path to a .jar file that holds a patch.

The patch .jar file is copied to the Controller's <home>/lib/patches directory.

.PARAMETER LicenseKey
Specifies the path to a license key file (*.pem, *.crt) for use with a commercial license.
A license key file is required should JS7 cluster operations for JOC Cockpit, Controller or Agents be used.

The license key file activates the licensed binary code that implements cluster operations, see -LicenseBin parameter.

.PARAMETER LicenseBin
Specifies the path to a license binary file (*.jar) that implements cluster operations.

Use of licensed binary code is activated by a license key file, see -LicenseKey.

.PARAMETER InstanceScript
Specifies the path to an Instance Start Script that acts as a template and that is copied to the 'bin' directory.
Users are free to choose any name for the Instance Start Script template. In the target directory the file name controller_instance.sh|.cmd will be used.

The script has to be executable for the Controller daemon or Windows Service, see -User parameter.
Permissions of the script are not changed by the Installation Script.
The Installation Script will perform replacements in the Instance Start Script template for known placeholders such as <JS7_CONTROLLER_USER>,
for details see ./bin/controller_instance.sh-example and .\bin\controller_instance.cmd-example.

.PARAMETER BackupDir
If a backup directory is specified then an Controller's existing installation directory will be added to a backup file in this directory.
The backup file type will be .tar.gz for Unix and .zip for Windows.

File names are created according to the pattern: backup_js7_controller.<hostname>.<release>.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.tar.gz|.zip
For example: backup_js7_controller.centostest_primary.2.3.1.2022-03-19T20-50-45.tar.gz

.PARAMETER LogDir
If a log directory is specified then the Installation Script will log information about processing steps to a log file in this directory.
File names are created according to the pattern: install_js7_controller.<hostname>.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.log
For example: install_js7_controller.centostest_primary.2022-03-19T20-50-45.log

.PARAMETER ExecStart
This parameter can be used should the Controller be started after installation.
For example, when using systemd for Unix or Windows Services then the -ExecStart "StartService" parameter value
will start the Controller service provided that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStart "sudo systemctl start js7_controller".

For Unix systemd service files see the 'JS7 - systemd Service Files for automated Startup and Shutdown with Unix Systems' article.
This parameter is an alternative to use of the -Restart switch which will start the Controller from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ExecStop
This parameter can be used should the Controller be stopped before installation.
For example, when using systemd for Unix or Windows Services then the -ExecStop "StopService" parameter value
will stop the Controller service provided that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStop "sudo systemctl stop js7_controller".
This parameter is an alternative to use of the -Restart switch which stops the Controller from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ReturnValues
Optionally specifies the path to a file to which return values will be added in the format <name>=<key>. For example:

log_file=install_js7_controller.centostest_primary.2022-03-20T04-54-31.log
backup_file=backup_js7_controller.centostest_primary.2.3.1.2022-03-20T04-54-31.tar.gz

An existing file will be overwritten. It is recommended to use a unique file name such as /tmp/return.$PID.properties.
A value from the file can be retrieved like this:

* Unix
** backup=$(cat /tmp/return.$$.properties | grep "backup_file" | cut -d'=' -f2)
* Windows
** $backup = ( Get-Content /tmp/return.$PID.properties | Select-String "^backup_file[ ]*=[ ]*(.*)" ).Matches.Groups[1].value

.PARAMETER DeployDir
Specifies the path to a deployment directory that holds configuration files and sub-directories that will be copied to the <config> directory.
A deployment directory allows to manage central copies of configuration files such as controller.conf, private.conf, log4j2.xml etc.

Use of a deployment directory has lower precedence as files can be overwritten by individual parameters such as -ControllerConf, -PrivateConf etc.

.PARAMETER ControllerConf
Specifies the path to a configuration file for global Controller configuration items. The file will be copied to the <config>/controller.conf file.

Any path to a file can be used as a value of this parameter, however, the target file name controller.conf will be used.

.PARAMETER PrivateConf
Specifies the path to a configuration file for private Controller configuration items. The file will be copied to the <config>/private/private.conf file.

Any path to a file can be used as a value of this parameter, however, the target file name private.conf will be used.

.PARAMETER ControllerId
Specifies the Controller ID, a unique identifier of the Controller installation. If a Controller Cluster is operated than all cluster members use the same Controller ID.
The Controller ID is used in the Controller's private.conf file to specify which Controller instance can access a given Controller.

.PARAMETER ControllerPrimaryCert
Specifies the path to the SSL/TLS certificate of the Primary Controller Instance.
The Installation Script extracts the distinguished name from the given certificate and adds it to the Controller's private.conf file
to allow HTTPS connections from the given Controller using mutual authentication without the need for passwords.

.PARAMETER ControllerSecondaryCert
Corresponds to the -ControllerPrimaryCert parameter and is used for the Secondary Controller Instance.

.PARAMETER HttpPort
Specifies the HTTP port that the Controller is operated for. The default value is 4444.

The HTTP port is used to specify the value of the JS7_CONTROLLER_HTTP_PORT environment variable in the instance start script.

The port can be prefixed by the network interface, for example localhost:4444.
When used with the -Restart switch the HTTP port is used to identify if the Controller is running.

.PARAMETER HttpsPort
Specifies the HTTPS port that the Controller is operated for. The HTTPS port is specified in the Controller Instance Start Script typically available
from the ./bin/controller_instance.sh|.cmd script with the environment variable JS7_CONTROLLER_HTTPS_PORT.

Use of HTTPS requires a keystore and truststore to be present, see -Keystore and -Truststore parameters.
The port can be prefixed by the network interface, for example batch.example.com:4444.

.PARAMETER PidFileDir
Specifies the directory to which the Controller stores its PID file. By default the <data>/logs directory is used.
When using SELinux then it is recommended to specify the /var/run directory, see the 'JS7 - How to install for SELinux' article.

.PARAMETER PidFileName
Specifies the name of the PID file in Unix environments. By default the file name controller.pid is used.
The PID file is created in the directory specified by the -PidFileDir parameter.

.PARAMETER Keystore
Specifies the path to a PKCS12 keystore file that holds the private key and certificate for HTTPS connections to the Controller.
Users are free to specify any file name, typically the name https-keystore.p12 is used. The keystore file will be copied to the <config>/private directory.

If a keystore file is made available then the Controller's <config>/private/private.conf file has to hold a reference to the keystore location and optionally the keystore password.
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
Specifies the path to a PKCS12 truststore file that holds the certificate(s) for HTTPS connections to the Controller using mutual authentication .
Users are free to specify any file name, typically the name https-truststore.p12 is used. The truststore file will be copied to the <config>/private directory.

If a truststore file is made available then the Controller's <config>/private/private.conf file has to hold a reference to the truststore location and optionally the truststore password.
It is therefore recommended to use the -PrivateConf parameter to deploy an individual private.conf file that holds settings related to a truststore.
For automating the creation of truststores see the 'JS7 - How to add SSL TLS Certificates to Keystore and Truststore' article.

.PARAMETER TruststorePassword
Specifies the password for access to the truststore from a secure string.
Use of a password is recommended: it is not primarily intended to protect access to the truststore, but to ensure integrity.
The password is intended to allow verification that truststore entries have been added using the same password.

The are a number of ways how to specify secure strings, for example:

-TruststorePassword ( 'secret' | ConvertTo-SecureString -AsPlainText -Force )

.PARAMETER JavaHome
Specifies the Java home directory that will be made available to the Controller from the JAVA_HOME environment variable
specified with the Controller Instance Start Script typically available from the ./bin/controller_instance.sh|.cmd script.

.PARAMETER JavaOptions
Specifies the Java options that will be made available to the Controller from the JAVA_OPTIONS environment variable specified with the Controller Instance Start Script typically available from the ./bin/controller_instancesh|.cmd script.

Java options can be used for example to specify Java heap space settings for the Controller.
If more than one Java option is used then the value has to be quoted, for example -JavaOptions "-Xms256m -Xmx512m".

.PARAMETER StopTimeout
Specifies the timeout in seconds for which the Installation Script will wait for the Agent to terminates, for example if jobs are running.
If this timeout is exceeded then the Agent will be killed. A timeout is not applicable when used with the -Abort or -Kill parameters.

.PARAMETER ServiceDir
For Unix environments specifies the systemd service directory to which the Controller's service file will be copied if the -MakeService switch is used.
By default the /usr/lib/systemd/system directory will be used. Users can specify an alternative location.

.PARAMETER ServiceFile
For Unix environments specifies the path to a systemd service file that acts as a template and that will be copied to the Controller's <home>/bin directory.
Users are free to choose any file name as a template for the service file. The resulting service file name will be controller_<http-port>.service.
The Installation Script will perform replacements in the service file to update paths and the port to be used, for details see ./bin/controller.service-example.

.PARAMETER ServiceName
For Unix environments specifies the name of the systemd service that will be created if the -MakeService switch is used.
By default for Unix the service name js7_controller_<controller-id> will be used.

For Windows the service name is not specified. Instead, the service name js7_controller_<controller-id> will be used.
If the -Standby option for a Secondary Controller is used then the service name js7_controller_<controller-id>-backup will be used.

.PARAMETER ServiceCredentials
In Windows environments the credentials for the Windows service account can be specified for which the Controller should be operated.

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
For Windows environments allows to specify the display name of the Controller's Windows Service.

.PARAMETER Active
Specifies the Controller instance to initially take the role of the active Controller instance in a Controller Cluster.

.PARAMETER Standby
Specifies the Controller instance to initially take the role of the standby Controller instance in a Controller Cluster.

.PARAMETER NoInstall
Specifies if the Installation Script should be used to update configuration items without changes to the binary files of the installation.
In fact no installation is performed but configuration changes as for example specified with the -Keystore parameter will be applied.

.PARAMETER Uninstall
Uninstalls the Controller instance including the steps to stop and remove a running Controller service and to remove the <home> and <data> directories.

.PARAMETER ShowLogs
Displays the log output created by the Installation Script if the -LogDir parameter is used.

.PARAMETER MakeDirs
If directories are missing that are indicated with the -HomeDir, -BackupDir or -LogDir parameters then they will be created.

.PARAMETER MakeService
Specifies that for Unix environments a systemd service should be created, for Windows environments a Windows Service should be created.
In Unix environments the service name will be created from the -ServiceName parameter value or its default value.

.PARAMETER MoveLibs
For an existing Controller installation the lib sub-directory includes .jar files that carry the release number in their file names.
If replaced by a newer version the lib directory has to be moved or removed.
This switch tries to move the directory to a previous version number as indicated from the .version file in the Controller's home directory,
for example to rename lib to lib.2.3.1.

Files in the lib/user_lib sub-directory are preserved.

.PARAMETER RemoveJournal
If Controllers have been installed for the wrong operating mode (standalone, clustered) then the Controller's journal in the <data>/state directory can be removed.
This operation removes any information such as orders submitted to an Controller and requires scheduling objects to be re-deployed to the Controller.

.PARAMETER Restart
Stops a running Controller before installation and starts the Controller after installation using the Controller's Instance Start Script.
This switch can be used with the -Abort and -Kill switches to control the way how the Controller is terminated.
This switch is ignored if the -ExecStart or -ExecStop parameters are used.

.PARAMETER Abort
Aborts a running Controller if used with the -Restart switch.
Aborting an Controller includes to terminate the Controller in an orderly manner which allows to close journal files consistently.

.PARAMETER Kill
Kills a running Controller if used with the -Restart switch.
Killing a Controller prevents journal files from being closed in an orderly manner.

.EXAMPLE
Install-JS7Controller.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\controller" -Data "C:\ProgramData\sos-berlin.com\js7\controller" -Tarball /tmp/js7_controller_windows.2.5.1.zip -HttpPort 4444 -MakeDirs

Downloads and installs the Controller release to the indicated location.

.EXAMPLE
Install-JS7Controller.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\controller" -Data "C:\ProgramData\sos-berlin.com\js7\controller" -Tarball /tmp/js7_controller_windows.2.5.1.zip -BackupDir /tmp/backups -LogDir /tmp/logs -HttpPort 4444 -MakeDirs

Applies the Controller release from a tarball and installs to the indicated locations. A backup is taken and log files are created.

.EXAMPLE
Install-JS7Controller.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\controller" -Data "C:\ProgramData\sos-berlin.com\js7\controller" -Tarball /tmp/js7_controller_windows.2.5.1.zip -HttpPort localhost:4444 -HttpsPort apmacwin:4444 -JavaHome "C:\Program Files\Java\jdk-11.0.12+7-jre" -JavaOptions "-Xms100m -Xmx256m" -MakeDirs

Applies the Controller release from a tarball and installs to the indicated locations. HTTP and HTTP port are the same using different network interfaces. The location of Java and Java Options are indicated.

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
    [string] $User,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ControllerId = 'controller',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Release,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Tarball,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Patch,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Jar,
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
    [string] $ControllerConf,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $PrivateConf,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HttpPort = '4444',
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
    [string] $JocPrimaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JocSecondaryCert,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Keystore,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Security.SecureString] $KeystorePassword,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $KeyAlias,
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
    [switch] $NoInstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Uninstall,
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
        if ( $Standby )
        {
            $script:ServiceNameDefault = "js7_controller_$($ControllerId)-backup"
        } else {
            $script:ServiceNameDefault = "js7_controller_$($ControllerId)"
        }

        if ( !$ServiceName )
        {
            $script:ServiceName = $ServiceNameDefault
        }
    } else {
        $script:ServiceNameDefault = "js7_controller_$($ControllerId).service"
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

    if ( !$ServiceName )
    {
        $script:ServiceName = "js7_controller.service"
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
            if ( $ControllerId )
            {
                ( Get-Process -Name $ServiceName -ErrorAction silentlycontinue ).length
            } else {
                ( Get-Process -Name "js7_controller_*" -ErrorAction silentlycontinue ).length
            }
        } else {
            if ( $HttpPort )
            {
                sh -c "ps -ef | grep -E ""js7\.controller\.main\.ControllerMain.*--http-port=$($HttpPort)"" | grep -v ""grep"" | awk '{print $2}'"
            } else {
                sh -c "ps -ef | grep -E ""js7\.controller\.main\.ControllerMain.*"" | grep -v ""grep"" | awk '{print $2}'"
            }
        }
    }

    function Start-ControllerBasic()
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
                        if ( $PSCmdlet.ShouldProcess( 'Start-ControllerBasic', 'start service' ) )
                        {
                            Out-LogInfo ".. starting Controller Windows Service (Start-ControllerBasic): $($ServiceName)"
                            Start-Service -Name $ServiceName | Out-Null
                        }
                    }
                } else {
                    if ( !$MakeService )
                    {
                        Out-LogError ".. Controller Windows Service not found and -MakeService switch is not present (Start-ControllerBasic): $($ServiceName)"
                    } else {
                        Out-LogError ".. Controller Windows Service not found (Start-ControllerBasic): $($ServiceName)"
                    }
                }
            }
        } else {
            if ( $ExecStart )
            {
                Out-LogInfo ".. starting Controller: $($ExecStart)"
                if ( $ExecStart -eq 'StartService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStart, 'start service' ) )
                    {
                        Start-ControllerService
                    }
                } else {
                    sh -c "$($ExecStart)"
                }
            } else {
                if ( $Restart )
                {
                    if ( Test-Path -Path "$($HomeDir)/bin" -PathType container )
                    {
                        if ( Test-Path -Path "$($HomeDir)/bin/controller_instance.sh" -PathType leaf)
                        {
                            Out-LogInfo ".. starting Controller: $($HomeDir)/bin/controller_instance.sh start"

                            if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                            {
                                $startControllerOutputFile = "/tmp/js7_install_controller_start_$($PID).tmp"
                                New-Item $startControllerOutputFile -ItemType file
                                sh -c "( ""$($HomeDir)/bin/controller_instance.sh"" start > ""$($startControllerOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startControllerOutputFile))"" && exit 5 )"
                                Out-LogInfo Get-Content -Path $startControllerOutputFile
                            } else {
                                sh -c "$($HomeDir)/bin/controller_instance.sh start"
                            }
                        } else {
                            if ( Test-Path -Path "$($HomeDir)/bin/controller.sh" -PathType leaf )
                            {
                                Out-LogInfo ".. starting Controller: $($HomeDir)/bin/controller.sh start"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $startControllerOutputFile = "/tmp/js7_install_controller_start_$($PID).tmp"
                                    New-Item $startControllerOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/bin/controller.sh"" start > ""$($startControllerOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startControllerOutputFile))"" && exit 5 )"
                                    Out-LogInfo Get-Content -Path $startControllerOutputFile
                                } else {
                                    sh -c "$($HomeDir)/bin/controller.sh start"
                                }
                            } else {
                                Out-LogError "could not start Controller, start script missing: $($HomeDir)/bin/controller_instance.sh, $($HomeDir)/bin/controller.sh"
                            }
                        }
                    } else {
                        Out-LogError "could not start Controller, directory missing: $($HomeDir)/bin"
                    }
                }
            }
        }
    }

    function Stop-ControllerBasic()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            $service = Get-Service -Name $ServiceName -ErrorAction silentlycontinue

            if ( $service )
            {
                if ( $service.Status -eq 'running' )
                {
                    if ( $PSCmdlet.ShouldProcess( 'Stop-ControllerBasic', 'stop service' ) )
                    {
                        Out-LogInfo ".. stopping Controller Windows Service (Stop-ControllerBasic): $($ServiceName)"
                        Stop-Service -Name $ServiceName -Force | Out-Null
                        Start-Sleep -Seconds 3
                    }
                }
            } else {
                Out-LogInfo ".. Controller Windows Service not found (Stop-ControllerBasic): $($ServiceName)"
            }
        } else {
            if ( $ExecStop )
            {
                Out-LogInfo ".. stopping Controller: $($ExecStop)"
                if ( $ExecStop -eq 'StopService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStop, 'stop service' ) )
                    {
                        Stop-ControllerService
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
                            if ( Test-Path -Path "$($HomeDir)/bin/controller_instance.sh" -PathType leaf )
                            {
                                Out-LogInfo ".. stopping Controller: $($HomeDir)/bin/controller_instance.sh $($stopOption)"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $stopControllerOutputFile = "/tmp/js7_install_controller_stop_$($PID).tmp"
                                    New-Item $stopControllerOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/bin/controller_instance.sh"" $($stopOption) > ""$($stopControllerOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopControllerOutputFile))"" && exit 6 )"
                                    Out-LogInfo Get-Content -Path $stopControllerOutputFile
                                } else {
                                    sh -c "$($HomeDir)/bin/controller_instance.sh $($stopOption)"
                                }
                            } else {
                                if ( Test-Path -Path "$($HomeDir)/bin/controller.sh" )
                                {
                                    Out-LogInfo ".. stopping Controller: $($HomeDir)/bin/controller.sh $($stopOption)"

                                    if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                    {
                                        $stopControllerOutputFile = "/tmp/js7_install_controller_stop_$($PID).tmp"
                                        New-Item -Path $stopControllerOutputFile -ItemType file
                                        sh -c "( ""$($HomeDir)/bin/controller.sh"" $($stopOption) > ""$($stopControllerOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopControllerOutputFile))"" && exit 6 )"
                                        Out-LogInfo Get-Content -Path $stopControllerOutputFile
                                    } else {
                                        sh -c "$($HomeDir)/bin/controller.sh $($stopOption)"
                                    }
                                } else {
                                    Out-LogError "could not stop Controller, start script missing: $($HomeDir)/bin/controller_instance.sh, $($HomeDir)/bin/controller.sh"
                                }
                            }
                        } else {
                            Out-LogError "could not stop Controller, directory missing: $($HomeDir)/bin"
                        }
                    } else {
                        Out-LogInfo ".. Controller not started"
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
                Out-LogInfo ".... removing Controller Windows Service using command: cmd.exe /S /C ""$($HomeDir)\bin\controller_instance.cmd"" remove-service"
                cmd.exe /S /C """$($HomeDir)\bin\controller_instance.cmd"" remove-service"
            }

            Out-LogInfo ".... installing Controller Windows Service using command: cmd.exe /S /C ""$($HomeDir)\bin\controller_instance.cmd"" install-service"
            cmd.exe /S /C """$($HomeDir)\bin\controller_instance.cmd"" install-service"
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

    function Start-ControllerService()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Start-ControllerService', 'start service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Out-LogInfo ".. starting Controller Windows Service (Start-ControllerBasic): $($ServiceName)"
                    Start-Service -Name $ServiceName | Out-Null
                } else {
                    Out-LogInfo "Controller Windows Service not found (Start-ControllerService): $($ServiceName)"
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

    function Stop-ControllerService()
    {
        [cmdletbinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Stop-ControllerService', 'stop service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Out-LogInfo ".. stopping Controller Windows Service (Stop-ControllerBasic): $($ServiceName)"
                    Stop-Service -Name $ServiceName -ErrorAction silentlycontinue | Out-Null
                    Start-Sleep -Seconds 3
                } else {
                    Out-LogInfo "Controller Windows Service not found (Stop-ControllerService): $($ServiceName)"
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
            Out-LogError "Controller home directory has to be specified: -HomeDir"
            return 1
        }

        if ( $Uninstall -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Controller home directory not found and -Uninstall switch is present: -HomeDir $HomeDir"
            return 1
        }

        if ( !$MakeDirs -and !$Uninstall -and $HomeDir -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Controller home directory not found and -MakeDirs switch not present: -HomeDir $HomeDir"
            return 1
        }

        if ( !$MakeDirs -and $Data -and !(Test-Path -Path $Data -PathType container) )
        {
            Out-LogError "Controller data directory not found and -MakeDirs switch not present: -Data $Data"
            return 1
        }

        if ( !$MakeDirs -and $Config -and !(Test-Path -Path $Config -PathType container) )
        {
            Out-LogError "Controller configuration directory not found and -MakeDirs switch not present: -Config $Config"
            return 1
        }

        if ( !$MakeDirs -and $Logs -and !(Test-Path -Path $Logs -PathType container) )
        {
            Out-LogError "Controller log directory not found and -MakeDirs switch not present: -Logs $Logs"
            return 1
        }

        if ( !$MakeDirs -and $BackupDir -and !(Test-Path -Path $BackupDir -PathType container) )
        {
            Out-LogError "Controller backup directory not found and -MakeDirs switch not present: -BackupDir $BackupDir"
            return 1
        }

        if ( !$MakeDirs -and $LogDir -and !(Test-Path -Path $LogDir -PathType container) )
        {
            Out-LogError "Controller log directory not found and -MakeDirs switch not present: -LogDir $LogDir"
            return 1
        }

        if ( !$Release -and !$Tarball -and !$Jar -and !$NoInstall -and !$Uninstall )
        {
            Out-LogError "Release must be specified if -Tarball option is not used and -NoInstall switch not present: -Release"
            return 1
        }

        if ( $Tarball -and !(Test-Path -Path $Tarball -PathType leaf) )
        {
            Out-LogError "Tarball not found (*.zip):: -Tarball $Tarball"
            return 1
        }

        if ( $Tarball -and $Tarball.IndexOf('installer') -ge -0 )
        {
            Out-LogError "Probably wrong tarball in use: js7_controller_windows_installer.<release>.zip, instead use js7_controller_windows.<release>.zip: -Tarball $Tarball"
            return 1
        }

        if ( $Patch -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Controller home directory not found and -Patch option is present: -HomeDir $HomeDir"
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

        if ( $ControllerConf -and !(Test-Path -Path $ControllerConf -PathType leaf) )
        {
            Out-LogError "Controller configuration file not found (controller.conf): -ControllerConf $ControllerConf"
            return 1
        }

        if ( $PrivateConf -and !(Test-Path -Path $PrivateConf -PathType leaf) )
        {
            Out-LogError "Controller private configuration file not found (private.conf): -PrivateConf $PrivateConf"
            return 1
        }

        if ( $Active -and $Standby )
        {
            Out-LogError "Controller instance can be configured to be either active or standby, use -Active or -Standby"
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

        if ( $JocPrimaryCert -and !(Test-Path -Path $JocPrimaryCert -PathType leaf) )
        {
            Out-LogError "Primary/Standalone JOC Cockpit certificate file not found: -JocPrimaryCert $JocPrimaryCert"
            return 1
        }

        if ( $JocSecondaryCert -and !(Test-Path -Path $JocSecondaryCert -PathType leaf) )
        {
            Out-LogError "Secondary JOC Cockpit certificate file not found: -JocSecondaryCert $JocSecondaryCert"
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

        Return 0
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

        if ( $startControllerOutputFile -and (Test-Path -Path $startControllerOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($startControllerOutputFile)"
            Remove-Item -Path $startControllerOutputFile -Force
        }

        if ( $stopControllerOutputFile -and (Test-Path -Path $stopControllerOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($stopControllerOutputFile)"
            Remove-Item -Path $stopControllerOutputFile -Force
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

    # drop alias names
    # if ( isPowerShellVersion 7 )
    # {
    #     Get-Alias | Where-Object { $_.Options -NE "Constant" } | Remove-Alias -Force
    # }

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

        $logFile = "$($LogDir)/install_js7_controller.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
        while ( Test-Path -Path $logFile -PathType leaf )
        {
            Start-Sleep -Seconds 1
            $script:startTime = Get-Date
            $script:logFile = "$($LogDir)/install_js7_controller.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
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
        $script:Data = "$($HomeDir)/var"
    }

    if ( !$Config )
    {
        $script:Config = "$($Data)/config"
    }

    if ( !$Logs )
    {
        $script:Logs = "$($Data)/logs"
    }

    try
    {
        if ( $Uninstall )
        {
            Stop-ControllerBasic

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
                    cmd.exe /C """$($java)""" -jar """$($HomeDir)/Uninstaller/uninstaller.jar""" -c -f
                } else {
                    Out-LogInfo ".... uninstaller not available"
                    if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                    {
                        Out-LogInfo ".... removing Windows Service using command: cmd.exe /S /C ""$($HomeDir)/bin/controller_instance.cmd"" remove-service"
                        cmd.exe /S /C """$($HomeDir)/bin/controller_instance.cmd"" remove-service"
                    } else {
                        Out-LogInfo ".... Windows service not found: $($ServiceName)"
                    }

                    for( $i=1; $i -le 20; $i++ )
                    {
                        $service = Get-Service -Name $ServiceName -ErrorAction silentlycontinue
                        if ( !$service -or $service.Status -eq 'stopped' )
                        {
                            break
                        }

                        Start-Sleep -Seconds 1
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
                    Out-LogInfo "could not find systemd service file: $($ServiceDir)/$($ServiceName)"
                }
            }

            if ( Test-Path -Path $HomeDir -PathType container )
            {
                Out-LogInfo ".... removing home directory: $($HomeDir)"
                Remove-Item -Path $HomeDir -Recurse -Force
            }

            if ( Test-Path -Path $Data -PathType container )
            {
                Out-LogInfo ".... removing data directory: $($Data)"
                Remove-Item -Path $Data -Recurse -Force
            }

            if ( Test-Path -Path $Config -PathType container )
            {
                Out-LogInfo ".... removing config directory: $($Config)"
                Remove-Item -Path $Config -Recurse -Force
            }

            if ( Test-Path -Path $Logs -PathType container )
            {
                Out-LogInfo ".... removing logs directory: $($Logs)"
                Remove-Item -Path $Logs -Recurse -Force
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
                if ( $isWindows )
                {
                    $Tarball = "js7_controller_windows.$($Release).$($Patch).zip"
                } else {
                    $Tarball = "js7_controller_unix.$($Release).$($Patch).tar.gz"
                }
            } else {
                if ( $isWindows )
                {
                    $Tarball = "js7_controller_windows.$($Release).zip"
                } else {
                    $Tarball = "js7_controller_unix.$($Release).tar.gz"
                }
            }

            $Match = $releaseMaint | Select-String "(SNAPSHOT)|(RC[0-9]?)$"
            if ( !$Match -or $Match.Matches.Groups.length -le 1 )
            {
                $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).$($releaseMinor)/$($Tarball)"
            } else {
                $downloadUrl = "https://download.sos-berlin.com/JobScheduler.$($releaseMajor).0/$($Tarball)"
            }

            Out-LogInfo ".. downloading tarball from: $($downloadUrl)"
            Invoke-WebRequest -Uri $downloadUrl -Outfile $Tarball
        }

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

                $backupFile = "$($BackupDir)/backup_js7_controller.$($hostname).$($version).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').zip"
                if ( Test-Path -Path $backupFile -PathType leaf )
                {
                    Remove-Item -Path $backupFile -Force
                }

                Out-LogInfo ".. creating backup file: $($backupFile) from home directory $($HomeDir)"
                Get-ChildItem -Path $HomeDir -Recurse | Compress-Archive -DestinationPath $backupFile
            }
        }

        # extract tarball
        if ( $Tarball )
        {
            if ( $isWindows )
            {
                $tarDir = "$($env:TEMP)/js7_install_controller_$($PID).tmp"
            } else {
                $tarDir = "/tmp/js7_install_controller_$($PID).tmp"
            }

            if ( !(Test-Path -Path $tarDir -PathType container) )
            {
                New-Item -Path $tarDir -ItemType directory | Out-Null
            }

            Out-LogInfo ".. extracting tarball to temporary directory: $($tarDir)"
            if ( $isWindows )
            {
                Expand-Archive -Path $Tarball -DestinationPath $tarDir -Force
            } else {
                sh -c "test -e ""$($Tarball)"" && gzip -c -d < ""$($Tarball)"" | tar -xf - -C ""$($tarDir)"""
            }

            $tarRoot = (Get-ChildItem -Path $tarDir -Directory).Name
        }

        Stop-ControllerBasic

        if ( $Patch )
        {
            if ( $Tarball )
            {
                # copy to Controller patch directoy
                if ( Test-Path -Path "$($tarDir)/$($tarRoot)/lib/patches" -PathType container )
                {
                    Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot)/lib/patches to Controller patch directory: $($HomeDir)/lib/patches"
                    Copy-Item -Path "$($tarDir)/$($tarRoot)/lib/patches/*" -Destination "$($HomeDir)/lib/patches" -Recurse -Force
                } else {
                    Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot) to Agent patch directory: $($HomeDir)/lib/patches"
                    Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination "$($HomeDir)/lib/patches" -Recurse -Force
                }
            } elseif ( $Jar ) {
                Out-LogInfo ".. copying patch .jar file: $($Jar) to Controller patch directory: $($HomeDir)/lib/patches"
                Copy-Item -Path $Jar -Destination "$($HomeDir)/lib/patches" -Recurse -Force
            }

            Start-ControllerBasic
            Out-LogInfo "-- end of log ----------------"
            return
        }

        if ( !$NoInstall )
        {
            # create Controller home directory if required
            if ( !(Test-Path -Path $HomeDir -PathType container) )
            {
                Out-LogInfo ".. creating Controller home directory: $($HomeDir)"
                New-Item -Path $HomeDir -ItemType directory | Out-Null
            }

            # create Controller data directory if required
            if ( !(Test-Path -Path $Data -PathType container) )
            {
                Out-LogInfo ".. creating Controller data directory: $($Data)"
                New-Item -Path $Data -ItemType directory | Out-Null
            }

            # create Controller config directory if required
            if ( !(Test-Path -Path $Config -PathType container) )
            {
                Out-LogInfo ".. creating Controller config directory: $($Config)"
                New-Item -Path $Config -ItemType directory | Out-Null
            }
        }

        # remove the Controller's journal if requested
        if ( $RemoveJournal -and ( Test-Path -Path "$($Data)/state" -PathType container) )
        {
            Out-LogInfo ".. removing Controller journal from directory: $($Data)/state/*"
            Remove-Item -Path "$($Data)/state/*" -Recurse -Force
        }

        # preserve the Controller's lib/user_lib directory
        if ( !$Patch -and !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib/user_lib") )
        {
            Out-LogInfo ".. copying files to extracted tarball directory: $($tarDir)/$($tarRoot) from Controller home: $($HomeDir)/lib/user_lib"
            Copy-Item -Path "$($HomeDir)/lib/user_lib/*" -Destination "$($tarDir)/$($tarRoot)/lib/user_lib" -Recurse
        }

        # remove the Controller's patches directory
        if ( !$Patch -and !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib/patches") )
        {
            Out-LogInfo ".. removing patches from Controller patch directory: $($HomeDir)/lib/patches"
            Remove-Item -Path "$($HomeDir)/lib/patches/*" -Recurse -Force
        }

        # move or remove the Controller's lib directory
        if ( !$Patch -and !$NoInstall -and (Test-Path -Path "$($HomeDir)/lib" -PathType container) )
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
            }

            # copy to Controller home directoy
            Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot) to Controller home: $($HomeDir)"
            Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination $HomeDir -Recurse -Force
        }

        # populate Controller data directory from configuration files and certificates
        if ( !$NoInstall -and !$Patch -and !(Test-Path -Path "$($Data)/state" -PathType container) -and (Test-Path -Path "$($HomeDir)/var" -PathType container) )
        {
            Out-LogInfo ".. copying writable files to Controller data directory: $($Data)"
            Copy-Item -Path "$($HomeDir)/var/*" -Destination $Data -Exclude (Get-ChildItem -Path $Data -File | Get-ChildItem -Recurse) -Recurse -Force

            if ( $Config -and $Config -ne "$($Data)/config" -and (Test-Path -Path "$($HomeDir)/var/config" -PathType container) )
            {
                Out-LogInfo ".. copying writable files to Controller config directory: $($Config)"
                Copy-Item -Path "$($HomeDir)/var/config/*" -Destination $Config -Exclude (Get-ChildItem -Path $Config -File | Get-ChildItem -Recurse) -Recurse -Force
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
                    Out-LogInfo ".. deploying configuration from $($directory) to Controller configuration directory: $($Config)"
                    Copy-Item -Path "$($directory)/*" -Destination $Config -Recurse -Force
                }
            }
        }

        # copy instance start script
        if ( !$InstanceScript )
        {
            if ( $isWindows )
            {
                $useInstanceScript = "$($HomeDir)/bin/controller_instance.cmd"
                $useInstanceTemplate = "$($HomeDir)/bin/controller_instance.cmd-example"
            } else {
                $useInstanceScript = "$($HomeDir)/bin/controller_instance.sh"
                $useInstanceTemplate = "$($HomeDir)/bin/controller_instance.sh-example"
            }

            if ( !$NoInstall -and !(Test-Path -Path $useInstanceScript -PathType leaf) -and (Test-Path -Path $useInstanceTemplate -PathType leaf) )
            {
                Out-LogInfo ".. copying sample Controller Instance Start Script $($useInstanceScript)-example to $($useInstanceScript)"
                Copy-Item -Path $useInstanceTemplate -Destination $useInstanceScript -Force
            }
        } else {
            $useInstanceScript = "$($HomeDir)/bin/$(Split-Path $InstanceScript -Leaf)"
            Out-LogInfo ".. copying Controller Instance Start Script $($InstanceScript) to $($useInstanceScript)"
            Copy-Item -Path $InstanceScript -Destination $useInstanceScript -Force
        }

        # copy systemd service file template
        $useServiceFile = "$($HomeDir)/bin/controller_instance.service"
        if ( !$isWindows )
        {
            if ( $ServiceFile )
            {
                Out-LogInfo ".. copying $($ServiceFile) to $($useServiceFile)"
                Copy-Item -Path $ServiceFile -Destination $useServiceFile -Force
            } elseif ( !(Test-Path -Path $useServiceFile -PathType leaf) ) {
                if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/bin/controller.service-example" -PathType leaf) )
                {
                    Out-LogInfo ".. copying $($HomeDir)/bin/controller.service-example to $($useServiceFile)"
                    Copy-Item -Path "$($HomeDir)/bin/controller.service-example" -Destination $useServiceFile -Force
                }
            }
        }

        # copy controller.conf
        if ( $ControllerConf )
        {
            if ( !(Test-Path -Path $Config -PathType container) )
            {
                New-Item -Path $Config -ItemType directory | Out-Null
            }

            Out-LogInfo ".. copying Controller configuration $($ControllerConf) to $($Config)/controller.conf"
            Copy-Item -Path $ControllerConf -Destination "$($Config)/controller.conf" -Force
        } else {
            if ( !(Test-Path -Path "$($Config)/controller.conf" -PathType leaf) )
            {
                if ( Test-Path -Path "$($Config)/controller.conf-example" -PathType leaf )
                {
                    Copy-Item -Path "$($Config)/controller.conf-example" -Destination "$($Config)/controller.conf" -Force
                }
            }
        }

        # copy private.conf
        if ( $PrivateConf )
        {
            if ( !(Test-Path -Path "$($Config)/private" -PathType container) )
            {
                New-Item -Path "$($Config)/private" -ItemType directory | Out-Null
            }

            Out-LogInfo ".. copying Controller private configuration $($PrivateConf) to $($Config)/private/private.conf"
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
        if ( !$NoInstall -and (Test-Path -Path $useInstanceScript -PathType leaf) )
        {
            Out-LogInfo ".. updating Controller Instance Start Script: $($useInstanceScript)"

            if ( $isWindows )
            {
                $setVar = 'set '
                $remVar = 'rem set '
            } else {
                $setVar = ''
                $remVar = '# '
            }

            ((Get-Content -Path $useInstanceScript) -replace "^[#remREMsetSET ]*JS7_CONTROLLER_HOME[ ]*=.*", "$($setVar)JS7_CONTROLLER_HOME=$($HomeDir)") | Set-Content -Path $useInstanceScript
            ((Get-Content -Path $useInstanceScript) -replace "^[#remREMsetSET ]*JS7_CONTROLLER_ID[ ]*=.*", "$($setVar)JS7_CONTROLLER_ID=$($ControllerId)") | Set-Content -Path $useInstanceScript

            if ( $Standby )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_SERVICE_NAME_SUFFIX[ ]*=.*', "$($setVar)JS7_SERVICE_NAME_SUFFIX=backup") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_SERVICE_NAME_SUFFIX[ ]*=.*', "$($remVar)JS7_SERVICE_NAME_SUFFIX=") | Set-Content -Path $useInstanceScript
            }

            if ( $User )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_USER[ ]*=.*', "$($setVar)JS7_CONTROLLER_USER=$($User)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_USER[ ]*=.*', "$($remVar)JS7_CONTROLLER_USER=") | Set-Content -Path $useInstanceScript
            }

            if ( $HttpPort )
            {
                if ( $HttpNetworkInterface )
                {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_HTTP_PORT[ ]*=.*', "$($setVar)JS7_CONTROLLER_HTTP_PORT=$($HttpNetworkInterface):$($HttpPort)") | Set-Content -Path $useInstanceScript
                } else {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_HTTP_PORT[ ]*=.*', "$($setVar)JS7_CONTROLLER_HTTP_PORT=$($HttpPort)") | Set-Content -Path $useInstanceScript
                }
            } else {
                ((Get-Content -Path $useInstanceScript) -replace "^[#remREMsetSET ]*JS7_CONTROLLER_HTTP_PORT[ ]*=.*", "$($remVar)JS7_CONTROLLER_HTTP_PORT=") | Set-Content -Path $useInstanceScript
            }

            if ( $HttpsPort )
            {
                if ( $HttpsNetworkInterface )
                {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_HTTPS_PORT[ ]*=.*', "$($setVar)JS7_CONTROLLER_HTTPS_PORT=$($HttpsNetworkInterface):$($HttpsPort)") | Set-Content -Path $useInstanceScript
                } else {
                    ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_HTTPS_PORT[ ]*=.*', "$($setVar)JS7_CONTROLLER_HTTPS_PORT=$($HttpsPort)") | Set-Content -Path $useInstanceScript
                }
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_HTTPS_PORT[ ]*=.*', "$($remVar)JS7_CONTROLLER_HTTPS_PORT=") | Set-Content -Path $useInstanceScript
            }

            if ( $Data )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_DATA[ ]*=.*', "$($setVar)JS7_CONTROLLER_DATA=$($Data)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_DATA[ ]*=.*', "$($remVar)JS7_CONTROLLER_DATA=") | Set-Content -Path $useInstanceScript
            }

            if ( $Config )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_CONFIG_DIR[ ]*=.*', "$($setVar)JS7_CONTROLLER_CONFIG_DIR=$($Config)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_CONFIG_DIR[ ]*=.*', "$($remVar)JS7_CONTROLLER_CONFIG_DIR=") | Set-Content -Path $useInstanceScript
            }

            if ( $Logs )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_LOGS[ ]*=.*', "$($setVar)JS7_CONTROLLER_LOGS=$($Logs)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_LOGS[ ]*=.*', "$($remVar)JS7_CONTROLLER_LOGS=") | Set-Content -Path $useInstanceScript
            }

            if ( $PidFileDir )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_PID_FILE_DIR[ ]*=.*', "$($setVar)JS7_CONTROLLER_PID_FILE_DIR=$($PidFileDir)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_PID_FILE_DIR[ ]*=.*', "$($remVar)JS7_CONTROLLER_PID_FILE_DIR=") | Set-Content -Path $useInstanceScript
            }

            if ( $PidFileName )
            {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_PID_FILE_NAME[ ]*=.*', "$($setVar)JS7_CONTROLLER_PID_FILE_NAME=$($PidFileName)") | Set-Content -Path $useInstanceScript
            } else {
                ((Get-Content -Path $useInstanceScript) -replace '^[#remREMsetSET ]*JS7_CONTROLLER_PID_FILE_NAME[ ]*=.*', "$($remVar)JS7_CONTROLLER_PID_FILE_NAME=") | Set-Content -Path $useInstanceScript
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
        if ( !$isWindows -and !$NoInstall -and (Test-Path -Path $useServiceFile -PathType leaf) )
        {
            Out-LogInfo ".. updating Controller systemd service file: $($useServiceFile)"

            ((Get-Content -Path $useServiceFile) -replace '<JS7_CONTROLLER_ID>', "$($ControllerId)") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '<JS7_CONTROLLER_HTTP_PORT>', "$($HttpPort)") | Set-Content -Path $useServiceFile

            $usePidFileName = if ( $PidFileName ) { $PidFileName } else { 'controller.pid' }

            if ( $PidFileDir )
            {
                ((Get-Content -Path $useServiceFile) -replace '<JS7_CONTROLLER_PID_FILE_DIR>', "$($PidFileDir)") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($PidFileDir)") | Set-Content -Path $useServiceFile
            } else {
                ((Get-Content -Path $useServiceFile) -replace '<JS7_CONTROLLER_PID_FILE_DIR>', "$($Data)/logs") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($Data)/logs/$($usePidFileName)") | Set-Content -Path $useServiceFile
            }

            ((Get-Content -Path $useServiceFile) -replace '<JS7_CONTROLLER_USER>', "$($User)") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^User[ ]*=[ ]*.*', "User=$($User)") | Set-Content -Path $useServiceFile

            ((Get-Content -Path $useServiceFile) -replace '<INSTALL_PATH>', "$($HomeDir)") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecStart[ ]*=[ ]*.*', "ExecStart=$($HomeDir)/bin/controller_instance.sh start") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecStop[ ]*=[ ]*.*', "ExecStop=$($HomeDir)/bin/controller_instance.sh stop") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecReload[ ]*=[ ]*.*', "ExecReload=$($HomeDir)/bin/controller_instance.sh restart") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardOutput[ ]*=[ ]*syslog\+console.*', "StandardOutput=journal+console") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardError[ ]*=[ ]*syslog\+console.*', "StandardError=journal+console") | Set-Content -Path $useServiceFile

            if ( $JavaHome )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_HOME[ ]*=.*', "Environment=""JAVA_HOME=$($JavaHome)""") | Set-Content -Path $useServiceFile
            }

            if ( $JavaOptions )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_OPTIONS[ ]*=.*', "Environment=""JAVA_OPTIONS=$($JavaOptions)""") | Set-Content -Path $useServiceFile
            }
        }

        # update controller.conf
        $useControllerConfigFile = "$($Config)/controller.conf"

        if ( $Standby )
        {
            if ( Test-Path -Path $useControllerConfigFile -PathType leaf )
            {
                Out-LogInfo ".. updating Controller configuration: $($useControllerConfigFile)"

                ((Get-Content -Path $useControllerConfigFile) -replace '^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*', 'js7.journal.cluster.node.is-backup = yes') | Set-Content -Path $useControllerConfigFile
            }
        } elseif ( $Active ) {
            if ( Test-Path -Path $useControllerConfigFile -PathType leaf )
            {
                Out-LogInfo ".. updating Controller configuration: $($useControllerConfigFile)"

                ((Get-Content -Path $useControllerConfigFile) -replace '^[# ]*js7.journal.cluster.node.is-backup[ ]*=.*', '# js7.journal.cluster.node.is-backup = no') | Set-Content -Path $useControllerConfigFile
            }
        }

        # update private.conf
        $usePrivateConfigFile = "$($Config)/private/private.conf"

        if ( $PrivateConf -and (Test-Path -Path $usePrivateConfigFile -PathType leaf) )
        {
            Out-LogInfo ".. updating Controller configuration: $($usePrivateConfigFile)"

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

            $dn = ''
            if ( $JocPrimaryCert -and (Test-Path -Path $JocPrimaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $JocPrimaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($JocPrimaryCert)"" -noout -nameopt RFC2253 -subject"

                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Primary/Standalone JOC Cockpit distinguished name: $($dn)"
                if ( $JocSecondaryCert )
                {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{joc-primary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
                } else {
                    ((Get-Content -Path $usePrivateConfigFile) -replace '{{joc-primary-distinguished-name}}",', "$($dn)`"") | Set-Content -Path $usePrivateConfigFile
                }
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '^.*{{joc-primary-distinguished-name}}.*$', '') | Set-Content -Path $usePrivateConfigFile
            }

            if ( $JocSecondaryCert -and (Test-Path -Path $JocSecondaryCert -PathType leaf) )
            {
                if ( $isWindows )
                {
                    $certPath = ( Resolve-Path $JocSecondaryCert ).Path
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2( $certPath )
                    $dn = $cert.subject
                } else {
                    $dn = sh -c "openssl x509 -in ""$($JocSecondaryCert)"" -noout -nameopt RFC2253 -subject"
                    if ( $dn.startsWith( 'subject=' ) -or $dn.startsWith( 'subject:' ) )
                    {
                        $dn = $dn.Substring( 'subject='.length )
                    }
                    $dn = $dn.Trim()
                }

                Out-LogInfo ".... updating Secondary JOC Cockpit distinguished name: $($dn)"
                ((Get-Content -Path $usePrivateConfigFile) -replace '{{joc-secondary-distinguished-name}}', "$($dn)") | Set-Content -Path $usePrivateConfigFile
            } else {
                ((Get-Content -Path $usePrivateConfigFile) -replace '^.*{{joc-secondary-distinguished-name}}.*$', '') | Set-Content -Path $usePrivateConfigFile
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
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $KeystorePassword )
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
            $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr )

            $rc = ( Get-CimInstance -ClassName Win32_Service -Filter "Name='$($ServiceName)'" | Invoke-CimMethod -Name Change -Arguments @{StartName="$($ServiceCredentials.UserName)";StartPassword="$($result)";StartMode="$($ServiceStartMode)"} ).ReturnValue
            if ( $rc )
            {
                throw "failed to set Windows Service properties, return code: $($rc)"
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

        Start-ControllerBasic
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
