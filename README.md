# Invoke-MigratevSS2vDS
A PowerShell script to migrate an ESXi Host from a vSS to a vDS

Example Usage:

```powershell
Remove-Variable -Name * -ErrorAction SilentlyContinue
Clear-Host

#vCenter Credentials
$VIServer = "mc-vcsa-v-201b.momusconsulting.com"
$VIUsername = 'administrator@vsphere.local'
$VIPassword = 'Pa55word5!'

$vCenter = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue -ErrorAction Stop
$VMHosts = Get-VMHost -Server $vCenter | Sort-Object Name

ForEach ($VMHost in $VMHosts) {
Write-Output "Adding $($VMHost)`n"
Invoke-MigratevSS2vDS -VMHost $VMHost -MgmtvDS 'vDS1-Management-B' -MgmtvDSPG 'VLAN0201_Management' -WarningAction SilentlyContinue -ErrorAction Continue
}
```
