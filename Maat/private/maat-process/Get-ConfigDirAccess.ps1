function Get-DirAccessFromConfig {
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
  $dirRelatedMembers = @()
  $dirRelatedGroups = @()

  # Retreive every mention of the specified directory
  $configRelatedGroups = $dir.SelectNodes("*/group")
  Write-Host "$($configRelatedGroups.count) groups related to '$dirName' in config file"

  foreach ($configGroup in $configRelatedGroups) {
    # Get the group node related to the directory to retreive its name
    $adConfigGroups = $adGroups.Where({ $_.Name -eq $configGroup.g_name })

    foreach ($adConfigGr in $adConfigGroups) {
      $dirRelatedMembers += Get-AccessRelatedUsers -GroupList $adConfigGr -Permissions $configGroup.g_permissions
    }

    # Formatting informations related to the group itself
    $configGroupData = [PSCustomObject]@{
      GroupName = $configGroup.g_name
      GroupUserCount = $adConfigGroups.members.count
      GroupPermissions = $configGroup.g_permissions
    }
    $dirRelatedGroups += $configGroupData
  }

  # Handle duplicated users : a user may be a member of multiple groups granting access to a dir
  $dirRelatedMembers = Clear-AccessUserList $dirRelatedMembers

  # Access feedback
  Write-Host "`n$($dirRelatedGroups.count) groups give access to $dirName :"
  foreach ($gr in $dirRelatedGroups) {
    Write-Host "$($gr.groupName): $($gr.groupPermissions)"
  }

  Write-Host "`n$($dirRelatedMembers.count) user have access to $dirName :"
  foreach ($usr in $dirRelatedMembers) {
    Write-Host "$($usr.UserSAN): $($usr.userPermissions)"
  }

  return [PSCustomObject]@{
    DirGroups = $dirRelatedGroups
    DirUsers = $dirRelatedMembers
  }
}