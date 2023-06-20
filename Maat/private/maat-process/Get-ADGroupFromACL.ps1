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

  # Define the type of identity reference : either group SID or group Name
  $sidRegex = 'S-\d-(?:\d+-){1,14}\d+'
  $referenceType = "Name"
  if ($IdentityReference -match $sidRegex) {
    $referenceType = "SID"
  }

  # If identity reference is an SID : translate it to a group name
  $formatedIDReference = $IdentityReference
  if ($referenceType -eq "SID") {
    $sid = New-Object System.Security.Principal.SecurityIdentifier($IdentityReference)
    $formatedIDReference = $sid.Translate([System.Security.Principal.NTAccount]).Value.Split("\")[-1]
  }

  $resACLGroup = @()

  # Check if IdentityReference can be found in the ad group list built from configuration
  $configADGroupCheck = $adGroups.Where({ $_.$referenceType -eq $formatedIDReference })
  if ($configADGroupCheck.count -gt 0) {
    $resACLGroup += $configADGroupCheck

  } else {
    foreach ($srv in $Server) {
      try {
        $idRefGr = Get-ADGroup $formatedIDReference -Server $srv -Properties Description, Members
        $resACLGroup += $idRefGr
      }
      catch {
        Write-Warning $_
      }
    }
  }

  return $resACLGroup
}