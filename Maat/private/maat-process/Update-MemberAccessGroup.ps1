function Update-MemberAccessGroup {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [pscustomobject]  $Member,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $NewAccessGroup
  )


  $currentAccessGroups = $Member.userAccessGroup.Split(", ")

  if ($NewAccessGroup -notin $currentAccessGroups) {
    $newAccessGroupValue = "$($Member.userAccessGroup), $NewAccessGroup"
    $Member  | add-member -MemberType NoteProperty -Name "UserAccessGroup" -Value $newAccessGroupValue -Force
  }

  return $Member
}