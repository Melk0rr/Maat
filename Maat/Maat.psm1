$public = @( Get-ChildItem -Path "$PSScriptRoot\public\*.ps1" )
$private = @( Get-ChildItem -Path "$PSScriptRoot\private\*.ps1" -Recurse )

@($public + $private) | foreach-object {
  try {
    . $_.FullName
  } catch {
    Write-Error -Message "Failed to import function $($_.FullName): $_"
  }
}

Export-ModuleMember -Function $public.BaseName
# Export-ModuleMember -Variable 'myVariable'