<#
The scripts is to be run every few minutes. Its purpose it to move
computers to a more agreeable OU so that GPO's can be applied
without extra effort.
#>
[cmdletbinding()] 
param (
 [Parameter(Position = 0, Mandatory = $True)]
 [Alias('DC', 'Server')]
 [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
 [string]$DomainController,
 [Parameter(Position = 1, Mandatory = $True)]
 [Alias('ADCred', 'ADCReds')]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Position = 2, Mandatory = $True)]
 [Alias('SrcOU')]
 [string]$SourceOrgUnitPath,
 [Parameter(Position = 3, Mandatory = $True)]
 [Alias('TargOU')]
 [string]$TargetOrgUnitPath,
 [switch]$WhatIf
)

# AD Domain Controller Session
$adCmdLets = 'Get-ADcomputer', 'Move-ADObject'
$adSession = New-PSSession -ComputerName $DomainController -Credential $ADCredential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber

. .\lib\Add-Log.ps1

$endTime = "11:30pm"
if (!$WhatIf) { "Running until $endTime" }
do {
 $computerObjs = Get-ADcomputer -Filter * -SearchBase $SourceOrgUnitPath | Where-Object { $_.OperatingSystem -notlike "Windows Server*" }
 foreach ($obj in $computerObjs) {
  # Move Object to TargetPath
  Add-Log action "Moving $($obj.name) to $($TargetOrgUnitPath.split(",")[0])" $WhatIf
  Move-ADObject -Identity $obj.ObjectGUID -TargetPath $targetOU -Whatif:$WhatIf
  # Loop every 5 minutes
 }
 Write-Verbose "Next run at $((Get-Date).AddSeconds(180))"
 if (!$WhatIf) { Start-Sleep -Seconds 180 }
} until ( $WhatIf -or ( (Get-Date) -ge (Get-Date $endTime) ) )

Write-Verbose "Tearing down sessions"
Get-PSSession | Remove-PSSession
 
