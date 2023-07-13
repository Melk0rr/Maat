function Get-ConfigDirAccess {
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
  $dirRelatedGroups = @()

  # Retreive every mention of the specified directory
  $configRelatedGroups = $dir.SelectNodes("*/group")
  Write-Host "`n$($configRelatedGroups.count) groups related to '$dirName' in config file"

  foreach ($configGroup in $configRelatedGroups) {
    # Get the group node related to the directory to retreive its name
    $adConfigGroups = $adGroups.Where({ $_.Name -eq $configGroup.g_name })
    $configGroupMembers = @()

    foreach ($adConfigGr in $adConfigGroups) {
      $configGroupMembers += Get-AccessRelatedUsers $adConfigGr $configGroup.g_permissions
    }

    # Formatting informations related to the group itself
    $dirRelatedGroups += [PSCustomObject]@{
      GroupName = $configGroup.g_name
      GroupMembers = $configGroupMembers
      GroupPermissions = $configGroup.g_permissions
    }
  }

  # Handle duplicated users : a user may be a member of multiple groups granting access to a dir
  $dirRelatedMembers = Clear-AccessUserList $dirRelatedGroups.GroupMembers

  # Access feedback
  Write-Host "`n$($dirRelatedGroups.count) groups give access to $dirName :"
  foreach ($gr in $dirRelatedGroups) {
    Write-Host "$($gr.groupName): $($gr.groupPermissions)"
  }

  Write-Host "`n$($dirRelatedMembers.count) user have access to $dirName :"
  foreach ($usr in $dirRelatedMembers) {
    Write-Host "$($usr.UserSAN): $($usr.userPermissions)"
  }

  return $dirRelatedGroups
}