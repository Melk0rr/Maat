function Invoke-Weighing {
  <#
  .SYNOPSIS
    This script will retreive access informations related to directories 
    specified in the configuration file

  .NOTES
    Name: Invoke-Weighing
    Author: JL
    Version: 2.2
    LastUpdated: 2023-Jun-13

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
    [string]  $HeartPath    
  )

  BEGIN {
    # If using help or version options, just write and exit
    if ($Help.IsPresent) {
      Write-Host $docString
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
    $startTime = Get-Date
  }

  PROCESS {
    try {
      [xml]$xmlHeart = Get-Content $HeartPath
      $maatHeart = [MaatResult]::new($xmlHeart)

      [xml]$xmlFeather = Get-Content $FeatherPath
      $maatFeather = [MaatResult]::new($xmlFeather)

      $comparator = [MaatComparator]::new($maatHeart, $maatFeather)
      $comparator.CompareMaatResults()
      $comparator.GetComparisonFeedback()
    }
    catch {
      Write-Error "MaatWeighing::Error while comparing heart with feather:`n$_"
    }
  }

  END {    
    $endTime = Get-Date
    Write-Host `n$bannerMin -f Yellow
    Write-Host "`nWeighing took $(Get-TimeDiff $startTime $endTime)"
  }
}