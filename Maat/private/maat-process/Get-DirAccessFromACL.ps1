foreach ($FolderFullName in $FolderFullNames) {
  Write-Host "Processing folder [$FolderFullName]"
  $Acl = Get-Acl -Path $FolderFullName

  # Get owner, group and inheritance
  $OwnerLines += $Acl | Select-Object -Property `
          @{Name="Path"; Expression={$Acl.Path.Replace("Microsoft.PowerShell.Core\FileSystem::","" )}}, `
          Owner, `
          Group, `
          AreAccessRulesProtected
  if (-not $?) {
          Write-LogMessage "Failed to get owner, group and inheritance: $($Error[0])" "ERROR"
  }
  if ($OwnerLines.Count -gt $MaximumLineCountPerFile) {
          $OwnerLines | Export-Csv -NoTypeInformation -Delimiter ";" -Encoding UTF8 -Path "$OwnerExportPath\$($ExportFilePrefix)_OwnerGroupInheritance_$($OwnerFileIndex.ToString().PadLeft(5, "0")).csv"
          $OwnerFileIndex++
          $OwnerLines = @()
  }

  # Get ACE permissions
  $TmpACELines = $Acl.Access | where { $_.IsInherited -eq $false } | Select-Object -Property `
          @{Name="Path"; Expression={$Acl.Path.replace("Microsoft.PowerShell.Core\FileSystem::","" )}}, `
          AccessControlType, `
          @{Name="AccessControlType_Value"; Expression={$_.AccessControlType.value__}}, `
          IdentityReference, `
          FileSystemRights, `
          @{Name="FileSystemRights_Value"; Expression={$_.FileSystemRights.value__}}, `
          IsInherited, `
          InheritanceFlags, `
          @{Name="InheritanceFlags_Value"; Expression={$_.InheritanceFlags.value__}}, `
          PropagationFlags, `
          @{Name="PropagationFlags_Value"; Expression={$_.PropagationFlags.value__}}
          
  # Output lines with "NT AUTHORITY\SYSTEM" and "BUILTIN\Administrators" first, to make text comparison easy between an exported permissions file with a translated permissions file (same order is used in both)
  $ACELines += $TmpACELines | where { $_.IdentityReference -eq "NT AUTHORITY\SYSTEM" } | Sort-Object -Property `
          @{Expression = "AccessControlType"; Descending = $True}, `
          @{Expression = "IdentityReference"; Descending = $False}, `
          @{Expression = "FileSystemRights";  Descending = $False}, `
          @{Expression = "IsInherited";       Descending = $False}, `
          @{Expression = "InheritanceFlags";  Descending = $False}, `
          @{Expression = "PropagationFlags";  Descending = $False}
  $ACELines += $TmpACELines | where { $_.IdentityReference -eq "BUILTIN\Administrators" } | Sort-Object -Property `
          @{Expression = "AccessControlType"; Descending = $True}, `
          @{Expression = "IdentityReference"; Descending = $False}, `
          @{Expression = "FileSystemRights";  Descending = $False}, `
          @{Expression = "IsInherited";       Descending = $False}, `
          @{Expression = "InheritanceFlags";  Descending = $False}, `
          @{Expression = "PropagationFlags";  Descending = $False}
  $ACELines += $TmpACELines | where { ($_.IdentityReference -ne "NT AUTHORITY\SYSTEM") -and ($_.IdentityReference -ne "BUILTIN\Administrators") } | Sort-Object -Property `
          @{Expression = "AccessControlType"; Descending = $True}, `
          @{Expression = "IdentityReference"; Descending = $False}, `
          @{Expression = "FileSystemRights";  Descending = $False}, `
          @{Expression = "IsInherited";       Descending = $False}, `
          @{Expression = "InheritanceFlags";  Descending = $False}, `
          @{Expression = "PropagationFlags";  Descending = $False}

  if (-not $?) {
          Write-LogMessage "Failed to get ACE permissions: $($Error[0])" "ERROR"
  }
  if ($ACELines.Count -gt $MaximumLineCountPerFile) {
          $ACELines | Export-Csv -NoTypeInformation -Delimiter ";" -Encoding UTF8  -Path "$ACEExportPath\$($ExportFilePrefix)_AccessControlEntries_$($ACEFileIndex.ToString().PadLeft(5, "0")).csv"
          $ACEFileIndex++
          $ACELines = @()
  }
}