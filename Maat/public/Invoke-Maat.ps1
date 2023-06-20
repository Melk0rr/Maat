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

    $accessDirs = Get-UniqueObject $accessConfiguration.SelectNodes("//dir") -Property "dir_name"
    Write-Host "`nRetreiving access for $($accessDirs.count) directories..."
  }

  PROCESS {
    foreach ($dir in $accessDirs) {
      try {
        $dirOut = "$OutPath\directories\$dir"
        New-Item -ItemType Directory "$OutPath\$dir" -Force

        # Retreive dir access from configuration and export it to a dedicated directory
        if ($ConfigCheck.IsPresent) {
          $dirAccess = Get-DirAccessFromConfig ($dir.dir_name.Replace("`n", ""))

          # Export
          $dirAccess.dirGroups | export-csv "$dirOut\config\access_groups.csv" -delimiter '|' -Force
          $dirAccess.dirUsers | export-csv "$dirOut\config\access_users.csv" -delimiter '|' -Force
        }

        # Retreive dir access from acl and export it to a dedicated directory
        if ($ACLCheck.IsPresent) {
          $aclAccess = Get-DirAccessFromACL ($dir.dir_name.Replace("`n", ""))

          # Export
          $aclAccess.dirGroups | export-csv "$dirOut\acl\access_groups.csv" -delimiter '|' -Force
          $aclAccess.dirUsers | export-csv "$dirOut\acl\access_users.csv" -delimiter '|' -Force
        }
      }

      catch {
        Write-Error "Maat::Error while retreiving $dir access:`n$_"
      }
    }
  }

  END {
    $endTime = Get-Date
    Write-Host $bannerMin -Yellow
    Write-Host "`nJudgment took $(Get-TimeDiff $startTime $endTime)"
  }
}