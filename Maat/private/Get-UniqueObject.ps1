function Get-UniqueObject {
  [CmdletBinding()]
  param(
    [Parameter(
      Position = 0,
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    $ObjectList,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $Property
  )

  $uniqueList = @()

  foreach ($obj in $ObjectList) {
    $find = $uniqueList.Where({ $_.$Property -eq $obj.$Property })
    
    if ($find.count -eq 0) {
      $uniqueList += $obj
    }
  }

  return $uniqueList
}