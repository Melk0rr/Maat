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

  [object[]]$resACLGroup = @()

  # If the reference is not an sid : removes the domain reference if any
  $sidRegex = "^S-1-[0-59]-\d{2}-\d{8,10}-\d{8,10}-\d{8,10}-[1-9]\d{3,9}"
  if ($IdentityReference -notmatch $sidRegex) {
    $IdentityReference = $IdentityReference.Split("\")[1]
  }

  # Check if IdentityReference can be found in the ad group list built from configuration
  $configADGroupCheck = $adGroups.Where({ ($_.Name -eq $IdentityReference) -or ($_.SID -eq $IdentityReference) })

  if ($configADGroupCheck.count -gt 0) {
    $IdentityReference = $configADGroupCheck[0].Name
  }

  # Helper function to search ad domains for the identity reference
  # If the reference is an sid and a group is found in one of the domains, the function will be executed a second time
  # This is done because in some architectures, acl descend from a trusted domain
  function Get-ADGroupsMatchingIDRef {
    $matchingGroups = @()
    foreach ($srv in $Server) {
      $search = $resACLGroup.Where({ $srv -in $_.DistinguishedName })
      if ($search.count -eq 0) {
        try {
          $idRefGr = Get-ADGroup $IdentityReference -Server $srv -Properties Description, Members
          
          if ($idRefGr) {
            Write-Host "Found group matching $IdentityReference in $srv"
            # If a group was found and the reference is an sid : replace it with the group name
            if ($IdentityReference -match $sidRegex) {
              Write-Host "Replacing identity reference $IdentityReference with $($idRefGr.Name)"
              $IdentityReference = $idRefGr.Name
            }

            $matchingGroups += $idRefGr
          }
        }
        catch {
          Write-Warning $_
        }
      } else {
        Write-Host "A group was already found in $srv"
      }
    }

    return $matchingGroups
  }

  $resACLGroup += Get-ADGroupsMatchingIDRef

  if ($IdentityReference -match $sidRegex) {
    if (($resACLGroup.count -gt 0) -and ($resACLGroup.count -ne $Server.count)) {
      Write-Host "A group matching identity reference was not found in all domains. Looking a second time with new identity reference..."
      $resACLGroup += Get-ADGroupsMatchingIDRef
    }
  }

  return $resACLGroup
}