function Get-AccessRelatedUsers {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object]  $adGroup,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    $accessGroup
  )

  foreach ($accessUsr in $adGroup.members) {
    # Formatting some basic informations about the group members
    $memberADObject = Get-ADUser $accessUsr -Server (Split-DN $accessUsr).domain -Properties Description, EmailAddress, Modified, PasswordLastSet
    $memberProperties = @{
      m_distinguishedname = $accessUsr
      m_san               = $memberADObject.samAccountName
      m_name              = $memberADObject.name
      m_domain            = (Split-DN $accessUsr).Domain
      m_last_change       = $memberADObject.modified
      m_last_pwdchange    = $memberADObject.passwordLastSet
      m_description       = $memberADObject.description
    }

    $newMember = $accessGroup.GetResultRef().GetUniqueAccessGroupMember($memberProperties)
    $newMember.AddRelatedAccessGroup($accessGroup)
    $accessGroup.AddMember($newMember)
  }
}