function Format-ACLAccessRights {
  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]  $AccessRights
  )

  $formatedAccess = ""

  if ($AccessRights -like "*Read*") {
    $formatedAccess = "R"
  }

  if ($AccessRights -like "*Modify*") {
    $formatedAccess = "RW"
  }

  return $formatedAccess
}