function Get-DirAccessFromACL {
	[CmdletBinding()]
	param(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $false,
			ValueFromPipelineByPropertyName = $false
		)]
		[ValidateNotNullOrEmpty()]
		[object]  $Dir
	)

  $dirName = $dir.dir_name.Replace("`n", "")
  $dirACLRelatedMembers = @()
  $dirACLRelatedGroups = @()

	$acl = Get-ACL -Path $dir.dir_path
	# $builtInAccess = $acl.Access.Where({ ($_.IdentityReference -like "*NT*\SYST*") -and ($_.IdentityReference -like "BUILTIN\Admin*") })
	$otherAccess = $acl.Access.Where({ ($_.IdentityReference -notlike "*NT*\SYST*") -and ($_.IdentityReference -notlike "BUILTIN\*") })

  # 1 acl access = 1 identity reference
	foreach ($aclAccess in $otherAccess) {
    # Translate MS file system rights to simple R/RW short string
		$accessPermissions = Format-ACLAccessRights $aclAccess.FileSystemRights

    # Get AD Groups based on name of the retreived group with identity reference
    # If identity reference is an sid, it is linked to only one domain. But multiple domains can be provided
    # Multiple domains may share group architecture, so a group name can be found in multiple domains
    $adACLGroups = Get-ADGroupFromACL -IdentityReference $aclAccess.IdentityReference
    foreach ($adACLGr in $adACLGroups) {
      $dirACLRelatedMembers += Get-AccessRelatedUsers -GroupList $adACLGr -Permissions $accessPermissions
    }

    $aclGroupData = [PSCustomObject]@{
      GroupName = $aclGroup.name
      GroupDescription = $aclGroup.description.Replace("`n", "")
      GroupUserCount = $adACLGroups.members.count
      GroupPermissions = $accessPermissions
    }

    $dirACLRelatedGroups += $aclGroupData
	}

  # Handle duplicated users : a user may be a member of multiple groups granting access to a dir
  $dirACLRelatedMembers = Clear-AccessUserList $dirACLRelatedMembers

  # Access feedback
  Write-Host "`n$($dirACLRelatedGroups.count) groups give access to $dirName :"
  foreach ($gr in $dirACLRelatedGroups) {
    Write-Host "$($gr.groupName): $($gr.groupPermissions)"
  }

  Write-Host "`n$($dirACLRelatedMembers.count) user have access to $dirName :"
  foreach ($usr in $dirACLRelatedMembers) {
    Write-Host "$($usr.UserSAN): $($usr.userPermissions)"
  }

  return [PSCustomObject]@{
    DirGroups = $dirACLRelatedGroups
    DirUsers = $dirACLRelatedMembers
  }
}