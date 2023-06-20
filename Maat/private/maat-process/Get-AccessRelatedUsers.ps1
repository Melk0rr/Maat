function Get-AccessRelatedUsers {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object]  $Group,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $Permissions
  )

  $accessRelatedUsers = @()

  foreach ($accessUsr in $Group.members) {
    # Formatting some basic informations about the group members
    $memberADObject = Get-ADUser $accessUsr -Server (Split-DN $accessUsr).domain -Properties Description, EmailAddress, Modified, PasswordLastSet
    $formatedMember = [PSCustomObject]@{
      UserDN = $accessUsr
      UserSAN = $memberADObject.samAccountName
      UserName = $memberADObject.name
      UserLastChange = $memberADObject.modified
      UserLastPwdChange = $memberADObject.passwordLastSet
      UserDescription = $memberADObject.description
      UserAccessGroup = $Group.name
      UserPermissions = $Permissions
    }

    # Check if the current member is already in the list
    $checkDuplicate = $accessRelatedUsers.Where({ $_.UserDN -eq $formatedMember.UserName })
    if ($checkDuplicate.count -gt 0) {
      $duplicateIndex = $accessRelatedUsers.IndexOf($checkDuplicate[0])

      # Update permissions if the current member is already in the list
      $accessRelatedUsers[$duplicateIndex] = Update-MemberPermissions $accessRelatedUsers[$duplicateIndex] $formatedMember.UserPermissions

      # Update access group if the current member is already in the list
      $accessRelatedUsers[$duplicateIndex] = Update-MemberAccessGroup $accessRelatedUsers[$duplicateIndex] $formatedMember.UserAccessGroup
    }

    $accessRelatedUsers += $formatedMember
  }

  return $accessRelatedUsers
}