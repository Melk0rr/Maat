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

  # 1 acl access = 1 identity reference
  foreach ($aclAccess in $dir.GetNonBuiltInACLAccesses()) {
    # Translate MS file system rights to simple R/RW short string
    $accessPermissions = ""
    if ($aclAccess.FileSystemRights -like "*Read*") {
      $accessPermissions = "R"
    }

    if ($AccessRights -like "*Modify*") {
      $accessPermissions = "RW"
    }

    $adACLGroups = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference

    # Create access group instance + bind it to the directory
    [MaatAccess]$maatAccessToDir = [MaatAccess]::new($dir, $accessPermissions, "acl")
    $maatAccessGroup = $dir.GetResultRef().GetUniqueAccessGroup($adACLGroups[0].Name, $maatAccessToDir)
    $dir.AddAccessGroup($maatAccessGroup)

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