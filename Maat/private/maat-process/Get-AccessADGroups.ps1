function Get-AccessADGroups {

  [CmdletBinding()]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]  $GroupList,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]  $ServerList,
  )

  $adGroups = @()
  foreach ($srv in $ServerList) {
    foreach ($gr in $GroupList) {
      try {
        $adGroup = Get-ADGroup $gr -Server $srv -Properties Description, Members
        $adGroups += $adGroup
      }
      catch {
        Write-Error "Invoke-Maat: error occured while retreiving $gr group from $srv`n$_"
      }
    }
  }

  return $adGroups
}