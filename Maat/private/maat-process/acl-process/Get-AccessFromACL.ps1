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

  # 1 acl access = 1 identity reference
  foreach ($aclAccess in $dir.GetNonBuiltInACLAccesses()) {
    # Translate MS file system rights to simple R/RW short string
    $accessPermissions = ""
    if ($aclAccess.FileSystemRights -like "*Read*") {
      $accessPermissions = "R"
    }

    if ($aclAccess.FileSystemRights -like "*Modify*") {
      $accessPermissions = "RW"
    }

    $adACLGroups = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference

    if ($adACLGroups) {
      # Create access group instance + bind it to the directory
      [MaatAccess]$maatAccessToDir = [MaatAccess]::new($dir, $accessPermissions, "acl")
      $maatAccessGroup = $dir.GetResultRef().GetUniqueAccessGroup($adACLGroups[0].Name, $maatAccessToDir)
      $dir.AddAccessGroup($maatAccessGroup)

      foreach ($adACLGr in $adACLGroups) {
        $maatAccessGroup.SetAccessMembersFromADGroup($adACLGr)
      }
    }
  }
}