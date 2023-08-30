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

  # If the reference is not an sid : removes the domain reference if any
  $sidRegex = "/^S-1-[0-59]-\d{2}-\d{8,10}-\d{8,10}-\d{8,10}-[1-9]\d{3}/"
  if ($IdentityReference -notmatch $sidRegex) {
    $IdentityReference = $IdentityReference.Split("\")[1]
  }

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