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


