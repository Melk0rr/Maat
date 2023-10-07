function Get-DirAccess {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    $Dir,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $SkipACL
  )

  # Retreive every mention of the specified directory
  $dirAccessGroups = $dir.GetAccessGroups()
  Write-Host "`n$($dirAccessGroups.count) group access to '$($dir.GetName())' specified in config"

  foreach ($maatAccessGroup in $dirAccessGroups) {
    Write-Host "$($maatAccessGroup.GetName()): $($maatAccessGroup.GetDirAccess($dir).GetPermissions())"

    # Get the group node related to the directory to retreive its name
    $accessGroupsInDomain = $adGroups.Where({ $_.Name -eq $maatAccessGroup.GetName() })

    foreach ($adAccessGroup in $accessGroupsInDomain) {
      $maatAccessGroup.SetAccessMembersFromADGroup($adAccessGroup)
    }
  }

  # Retreive dir access from acl and export it to a dedicated directory
  if (!$SkipACL.IsPresent) {
    Get-AccessFromACL $maatDir
  }

  # Access feedback
  $dir.GetAccessFeedback()
}