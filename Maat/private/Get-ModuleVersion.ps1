<#
  .SYNOPSIS
    Returns the module version number
#>

function Get-ModuleVersion() {
  $raw = $MyInvocation.MyCommand.ScriptBlock.Module.Version
  return "$($raw.Major).$($raw.Minor).$($raw.Build)"
}