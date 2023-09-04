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
    [switch]  $ACLCheck,

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
    $startTime = Get-Date

    if ($ConfigCheck.IsPresent -or $ACLCheck.IsPresent) {
      # Retreive List of group names from access configuration + get groups from AD
      [xml]$accessConfiguration = Get-Content $XMLConfigPath
      $accessGroupNames = $accessConfiguration.SelectNodes("//g_name").innerText | select-object -unique
      $adGroups = Get-AccessADGroups -GroupList $accessGroupNames -ServerList $Server

      $maatResultFromCurrentRun = [MaatResult]::new("maat_config_res")

      if ($DebugMode.IsPresent) {
        $maatResultFromCurrentRun.SetDebugMode($true)
      }
      
      $accessDirs = $accessConfiguration.SelectNodes("//dir")
      Write-Host "`nRetreiving access for $($accessDirs.count) directories..."
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
  }

  END {
    # Save results in xml file
    if ($ConfigCheck.IsPresent -or $ACLCheck.IsPresent) {
      Write-Host "`nSaving result to $OutPath" -f Green
      $maatResultFromCurrentRun.SaveXml($OutPath, $Override)
    }
    
    $endTime = Get-Date
    Write-Host "`Retreiving heart took $(Get-TimeDiff $startTime $endTime)"
    Write-Host `n$bannerClose -f Yellow
  }
}