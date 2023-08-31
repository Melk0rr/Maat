function Invoke-Maat {
  <#
  .SYNOPSIS
    This script will retreive access informations related to directories 
    specified in the configuration file

  .NOTES
    Name: Invoke-ADRetreiver
    Author: JL
    Version: 2.2
    LastUpdated: 2023-Jun-13

  .EXAMPLE

  #>

  [CmdletBinding()]
  param(

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $XMLConfigPath = "$PSScriptRoot/conf/access.conf.xml",

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $ACLCheck,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]  $CompareResults,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $ConfigCheck,

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
    [string]  $OutPath = "$PSScriptRoot",

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $Override,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]  $Server = $env:USERDNSDOMAIN,

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
      Write-Host $docString
      continue
    }

    if ($Version.IsPresent) {
      Write-Host (Get-ModuleVersion)
      continue
    }

    if (!(Test-Path -Path $XMLConfigPath -PathType Leaf)) {
      throw "Maat::Invalid XML configuration path !"
    }

    if (!(Test-Path -Path $OutPath -PathType Container)) {
      throw "Maat::Invalid output directory !"
    }

    Write-Host $banner`n -f Yellow
    $startTime = Get-Date

    if ($ConfigCheck.IsPresent -or $ACLCheck.IsPresent) {
      # Retreive List of group names from access configuration + get groups from AD
      [xml]$accessConfiguration = Get-Content $XMLConfigPath
      $accessGroupNames = $accessConfiguration.SelectNodes("//g_name").innerText | select-object -unique
      $adGroups = Get-AccessADGroups -GroupList $accessGroupNames -ServerList $Server

      $maatResultFromCurrentRun = [MaatResult]::new("maat_config_res")
      
      $accessDirs = $accessConfiguration.SelectNodes("//dir")
      Write-Host "`nRetreiving access for $($accessDirs.count) directories..."
    }

    # Check paths for results to compare
    if ($CompareResults.IsPresent) {
      $invalidResultPaths = @()
      if (!(Test-Path -Path $CompareResults[0] -PathType Leaf)) {
        $invalidResultPaths += $CompareResults[0]
      }

      if ($CompareResults.count -gt 1) {
        if (!(Test-Path -Path $CompareResults[1] -PathType Leaf)) {
          $invalidResultPaths += $CompareResults[1]
        }
      }

      if ($invalidResultPaths.count -gt 0) {
        throw "Maat::Invalid XML result path: $invalidResultPaths !"
      }
    }
  }

  PROCESS {
    foreach ($dir in $accessDirs) {
      try {
        $maatDir = [MaatDirectory]::new($dir, $maatResultFromCurrentRun)

        # Retreive dir access from configuration and export it to a dedicated directory
        if ($ConfigCheck.IsPresent) {
          Get-AccessFromConfig $maatDir
        }

        # Retreive dir access from acl and export it to a dedicated directory
        if ($ACLCheck.IsPresent) {
          Get-AccessFromACL $maatDir
        }

        $maatResultFromCurrentRun.AddDir($maatDir)
      }

      catch {
        Write-Error "Maat::Error while retreiving $($dir.dir_name) access:`n$_"
      }
    }

    # Result comparison
    if ($CompareResults) {
      [xml]$xmlResultToCompare0 = Get-Content $CompareResults[0]
      $maatResultToCompare0 = [MaatResult]::new($xmlResultToCompare0)

      if ($CompareResults.count -gt 1) {
        [xml]$xmlResultToCompare1 = Get-Content $CompareResults[1]
        $maatResultToCompare1 = [MaatResult]::new($xmlResultToCompare1)
      }
      else {
        $maatResultToCompare1 = $maatResultFromCurrentRun
      }

      $comparator = [MaatComparator]::new($maatResultToCompare0, $maatResultToCompare1)
      $comparator.CompareMaatResults()
      $comparator.GetComparisonFeedback()
    }
  }

  END {
    # Save results in xml file
    if ($ConfigCheck.IsPresent -or $ACLCheck.IsPresent) {
      Write-Host "`nSaving result to $OutPath" -f Green
      $maatResultFromCurrentRun.SaveXml($OutPath, $Override)
    }
    
    $endTime = Get-Date
    Write-Host `n$bannerMin -f Yellow
    Write-Host "`nJudgment took $(Get-TimeDiff $startTime $endTime)"
  }
}