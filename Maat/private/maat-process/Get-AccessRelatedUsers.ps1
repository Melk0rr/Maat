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
      UserDomain = (Split-DN $accessUsr).Domain
      UserLastChange = $memberADObject.modified
      UserLastPwdChange = $memberADObject.passwordLastSet
      UserDescription = $memberADObject.description
      UserAccessGroup = $Group.name
      UserPermissions = $Permissions
    }

    $accessRelatedUsers += $formatedMember
  }

  return $accessRelatedUsers
}