function Get-AccessFromConfig {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatDirectory]  $Dir
  )

  $dirName = $dir.GetName()

  # Retreive every mention of the specified directory
  $dirAccessGroups = $dir.GetAccessGroups()
  Write-Host "`n$($dirAccessGroups.count) groups give access to $dirName :"
  foreach ($maatAccessGroup in $dirAccessGroups) {
    Write-Host "$($maatAccessGroup.GetName()): $($maatAccessGroup.GetPermissions())"

    # Get the group node related to the directory to retreive its name
    $accessGroupsInDomain = $adGroups.Where({ $_.Name -eq $configGroup.GetName() })

    foreach ($adAccessGroup in $accessGroupsInDomain) {
      Get-AccessRelatedUsers $adAccessGroup $maatAccessGroup
    }
  }

  # Access feedback
  $usersWithAccessToCurrentDir = $dir.GetAccessUsers()
  Write-Host "`n$($usersWithAccessToCurrentDir.count) user have access to $dirName :"
  foreach ($usr in $usersWithAccessToCurrentDir) {
    $usrPermissions = $usr.GetDirPermissions($dir)
    Write-Host "$($usr.GetSAN()): $usrPermissions"
  }

}