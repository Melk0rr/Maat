function Get-AccessFromConfig {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    $Dir
  )

  # Retreive every mention of the specified directory
  $dirAccessGroups = $dir.GetAccessGroups()
  Write-Host "`n$($dirAccessGroups.count) groups give access to '$($dir.GetName())' :"

  foreach ($maatAccessGroup in $dirAccessGroups) {
    Write-Host "$($maatAccessGroup.GetName()): $($maatAccessGroup.GetDirAccess($dir).GetPermissions())"

    # Get the group node related to the directory to retreive its name
    $accessGroupsInDomain = $adGroups.Where({ $_.Name -eq $maatAccessGroup.GetName() })

    foreach ($adAccessGroup in $accessGroupsInDomain) {
      Get-AccessRelatedUsers $adAccessGroup $maatAccessGroup
    }
  }

  # Access feedback
  $dir.GetAccessFeedback()
}