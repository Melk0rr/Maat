function Compare-MaatResults {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatResult]  $FirstResult,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatResult]  $SecondResult
  )

  try {
    [MaatChange[]]$resultComparison = $maatResultToCompare1.CompareMaatResults($maatResultToCompare0)

    if ($resultComparison.count -eq 0) {
      Write-Host "$($resultComparison.count) changes between $($maatResultToCompare0.ToString()) and $($maatResultToCompare1.ToString())"
      foreach ($change in $resultComparison) {
        Write-Host $change.ToString()
      }
    }
    else {
      Write-Host "No changes between $($maatResultToCompare0.ToString()) and $($maatResultToCompare1.ToString())"
    }
  }
  catch {
    Write-Error "Maat::Error while trying to compare results:`n$_"
  }

  return $resultComparison
}