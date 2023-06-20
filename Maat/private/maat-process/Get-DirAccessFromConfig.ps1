function Get-DirAccessFromConfig {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $DirName
  )

  $dirRelatedMembers = @()
  $dirRelatedGroups = @()

  # Retreive every mention of the specified directory
  $configRelatedGroups = $accessConfiguration.SelectNodes("//group/*/dir[contains(dir_name,'$dirName')]")
  Write-Host "$($configRelatedGroups.count) groups related to '$dirName' in config file"

  foreach ($configGroup in $configRelatedGroups) {
    # Get the group node related to the directory to retreive its name
    $groupNode = $configGroup.parentNode.parentNode
    $adConfigGroups = $adGroups.Where({ $_.Name -eq $groupNode.g_name })

    foreach ($adConfigGr in $adConfigGroups) {
      $dirRelatedMembers += Get-AccessRelatedUsers -GroupList $adConfigGr -Permissions $configGroup.permissions
    }

    # Formatting informations related to the group itself
    $configGroupData = [PSCustomObject]@{
      GroupName = $groupNode.g_name
      GroupDescription = $groupNode.description.Replace("`n", "")
      GroupUserCount = $adConfigGroups.members.count
      GroupPermissions = $configGroup.permissions
    }
    $dirRelatedGroups += $configGroupData
  }

  # Access feedback
  Write-Host "`n$($dirRelatedGroups.count) groups give access to $DirName :"
  foreach ($gr in $dirRelatedGroups) {
    Write-Host "$($gr.groupName): $($gr.groupPermissions)"
  }

  Write-Host "`n$($dirRelatedMembers.count) user have access to $DirName :"
  foreach ($usr in $dirRelatedMembers) {
    Write-Host "$($usr.UserSAN): $($usr.userPermissions)"
  }

  return [PSCustomObject]@{
    DirGroups = $dirRelatedGroups
    DirUsers = $dirRelatedMembers
  }
}