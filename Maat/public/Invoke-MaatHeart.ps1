function Invoke-MaatHeart {
  <#
  .SYNOPSIS
    This script will retreive access informations related to directories 
    specified in the configuration file

  .NOTES
    Name: Invoke-MaatHeart
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
    [switch]  $DebugMode,

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
    [string]  $ReportTitle = "my_report",

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
      Write-Host $helpHeart
      continue
    }

    if ($Version.IsPresent) {
      Write-Host (Get-ModuleVersion)
      continue
    }

    if (!(Test-Path -Path $XMLConfigPath -PathType Leaf)) {
      throw "MaatHeart::Invalid XML configuration path !"
    }

    if (!(Test-Path -Path $OutPath -PathType Container)) {
      throw "MaatHeart::Invalid output directory !"
    }

    Write-Host $banner`n -f Yellow
    Write-Host $bannerHeart`n -f DarkRed
    $startTime = Get-Date

    # Retreive List of group names from access configuration + get groups from AD
    [xml]$accessConfiguration = Get-Content $XMLConfigPath

    $maatHeartResult = [MaatResult]::new($ReportTitle, $accessConfiguration)
    if ($Server) {
      $adConnector = [MaatADConnector]::new($Server, $maatHeartResult)
      $maatHeartResult.SetADConnector($adConnector)

      $maatHeartResult.GetADGroupsFromConfig()
    }

    if ($DebugMode.IsPresent) {
      $maatHeartResult.SetDebugMode($true)
    }
      
    $accessDirs = $accessConfiguration.SelectNodes("//dir")
    Write-Host "`nRetreiving access for $($accessDirs.count) directories..."
  }

  PROCESS {
    foreach ($dir in $accessDirs) {
      try {
        $maatDir = [MaatDirectory]::new($dir, $maatHeartResult)

        # Retreive dir access from configuration and export it to a dedicated directory
        $maatDir.GetAccessFromACL()

        $maatHeartResult.AddDir($maatDir)
        $maatDir.GetAccessFeedback()
      }

      catch {
        Write-Error "Maat::Error while retreiving $($dir.dir_name) access:`n$_"
      }
    }
  }

  END {
    # Save results in xml file
    Write-Host "`nSaving result to $OutPath" -f Green
    $maatHeartResult.SaveXml($OutPath, $Override)
    
    $endTime = Get-Date
    Write-Host "`Retreiving heart took $(Get-TimeDiff $startTime $endTime)"
    Write-Host `n$bannerClose -f Yellow
  }
}