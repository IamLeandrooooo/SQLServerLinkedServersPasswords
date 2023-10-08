Write-Host "[*] Enabling TCP/IP Connection on instances"

Import-Module SQLPS -DisableNameChecking

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
