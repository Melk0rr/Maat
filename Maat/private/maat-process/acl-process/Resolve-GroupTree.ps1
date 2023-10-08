function Resolve-GroupTree {
  [CmdletBinding()]
  param(

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [object] $ADGroup,

    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatAccess] $Access,

    [Parameter(
      Mandatory = $false,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false
    )]
    [ValidateNotNullOrEmpty()]
    [MaatAccessGroup] $ParentGroup
  )

  # Create access group instance + bind it to the directory
  $maatAccessGroup = $dir.GetResultRef().GetUniqueAccessGroup($adACLGroups[0].Name, $access)

  if ($ParentGroup) {
    $ParentGroup.AddSubGroup($maatAccessGroup, $true)
  }

  $currentSrv = (Split-DN $ADGroup.DistinguishedName).Domain
  $objectMembers = $ADGroup.members | foreach-object { Get-ADObject $_ -Server $currentSrv }
  [object[]]$userMembers = $objectMembers.Where({ $_.ObjectClass -eq "user" })
  [object[]]$groupAndForeignPrincipals = $objectMembers.Where({ $_.ObjectClass -in "group", "foreignScurityPrincipal" })

  # Set user members
  $ADGroup.members = $userMembers
  $maatAccessGroup.SetAccessMembersFromADGroup($adACLGr)

  foreach ($gr in $groupAndForeignPrincipals) {
    if ($gr.ObjectClass -eq "group") {
      $subADGroup = Get-ADGroup $gr.Name -Server $currentSrv -Properties Description, Members
      Resolve-GroupTree -ADGroup $subADGroup -Access $access -ParentGroup $maatAccessGroup

    }
    else {
      $foreignDomains = $Server.Where({ $_ -ne $currentSrv })
      foreach ($d in $foreignDomains) {
        try {
          $subForeignADGroup = Get-ADGroup $gr.Name -Server $d -Properties Description, Members
          Resolve-GroupTree -ADGroup $subForeignADGroup -Access $access -ParentGroup $maatAccessGroup
        }
        catch {
          Write-Warning "MaatResolveTree::Error while retreiving foreign principal $($gr.Name): $_"
        }
      }
    }
  }  
}