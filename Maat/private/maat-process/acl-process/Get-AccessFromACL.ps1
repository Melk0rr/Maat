function Get-AccessFromACL {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    $Dir
  )

  $dirName = $dir.GetName()
  $acl = Get-ACL -Path $dir.GetPath()

  # $builtInAccess = $acl.Access.Where({ ($_.IdentityReference -like "*NT*\SYST*") -and ($_.IdentityReference -like "BUILTIN\Admin*") })
  $nonBuiltInAccesses = $acl.Access.Where({ ($_.IdentityReference -notlike "*NT*\SYST*") -and ($_.IdentityReference -notlike "BUILTIN\*") })
  Write-Host "`n$($nonBuiltInAccesses.count) groups give access to '$dirName' :"

  # 1 acl access = 1 identity reference
  foreach ($aclAccess in $nonBuiltInAccesses) {
    # Translate MS file system rights to simple R/RW short string
    $accessPermissions = Format-ACLAccessRights $aclAccess.FileSystemRights
    $adACLGroups = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference

    # Create access group instance + bind it to the directory
    [MaatAccess]$maatAccessToDir = [MaatAccess]::new($dir, $accessPermissions)
    $maatAccessGroup = $dir.GetResultRef().GetUniqueAccessGroup($adACLGroups[0].Name, $maatAccessToDir)
    $dir.AddACLGroup($maatAccessGroup)

    # Get AD Groups based on name of the retreived group with identity reference
    # If identity reference is an sid, it is linked to only one domain. But multiple domains can be provided
    # Multiple domains may share group architecture, so a group name can be found in multiple domains
    foreach ($adACLGr in $adACLGroups) {
      Get-AccessRelatedUsers $adACLGr $maatAccessGroup
    }
  }

  # Access feedback
  $dir.GetAccessFeedback()
}