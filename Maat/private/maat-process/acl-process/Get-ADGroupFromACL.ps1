function Get-ADGroupFromACL {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $IdentityReference
  )

  # Check if IdentityReference can be found in the ad group list built from configuration
  $configADGroupCheck = $adGroups.Where({ ($_.Name -eq $IdentityReference) -or ($_.SID -eq $IdentityReference) })
  if ($configADGroupCheck.count -gt 0) {
    $resACLGroup += $configADGroupCheck
  }
  else {
    foreach ($srv in $Server) {
      try {
        $idRefGr = Get-ADGroup $IdentityReference -Server $srv -Properties Description, Members
        $resACLGroup += $idRefGr
      }
      catch {
        Write-Warning $_
      }
    }
  }

  return $resACLGroup
}