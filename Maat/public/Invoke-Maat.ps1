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
    [switch]  $ConfigCheck,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $Help,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $OutPath,

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

    Write-Host $banner -f Yellow
    $startTime = Get-Date

    # Retreive List of group names from access configuration + get groups from AD
    [xml]$accessConfiguration = Get-Content $XMLConfigPath
    $accessGroupNames = $accessConfiguration.SelectNodes("//g_name").innerText | select-object -unique
    $adGroups = Get-AccessADGroups -GroupList $accessGroupNames -ServerList $Server

    $maatResFromConfig = [MaatResult]::new("maat_config_res")
    if ($ACLCheck.IsPresent) {
      $maatResFromACL = [MaatResult]::new("maat_acl_res")
    }
    
    $accessDirs = $accessConfiguration.SelectNodes("//dir")
    Write-Host "`nRetreiving access for $($accessDirs.count) directories..."
  }

  PROCESS {
    foreach ($dir in $accessDirs) {      
      try {
        # Retreive dir access from configuration and export it to a dedicated directory
        if ($ConfigCheck.IsPresent) {
          $maatConfigDir = [MaatDirectory]::new($dir, $maatResFromConfig)
          Get-AccessFromConfig $maatConfigDir
          $maatResFromConfig.AddDir($maatConfigDir)
        }

        # Retreive dir access from acl and export it to a dedicated directory
        if ($ACLCheck.IsPresent) {
          $maatACLDir = [MaatDirectory]::new($dir, $maatResFromACL)
          Get-AccessFromACL $maatACLDir
          $maatResFromConfig.AddDir($maatACLDir)
        }
      }

      catch {
        Write-Error "Maat::Error while retreiving $($dir.dir_name) access:`n$_"
      }
    }
  }

  END {
    # Save results in xml file
    if ($ConfigCheck.IsPresent) {
      $maatResFromConfig.SaveXml($OutPath, $Override)
    }

    if ($ACLCheck.IsPresent) {
      $maatResFromACL.SaveXml($OutPath, $Override)
    }
    
    $endTime = Get-Date
    Write-Host `n$bannerMin -f Yellow
    Write-Host "`nJudgment took $(Get-TimeDiff $startTime $endTime)"
  }
}