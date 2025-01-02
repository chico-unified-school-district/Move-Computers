function Select-DomainController ([string[]]$DomainControllers) {
 begin {
  $myDCs = $DomainControllers
 }
 process {
  $dc = Get-Random $myDCs
  if ( Test-Connection -ComputerName $dc -Count 1 -ErrorAction SilentlyContinue ) { return $dc }
  else {
   $msg = $MyInvocation.MyCommand.Name, $dc
   Write-Host ('{0},{1} Not responding. Trying random Domain Controller in 30 seconds...' -f $msg)
   Start-Sleep 30
   Select-DomainController2 $myDCs
  }
 }
}
