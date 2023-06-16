function Update-MemberPermissions {
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
    [string]  $NewPermissions
  )
  $finalPermissions = ($Member.userPermissions -eq "RW") ? $Member.userPermissions : $NewPermissions
  $Member | add-member -MemberType NoteProperty -Name "UserPermissions" -Value $finalPermissions -Force

  return $Member
}