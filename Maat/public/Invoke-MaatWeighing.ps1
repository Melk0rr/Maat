function Invoke-MaatWeighing {
  <#
  .SYNOPSIS
    This script will compare two maat results

  .NOTES
    Name: Invoke-Weighing
    Author: JL
    Version: 2.0
    LastUpdated: 2023-SEPT-05

  .EXAMPLE

  #>

  [CmdletBinding()]
  param(

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $FeatherPath,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $HeartPath,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $Help,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $Version
  )

  BEGIN {
    # If using help or version options, just write and exit
    if ($Help.IsPresent) {
      Write-Host $helpWeighing
      continue
    }

    if ($Version.IsPresent) {
      Write-Host (Get-ModuleVersion)
      continue
    }

    # Check paths for results to compare
    if (!(Test-Path -Path $FeatherPath -PathType Leaf)) {
      throw "MaatWeighing::Invalid feather path !"
    }

    if (!(Test-Path -Path $HeartPath -PathType Leaf)) {
      throw "MaatWeighing::Invalid heart path !"
    }

    Write-Host $banner`n -f Yellow
    Write-Host $bannerScale`n -f Gray
    $startTime = Get-Date
  }

  PROCESS {
    try {
      [xml]$xmlHeart = Get-Content $HeartPath
      $maatHeart = [MaatResult]::new($xmlHeart)

      [xml]$xmlFeather = Get-Content $FeatherPath
      $maatFeather = [MaatResult]::new($xmlFeather)

      $comparator = [MaatComparator]::new($maatFeather, $maatHeart)
      $comparator.CompareMaatResults()
      $comparator.GetComparisonFeedback()
    }
    catch {
      Write-Error "MaatWeighing::Error while comparing heart with feather:`n$_"
    }
  }

  END {    
    $endTime = Get-Date
    Write-Host `n$bannerClose -f Yellow
    Write-Host "`nWeighing took $(Get-TimeDiff $startTime $endTime)"
  }
}