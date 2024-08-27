<#
.SYNOPSIS
Installs, updates, patches or uninstalls the JS7 JOC Cockpit on Windows and Unix platforms supporting PowerShell 5.1, 6, 7

.DESCRIPTION
The JOC Cockpit Installation Script can be used to automate installing, updating, patching and uninstalling JOC Cockpit.

The script offers the installation options and configuration options available from the JOC Cockpit's graphical installer.

For download see https://kb.sos-berlin.com/display/JS7/JS7+-+Download

.PARAMETER HomeDir
Specifies the directory in which the JOC Cockpit should be installed.

.PARAMETER Data
Specifies the directory in which JOC Cockpit data such as configuration files should be stored.
By default the <home>/jetty_base directory is used.

.PARAMETER InstanceId
Specifies a unique number between 0 and 99 that identifies the JOC Cockpit instance.

The ordering of numbers determines appearence of JOC Cockpit instances in the JOC Cockpit dashboard.

.PARAMETER Release
Specifies a release number of the JS7 JOC Cockpit such as 2.3.1 to be used.

The release will be downloaded from the SOS web site if the -Tarball parameter is not used.

.PARAMETER Tarball
Optionally specifies the path to a .zip or .tar.gz file that holds the JOC Cockpit installation files.
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

* For Unix the download file is https://download.sos-berlin.com/JobScheduler.2.2/js7_joc_linux.2.2.3.JS-1984.tar.gz
* For windows the downloaded file is https://download.sos-berlin.com/JobScheduler.2.2/js7_joc_windows.2.2.3.JS-1984.zip

Patches can be individually downloaded and can be made available from the -Tarball parameter.

For example the -Patch JS-1984 -Tarball /tmp/js7_joc_windows.2.2.3.JS-1984.zip parameters will apply the patch from the downloaded file.

Patches are applied to the JOC Cockpit's <data>/webapps/joc/WEB-INF/classes directory.
Note that patches will be removed when updating the JOC Cockpit installation.

To apply patches JOC Cockpit has to be restarted. The -Restart or -ExecStart, -ExecStop parameters can be used for automated restart.

.PARAMETER Jar
Opetionally specifies the path to a .jar file that holds a patch.

The patch .jar file is copied to the JOC Cockpit's <data>/webapps/joc/WEB-INF/classes directory.

.PARAMETER User
Specifies the user account for the JOC Cockpit daemon in Unix environments.
By default the account of the user running the JOC Cockpit Installation Script is used.

For Windows the -User parameter is informative. The -ServiceCredentials parameter can be used to specify credentials for the Windows Service account
that the JOC Cockpit is operated for.

.PARAMETER SetupDir
Specifies the directory to which the JOC Cockpit installation archive (*.tar.gz, *.zip) will be extracted.
Users can specify a directory, otherwise a temporary directory is created if the -MakeDirs switch is present.

.PARAMETER ResponseDir
Specifies a directory that holds files related to the installation of JOC Cockpit.
The files will be copied to the directory indicated with the -SetupDir parameter.

This option is preferably used if an individual version of the joc_install.xml response file should be applied.
In addition, DBMS JDBC Driver files (*.jar), DBMS Hibernate configuration file and license key file can be used from this directory
if indicated with the joc_install.xml response file.

.PARAMETER LicenseKey
Specifies the path to a license key file (*.pem, *.crt) for use with a commercial license.
A license key file is required should JS7 cluster operations for JOC Cockpit, Controller or Agents be used.

The license key file activates the licensed binary code that implements cluster operations, see -LicenseBin parameter.

.PARAMETER LicenseBin
Specifies the path to a license binary file (*.jar) that implements cluster operations.

Use of licensed binary code is activated by a license key file, see -LicenseKey.

.PARAMETER BackupDir
If a backup directory is specified then an JOC Cockpit's existing installation directory will be added to a backup file in this directory.
The backup file type will be .tar.gz for Unix and .zip for Windows.

File names are created according to the pattern: backup_js7_joc.<hostname>.<release>.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.tar.gz|.zip
For example: backup_js7_joc.centostest_primary.2.3.1.2022-03-19T20-50-45.tar.gz

.PARAMETER LogDir
If a log directory is specified then the Installation Script will log information about processing steps to a log file in this directory.
File names are created according to the pattern: install_js7_joc.<hostname>.<yyyy>-<MM>-<dd>T<hh>-<mm>-<ss>.log
For example: install_js7_joc.centostest_primary.2022-03-19T20-50-45.log

.PARAMETER ExecStart
This parameter can be used should the JOC Cockpit be started after installation.
For example, when using systemd for Unix or using a Windows Service then the -ExecStart "StartService" parameter value
will start the JOC Cockpit service provided that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStart "sudo systemctl start js7_joc".

For Unix systemd service files see the 'JS7 - systemd Service Files for automated Startup and Shutdown with Unix Systems' article.
This parameter is an alternative to use of the -Restart switch which will start the JOC Cockpit from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ExecStop
This parameter can be used should the JOC Cockpit be stopped before installation.
For example, when using Unix systemd or Windows Services then the -ExecStop "StopService" parameter value
will stop the JOC Cockpit service provided that the underlying service has been created manually or by use of the -MakeService switch.

For Unix users can specify individual commands, for example -ExecStop "sudo systemctl stop js7_joc".
This parameter is an alternative to use of the -Restart switch which stops the JOC Cockpit from its Instance Start Script.
If specified this parameter overrules the -Restart switch.

.PARAMETER ReturnValues
Optionally specifies the path to a file to which return values will be added in the format <name>=<key>. For example:

log_file=install_js7_joc.centostest_primary.2022-03-20T04-54-31.log
backup_file=backup_js7_joc.centostest_primary.2.3.1.2022-03-20T04-54-31.tar.gz

An existing file will be overwritten. It is recommended to use a unique file name such as /tmp/return.$PID.properties.
A value from the file can be retrieved like this:

* Unix
** backup=$(cat /tmp/return.$$.properties | grep "backup_file" | cut -d'=' -f2)
* Windows
** $backup = ( Get-Content /tmp/return.$PID.properties | Select-String "^backup_file[ ]*=[ ]*(.*)" ).Matches.Groups[1].value

.PARAMETER DeployDir
Specifies the path to a deployment directory that holds configuration files and sub-directories that will be copied to the <data>/resources/joc directory.
A deployment directory allows to manage central copies of configuration files such as joc.properties, log4j2.xml etc.

Use of a deployment directory has lower precedence as files can be overwritten by individual parameters such as -Properties etc.

.PARAMETER Ini
Specifies an array of *.ini files that will be copied to the <data>/start.d directory.
Typically the following .ini files can be provided:

* http.ini: specifies use of the HTTP module and HTTP Port
* https.ini: specifies use of the HTTPS module and HTTPS Port
* ssl.ini: specifies SSL related settings

.PARAMETER Properties
Specifies the path to a configuration file for global JOC Cockpit configuration items. The file will be copied to the <data>/resources/joc/joc.properties file.

Any path to a file can be used as a value of this parameter, however, the target file name joc.properties will be used.

.PARAMETER Title
Specifies the caption of the JOC Cockpit icon in the Dashboard view of the GUI.

.PARAMETER SecurityLevel
Specifies one of the security levels that are applied to digitally sign scheduling objects such as workflows during deployment:

* low (default): use of a common signing key for all JOC Cockpit user accounts.
* medium: use of an individual signing key per JOC Cockpit user account.
* high: use of an individual signing key per account that is stored outside of JOC Cockpit.

When using the security levels medium or high then users have to manage a Certificate Authority
to create and to sign certificates and have to import certificates to JOC Cockpit.

.PARAMETER DBMSConfig
Specifies the path to a hibernate.cfg.xml file that holds credentials and details for the database connection.
Check the 'JS7 - Database' article for details and examples.

When using the H2 DBMS then the shortcut -DBMSConfig 'H2' can be used and no Hibernate configuration file is required.

.PARAMETER DBMSDriver
The JS7 ships with JDBC Drivers for a number of DBMS such as MariaDB, MySQL, Oracle, PostgreSQL.
For other DBMS such as SQL Server and H2 users have to download the JDBC Driver .jar file from the DBMS vendor's site.

See the 'JS7 - Database' article for versions of JDBC Drivers that ship with JS7.

.PARAMETER DBMSInit
Specifies the point in time when objects such as tables are created in the database:

* byInstaller (default): at the point in time of installation
* byJoc: on each start-up JOC Cockpit will check if database objects have to be updated
* off: users create database objects from a database client

.PARAMETER HttpPort
Specifies the HTTP port that the JOC Cockpit is operated for. The default value is 4446.

The port can be prefixed by the network interface, for example joc.example.com:4446.
When used with the -Restart switch the HTTP port is used to identify if the JOC Cockpit is running.

.PARAMETER HttpsPort
Specifies the HTTPS port that the JOC Cockpit is operated for.

Use of HTTPS requires a keystore and truststore to be present, see -Keystore and -Truststore parameters.
The port can be prefixed by the network interface, for example joc.example.com:4446.

.PARAMETER PidFileDir
Specifies the directory to which the JOC Cockpit stores its PID file. By default the <data>/logs directory is used.
When using SELinux then it is recommended to specify the /var/run directory, see JS7 - How to install for SELinux.

.PARAMETER PidFileName
Specifies the name of the PID file in Unix environments. By default the file name joc.pid is used.
The PID file is created in the directory specified by the -PidFileDir parameter.

.PARAMETER Keystore
Specifies the path to a PKCS12 keystore file that holds the private key and certificate for HTTPS connections to the JOC Cockpit.
Users are free to specify any file name, typically the name https-keystore.p12 is used. The keystore file will be copied to the <data>/resources/joc directory.

If a keystore file is made available then the JOC Cockpit's <data>/resources/joc/joc.properties file has to hold a reference to the keystore location and the keystore password.
It is therefore recommended to use the -PrivateConf parameter to deploy an individual private.conf file that holds settings related to a keystore.
For automating the creation of keystores see JS7 - How to add SSL TLS Certificates to Keystore and Truststore.

.PARAMETER KeystorePassword
Specifies the password for access to the keystore from a secure string. Use of a keystore password is required.

There are a number of ways how to specify secure strings, for example:

-KeystorePassword ( 'secret' | ConvertTo-SecureString -AsPlainText -Force )

.PARAMETER KeyAlias
If a keystore holds more than one private key, for example if separate pairs of private keys/certificates for server authentication and client authentication exist, then it is not determined which private key/certificate will be used.

The alias name of a given private key/certificate is specified when the entry is added to the keystore. The alias name allows to indicate a specific private key/certificate to be used.

.PARAMETER Truststore
Specifies the path to a PKCS12 truststore file that holds the certificate(s) for HTTPS connections to the JOC Cockpit using mutual authentication .
Users are free to specify any file name, typically the name https-truststore.p12 is used. The truststore file will be copied to the <data>/resources/joc directory.

If a truststore file is made available then the JOC Cockpit's <data>/resources/joc/joc.properties file has to hold a reference to the truststore location and the truststore password.
It is therefore recommended to use the -PrivateConf parameter to deploy an individual private.conf file that holds settings related to a truststore.
For automating the creation of truststores see JS7 - How to add SSL TLS Certificates to Keystore and Truststore.

.PARAMETER TruststorePassword
Specifies the password for access to the truststore from a secure string.
Use of a password is recommended: it is not primarily intended to protect access to the truststore, but to ensure integrity.
The password is intended to allow verification that truststore entries have been added using the same password.

There are a number of ways how to specify secure strings, for example:

-TruststorePassword ( 'secret' | ConvertTo-SecureString -AsPlainText -Force )

.PARAMETER JavaHome
Specifies the Java home directory that will be made available to the JOC Cockpit from the JAVA_HOME environment variable
specified with the JOC Cockpit profile typically available from the $HOME/.jocrc script.

.PARAMETER JavaOptions
Specifies the Java options that will be made available to the JOC Cockpit from the JAVA_OPTIONS environment variable specified with the JOC Cockpit profile typically available from the $HOME/.jocrc script.

Java options can be used for example to specify Java heap space settings for the JOC Cockpit.
If more than one Java option is used then the value has to be quoted, for example -JavaOptions "-Xms256m -Xmx512m".

.PARAMETER ServiceDir
For Unix environments specifies the systemd service directory to which the JOC Cockpit's service file will be copied if the -MakeService switch is used.
By default the /usr/lib/systemd/system directory will be used. Users can specify an alternative location.

.PARAMETER ServiceFile
For Unix environments specifies the path to a systemd service file that acts as a template and that will be copied to the JOC Cockpit's <home>/jetty/bin directory.
Users are free to choose any file name as a template for the service file. The resulting service file name will be joc.service.
The Installation Script will perform replacements in the service file to update paths and the port to be used, for details see ./bin/jetty.service-example.

.PARAMETER ServiceName
For Unix environments specifies the name of the systemd service that will be created if the -MakeService switch is used.
By default the service name js7_joc will be used.

For Windows the service name is not specified, instead the service name js7_joc will be used.
Optionally a suffix to the service name can be added with the -ServiceNameSuffix parameter.

.PARAMETER ServiceNameSuffix
For Windows environments the Windows service name is not specified. Instead the service name js7_joc will be used.

The parameter optionally specifies a suffix that is appended the Windows service name.

.PARAMETER ServiceCredentials
In Windows environments the credentials for the Windows service account can be specified for which the JOC Cockpit should be operated.

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

.PARAMETER AsUser
Performs the installation for the user account specified with the -User parameter.
Without this switch the installation is performend with administrative privileges.

.PARAMETER ServiceDisplayName
For Windows environments allows to specify the display name of the JOC Cockpit's Windows Service.

.PARAMETER PreserveEnv
In Unix environments if the -AsUser parameter is not used then 'sudo' will be used to switch to the root account for installation
of files in the <home> directory. The switch specifies if environment variables such as JAVA_HOME that are available with the
current user account will be preserved and forwarded to the 'sudo' session.

.PARAMETER AsApiServer
Installs JOC Cockpit for use as an API Server instance without user interface. 
Users cannot login to the JOC Cockpit instance as it is used for API requests from jobs and REST Clients only.

Any number of API Servers instances can be operated in parallel, the instances are not subject to clustering.

.PARAMETER NoConfig
Specifies that no configuration changes will be applied. This switch can be used for example if JOC Cockpit should be started or stopped only,
using the -Restart or -ExecStart, -ExecStop arguments.

.PARAMETER NoInstall
Specifies if the Installation Script should be used to update configuration items without changes to the binary files of the installation.
In fact no installation is performed but configuration changes as for example specified with the -Keystore parameter will be applied.

.PARAMETER NoJetty
Specifies that JOC Cockpit will be installed without the Jetty Servlet Container.
This option is applicable if users prefer to use an alternative Servlet Container.

.PARAMETER Uninstall
Uninstalls JOC Cockpit including the steps to stop and remove a running JOC Cockpit service and to remove the <home> and <data> directories.

.PARAMETER ShowLogs
Displays the log output created by the Installation Script if the -LogDir parameter is used.

.PARAMETER MakeDirs
If directories are missing that are indicated with the -HomeDir, -SetupDir, -BackupDir or -LogDir parameters then they will be created.

.PARAMETER MakeService
Specifies that for Unix environments a systemd service should be created, for Windows environments a Windows Service should be created.
In Unix environments the service name will be created from the -ServiceName parameter value or from its default value.

.PARAMETER Restart
Stops a running JOC Cockpit before installation and starts the JOC Cockpit after installation using the JOC Cockpit's Instance Start Script.
This switch can be used with the-Kill switch to control the way how the JOC Cockpit is terminated.
This switch is ignored if the -ExecStart or -ExecStop parameters are used.

.PARAMETER Kill
Kills a running JOC Cockpit and any running tasks if used with the -Restart switch.
This includes killing child processes of running tasks.

Killing a JOC Cockpit prevents journal files from being closed in an orderly manner.

.EXAMPLE
Install-JS7Joc.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\joc" -Data "C:\ProgramData\sos-berlin.com\js7\joc" -Release 2.5.1 -HttpPort 4446 -MakeDirs

Downloads and installs the JOC Cockpit release to the indicated location.

.EXAMPLE
Install-JS7Joc.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\joc" -Data "C:\ProgramData\sos-berlin.com\js7\joc" -Tarball /tmp/js7_joc_windows.2.5.1.zip -BackupDir /tmp/backups -LogDir /tmp/logs -HttpPort 4446 -MakeDirs

Applies the JOC Cockpit release from a tarball and installs to the indicated locations. A backup is taken and log files are created.

.EXAMPLE
Install-JS7Joc.ps1 -HomeDir "C:\Program Files\sos-berlin.com\js7\joc" -Data "C:\ProgramData\sos-berlin.com\js7\joc" -Tarball /tmp/js7_joc_windows.2.5.1.zip -HttpPort localhost:4446 -HttpsPort apmacwin:4446 -JavaHome "C:\Program Files\Java\jdk-11.0.12+7-jre" -JavaOptions "-Xmx512m" -MakeDirs

Applies the JOC Cockpit release from a tarball and installs to the indicated locations. HTTP and HTTP port are the same using different network interfaces. The location of Java and Java Options are indicated.

#>

[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HomeDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Data,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $InstanceId = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Release,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Tarball,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Patch,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Jar,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $User,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $SetupDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ResponseDir,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $LicenseKey,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $LicenseBin,
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
    [string[]] $Ini,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Properties,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Title,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('low','medium','high')]
    [string] $SecurityLevel = 'low',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $DBMSConfig,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $DBMSDriver,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('byInstaller','byJoc','Off')]
    [string[]] $DBMSInit = 'byInstaller',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HttpPort,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $HttpsPort,
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
    [string] $ServiceDir = '/usr/lib/systemd/system',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceFile,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceNameSuffix,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ServiceCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('System','Automatic','Manual','Disabled')]
    [string] $ServiceStartMode = 'Automatic',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ServiceDisplayName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $AsUser,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PreserveEnv,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $AsApiServer,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoConfig,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoInstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoJetty,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Uninstall,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ShowLogs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $MakeDirs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $MakeService,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Restart,
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

    if ( !$HttpPort -and !$HttpsPort )
    {
        $script:HttpPort = 4446
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
        $script:ServiceNamePrefix = 'js7_'
        $script:ServiceNameDefault = "$($ServiceNamePrefix)joc"
        if ( !$ServiceName )
        {
            if ( $ServiceNameSuffix )
            {
                $script:ServiceName = "$($ServiceNameDefault)_$($ServiceNameSuffix)"
            } else {
                $script:ServiceName = $ServiceNameDefault
            }
        }
    } else {
        $script:ServiceNamePrefix = 'js7_'
        $script:ServiceNameDefault = "$($ServiceNamePrefix)joc.service"
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

    # nop operations to work around ScriptAnalyzer bugs
    $script:ServiceDir = $ServiceDir
    $script:ExecStart = $ExecStart
    $script:ExecStop = $ExecStop
    $script:ReturnValues = $ReturnValues
    $script:ShowLogs = $ShowLogs
    $script:Restart = $Restart
    $script:Kill = $Kill

    # default variables
    $script:tmpSetupDir = $null
    $script:clusterId = 'joc'
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
                ( Get-Process -Name "js7_joc_$($clusterId)#$($InstanceId)" -ErrorAction silentlycontinue ).length
            } else {
                ( Get-Process -Name "js7_joc_*" -ErrorAction silentlycontinue ).length
            }
        } else {
            sh -c "ps -ef | grep -E ""\-Djetty.base=([^ ]+)"" | grep -v ""grep"" | awk '{print $2}'"
        }
    }

    function Start-JocBasic()
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
                        if ( $PSCmdlet.ShouldProcess( 'Start-JocBasic', 'start service' ) )
                        {
                            Out-LogInfo ".. starting JOC Cockpit Windows Service: $($ServiceName)"
                            Start-Service -Name $ServiceName | Out-Null
                        }
                    }
                } else {
                    if ( !$MakeService )
                    {
                        Out-LogError ".. JOC Cockpit Windows Service not found and -MakeService switch not present (Start-JocBasic): $($ServiceName)"
                    } else {
                        Out-LogError ".. JOC Cockpit Windows Service not found (Start-JocBasic): $($ServiceName)"
                    }
                }
            }
        } else {
            if ( $ExecStart )
            {
                Out-LogInfo ".. starting JOC Cockpit (Start-JocBasic): $($ExecStart)"
                if ( $ExecStart -eq 'StartService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStart, 'start service' ) )
                    {
                        Start-JocService
                    }
                } else {
                    sh -c "$($ExecStart)"
                }
            } else {
                if ( $Restart )
                {
                    if ( Test-Path -Path "$($HomeDir)/jetty/bin" -PathType container )
                    {
                        if ( Test-Path -Path "$($HomeDir)/jetty/bin/jetty.sh" -PathType leaf)
                        {
                            Out-LogInfo ".. starting JOC Cockpit: $($HomeDir)/jetty/bin/jetty.sh start"

                            if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                            {
                                $startJocOutputFile = "/tmp/js7_install_joc_start_$($PID).tmp"
                                New-Item $startJocOutputFile -ItemType file
                                sh -c "( ""$($HomeDir)/jetty/bin/jetty.sh"" start > ""$($startJocOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startJocOutputFile))"" && exit 5 )"
                                Out-LogInfo Get-Content -Path $startJocOutputFile
                            } else {
                                sh -c "$($HomeDir)/jetty/bin/jetty.sh start"
                            }
                        } else {
                            if ( Test-Path -Path "$($HomeDir)/jetty/bin/jetty.sh" -PathType leaf )
                            {
                                Out-LogInfo ".. starting JOC Cockpit: $($HomeDir)/jetty/bin/jetty.sh start"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $startJocOutputFile = "/tmp/js7_install_joc_start_$($PID).tmp"
                                    New-Item $startJocOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/jetty/bin/jetty.sh"" start > ""$($startJocOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($startJocOutputFile))"" && exit 5 )"
                                    Out-LogInfo Get-Content -Path $startJocOutputFile
                                } else {
                                    sh -c "$($HomeDir)/jetty/bin/jetty.sh start"
                                }
                            } else {
                                Out-LogError "could not start JOC Cockpit, start script missing: $($HomeDir)/jetty/bin/jetty.sh"
                            }
                        }
                    } else {
                        Out-LogError "could not start JOC Cockpit, directory missing: $($HomeDir)/jetty/bin"
                    }
                }
            }
        }
    }

    function Stop-JocBasic()
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
                    if ( $PSCmdlet.ShouldProcess( 'Stop-JocBasic', 'stop service' ) )
                    {
                        Out-LogInfo ".. stopping JOC Cockpit Windows Service (Stop-JocBasic): $($ServiceName)"
                        Stop-Service -Name $ServiceName -Force
                        Start-Sleep -Seconds 3
                    }
                }
            } else {
                Out-LogInfo ".. JOC Cockpit Windows Service not found (Stop-JocBasic): $($ServiceName)"
            }
        } else {
            if ( $ExecStop )
            {
                Out-LogInfo ".. stopping JOC Cockpit: $($ExecStop)"
                if ( $ExecStop -eq 'StopService' )
                {
                    if ( $PSCmdlet.ShouldProcess( $ExecStop, 'stop service' ) )
                    {
                        Stop-JocService
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
                        $stopOption = 'stop'
                    }

                    if ( Get-PID )
                    {
                        if ( Test-Path -Path "$($HomeDir)/jetty/bin" -PathType container )
                        {
                            if ( Test-Path -Path "$($HomeDir)/jetty/bin/jetty.sh" -PathType leaf )
                            {
                                Out-LogInfo ".. stopping JOC Cockpit: $($HomeDir)/jetty/bin/jetty.sh $($stopOption)"

                                if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                {
                                    $stopJocOutputFile = "/tmp/js7_install_joc_stop_$($PID).tmp"
                                    New-Item $stopJocOutputFile -ItemType file
                                    sh -c "( ""$($HomeDir)/jetty/bin/jetty.sh"" $($stopOption) > ""$($stopJocOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopJocOutputFile))"" && exit 6 )"
                                    Out-LogInfo Get-Content -Path $stopJocOutputFile
                                } else {
                                    sh -c "$($HomeDir)/jetty/bin/jetty.sh $($stopOption)"
                                }
                            } else {
                                if ( Test-Path -Path "$($HomeDir)/jetty/bin/jetty.sh" )
                                {
                                    Out-LogInfo ".. stopping JOC Cockpit: $($HomeDir)/jetty/bin/jetty.sh $($stopOption)"

                                    if ( $logFile -and (Test-Path -Path $logFile -PathType leaf) )
                                    {
                                        $stopJocOutputFile = "/tmp/js7_install_joc_stop_$($PID).tmp"
                                        New-Item -Path $stopJocOutputFile -ItemType file
                                        sh -c "( ""$($HomeDir)/jetty/bin/jetty.sh"" $($stopOption) > ""$($stopJocOutputFile)"" 2>&1 ) || ( >&2 echo ""[ERROR]"" ""$(\cat $($stopJocOutputFile))"" && exit 6 )"
                                        Out-LogInfo Get-Content -Path $stopJocOutputFile
                                    } else {
                                        sh -c "$($HomeDir)/jetty/bin/jetty.sh $($stopOption)"
                                    }
                                } else {
                                    Out-LogError "could not stop JOC Cockpit, start script missing: $($HomeDir)/jetty/bin/jetty.sh"
                                }
                            }
                        } else {
                            Out-LogError "could not stop JOC Cockpit, directory missing: $($HomeDir)/jetty/bin"
                        }
                    } else {
                        Out-LogInfo ".. JOC Cockpit not started"
                    }
                }
            }
        }
    }

    function Register-Service( [string] $useSystemdServiceFile )
    {
        if ( !$isWindows )
        {
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

    function Start-JocService()
    {
        [CmdletBinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Start-JocService', 'start service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Out-LogInfo ".. starting JOC Cockpit Windows Service (Start-JocService): $($ServiceName)"
                    Start-Service -Name $ServiceName | Out-Null
                } else {
                    Out-LogInfo "JOC Cockpit Windows Service not found: $($ServiceName)"
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

    function Stop-JocService()
    {
        [cmdletbinding(SupportsShouldProcess)]
        param (
        )

        if ( $isWindows )
        {
            if ( $PSCmdlet.ShouldProcess( 'Stop-JocService', 'stop service' ) )
            {
                if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                {
                    Out-LogInfo ".. stopping JOC Cockpit Windows Service (Stop-JocService): $($ServiceName)"
                    Stop-Service -Name $ServiceName -ErrorAction silentlycontinue | Out-Null
                    Start-Sleep -Seconds 3
                } else {
                    Out-LogInfo "JOC Cockpit Windows Service not found (Stop-JocService): $($ServiceName)"
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
        if ( $ResponseDir -and !(Test-Path -Path $ResponseDir -PathType container) )
        {
            Out-LogError "Response directory not found: -ResponseDir $($ResponseDir)"
            return 1
        }

        if ( !$MakeDirs -and !$SetupDir -and !$Patch -and !$NoInstall -and !$Uninstall )
        {
            Out-LogError "Setup directory not specified and -MakeDirs switch not present: -SetupDir, -MakeDirs"
            return 1
        }

        if ( !$MakeDirs -and $SetupDir -and !(Test-Path -Path $SetupDir -PathType container) )
        {
            Out-LogError "Setup directory not found and -MakeDirs switch not present: -SetupDir $SetupDir"
            return 1
        }

        if ( !$HomeDir -and $ResponseDir -and (Test-Path -Path "$($RespnseDir)/joc_install.xml" -PathType leaf) )
        {
            $Match = Get-Content -Path "$($ResponseDir)/joc_install.xml" | Select-String ".*<installpath>(.*)</installpath>.*"
            if ( $Match -and $Match.Matches.Groups.length -gt 1 )
            {
                $script:HomeDir = $Match.Matches.Groups[1].value
            }
        }

        if ( !$Data -and $ResponseDir -and (Test-Path -Path "$($RespnseDir)/joc_install.xml" -PathType leaf) )
        {
            $Match = Get-Content -Path "$($ResponseDir)/joc_install.xml" | Select-String ".*<entry[ ]+key[ ]*=[ ]*`"jettyBaseDir`"[ ]+value[ ]*=[ ]*`"(.*)`".*"
            if ( $Match -and $Match.Matches.Groups.length -gt 1 )
            {
                $script:Data = $Match.Matches.Groups[1].value
            }
        }

        if ( $Uninstall -and !$HomeDir )
        {
            Out-LogError "Home directory has to be specified if -Uninstall switch is present: -HomeDir"
            return 1
        }

        if ( $Uninstall -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Home directory not found and -Uninstall switch is present: -HomeDir $HomeDir"
            return 1
        }

        if ( $LicenseKey -and !(Test-Path -Path $LicenseKey -PathType leaf) )
        {
            Out-LogError "License key file not found: -LicenseKey $LicenseKey"
            return 1
        }

        if ( $LicenseBin -and !(Test-Path -Path $LicenseBin -PathType leaf) )
        {
            Out-LogError "License binary file not found: -LicenseBin $LicenseBin"
            return 1
        }

        if ( !$LicenseKey -and $LicenseBin )
        {
            Out-LogError "License key file not specified and -LicenseBin option is present: -LicenseKey"
        }

        if ( !$MakeDirs -and $BackupDir -and !(Test-Path -Path $BackupDir -PathType container) )
        {
            Out-LogError "Backup directory not found and -MakeDirs switch not present: -BackupDir $BackupDir"
            return 1
        }

        if ( $BackupDir -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Home directory not found and -BackupDir option present: -HomeDir $($HomeDir)"
            return 1
        }

        if ( $DeployDir )
        {
            foreach( $dir in $DeployDir )
            {
                if ( !(Test-Path -Path $dir -PathType container) )
                {
                    Out-LogError "Deployment directory not found: -DeployDir $dir"
                    return 1
                }
            }
        }

        if ( $Ini )
        {
            foreach( $iniFile in $Ini )
            {
                if ( !(Test-Path -Path $iniFile -PathType leaf) )
                {
                    Out-LogError "Jetty *.ini file not found: -Ini $iniFile"
                    return 1
                }
            }
        }

        if ( $Properties -and !(Test-Path -Path $Properties -PathType leaf) )
        {
            Out-LogError "Properties configuration file not found (joc.properties): -Properties $Properties"
            return 1
        }

        if ( $DBMSConfig -and $DBMSConfig -ne 'H2' -and !(Test-Path -Path $DBMSConfig -PathType leaf) )
        {
            Out-LogError "Hibernate configuration file not found: -DBMSConfig $DBMSConfig"
            return 1
        }

        if ( $DBMSDriver -and !(Test-Path -Path $DBMSDriver -PathType leaf) )
        {
            Out-LogError "JDBC Driver file not found: -DBMSDriver $DBMSDriver"
            return 1
        }

        if ( !$MakeDirs -and $LogDir -and !(Test-Path -Path $LogDir -PathType container) )
        {
            Out-LogError "Log directory not found and -MakeDirs switch not present: -LogDir $LogDir"
            return 1
        }

        if ( !$Release -and !$Tarball -and !$Jar -and !$NoInstall -and !$Uninstall )
        {
            Out-LogError "Release must be specified if -Tarball option is not used and -NoInstall switch not present: -Release"
            return 1
        }

        if ( $Tarball -and !(Test-Path -Path $Tarball -PathType leaf) )
        {
            Out-LogError "Tarball not found (*.tar.gz, *.zip): -Tarball $Tarball"
            return 1
        }

        if ( $Patch -and !(Test-Path -Path $HomeDir -PathType container) )
        {
            Out-LogError "Home directory not found and -Patch option is present: -HomeDir $HomeDir"
            return 1
        }

        if ( $AsApiServer )
        {
            $script:clusterId = 'api'
        }

        if ( $ShowLogs -and !$LogDir )
        {
            Out-LogError "Log directory not specified and -ShowLogs switch is present: -LogDir"
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
                if ( $java )
                {
                    $javaHomeDir = (Get-Item -Path $java.Source).Directory.Parent.Name
                    [Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHomeDir)
                }
            }

            if ( !$java )
            {
                Out-LogError "Java home not specified and no JAVA_HOME environment variable in place: -JavaHome"
                return 1
            }
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

        if ( $isWindows -and ( $ServiceName -ne $ServiceNameDefault -and $ServiceName -ne "$($ServiceNameDefault)_$($ServiceNameSuffix)" ) )
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
        if ( $tmpSetupDir -and (Test-Path -Path $tmpSetupDir -PathType container) )
        {
            if ( $isWindows )
            {
                Start-Sleep -Seconds 3
            }
            Remove-Item -Path $tmpSetupDir -Recurse -Force
        }

        if ( $tarDir -and (Test-Path -Path $tarDir -PathType container) )
        {
            Remove-Item -Path $tarDir -Recurse -Force
        }

        if ( $startJocOutputFile -and (Test-Path -Path $startJocOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($startJocOutputFile)"
            Remove-Item -Path $startJocOutputFile -Force
        }

        if ( $stopJocOutputFile -and (Test-Path -Path $stopJocOutputFile -PathType leaf) )
        {
            # Out-LogInfo ".. removing temporary file: $($stopJocOutputFile)"
            Remove-Item -Path $stopJocOutputFile -Force
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
    if ( isPowerShellVersion 7 )
    {
        Get-Alias | Where-Object { $_.Options -NE "Constant" } | Remove-Alias -Force
    }

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

        $logFile = "$($LogDir)/install_js7_joc.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
        while ( Test-Path -Path $logFile -PathType leaf )
        {
            Start-Sleep -Seconds 1
            $script:startTime = Get-Date
            $script:logFile = "$($LogDir)/install_js7_joc.$($hostname).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').log"
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

    try
    {
        if ( $Data )
        {
            $baseDir = $Data
            $configDir = "$($Data)/resources/joc"
        } else {
            $baseDir = "$($HomeDir)"
            $configDir = "$($HomeDir)/resources/joc"
        }

        # Java required for installation (except for patches)
        if ( $JavaHome )
        {
            [Environment]::SetEnvironmentVariable('JAVA_HOME', $JavaHome)
            [Environment]::SetEnvironmentVariable('JAVA', "$($JavaHome)/bin/java")
        } elseif ( !$Patch -and !$NoInstall ) {
            if ( $env:JAVA_HOME )
            {
                [Environment]::SetEnvironmentVariable('JAVA', "$($env:JAVA_HOME)/bin/java")
            }
        }

        if ( $Uninstall )
        {
            Stop-JocBasic

            if ( $isWindows )
            {
                if ( Test-Path -Path "$($HomeDir)/Uninstaller)/uninstaller.jar" -PathType leaf )
                {
                    if ( $env:JAVA_HOME )
                    {
                        $java = "$($env:JAVA_HOME)/bin/java"
                    } else {
                        $java = "java"
                    }

                    Out-LogInfo ".... running uninstaller: cmd.exe /C ""$($java)"" ""$($HomeDir)/Uninstaller/uninstaller.jar"" -c -f"
                    cmd.exe /C """$($java)""" -jar """$($HomeDir)/Uninstaller/uninstaller.jar""" -c -f
                } else {
                    Out-LogInfo ".... uninstaller not available"

                    if ( Get-Service -Name $ServiceName -ErrorAction silentlycontinue )
                    {
                        if ( isPowerShellVersion 6 )
                        {
                            Out-LogInfo ".... removing Windows Service: $($ServiceName)"
                            Remove-Service -Name $ServiceName -ErrorAction silentlycontinue | Out-Null
                        } else {
                            Out-LogInfo ".... removing Windows Service using command: sc.exe delete $($ServiceName)"
                            cmd.exe /C "sc.exe delete $($ServiceName)"
                        }
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

            # remove symlinks before removing directories
            if ( Test-Path -Path $HomeDir -PathType container )
            {
                $items = Get-ChildItem -Path $HomeDir | Where-Object { $_.Attributes -match "ReparsePoint" }
                foreach( $item in $items )
                {
                    $item.Delete()
                }
            }

            # remove symlinks before removing directories
            if ( Test-Path -Path $Data -PathType container )
            {
                $items = Get-ChildItem -Path $Data | Where-Object { $_.Attributes -match "ReparsePoint" }
                foreach( $item in $items )
                {
                    $item.Delete()
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
                    $Tarball = "js7_joc_windows.$($Release).$($Patch).zip"
                } else {
                    $Tarball = "js7_joc_linux.$($Release).$($Patch).tar.gz"
                }
            } else {
                if ( $isWindows )
                {
                    $Tarball = "js7_joc_windows.$($Release).zip"
                } else {
                    $Tarball = "js7_joc_linux.$($Release).tar.gz"
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
        if ( $BackupDir -and $HomeDir -and (Test-Path -Path $HomeDir -PathType container) )
        {
            if ( $MakeDirs -and !(Test-Path -Path $BackupDir -PathType container) )
            {
                New-Item -Path $BackupDir -ItemType directory | Out-Null
            }

            $version = '0.0.0'
            if ( Test-Path -Path "$($baseDir)/webapps/joc/version.json" -PathType leaf )
            {
                $Match = Get-Content "$($baseDir)/webapps/joc/version.json" | Select-String """version"":[ ]*""([^""]{1,}).*$"
                if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                {
                    $version = $Match.Matches.Groups[1].value
                }

                $backupFile = "$($BackupDir)/backup_js7_joc.$($hostname).$($version).$(Get-Date $startTime -Format 'yyyy-MM-ddTHH-mm-ss').zip"
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
                $tarDir = "$($env:TEMP)/js7_install_joc_$($PID).tmp"
            } else {
                $tarDir = "/tmp/js7_install_joc_$($PID).tmp"
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

        Stop-JocBasic

        if ( $Patch )
        {
            if ( Test-Path -Path "$($baseDir)/webapps/joc/WEB-INF/classes" -PathType container )
            {
                if ( Test-Path -Path "$($baseDir)/webapps/joc/WEB-INF/classes/joc-settings.properties" -PathType leaf )
                {
                    $Match = Get-Content "$($baseDir)/webapps/joc/WEB-INF/classes/joc-settings.properties" | Select-String "security_level[ ]*=[ ]*(.*)$"
                    if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                    {
                        $currentSecurityLevel = $Match.Matches.Groups[1].value
                        if ( $Tarball.IndexOf( $currentSecurityLevel ) -lt 0 )
                        {
                           Out-LogInfo ".. ccurrent security level is '$($currentSecurityLevel)', non-matching security level from patch tarball: -Tarball $Tarball"
                        }
                    }
                }

                if ( $Tarball )
                {
                    # copy to JOC Cockpit base directory
                    Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/. to JOC Cockpit patch directory: $($baseDir)/webapps/joc/WEB-INF/classes"
                    Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination "$($baseDir)/webapps/joc/WEB-INF/classes" -Recurse -Force
                } elseif ( $Jar ) {
                    Out-LogInfo ".. copying patch .jar file: $($Jar) to JOC Cockpit patch directory: $($baseDir)/webapps/joc/WEB-INF/classes"
                    Copy-Item -Path $Jar -Destination "$($baseDir)/webapps/joc/WEB-INF/classes" -Force
                }

                $jarFiles = Get-ChildItem -Path "$($baseDir)/webapps/joc/WEB-INF/classes/*.jar" -File
                $jarFiles | Rename-Item -NewName { [io.path]::ChangeExtension($_.name, "zip") }
                $jarFiles = Get-ChildItem -Path "$($baseDir)/webapps/joc/WEB-INF/classes/*.zip" -File
                foreach( $jarFile in $jarFiles )
                {
                    Out-LogInfo ".... extracting patch .jar file: $jarFile"
                    Expand-Archive -Path $jarFile -DestinationPath "$($baseDir)/webapps/joc/WEB-INF/classes" -Force
                    Out-LogInfo ".... removing patch .jar file: $jarFile"
                    Remove-Item -Path $jarFile -Force
                }

                Start-JocBasic
                Out-LogInfo "-- end of log ----------------"
                return
            } else {
                Out-LogError "JOC Cockpit patch directory not found: $($baseDir)/webapps/joc/WEB-INF/classes"
            }
        }

        if ( !$NoInstall )
        {
            # create JOC Cockpit setup directory if required
            if ( !$SetupDir )
            {
                if ( $isWindows )
                {
                    $script:SetupDir = "$($env:TEMP)/js7_install_joc_$($PID).setup"
                } else {
                    $script:SetupDir = "/tmp/js7_install_joc_$($PID).setup"
                }
                $script:tmpSetupDir = $SetupDir

                if ( !(Test-Path -Path $SetupDir -PathType container) )
                {
                    Out-LogInfo ".. creating setup directory: $($SetupDir)"
                    New-Item -Path $SetupDir -ItemType directory | Out-Null
                }
            }

            # copy to JOC Cockpit setup directory
            Out-LogInfo ".. copying files from extracted tarball directory: $($tarDir)/$($tarRoot) to JOC Cockpit setup directory: $($SetupDir)"
            Copy-Item -Path "$($tarDir)/$($tarRoot)/*" -Destination $SetupDir -Recurse -Force

            if ( $ResponseDir )
            {
                Out-LogInfo ".. copying installer response files from $($ResponseDir) to $($SetupDir)"
                Copy-Item -Path "$($ResponseDir)/*" -Destination $SetupDir -Recurse -Force
            }

            # update installer options
            $useJocInstallXml = "$($SetupDir)/joc_install.xml"
            ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"launchJetty"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}no`${3}") | Set-Content -Path $useJocInstallXml
            ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"withJocInstallAsDaemon"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}no`${3}") | Set-Content -Path $useJocInstallXml

            if ( $HomeDir )
            {
                Out-LogInfo ".. updating home directory in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<installpath>)(.*)(</installpath>)', "`${1}$($HomeDir)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $baseDir )
            {
                Out-LogInfo ".. updating data directory in response file ${useJocInstallXml}"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"jettyBaseDir"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($baseDir)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $AsApiServer )
            {
                Out-LogInfo ".. updating API Server settings in response file ${useJocInstallXml}"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"asApiServer"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}yes`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $User )
            {
                Out-LogInfo ".. updating run-time user account in response file ${useJocInstallXml}"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"runningUser"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($User)`${3}") | Set-Content -Path $useJocInstallXml
            } else {
                if ( $ResponseDir -and (Test-Path -Path "$($ResponseDir)/joc_install.xml" -PathType leaf) )
                {
                    $Match = Get-Content "$($ResponseDir)/joc_install.xml" | Select-String '<entry[ ]*key[ ]*=[ ]*"runningUser"[ ]*value[ ]*=[ ]*"(.*)"/>'
                    if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                    {
                        $User = $Match.Matches.Groups[1].value
                    }
                }
            }

            if ( $clusterId )
            {
                Out-LogInfo ".. updating Cluster ID in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"jocClusterId"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($clusterId)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $InstanceId -gt -1 )
            {
                Out-LogInfo ".. updating Instance ID in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"ordering"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($InstanceId)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $Title )
            {
                Out-LogInfo ".. updating title in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"jocTitle"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($Title)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $SecurityLevel )
            {
                Out-LogInfo ".. updating security level in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"securityLevel"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($SecurityLevel)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $NoJetty )
            {
                Out-LogInfo ".. updating use of Jetty Servlet Container in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"withJettyInstall"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}no`${3}'") | Set-Content -Path $useJocInstallXml
            }

            if ( !$MakeService )
            {
                Out-LogInfo ".. updating use of systemd service in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"withJocInstallAsDaemon"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}no`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $DBMSConfig )
            {
                Out-LogInfo ".. updating DBMS Hibernate configuration in response file $($useJocInstallXml)"
                if ( $DBMSConfig -eq 'H2' )
                {
                    ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"databaseConfigurationMethod"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}h2`${3}") | Set-Content -Path $useJocInstallXml
                } else {
                    ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"hibernateConfFile"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($DBMSConfig)`${3}") | Set-Content -Path $useJocInstallXml
                    ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"databaseDbms"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}`${3}") | Set-Content -Path $useJocInstallXml

                    $Match = Get-Content -Path $DBMSConfig | Select-String "H2Dialect"
                    if ( $Match -and $Match.Matches.Groups.length -gt 0 )
                    {
                        ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"databaseConfigurationMethod"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}h2`${3}") | Set-Content -Path $useJocInstallXml
                    } else {
                        ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"databaseConfigurationMethod"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}withHibernateFile`${3}") | Set-Content -Path $useJocInstallXml
                    }
                }
            }

            if ( $DBMSDriver )
            {
                Out-LogInfo ".. updating DBMS JDBC Driver in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"connector"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($DBMSDriver)`${3}") | Set-Content -Path $useJocInstallXml
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"internalConnector"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}no`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $DBMSInit )
            {
                Out-LogInfo ".. updating option to create tables in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"databaseCreateTables"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($DBMSInit)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $HttpPort )
            {
                Out-LogInfo ".. updating http port in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"jettyPort"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($HttpPort)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $JavaOptions )
            {
                Out-LogInfo ".. updating Java options in response file $($useJocInstallXml)"
                ((Get-Content -Path $useJocInstallXml) -replace '(<entry[ ]*key[ ]*=[ ]*"jettyOptions"[ ]*value[ ]*=[ ]*")(.*)("/>)', "`${1}$($JavaOptions)`${3}") | Set-Content -Path $useJocInstallXml
            }

            if ( $ServiceNameSuffix )
            {
                [xml] $xmlDom = Get-Content -Path $useJocInstallXml
                $xmlXpath = "//*[@id = 'jetty']"
                $xmlJetty = Select-XML -XML $xmlDom.AutomatedInstallation -Xpath $xmlXpath

                if ( $xmlJetty )
                {
                    $xmlElement = $xmlDom.CreateElement( 'entry' )
                    $xmlElement.SetAttribute( 'key', 'jettyServiceName' )
                    $xmlElement.SetAttribute( 'value', "joc_$($ServiceNameSuffix)" )
                    $xmlJetty.Node.AppendChild( $xmlElement ) | Out-Null
                    $xmlDom.Save( $useJocInstallXml )
                }
            }

            # run installer
            $resultLog = "$($baseDir)/logs/install-result.log"
            if ( Test-Path -Path $resultLog -PathType leaf )
            {
                Remove-Item -Path $resultLog -Force | Out-Null
            }

            if ( $isWindows )
            {
                Out-LogInfo ".. running installer from JOC Cockpit setup directory: $($SetupDir)/setup.cmd joc_install.xml"
                cmd.exe /C "cd ""$($SetupDir)"" && setup.cmd joc_install.xml"
            } else {
                if ( $AsUser )
                {
                    $userOption = '-u'
                } else {
                    $userOption = ''
                }

                if ( $PreserveEnv )
                {
                    $userOption += ' -E'
                }

                Out-LogInfo ".. running installer from JOC Cockpit setup directory: $($SetupDir)/setup.sh $($userOption) joc_install.xml"
                sh -c "cd ""$($SetupDir)"" && export JAVA_HOME=""$env:JAVA_HOME"" && export JAVABIN=""$env:JAVA_HOME/bin"" && ""./setup.sh"" $($userOption) joc_install.xml || exit 8"
            }

            if ( !(Test-Path -Path $resultLog -PathType leaf) )
            {
                Out-LogError "installation failed, result log is missing: $($resultLog)"
            } else {
                $Match = Get-Content -Path $resultLog | Select-String "^return_code[ ]*=[ ]*(.*)$"
                if ( $Match -and $Match.Matches.Groups.length -eq 2 )
                {
                    $returnCode = $Match.Matches.Groups[1].value
                    if ( $returnCode -ne 0 )
                    {
                        Out-LogError "installation failed, return code $($returnCode) reported from result log: $($resultLog)"
                    }
                }
            }
        }

        # copy license key and license binary file
        if ( $LicenseKey )
        {
            if ( !(Test-Path -Path "$($baseDir)/lib/ext/joc" -PathType container) )
            {
                New-Item -Path "$($baseDir)/lib/ext/joc" -ItemType directory | Out-Null
            }

            if ( !$LicenseBin )
            {
                if ( !(Test-Path -Path "$($baseDir)/lib/ext/joc/js7-license.jar") )
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
                    Invoke-WebRequest -Uri $downloadUrl -Outfile "$($baseDir)/lib/ext/joc/js7-license.jar"
                }
            } else {
                Copy-Item -Path $LicenseBin -Destination "$($baseDir)/lib/ext/joc/js7-license.jar" -Force
            }

            if ( !(Test-Path -Path "$($configDir)/license" -PathType container) )
            {
                New-Item -Path "$($configDir)license" -ItemType directory | Out-Null
            }

            Out-LogInfo ".. copying license key file to: $($configDir)/license"
            Copy-Item -Path $LicenseKey -Destination "$($configDir)/license" -Force
        }

        # copy deployment directory
        if ( $DeployDir -and (Test-Path -Path $configDir -PathType container) )
        {
            foreach( $directory in $DeployDir )
            {
                if ( !(Test-Path -Path $directory -PathType container) )
                {
                    Out-LogError "Deployment Directory not found: -DeployDir $($directory)"
                } else {
                    Out-LogInfo ".. deploying configuration from $($directory) to JOC Cockpit configuration directory: $($configDir)"
                    Copy-Item -Path "$($directory)/*" -Destination $configDir -Recurse -Force
                }
            }
        }

        # copy systemd service file
        $useServiceFile = "$($HomeDir)/jetty/bin/joc.service"
        if ( !$isWindows )
        {
            if ( $ServiceFile )
            {
                Out-LogInfo ".. copying $($ServiceFile) to $($useServiceFile)"
                Copy-Item -Path $ServiceFile -Destination $useServiceFile -Force
            } elseif ( !(Test-Path -Path $useServiceFile -PathType leaf) ) {
                if ( !$NoInstall -and (Test-Path -Path "$($HomeDir)/jetty/bin/jetty.service-example" -PathType leaf) )
                {
                    Out-LogInfo ".. copying $($HomeDir)/jetty/bin/jetty.service-example to $($useServiceFile)"
                    Copy-Item -Path "$($HomeDir)/jetty/bin/jetty.service-example" -Destination $useServiceFile -Force
                }
            }
        }

        # initialize SSL
        if ( $HttpsPort )
        {
            if ( $env:JAVA_HOME )
            {
                $java = "$($env:JAVA_HOME)/bin/java"
            } else {
                $java = "java"
            }

            Out-LogInfo ".. initializing Jetty SSL: $($java) -jar $($HomeDir)/jetty/start.jar -Djetty.home=$($HomeDir)/jetty -Djetty.base=$($baseDir) --add-module=ssl,https"
            if ( $isWindows )
            {
                cmd.exe /c """$($java)"" -jar ""$($HomeDir)/jetty/start.jar"" -Djetty.home=""$($HomeDir)/jetty"" -Djetty.base=""$($baseDir)"" --add-module=ssl,https"
            } else {
                sh -c """$($java)"" -jar ""$($HomeDir)/jetty/start.jar"" -Djetty.home=""$($HomeDir)/jetty"" -Djetty.base=""$($baseDir)"" --add-module=ssl,https"
            }

            if ( !(Test-Path -Path "$($baseDir)/start.d/https.ini" -PathType leaf) )
            {
                if ( Test-Path -Path "$($baseDir)/start.d/https.in~" -PathType leaf )
                {
                    Move-Item -Path "$($baseDir)/start.d/https.in~" -Destination "$($baseDir)/start.d/https.ini" -Force
                } else {
                    Out-LogError "Jetty https.ini file not found for use of HTTPS connections"
                }
            }

            if ( !(Test-Path -Path "$($baseDir)/start.d/ssl.ini" -PathType leaf) )
            {
                if ( Test-Path -Path "$($baseDir)/start.d/ssl.in~" -PathType leaf )
                {
                    Move-Item -Path "$($baseDir)/start.d/ssl.in~" -Destination "$($baseDir)/start.d/ssl.ini" -Force
                } else {
                    Out-LogError "Jetty ssl.ini file not found for use of HTTPS connections"
                }
            }
        }

        # copy *.ini files
        if ( $Ini )
        {
            if ( !(Test-Path -Path "$($baseDir)/start.d" -PathType container) )
            {
                New-Item -Path "$($baseDir)/start.d" -ItemType directory | Out-Null
            }

            foreach( $iniFile in $Ini )
            {
                Out-LogInfo ".. copying .ini file $($iniFile) to $($baseDir)/start.d/"
                Copy-Item -Path $iniFile -Destination "$($baseDir)/start.d" -Force
            }
        } 

        # copy joc.properties
        $usePropertiesFile = "$($configDir)/joc.properties"
        if ( $Properties -and (Test-Path -Path $configDir -PathType container) )
        {
            Out-LogInfo ".. copying properties file $($Properties) to $($usePropertiesFile)"
            Copy-Item -Path $Properties -Destination $usePropertiesFile -Force
        }

        # copy keystore
        if ( $Keystore )
        {
            $useKeystoreFile = "$($configDir)/$(Split-Path $Keystore -Leaf)"
            Out-LogInfo ".. copying keystore file $($Keystore) to $($useKeystoreFile)"
            Copy-Item -Path $Keystore -Destination $useKeystoreFile -Force
        }

        # copy truststore
        if ( $Truststore )
        {
            $useTruststoreFile = "$($configDir)/$(Split-Path $Truststore -Leaf)"
            Out-LogInfo ".. copying truststore file $($Truststore) to $($useTruststoreFile)"
            Copy-Item -Path $Truststore -Destination $useTruststoreFile -Force
        }

        # copy Hibernate configuration file if specified
        if ( $DBMSConfig -and $DBMSConfig -ne 'H2' )
        {
            $Match = Get-Content -Path $DBMSConfig | Select-String "H2Dialect"
            if ( $Match -and $Match.Matches.Groups.length -gt 0 )
            {
                Out-LogInfo ".. copying hibernate configuration file $($DBMSConfig) to $($configDir)/hibernate.cfg.xml"
                Copy-Item -Path $DBMSConfig -Destination "$($configDir)/hibernate.cfg.xml" -Force
            }
        }

        # update configuration items

        # update Jetty start script
        if ( !$isWindows -and !$NoInstall )
        {
            $useStartScript = "$($HomeDir)/jetty/bin/jetty.sh"
            if ( Test-Path -Path $useStartScript -PathType leaf )
            {
                Out-LogInfo ".. updating Jetty Start Script: $($useStartScript)"

                if ( $User )
                {
                    ((Get-Content -Path $useStartScript) -replace "^[# ]*JETTY_USER[ ]*=(.*)", "JETTY_USER=""$($User)""") | Set-Content -Path $useStartScript
                    ((Get-Content -Path $useStartScript) -replace "^[# ]*JETTY_USER_HOME[ ]*=(.*)", "JETTY_USER_HOME=""`$HOME""") | Set-Content -Path $useStartScript
                }

                if ( $ServiceName )
                {
                    $tempServiceName = $ServiceName.Substring( $ServiceName.IndexOf( $ServiceNamePrefix ) + $ServiceNamePrefix.length )
                    $tempServiceName = $tempServiceName.Substring( 0, $tempServiceName.IndexOf( '.service' ) )
                    ((Get-Content -Path $useStartScript) -replace "^[# ]*NAME[ ]*=(.*)", "NAME=""$($tempServiceName)""") | Set-Content -Path $useStartScript
                }
            }
        }

        # update systemd service file
        if ( !$isWindows -and !$NoInstall -and (Test-Path -Path $useServiceFile -PathType leaf) )
        {
            Out-LogInfo ".. updating JOC Cockpit systemd service file: $($useServiceFile)"

            $tempServiceName = $ServiceName.Substring( $ServiceName.IndexOf( $ServiceNamePrefix ) + $ServiceNamePrefix.length )
            $tempServiceName = $tempServiceName.Substring( 0, $tempServiceName.IndexOf( '.service' ) )

            $usePidFileName = if ( $PidFileName ) { $PidFileName } else { "$($tempServiceName).pid" }

            if ( $PidFileDir )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JETTY_RUN[ ]*=.*', "Environment=""JETTY_RUN=$($PidFileDir)""") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($PidFileDir)") | Set-Content -Path $useServiceFile
            } else {
                ((Get-Content -Path $useServiceFile) -replace '^PIDFile[ ]*=[ ]*.*', "PIDFile=$($baseDir)/$($usePidFileName)") | Set-Content -Path $useServiceFile
            }

            if ( $User )
            {
                ((Get-Content -Path $useServiceFile) -replace '^User[ ]*=[ ]*.*', "User=$($User)") | Set-Content -Path $useServiceFile
            }

            ((Get-Content -Path $useServiceFile) -replace '^ExecStart[ ]*=[ ]*.*', "ExecStart=$($HomeDir)/jetty/bin/jetty.sh start") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecStop[ ]*=[ ]*.*', "ExecStop=$($HomeDir)/jetty/bin/jetty.sh stop") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^ExecReload[ ]*=[ ]*.*', "ExecReload=$($HomeDir)/jetty/bin/jetty.sh restart") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardOutput[ ]*=[ ]*syslog\+console', "StandardOutput=journal+console") | Set-Content -Path $useServiceFile
            ((Get-Content -Path $useServiceFile) -replace '^StandardError[ ]*=[ ]*syslog\+console', "StandardError=journal+console") | Set-Content -Path $useServiceFile

            if ( $JavaHome )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_HOME[ ]*=.*', "Environment=""JAVA_HOME=$($JavaHome)""") | Set-Content -Path $useServiceFile
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA[ ]*=.*', "Environment=""JAVA=$($JavaHome)/bin/java""") | Set-Content -Path $useServiceFile
            }

            if ( $JavaOptions )
            {
                ((Get-Content -Path $useServiceFile) -replace '^[# ]*Environment[ ]*=[ ]*\"JAVA_OPTIONS[ ]*=.*', "Environment=""JAVA_OPTIONS=$($JavaOptions)""") | Set-Content -Path $useServiceFile
            }
        }

        # update joc.properties
        $usePropertiesFile = "$($configDir)/joc.properties"
        if ( !$NoConfig -and (Test-Path $usePropertiesFile -PathType leaf) )
        {
            Out-LogInfo ".. updating properties in file: $($usePropertiesFile)"

            if ( $Keystore )
            {
                Out-LogInfo ".... updating keystore file name: $(Split-Path $Keystore -Leaf)"
                ((Get-Content -Path $usePropertiesFile) -replace '{{keystore-file}}', "$(Split-Path $Keystore -Leaf)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*keystore_path[ ]*=[ ]*(.*)$', "keystore_path = $(Split-Path $Keystore -Leaf)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*keystore_type[ ]*=[ ]*(.*)$', 'keystore_type = PKCS12') | Set-Content -Path $usePropertiesFile
            }

            if ( $KeystorePassword )
            {
                Out-LogInfo ".... updating keystore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $KeystorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )

                ((Get-Content -Path $usePropertiesFile) -replace '{{keystore-password}}', "$($result)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '{{key-password}}', "$($result)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*keystore_password[ ]*=[ ]*(.*)$', "keystore_password = $($result)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*key_password[ ]*=[ ]*(.*)$', "key_password = $($result)") | Set-Content -Path $usePropertiesFile
            }

            if ( $KeyAlias )
            {
                Out-LogInfo ".... updating key alias name for key: $($KeyAlias)"
                ((Get-Content -Path $usePropertiesFile) -replace '{{keystore-alias}}', "$($KeyAlias)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*keystore_alias[ ]*=[ ]*(.*)$', "keystore_alias = $($KeyAlias)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '{{key-alias}}', "$($KeyAlias)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*key_alias[ ]*=[ ]*(.*)$', "keystore_alias = $($KeyAlias)") | Set-Content -Path $usePropertiesFile
            }

            if ( $Truststore -and (Test-Path -Path $Truststore -PathType leaf) )
            {
                Out-LogInfo ".... updating truststore file name: $(Split-Path $Truststore -Leaf)"
                ((Get-Content -Path $usePropertiesFile) -replace '{{truststore-file}}', "$(Split-Path $Truststore -Leaf)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*truststore_path[ ]*=[ ]*(.*)$', "truststore_path = $(Split-Path $Keystore -Leaf)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*truststore_type[ ]*=[ ]*(.*)$', 'truststore_type = PKCS12') | Set-Content -Path $usePropertiesFile
            }

            if ( $TruststorePassword )
            {
                Out-LogInfo ".... updating truststore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $TruststorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )
                ((Get-Content -Path $usePropertiesFile) -replace '{{truststore-password}}', "$($result)") | Set-Content -Path $usePropertiesFile
                ((Get-Content -Path $usePropertiesFile) -replace '^[# ]*truststore_password[ ]*=[ ]*(.*)$', "truststore_password = $($result)") | Set-Content -Path $usePropertiesFile
            }

            ((Get-Content -Path $usePropertiesFile) -replace '{{.*}}', '') | Set-Content -Path $usePropertiesFile
        }

        # update http.ini
        $useHttpIniFile = "$($baseDir)/start.d/http.ini"
        if ( !$NoConfig -and (Test-Path $useHttpIniFile -PathType leaf) )
        {
            Out-LogInfo ".. updating JOC Cockpit configuration file: $($useHttpIniFile)"

            if ( $HttpPort )
            {
                ((Get-Content -Path $useHttpIniFile) -replace '^[# ]*--module=http.*$', '--module=http') | Set-Content -Path $useHttpIniFile
                ((Get-Content -Path $useHttpIniFile) -replace '^[# ]*jetty.http.port=.*', "jetty.http.port=$($HttpPort)") | Set-Content -Path $useHttpIniFile

                if ( $HttpNetworkInterface )
                {
                    ((Get-Content -Path $useHttpIniFile) -replace '^[# ]*jetty.http.host=.*', "jetty.http.host=$($HttpNetworkInterface)") | Set-Content -Path $useHttpIniFile
                } else {
                    ((Get-Content -Path $useHttpIniFile) -replace '^[# ]*jetty.http.host=.*', "# jetty.http.host=") | Set-Content -Path $useHttpIniFile
                }
            } else {
                ((Get-Content -Path $useHttpIniFile) -replace '^[# ]*--module=http.*$', '# --module=http') | Set-Content -Path $useHttpIniFile
            }
        }

        # update https.ini
        $useHttpsIniFile = "$($baseDir)/start.d/https.ini"
        if ( !$NoConfig -and (Test-Path $useHttpsIniFile -PathType leaf) )
        {
            Out-LogInfo ".. updating JOC Cockpit configuration file: $($useHttpsIniFile)"

            if ( $HttpsPort )
            {
                ((Get-Content -Path $useHttpsIniFile) -replace '^[# ]*--module=https.*$', '--module=https') | Set-Content -Path $useHttpsIniFile
            } else {
                ((Get-Content -Path $useHttpsIniFile) -replace '^[# ]*--module=http.*$', '# --module=https') | Set-Content -Path $useHttpsIniFile
            }
        }

        # update ssl.ini
        $useSslIniFile = "$($baseDir)/start.d/ssl.ini"
        if ( !$NoConfig -and (Test-Path $useSslIniFile -PathType leaf) )
        {
            Out-LogInfo ".. updating JOC Cockpit configuration file: $($useSslIniFile)"

            if ( $HttpsPort )
            {
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*--module=ssl.*$', '--module=ssl') | Set-Content -Path $useSslIniFile
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.ssl.port=.*', "jetty.ssl.port=$($HttpsPort)") | Set-Content -Path $useSslIniFile

                if ( $HttpsNetworkInterface )
                {
                    ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.ssl.host=.*', "jetty.ssl.host=$($HttpsNetworkInterface)") | Set-Content -Path $useSslIniFile
                } else {
                    ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.ssl.host=.*', "# jetty.ssl.host=") | Set-Content -Path $useSslIniFile
                }
            } else {
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*--module=ssl.*$', '# --module=ssl') | Set-Content -Path $useSslIniFile
            }

            if ( $Keystore )
            {
                Out-LogInfo ".... updating keystore file name: $(Split-Path $Keystore -Leaf)"
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.keyStorePath[ ]*=[ ]*(.*)$', "jetty.sslContext.keyStorePath=resources/joc/$(Split-Path $Keystore -Leaf)") | Set-Content -Path $useSslIniFile
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.keyStoreType[ ]*=[ ]*(.*)$', 'jetty.sslContext.keyStoreType=PKCS12') | Set-Content -Path $useSslIniFile
            }

            if ( $KeystorePassword )
            {
                Out-LogInfo ".... updating keystore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $KeystorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )

                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.keyStorePassword[ ]*=[ ]*(.*)$', "jetty.sslContext.keyStorePassword=$($result)") | Set-Content -Path $useSslIniFile
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.keyManagerPassword[ ]*=[ ]*(.*)$', "jetty.sslContext.keyManagerPassword=$($result)") | Set-Content -Path $useSslIniFile
            }

            if ( $KeyAlias )
            {
                Out-LogInfo ".... updating key alias name for key: $($KeyAlias)"
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.keyAlias[ ]*=[ ]*(.*)$', "jetty.sslContext.keyAlias=$($KeyAlias)") | Set-Content -Path $useSslIniFile
            }

            if ( $Truststore )
            {
                Out-LogInfo ".... updating truststore file name: $(Split-Path $Truststore -Leaf)"
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.trustStorePath[ ]*=[ ]*(.*)$', "jetty.sslContext.trustStorePath=resources/joc/$(Split-Path $Truststore -Leaf)") | Set-Content -Path $useSslIniFile
                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.trustStoreType[ ]*=[ ]*(.*)$', 'jetty.sslContext.trustStoreType=PKCS12') | Set-Content -Path $useSslIniFile
            }

            if ( $TruststorePassword )
            {
                Out-LogInfo ".... updating truststore password"
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode( $TruststorePassword )
                $result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni( $ptr )

                ((Get-Content -Path $useSslIniFile) -replace '^[# ]*jetty.sslContext.trustStorePassword[ ]*=[ ]*(.*)$', "jetty.sslContext.trustStorePassword=$($result)") | Set-Content -Path $useSslIniFile
            }

            # update jetty-ssl-context.xml
            $useSslContextFile = "$($HomeDir)/jetty/etc/jetty-ssl-context.xml"
            if ( Test-Path $useSslContextFile -PathType leaf )
            {
                if ( $KeyAlias )
                {
                    Out-LogInfo ".. updating JOC Cockpit configuration file: $($useSslContextFile)"
                    ((Get-Content -Path $useSslContextFile) -replace '(Property[ ]*name[ ]*=[ ]*"jetty.sslContext.keystore.alias"[ ]*default[ ]*=[ ]*")(.*)(")', "`${1}$($KeyAlias)`${3}") | Set-Content -Path $useSslContextFile
                }
            }

            # make systemd service
            if ( !$isWindows -and $MakeService )
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
                    throw "failed to update Windows Service properties, return code: $($rc)"
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
        }

        Start-JocBasic
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
