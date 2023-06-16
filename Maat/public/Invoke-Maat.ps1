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
    [string]  $XMLConfigPath = ./src/access.conf.xml,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [switch]  $GetAccessFromConfig

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
    [string[]]  $Server,

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

    if (!Test-Path -Path $XMLConfig -PathType Leaf) {
      throw "Maat::Invalid XML configuration path !"
    }

    if (!Test-Path -Path $OutPath -PathType Container) {
      throw "Maat::Invalid output directory !"
    }

    Write-Host $banner -f Yellow
    $startTime = Get-Date

    # Retreive List of group names from access configuration + get groups from AD
    [xml]$accessConfiguration = Get-Content $XMLConfigPath
    $accessGroupNames = $accessConfiguration.SelectNodes("//g_name").innerText | select-object -unique
    $adGroups = Get-AccessADGroups -GroupList $accessGroupNames -ServerList $Server

    $accessDir = $accessConfiguration.SelectNodes("//dir_name").innerText | select-object -unique

  }

  PROCESS {
    foreach ($dir in $accessDir) {
      try {
        # Retreive dir access and export it to a dedicated directory
        $dirAccess = Get-DirAccessFromConfig $dir
        New-Item -ItemType Directory "$OutPath\$dir"
        
        $dirAccess.dirGroups | export-csv "$OutPath\$dir\access_groups.csv" -delimiter '|'
        $dirAccess.dirUsers | export-csv "$OutPath\$dir\access_users.csv" -delimiter '|'
      }
      catch {
        Write-Error "Maat::Error while retreiving $dir access:`n$_"
      }
    }
  }

  END {
    Write-Host "Judgment has been rendered"
  }
}