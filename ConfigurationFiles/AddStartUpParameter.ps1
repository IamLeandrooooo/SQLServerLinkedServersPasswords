$StartupParameter = "-T7806"

Import-Module SQLPS -DisableNameChecking

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