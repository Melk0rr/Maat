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
    [string[]]  $ServerList
  )

  Write-Host "Retreiving $($GroupList.count) groups from $($ServerList.count) domain(s)..."

  $adGroups = @()
  foreach ($srv in $ServerList) {
    foreach ($gr in $GroupList) {
      try {
        $adGroup = Get-ADGroup $gr -Server $srv -Properties Description, Members
        $adGroups += $adGroup
      }
      catch {
        Write-Warning "Maat::Get-AccessADGroups:: $_"
      }
    }
  }

  Write-Host "Found $($adGroups.count)/$($GroupList.count) groups in AD"
  return $adGroups
}