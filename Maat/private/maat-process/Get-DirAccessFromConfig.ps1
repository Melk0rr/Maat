function Get-DirAccessFromConfig {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $Dir
  )

  $configRelatedGroups = $accessConfiguration.SelectNodes("//group/*/dir[contains(dir_name,'$dir')]")
  $dirRelatedMembers = @()
  $dirRelatedGroups = @()

  foreach ($configGroup in $configRelatedGroups) {
    $groupNode = $configGroup.parentNode.parentNode
    $adConfigGroups = $adGroups.Where({ $_.Name -eq $groupNode.g_name })

    foreach ($adConfigGr in $adConfigGroups) {
      foreach ($relatedMember in $adConfigGr.members) {
        $memberADObject = Get-ADUser $relatedMember -Server (Split-DN $relatedMember) -Properties Description, EmailAddress, Modified, PasswordLastSet
        $formatedMember = [PSCustomObject]@{
          UserDN = $relatedMember
          UserSAN = $memberADObject.samAccountName
          UserName = $memberADObject.name
          UserLastChange = $memberADObject.modified
          UserLastPwdChange = $memberADObject.passwordLastSet
          UserDescription = $memberADObject.description
          UserAccessGroup = $adConfigGr.name
          UserPermissions = $configGroup.permissions
        }

        # Check if the current member is already in the list
        $checkDuplicate = $dirRelatedMembers.Where({ $_.UserDN -eq $formatedMember.UserName })
        if ($checkDuplicate.count -gt 0) {
          $duplicateIndex = $dirRelatedMembers.IndexOf($checkDuplicate[0])

          # Update permissions if the current member is already in the list
          $dirRelatedMembers[$duplicateIndex] = Update-MemberPermissions $dirRelatedMembers[$duplicateIndex] $formatedMember.UserPermissions

          # Update access group if the current member is already in the list
          $dirRelatedMembers[$duplicateIndex] = Update-MemberAccessGroup $dirRelatedMembers[$duplicateIndex] $formatedMember.UserAccessGroup
        }

        $dirRelatedMembers += $formatedMember
      }
    }

    $configGroupData = [PSCustomObject]@{
      GroupName = $groupNode.g_name
      GroupDescription = $groupNode.description
      GroupUserCount = $adConfigGroups.members.count
      GroupPermissions = $configGroup.permissions
    }
    $dirRelatedGroups += $configGroupData
  }

  Write-Host "$($dirRelatedGroups.count) groups give access to $dir:"
  foreach ($gr in $dirRelatedGroups) {
    Write-Host "$($gr.groupName): $($gr.groupPermissions)"
  }

  Write-Host "$($dirRelatedMembers.count) user have access to $dir:"
  foreach ($usr in $dirRelatedMembers) {
    Write-Host "$($usr.UserSAN): $($usr.userPermissions)"
  }

  return [PSCustomObject]@{
    DirGroups = $dirRelatedGroups
    DirUsers = $dirRelatedMembers
  }
}