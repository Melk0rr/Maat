function Compare-MaatResults {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object[]]  $OldResults,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object[]]  $NewResults
  )

  [AccessChange[]]$resultChanges = @()

  # Helper function to search directory xml node in xml results
  function Search-DirByName {
    [CmdletBinding()]
    param (
      [string] $dirName
    )
    
    $dirSearch = $OldResults.SelectNodes("//dir[dir_name='$dirName']")

    if ($dirSearch.count -eq 0) {
      $resultChanges += [AccessChange]::new("New directory result", "", $dirName)
    }

    return $dirSearch
  }

  # Helper function to search access group in directory xml node
  function Search-GroupInDir {
    [CmdletBinding()]
    param (
      [string] $groupName,
      [xmlelement] $dir
    )

    $groupSearch = $dir.SelectNodes("*/group[g_name='$groupName']")

    if ($groupSearch.count -eq 0) {
      $resultChanges += [AccessChange]::new("New access group related to $($dir.dir_name)", "", $groupName)
    }

    return $groupSearch
  }

  foreach ($newResDir in $NewResults.SelectNodes("//dir")) {
    # Check if the current directory in new results is present in old result
    $newResDirInOldResults = Search-DirByName $newResDir.dir_name

    if ($newResDirInOldResults.count -gt 0) {
      foreach ($newGroup in $newResDir.SelectNodes("*/group")) {
        # Same for each access group in current directory
        $newGroupInOldResultsDir = Search-GroupInDir $newGroup.g_name $newResDirInOldResults[0]

        if ($newGroupInOldResultsDir.count -gt 0) {

          # Permission change
          if ($newGroup.g_permissions -ne $newGroupInOldResultsDir.g_permissions) {
            $resultChanges += [AccessChange]::new(
              "Permissions change for access group $($newGroup.g_name) on $($newResDir.dir_name)",
              $newGroupInOldResultsDir.g_permissions,
              $newGroup.g_permissions
            )
          }
        }
      }
    }
  }

}