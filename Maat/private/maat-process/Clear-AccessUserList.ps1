function Clear-AccessUserList {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [pscustomobject[]]  $UserList
  )

  $uniqueUserList = @()

  foreach ($user in $UserList) {
    # If a user is already in the list:
    # - he is a member of multiple groups granting access to the dir
    # - join group access names + merge permissions
    $checkDuplicate = $uniqueUserList.Where({ $_.UserDN -eq $user.UserDN })
    if ($checkDuplicate.count -gt 0) {
      $indexOfDuplicate = $uniqueUserList.IndexOf($checkDuplicate[0])

      # Update permissions if the current member is already in the list
      $uniqueUserList[$indexOfDuplicate] = Update-MemberPermissions $uniqueUserList[$indexOfDuplicate] $user.UserPermissions

      # Update access group if the current member is already in the list
      $uniqueUserList[$indexOfDuplicate] = Update-MemberAccessGroup $uniqueUserList[$indexOfDuplicate] $user.UserAccessGroup

    } else {
      $uniqueUserList += $user
    }
  }

  return $uniqueUserList
}