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
  $adGroupCheck = $adGroups.Where({ $_.SID -eq $IdentityReference })
  if ($adGroupCheck.count -gt 0) {
    return $adGroupCheck[0]
  }

  try {
    $aclADGroup = $Server | foreach-object {
      Get-ADGroup -Filter { SID -eq $IdentityReference } -Server $_
    }
    return $aclADGroup[0]
  }
  catch {
    Write-Warning $_
  }   
}