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

  function Search-DirByName {
    [CmdletBinding()]
    param (
      [string] $dirName,
      [object[]] $dirList
    )
    
    $dirSearch = $dirList.Where({ $_.dir_name -eq $dirName })[0]

    if ($dirSearch.count -eq 0) {
      $resultChanges += [AccessChange]::new("New directory result", "None", $dirName)
    }
  }

  foreach ($newResDir in $NewResults.SelectNodes("//dir")) {

  }

}