function Get-AccessFromACL {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatDirectory] $Dir
  )

  Write-Host "Checking ACL on $($dir.GetName())..."

  $aclAccesses = $dir.GetNonBuiltInACLAccesses()
  Write-Host "$($aclAccesses.count) ACL groups give access to '$($dir.GetName())'"

  # 1 acl access = 1 identity reference
  foreach ($aclAccess in $aclAccesses) {
    # Translate MS file system rights to simple R/RW short string
    $accessPermissions = ""
    if ($aclAccess.FileSystemRights -like "*Read*") {
      $accessPermissions = "R"
    }

    if ($aclAccess.FileSystemRights -like "*Modify*") {
      $accessPermissions = "RW"
    }

    Write-Host "$($aclAccess.IdentityReference): $accessPermissions"
    $adACLGroups = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference

    if ($adACLGroups) {
      # Create access group instance + bind it to the directory
      [MaatAccess]$maatAccessToDir = [MaatAccess]::new($dir, $accessPermissions, "acl")
      $maatAccessGroup = $dir.GetResultRef().GetUniqueAccessGroup($adACLGroups[0].Name, $maatAccessToDir)

      foreach ($adACLGr in $adACLGroups) {
        $maatAccessGroup.SetAccessMembersFromADGroup($adACLGr)
      }
    }
  }
}