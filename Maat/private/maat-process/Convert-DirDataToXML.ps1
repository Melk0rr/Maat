function Get-DirAccessFromACL {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object[]]  $DirData
  )

  $directoryXMLList = @()

  foreach ($dirObject in $DirData) {
    $directoryXMLList += @"
    <dir>

    </dir>
"@
  }

  $finalXML = @"
<?xml version="1.0" encoding="utf-8"?>
<directories>
$directoryXMLList
</directories>
"@

  return $finalXML
}