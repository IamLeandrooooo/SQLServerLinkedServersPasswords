# SQL Server Linked Server Passwords
A Powershell Script that automates all the needed configurations in order to get the SQL Server Linked Server Passwords.


# **Disclaimer: Legal Use Only**


This script is provided solely for legal purposes. Any use of this script for illegal activities or in violation of applicable laws is strictly prohibited.

I take no responsibility if:

- You use this script for unlawful purposes.
- You encounter any legal consequences as a result of using this script inappropriately.

# This whole script can be broken down into 4 steps.

1. The first step is enabling TCP/IP connections on all SQL Server Instances.
2. The second step is to add a Start Up parameter, in this case, a trace flag will be added, which is -T7806. This flag is needed since we need to enable the Dedicated Administrator connection feature.
3. The third step is to enable remote admin connection. In order to use the Dedicated Administrator connection login, we need to enable it in SQL Server.
4. Finally, after all the configurations are enabled, the final step is to decrypt the passwords on the Linked Servers.

In the folder ```ConfigurationScripts``` there are the 3 main scripts for the configuration. They are seperated for each step.

The full script, which includes the configurations + the gathering and decryption of passwords are on the root of the repository, which is ```ConfigDecryptLinkedServers.ps1```

In case you want to download the final part that is used on the full script, you can do it [here](https://www.richardswinbank.net/admin/extract_linked_server_passwords).

# But why do I need this script?
Gaining access to Linked Servers passwords is a perfect way to acquire a greater foothold on the target. 
To perform all these configurations you need administration access to the machine, and on top of that, a Graphical User Interface, and that's the motivation to create this script. 
Having a script that manages all the configurations without a GUI is crucial because sometimes we are only left with a shell and a dream. 

With this, it will be way easier to set up everything, even if you have a GUI, it's just way quicker, and normally whether you are on an exam, a CTF, or a real engagement, time is of the essence.

## First part of the script
To start off, as mentioned before, we need to enable TCP/IP connections. 
You can do it on a specific instance, but I made the script so it could cover ALL the instances.

### In a GUI, you would see something like this

![EnablingTCP](https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/2.png?raw=true)

This PowerShell script is designed to perform the following actions for a list of SQL Server instances specified in the `$SqlInstances` array:

1. For each SQL Server instance in the array, it creates a new instance of the `Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer` class, associated with the local machine (`localhost`).

2. It retrieves the TCP protocol settings for the current SQL Server instance specified by `$InstanceName` using the `ServerProtocols` property of the `ManagedComputer` object.

3. It sets the `IsEnabled` property of the TCP protocol to `$true`, effectively enabling the TCP/IP protocol for the SQL Server instance.

4. It retrieves a list of Windows services using `Get-Service`.

5. The script filters the list of services to find services with display names matching the pattern `'SQL Server (*'`, typically used for identifying SQL Server services.

6. Further filtering is applied to find the specific service associated with the current SQL Server instance (`$InstanceName`) by matching the display name.

7. The SQL Server service associated with the current instance is then forcibly restarted using the `Restart-Service` cmdlet with the `-Force` parameter.

There are also validations in place to check either the TCP/IP is already enabled or not.

### The output should be something like this

<img src="https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/tcp.gif" width="800" height="500"/>


## Second part of the script


After TCP/IP connections are enabled, it's time to the Start Up parameter. In this case it will be -T7806, as mentioned above, we will need to enable the Dedicated Administrator connection feature.
In a GUI perspective, you would see something like this, where the flag isn't added, and you need to manually type it and insert it:
![AddingStartUpFlag](https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/1.png?raw=true)

1. Set the `$hklmRootNode` variable to the Registry path `"HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"`, which typically stores SQL Server configuration in the Windows Registry.

2. Retrieve properties of the Registry key `"HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"`, containing information about SQL Server instances.

3. Filter properties of this Registry key to select instances whose values match the pattern `'MSSQL*'`, identifying SQL Server instances.

4. Iterate through selected instances, performing the following actions for each:

   - Extract instance name into the `$inst` variable.
   
   - Construct Registry key path for instance's SQL Server parameters (usually `"HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$inst\MSSQLServer\Parameters"`).
   
   - Retrieve properties of this Registry key, including SQL Server startup parameters.
   
   - Filter these properties to select those with names matching the pattern `'SQLArg*'`, representing SQL Server startup parameters.

   - Check if specified `$StartupParameter` exists among selected startup parameters for the current instance, setting `$hasFlag` to `false` if not.

   - If `$StartupParameter` is not found among existing parameters for the current instance, add it to the Registry by creating a new property with a name like `"SQLArgX"` (incrementing `X` based on existing parameter count) and set its value to `$StartupParameter`.

   - If `$StartupParameter` already exists among existing startup parameters for the current instance, log a message indicating that the parameter is already set.

  
### The output should be something like this

<img src="https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/param.gif" width="800" height="500"/>

## Third part of the script
As for the final part of the configuration setup, is time to enable Remote Admin Connections on SQL Server, which is disabled by default.
You can see if your Remote Admin Connection is enabled with the following SQL Script:

```SELECT name,value_in_use FROM sys.configurations WHERE name = 'remote admin connections';```


### If the Remote Admin Connection is disabled, the following output should be shown

![AddingStartUpFlag](https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/3.png?raw=true)

## To make it easier to explain, it will be divided by tasks:


### Task 1: Get SQL Server Instances

- The script begins by retrieving the name of the computer using the `ENV:computername` environment variable.
- It then identifies the SQL Server instances installed on the computer by querying the Windows Registry under `HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server`. The list of instances is stored in the `$SqlInstances` variable.

### Task 2: Enable DAC (Dedicated Administrator Connection)

- For each SQL Server instance in `$SqlInstances`, it constructs a connection string for the instance.
- It opens a connection to the SQL Server using the constructed connection string.
- It executes a series of SQL queries to enable DAC by configuring advanced options and remote admin connections.

### Task 3: Enable SQL Browser Service

- The script ensures that the SQL Server Browser service is enabled and started.
- It checks if the service exists using `Get-Service`.
- If the service exists but is not running, it sets the service to start automatically and starts it.
- It displays a message indicating whether the SQL Server Browser service was enabled and started.

### The output should be something like this

<img src="https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/enableRemoteConnection.gif" width="800" height="500"/>

## Final Part
With all these configurations made sucessfully, the final part is running the script that gets the SQL Server Linked Servers passwords.
I won't be going into detail at all in this final part, since this is an already known script and has already some information on the internet.
You can find the link for the script [here](https://www.richardswinbank.net/admin/extract_linked_server_passwords).

For a final reference of documentation, you can find the configurations and much more about this attack in the following links:

[Decrypting MSSQL Database Link Server Passwords](https://www.netspi.com/blog/technical/adversary-simulation/decrypting-mssql-database-link-server-passwords/)

[Troubleshooting the SQL Server Dedicated Administrator Connection](https://www.mssqltips.com/sqlservertip/5364/troubleshooting-the-sql-server-dedicated-administrator-connection/)

## The full script, should give you the following output


![FinalScriptOutput](https://github.com/IamLeandrooooo/SQLServerLinkedServersPasswords/blob/main/img/5.png)


