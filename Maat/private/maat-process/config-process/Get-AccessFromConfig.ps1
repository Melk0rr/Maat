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

  $dirName = $dir.GetName()

  # Retreive every mention of the specified directory
  $dirAccessGroups = $dir.GetAccessGroups()
  Write-Host "`n$($dirAccessGroups.count) groups give access to '$dirName' :"

  foreach ($maatAccessGroup in $dirAccessGroups) {
    Write-Host "$($maatAccessGroup.GetName()): $($maatAccessGroup.GetPermissions())"

    # Get the group node related to the directory to retreive its name
    $accessGroupsInDomain = $adGroups.Where({ $_.Name -eq $maatAccessGroup.GetName() })

    foreach ($adAccessGroup in $accessGroupsInDomain) {
      Get-AccessRelatedUsers $adAccessGroup $maatAccessGroup
    }
  }

  # Access feedback
  $dir.GetAccessFeedback()
}