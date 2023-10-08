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
    $adGroupsMatchingRef = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference

    if ($adGroupsMatchingRef) {
      # Create access group instance + bind it to the directory
      [MaatAccess]$maatAccessToDir = [MaatAccess]::new($dir, $accessPermissions, "acl")
     
      foreach ($matchingGr in $adGroupsMatchingRef) {
        Resolve-GroupTree -ADGroup $matchingGr -Access $maatAccessToDir
      }
    }
  }
}