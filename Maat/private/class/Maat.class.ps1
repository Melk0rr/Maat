##############################################################################
# MaatResult class : analyse accesses given to users over directories
##############################################################################
class MaatResult {
  hidden [string]$resTitle = ""
  hidden [string]$resDate
  hidden [xml]$rawConfiguration
  hidden [MaatDirectory[]]$resDirectories = @()
  hidden [MaatAccessGroup[]]$uniqueAccessGroups = @()
  hidden [MaatAccessGroupMember[]]$uniqueAccessUsers = @()
  hidden [bool]$debugMode = $false
  hidden [MaatADConnector]$adConnector

  # Constructors
  MaatResult([string]$title, [xml]$configuration) {
    $this.rawConfiguration = $configuration
    $this.resTitle = $title
    $this.resDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  }

  MaatResult([xml]$xmlContent) {
    $this.rawConfiguration = $xmlContent
    $this.resTitle = $xmlContent.SelectSingleNode("/maat_result/title").InnerText
    $this.resDate = $xmlContent.SelectSingleNode("/maat_result/date").InnerText
    foreach ($xmlDir in $xmlContent.SelectNodes("//dir")) {
      $this.resDirectories += [MaatDirectory]::new($xmlDir, $this)
    }
  }

  # Getter method for the debug mode
  [bool] GetDebugMode() {
    return $this.debugMode
  }

  # Getter method for current result ad connector
  [MaatADConnector] GetADConnector() {
    return $this.adConnector
  }

  # Search a MaatDirectory by name
  [MaatDirectory] GetDirByName([string]$dirName) {
    return $this.resDirectories.Where({ $_.GetName() -eq $dirName })[0]
  }

  # Search a MaatAccessGroup by name
  [MaatAccessGroup] GetAccessGroupByName([string]$groupName) {
    return $this.uniqueAccessGroups.Where({ $_.GetName() -eq $groupName })[0]
  }

  # Search a MaatAccessGroupMember by Distinguished name
  [MaatAccessGroupMember] GetAccessGroupMemberByDN([string]$memberDN) {
    return $this.uniqueAccessUsers.Where({ $_.GetDN() -eq $memberDN })[0]
  }

  # Returns the list of unique directories
  [MaatDirectory[]] GetAllUniqueDirectories() {
    return $this.resDirectories
  }

  # Returns the list of unique access groups
  [MaatAccessGroup[]] GetAllUniqueAccessGroups() {
    return $this.uniqueAccessGroups
  }

  # Returns the list of unique members
  [MaatAccessGroupMember[]] GetAllUniqueAccessGroupMembers() {
    return $this.uniqueAccessUsers
  }

  # Setter method to change debug mode
  [void] SetDebugMode([bool]$mode) {
    $this.debugMode = $mode
  }

  # Setter method to change ad connector
  [void] SetADConnector([MaatADConnector]$connector) {
    $this.adConnector = $connector
  }

  # Handles log based on debug mode
  [void] HandleLogs([string]$msg, [string]$color = "White") {
    if ($this.debugMode) {
      Write-Host -f $color "* MaatDebugLog::$msg *"
    }
  }

  # Method to return AD groups matching group names in configuration
  [void] GetADGroupsFromConfig() {
    if (!$this.adConnector) {
      throw "MaatResult::Can't get AD groups from config without AD connector !"
    }

    $accessGroupNames = $this.rawConfiguration.SelectNodes("//g_name").innerText | select-object -unique
    if ($accessGroupNames.count -gt 0) {
      $configGroups = $this.adConnector.GetADGroups($accessGroupNames, $this.adConnector.GetServers())
      Write-Host "Found $($configGroups.count) AD groups based on config"
    }
  }

  # Adds a new unique maat directory
  [void] AddDir([MaatDirectory]$newDir) {
    if ($this.GetDirByName($newDir.GetName())) {
      Write-Host "A directory with the name $($newDir.GetName()) is already in this result"
      return
    }

    $this.resDirectories += $newDir
  }

  # Unique access group factory
  [MaatAccessGroup] GetUniqueAccessGroup([string]$groupName, [MaatAccess]$access) {
    $uniqueAccessGroup = $null
    $searchUniqueAccessGroup = $this.GetAccessGroupByName($groupName)

    if (!$searchUniqueAccessGroup) {
      $uniqueAccessGroup = [MaatAccessGroup]::new($groupName, $access)
      $this.uniqueAccessGroups += $uniqueAccessGroup
    }
    else {
      $searchUniqueAccessGroup[0].AddAccess($access, $true)
      $uniqueAccessGroup = $searchUniqueAccessGroup[0]
    }

    return $uniqueAccessGroup
  }

  # Unique access user factory
  [MaatAccessGroupMember] GetUniqueAccessGroupMember([object]$memberObject) {
    $uniqueMember = $null
    $searchUniqueMember = $this.GetAccessGroupMemberByDN($memberObject.m_distinguishedname)

    if (!$searchUniqueMember) {
      $uniqueMember = [MaatAccessGroupMember]::new($memberObject)
      $this.uniqueAccessUsers += $uniqueMember
    }
    else {
      $uniqueMember = $searchUniqueMember[0]
    }

    return $uniqueMember
  }

  # Method to return a string describing current instance
  [string] ToString() {
    $resString = "$($this.resTitle)($($this.resDate))"
    return $resString
  }

  [void] SaveXml([string]$path, [bool]$override = $false) {
    $xmlResults = New-Object xml
    $xmlResults.PreserveWhiteSpace = $true
    $xmlResults.innerXML = $this.ToXml()

    $resolved = (Resolve-Path $path).path
    $resultOutPath = "$($resolved.Trim('\'))\$($this.resTitle)"
    if (!$override) {
      $resultOutPath += ("$($this.resDate)" -split " ")[0].Replace('-', '')
    }

    $xmlResults.Save("$resultOutPath.maatreport.xml")
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $directoriesXml = foreach ($dir in $this.resDirectories) {
      $dir.ToXml()
    }

    return @"
<?xml version="1.0" encoding="utf-8"?>
<maat_result>
  <title>$($this.resTitle)</title>
  <date>$($this.resDate)</date>
  <directories>
  $directoriesXml
  </directories>
</maat_result>
"@
  }
}

##############################################################################
# MaatADConnector class : tools to query AD domains and link findings to maat
##############################################################################
class MaatADConnector {
  hidden [string[]]$servers = @()
  hidden [MaatResult]$maat
  hidden [object[]]$groupList = @()

  # Constructor
  MaatADConnector([string[]]$servers, [MaatResult]$maatResult) {
    $this.maat = $maatResult
    foreach ($srv in $servers) {
      try {
        $domainTest = Get-ADDomain -Server $srv
        if ($domainTest) {
          $this.servers += $srv
        }
      }
      catch {
        Write-Error "MaatADConnector::Error while testing $srv : $_"
      }
    }
  }

  # Getter for ad servers
  [string[]] GetServers() {
    return $this.servers
  }

  # Method to save ad group
  [void] SaveADGroup([object]$group) {
    $checkDuplicate = $this.groupList.Where({ $_.DistinguishedName -eq $group.Distinguishedname })

    if ($checkDuplicate.count -gt 0) {
      $this.groupList += $group
    }
  }

  # Simple method to search provided identity in current group list 
  [object[]] SearchGroupListForIdentity([string]$identityReference, [string]$srv = $null) {
    $search = $this.groupList.Where({
      (($_.Name -eq $identityReference) -or ($_.SID -eq $identityReference)) -and
      ($srv ? ($srv -in $_.DistinguishedName) : $true)
      })
    
    return $search
  }

  # Search the provided groups in the current servers
  [object[]] GetADGroups([string[]]$groupRefs, [string[]]$servers = $this.servers) {
    $this.maat.HandleLogs("`nLooking for $($groupRefs -join ', ') in $($this.servers.count) domain(s)...", "White")

    [object[]]$findings = @()
    foreach ($srv in $servers) {
      foreach ($gr in $groupRefs) {
        $searchDuplicates = $this.SearchGroupListForIdentity($gr, $srv)

        if ($searchDuplicates.count -eq 0) {
          try {
            [object]$adGroup = Get-ADGroup -Filter { (Name -eq $gr) -or (SID -eq $gr) } -Server $srv -Properties Description, Members
            
            if ($adGroup) {
              $this.SaveADGroup($adGroup)
              $findings += $adGroup

              $this.maat.HandleLogs("Found $gr in $srv : $($adGroup.name) !", "Green")
            }
          }
          catch {
            $this.maat.HandleLogs("MaatADConnector::$gr not found in $srv", "Red")
          }
        }
        else {
          $findings += $searchDuplicates
          $this.maat.HandleLogs("A group matching $gr was already found in $srv", "White")
        }
      }
    }

    if ($findings.count -gt 0) {
      $this.maat.HandleLogs("Found $($findings.count) group(s) out of $($groupRefs.count)", "Green")
    }
    
    return $findings
  }

  # Method to explore group members and populate maat access groups aswell as their members
  [void] ResolveADGroupTree([object]$adGroup, [MaatAccess]$access, [MaatAccessGroup]$parentGroup = $null) {
    # Create access group instance + bind it to the directory
    $maatAccessGroup = $this.maat.GetUniqueAccessGroup($adGroup.Name, $access)
    $currentGroupName = $maatAccessGroup.GetName()

    $parentLog = $parentGroup ? " $($parentGroup.GetName()) subgroup" : ""
    $this.maat.HandleLogs("`nResolving$parentLog $currentGroupName group tree...", "White")

    if ($parentGroup) {
      $parentGroup.AddSubGroup($maatAccessGroup, $true)
    }

    $currentSrv = (Split-DN $adGroup.DistinguishedName).Domain
    $objectMembers = $adGroup.members | foreach-object { Get-ADObject $_ -Server $currentSrv }
    [object[]]$groupAndForeignPrincipals = $objectMembers.Where({ $_.ObjectClass -in "group", "foreignSecurityPrincipal" })
    [object[]]$userMembers = $objectMembers.Where({ $_.ObjectClass -eq "user" })

    # Check if members of the current maat access group were already set for the current dommain
    $checkPopulated = $maatAccessGroup.HasMemberOnDomain($currentSrv)
    if (!$checkPopulated) {
      # Set user members
      if ($userMembers.count -gt 0) {
        Write-Host -f Green "Found $($userMembers.count) users in $currentGroupName ($currentSrv). Populating..."
        $adGroup | add-member -MemberType NoteProperty -Name "members" -Value $userMembers -Force
        $maatAccessGroup.SetAccessMembersFromADGroup($adGroup)
      }
    }

    foreach ($gr in $groupAndForeignPrincipals) {
      $this.maat.HandleLogs("`nRecursively looking into sub group $($gr.Name) from $currentSrv", "White")

      # Classic sub group recursivity
      if ($gr.ObjectClass -eq "group") {
        $subADGroup = Get-ADGroup -Filter { Name -eq $gr.Name } -Server $currentSrv -Properties Description, Members
        $this.ResolveADGroupTree($subADGroup, $access, $maatAccessGroup)

      }
      # Foreign group : checking recursively into group found in foreign domain
      else {
        $foreignDomains = $this.servers.Where({ $_ -ne $currentSrv })
        $this.maat.HandleLogs("$($gr.Name) is a foreign group. Checking $($foreignDomains -join ', ')...", "White")
        foreach ($d in $foreignDomains) {
          try {
            $subForeignADGroup = Get-ADGroup -Filter { (Name -eq $gr.Name) -or (SID -eq $gr.Name) } -Server $d -Properties Description, Members

            if ($subForeignADGroup) {
              $this.maat.HandleLogs("Found foreign group in $d : $($subForeignADGroup.name)", "Green")

            }
            else {
              $this.maat.HandleLogs("Could not find $($gr.Name) in $d", "Red")
            }

            $this.ResolveADGroupTree($subForeignADGroup, $access, $maatAccessGroup)
          }
          catch {
            $this.maat.HandleLogs("MaatResolveTree::Error while retreiving foreign principal $($gr.Name): $_", "Red")
          }
        }
      }
    }  
  }
}

##############################################################################
# MaatACLAccess class : acl access and permissions translation
##############################################################################
class MaatACLAccess {

  [object]$rightsTranslator = @{
    "Read|Write|Modify|FullControl" = "R"
    "Write|Modify|FullControl"      = "W"
    "Execute|FullControl"           = "X"
  }
  [string]$sidRegex = "^S-1-[0-59]-\d{2}-\d{8,10}-\d{8,10}-\d{8,10}-[1-9]\d{3,9}"

  hidden [MaatACLConnector]$aclConnector
  hidden [string]$identityReference
  hidden [string]$permissions
  hidden [bool]$inherited

  MaatACLAccess([object]$accessObject, [MaatACLConnector]$connector) {
    $this.aclConnector = $connector
    $this.identityReference = $accessObject.IdentityReference

    # If the reference is not an sid : removes the domain reference if any
    if (($this.identityReference -notmatch $this.sidRegex) -and (j$this.identityReference -match "\\")) {
      $this.identityReference = $this.identityReference.Split("\")[1]
    }

    $this.inherited = $accessObject.IsInherited

    # Translate MS file system rights to simple RWX short string
    $this.permissions = ""
    $this.rightsTranslator.keys | foreach-object {
      if ($accessObject.FileSystemRights -match $_) {
        $this.permissions += $this.rightsTranslator[$_]
      }
    }
  }

  # Getter for identity reference
  [string] GetIdentityReference() {
    return $this.identityReference
  }

  # Getter for acl access permissions
  [string] GetPermissions() {
    return $this.permissions
  }

  # Returns the related ad connector
  [MaatADConnector] GetADConnector() {
    return $this.aclConnector.GetMaatDirectory().GetADConnector()
  }

  # Method to translate the current acl access into ad groups
  [object[]] TranslateToADGroups() {
    [object[]]$resACLGroup = @()
    [string[]]$servers = $this.GetADConnector().GetServers()

    # Check if identity reference can be found in the ad group list built from configuration
    $resACLGroup = $this.GetADConnector().SearchGroupListForIdentity($this.identityReference, $servers)

    if ($resACLGroup.count -gt 0) {
      $this.identityReference = $resACLGroup[0].Name
    }

    $resACLGroup = $this.GetADConnector().GetADGroups($this.identityReference, $servers)
    
    # If the identity reference is an SID and was found in one of the domains
    # Check a second time using the name of the group found
    if ($this.identityReference -match $this.sidRegex) {
      $resCount = $resACLGroup.count
      if (($resCount -gt 0) -and ($resCount -ne $servers.count)) {
        Write-Host "`nFound only $resCount group(s) matching $($this.identityReference) in $resCount domains. Looking a second time with new identity reference..."
        $this.identityReference = $resACLGroup[0].Name
        $resACLGroup = $this.GetADConnector().GetADGroups($this.identityReference, $servers)

        if ($resACLGroup.count -gt $resCount) {
          Write-Host -f Green "Found $($resACLGroup.count - $resCount) more group(s) matching $($this.identityReference)"

        }
        else {
          Write-Host -f Green "Did not find more group matching $($this.identityReference)"
        }
      }
    }

    return $resACLGroup
  }
}

##############################################################################
# MaatACLConnector class : providing methods related to directory acl
##############################################################################
class MaatACLConnector {
  
  hidden [MaatDirectory]$maatDir
  hidden [object]$acl
  hidden [object]$accesses
  hidden [string]$owner

  MaatACLConnector([MaatDirectory]$dir) {
    $this.maatDir = $dir
    $this.acl = Get-ACL -Path $dir.GetPath()

    $this.owner = $this.acl.Owner
    $accessInstances = $this.acl.Access | foreach-object { [MaatACLAccess]::new($_, $this) }
    $builtInStrings = @("\\SYST", "BUILTIN\\")
    $this.accesses = @{
      BuiltIn    = $accessInstances.Where({ $_.GetIdentityReference() -match ($builtInStrings -join '|') })
      NonBuiltIn = $accessInstances.Where({ $_.GetIdentityReference() -notmatch ($builtInStrings -join '|') })
    }

    Write-Host "$($this.accesses.NonBuiltIn.count) ACL references found on $($this.maatDir.GetName())"
  }

  # Getter for maat directory instance
  [MaatDirectory] GetMaatDirectory() {
    return $this.maatDir
  }

  # Getter for built in accesses (NT\System, BUILTIN\Admins, etc)
  [object[]] GetBuiltInAccesses() {
    return $this.accesses.BuiltIn
  }

  # Getter for non built in accesses
  [object[]] GetNonBuiltInAccesses() {
    return $this.accesses.NonBuiltIn
  }

  # Getter for current acl accesses
  [object] GetAccesses() {
    return ($this.GetNonBuiltInAccesses() + $this.GetBuiltInAccesses())
  }

  # Populate maat access groups based on the current acl accesses
  [void] TranslateAccessesToGroups() {
    $accessIndex = 0
    # 1 acl access = 1 identity reference
    foreach ($aclAccess in $this.GetNonBuiltInAccesses()) {
      $accessPermissions = $aclAccess.GetPermissions()
      $translated = $aclAccess.TranslateToADGroups()

      if ($translated) {
        Write-Host "`n$($accessIndex + 1)) $($translated[0].Name): $accessPermissions"

        # Create access group instance + bind it to the directory
        [MaatAccess]$maatAccessToDir = [MaatAccess]::new($this.maatDir, $accessPermissions, "acl")
      
        foreach ($matchingGr in $translated) {
          $this.maatDir.GetADConnector().ResolveADGroupTree($matchingGr, $maatAccessToDir, $null)
        }
      }

      $accessIndex++
    }
  }
}

##############################################################################
# MaatDirectory class : directories accessed by users through groups
##############################################################################
class MaatDirectory {
  hidden [string]$dirName
  hidden [string]$dirPath
  hidden [MaatAccessGroup[]]$dirAccessGroups = @()
  hidden [MaatResult]$resultRef
  hidden [MaatACLConnector]$aclConnector = [MaatACLConnector]::new($this)

  # Constructors
  MaatDirectory([System.Xml.XmlElement]$dirXmlContent, [MaatResult]$result) {
    $this.dirName = $dirXmlContent.dir_name
    $this.dirPath = $dirXmlContent.dir_path
    $this.resultRef = $result

    foreach ($accessGroupXml in $dirXmlContent.SelectNodes("*/group")) {
      [MaatAccess]$accessToCurrentDir = [MaatAccess]::new($this, $accessGroupXml.g_permissions, "config")
      [MaatAccessGroup]$uniqueRelatedAccessGroup = $this.resultRef.GetUniqueAccessGroup($accessGroupXml.g_name, $accessToCurrentDir)

      if ($accessGroupXml.SelectNodes("*/member").count -gt 0) {
        $uniqueRelatedAccessGroup.PopulateMembers($accessGroupXml)
      }
      
      $groupNames = $this.dirAccessGroups | foreach-object { $_.GetName() }
      if ($uniqueRelatedAccessGroup.GetName() -notin $groupNames) {
        $this.dirAccessGroups += $uniqueRelatedAccessGroup
      }
    }
  }

  # Getter method to return dir name
  [string] GetName() {
    return $this.dirName
  }

  # Getter method to return dir path
  [string] GetPath() {
    return $this.dirPath
  }

  # Getter method to return current dir result instance reference
  [MaatResult] GetResultRef() {
    return $this.resultRef
  }

  # Getter for acl connector
  [MaatACLConnector] GetACLConnector() {
    return $this.aclConnector
  }

  # Getter method to return the list of access groups
  [MaatAccessGroup[]] GetAccessGroups() {
    return $this.resultRef.GetAllUniqueAccessGroups().Where({ $_.GivesPermissionsOnDir($this) })
  }

  [string[]] GetAccessGroupNames() {
    return $this.dirAccessGroups | foreach-object { $_.GetName() }
  }

  [MaatADConnector] GetADConnector() {
    return $this.resultRef.GetADConnector()
  }

  [bool] IsAccessedByGroup([string]$groupName) {
    return ($groupName -in $this.GetAccessGroupNames())
  }

  # Get the list of users whom have access to the current directory
  [MaatAccessGroupMember[]] GetAccessUsers() {
    return $this.resultRef.GetAllUniqueAccessGroupMembers().Where({ $_.HasPermissionsOnDir($this.dirName) })
  }

  # Method to retreive an access group based on a group name
  [MaatAccessGroup] GetGroupByName([string]$groupName) {
    return $this.dirAccessGroups.Where({ $_.GetName() -eq $groupName })[0]
  }

  # Method to add an access group
  [void] AddAccessGroup([MaatAccessGroup]$newAccessGroup) {
    if ($this.IsAccessedByGroup($newAccessGroup.GetName())) {
      Write-Host "Access group $($newAccessGroup.GetName()) is already in $($this.dirName) access groups"
      return
    }

    $this.dirAccessGroups += $newAccessGroup
  }

  # Method to populate access groups and members from ACL
  [void] GetAccessFromACL([string]$scope = "NonBuiltIn") {
    Write-Host "`nChecking ACL on $($this.dirName)..."

    $this.aclConnector.TranslateAccessesToGroups()
  }

  # Give feedback on the current dir accesses
  [void] GetAccessFeedback() {
    Write-Host "`n######## $($this.dirName) - Feedback ########"

    # Feedback on groups
    $accessGroups = $this.GetAccessGroups()
    Write-Host "$($accessGroups.count) group(s) have access to $($this.dirName) :"

    foreach ($gr in $accessGroups) {
      $groupAccess = $gr.GetDirAccess($this).GetPermissions()
      Write-Host "$($gr.GetName()): $groupAccess"
    }

    # Feedback on users
    $accessUsers = $this.GetAccessUsers()
    $enabledUsers = $accessUsers.Where({ $_.GetStatus() })
    Write-Host "`n$($enabledUsers.count) user(s) have access to $($this.dirName) ($($accessUsers.count - $enabledUsers.count) disabled) :"

    foreach ($usr in $enabledUsers) {
      $usrAccessOverDirByPermissions = $usr.GetDirAccessGroupsByPerm($this)
      $usrPermissions = $usr.GetDirPermissions($usrAccessOverDirByPermissions)
      $usrAccessHighestGroups = $usrAccessOverDirByPermissions[$usrPermissions] | foreach-object { $_.GetName() }

      Write-Host "$($usr.GetSAN()): $usrPermissions ($($usrAccessHighestGroups -join ', '))"
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $dirAccessGroupsXml = $this.GetAccessGroups() | foreach-object { $_.ToXml($this) }
    $dirAccessUsersXml = $this.GetAccessUsers() | foreach-object { $_.ToXml($this) }

    return @"
    <dir>
      <dir_name>$($this.dirName)</dir_name>
      <dir_path>$($this.dirPath)</dir_path>
      <dir_access_groups>
      $dirAccessGroupsXml
      </dir_access_groups>

      <dir_access_users>
      $dirAccessUsersXml
      </dir_access_users>
    </dir>
  
"@
  }
}

##############################################################################
# MaatAccess class : access over a directory with R or RW permissions
##############################################################################
class MaatAccess {
  hidden [MaatDirectory] $targetDirectory
  hidden [string]$permissions
  hidden [string]$type = "acl"
  hidden [string[]]$validPermissions = @("R", "RX", "RW", "RWX")

  # Constructors
  MaatAccess([MaatDirectory]$dir, [string]$perm, [string]$type) {
    if ($perm -notin $this.validPermissions) {
      throw "MaatAccess::Invalid permissions provided: $perm"
    }
    
    $this.targetDirectory = $dir
    $this.permissions = $perm
    $this.type = $type
  }

  # Getter method to return targeted directory
  [MaatDirectory] GetDirectory() {
    return $this.targetDirectory
  }

  # Getter method to return permissions associated with directory
  [string] GetPermissions() {
    return $this.permissions
  }

  # Setter method to change permission value
  [void] SetPermissions([string] $perm) {
    if ($perm -in $this.validPermissions) {
      $this.permissions = $perm
    }
  }

  [bool] CheckHigherPermissions([string]$perm) {
    if ($perm -notin $this.validPermissions) {
      throw "MaatAccess::Invalid permissions provided for update: $perm"
    }

    return $this.validPermissions.IndexOf($perm) -gt $this.validPermissions.IndexOf($this.permissions)
  }

  # Method to update access permissions if the provided permissions are highest
  [bool] UpdatePermissions([string]$perm) {
    $permChanged = $false

    if ($this.CheckHigherPermissions($perm)) {
      $permChanged = $true
      $this.permissions = $perm
    }

    return $permChanged
  }

  [string] ToString() {
    return "$($this.targetDirectory.GetName()): $($this.permissions)"
  }
}


##############################################################################
# MaatAccessGroup class : groups giving access to users over a directory
##############################################################################
class MaatAccessGroup {
  hidden [string]$groupName
  hidden [MaatAccess[]]$accesses = @()
  hidden [MaatAccessGroupMember[]]$groupMembers = @()
  hidden [MaatAccessGroup[]]$parentGroups = @()
  hidden [MaatAccessGroup[]]$subGroups = @()
  # Constructors
  MaatAccessGroup([string]$name, [MaatAccess]$access) {
    $this.groupName = $name
    $access.GetDirectory().AddAccessGroup($this)
    $this.accesses += $access
  }

  # Getter method to return access group name
  [string] GetName() {
    return $this.groupName
  }

  # Getter method to return accesses
  [MaatAccess[]] GetAccesses() {
    return $this.accesses
  }

  # Getter method to return members
  [MaatAccessGroupMember[]] GetMembers() {
    return $this.groupMembers
  }

  # Get the list of directories that the current group gives access on
  [MaatDirectory[]] GetDirectoryList() {
    return $this.accesses | foreach-object { $_.GetDirectory() }
  }

  # Get the current MaatResult
  [MaatResult] GetResultRef() {
    return $this.accesses[0].GetDirectory().GetResultRef()
  }

  [string[]] GetMembersDN() {
    return $this.groupMembers | foreach-object { $_.GetDN() }
  }

  # Get members related to a given domain
  [MaatAccessGroupMember[]] GetDomainMembers([string]$domain) {
    return $this.GetMembers().Where({ $_.GetDomain() -eq $domain })
  }

  # Chech if current group has members on a given domain
  [bool] HasMemberOnDomain([string]$domain) {
    return ($this.GetDomainMembers($domain).count -gt 0)
  }

  # Return the names of related directories
  [string[]] GetDirNames() {
    return $this.GetDirectoryList() | foreach-object { $_.GetName() }
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberBySAN([string]$memberSAN) {
    return $this.groupMembers.Where({ $_.GetSan() -eq $memberSAN })[0]
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberByDN([string]$memberDN) {
    return $this.groupMembers.Where({ $_.GetDN() -eq $memberDN })[0]
  }

  # Method to check if the current group gives access over a dir
  [bool] GivesPermissionsOnDir([MaatDirectory]$dir) {
    return ($dir.GetName() -in $this.GetDirNames())
  }

  # Method to return Accesses over given dir
  [MaatAccess] GetDirAccess([MaatDirectory]$dir) {
    return $this.accesses.Where({ $_.GetDirectory().GetName() -eq $dir.GetName() })[0]
  }

  # Method to return accesses based on a type
  [MaatAccess[]] GetAccessByType([string]$accessType) {
    return $this.accesses.Where({ $_.GetType() -eq $accessType })
  }

  # Method to change access permissions over a dir
  [void] ChangeDirAccess([MaatDirectory]$dir, [string]$perm) {
    $this.GetDirAccess($dir).SetPermissions($perm)
  }

  # Adds a directory to the list of related dir the group gives access on
  [void] AddAccess([MaatAccess]$access, [bool]$update = $true) {
    $accessCheck = $this.GetDirAccess($access.GetDirectory())
    if ($accessCheck) {
      
      $this.GetResultRef().HandleLogs("MaatAccessGroup::$($this.groupName) already has access to $($access.GetDirectory().GetName()): $($accessCheck.GetPermissions())", "White")
      
      if ($update) {
        $accessUpdated = $accessCheck.UpdatePermissions($access.GetPermissions())
        if ($accessUpdated) {
          Write-Host "MaatAccessGroup::$($this.groupName) access over $($access.GetDirectory().GetName()) updated with new permissions: $($access.GetPermissions())"
        }
      }

      return
    }

    $access.GetDirectory().AddAccessGroup($this)
    $this.accesses += $access
  }

  [void] AddSubGroup([MaatAccessGroup]$subGroup, [bool]$withInheritance = $true) {
    $subGroupCheck = $this.subGroups.Where({ $_.GetName() -eq $subGroup.GetName() })
    if ($subGroupCheck) {
      $this.GetResultRef().HandleLogs("MaatAccessGroup::$($subGroup.GetName()) is already a sub group of $($this.GetName())", "White")
      return
    }

    $this.subGroups += $subGroup
    if ($withInheritance) {
      $this.accesses | foreach-object {
        $subGroup.AddAccess($_, $true)
      }
    }
    $subGroup.AddParentGroup($this)
  }

  # Adds a group to the list of parent groups
  [void] AddParentGroup([MaatAccessGroup]$parentGroup) {
    $this.parentGroups += $parentGroup
  }

  # Method to create MaatAccessGroupMember intances based from xml content
  [void] PopulateMembers([System.Xml.XmlElement]$xmlContent) {
    foreach ($accessGroupMemberXml in $xmlContent.SelectNodes("*/member")) {
      $uniqueRelatedMember = $this.GetResultRef().GetUniqueAccessGroupMember($accessGroupMemberXml)
      $uniqueRelatedMember.AddRelatedAccessGroup($this)

      $membersDN = $this.groupMembers | foreach-object { $_.GetDN() }
      if (!($uniqueRelatedMember.GetDN() -in $membersDN)) {
        $this.groupMembers += $uniqueRelatedMember
      }
    }
  }

  # Method to add a group member
  [void] AddMember([MaatAccessGroupMember]$newMember) {
    if ($newMember.GetDN() -in $this.GetMembersDN()) {
      $this.GetResultRef().HandleLogs("MaatAccessGroup::$($newMember.GetSAN()) is already a member of $($this.groupName)", "White")
      return
    }

    $this.groupMembers += $newMember
  }

  # Add members to current group based on an AD group members
  [void] SetAccessMembersFromADGroup([object]$adGroup) {
    foreach ($accessUsr in $adGroup.members) {
      # Formatting some basic informations about the group members
      try {
        $memberADObject = Get-ADUser $accessUsr -Server (Split-DN $accessUsr).domain -Properties Description, EmailAddress
        $memberProperties = @{
          m_distinguishedname = $accessUsr
          m_san               = $memberADObject.samAccountName
          m_name              = $memberADObject.name
          m_domain            = (Split-DN $accessUsr).domain
          m_enabled           = $memberADObject.enabled ?? $true
          m_description       = $memberADObject.description
        }
    
        $newMember = $this.GetResultRef().GetUniqueAccessGroupMember($memberProperties)
        $newMember.AddRelatedAccessGroup($this)
        $this.AddMember($newMember)
      }
      catch {
        Write-Warning "MaatGroup:: $_"
      }
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml([MaatDirectory]$dir) {
    return @"
      <group>
        <g_name>$($this.groupName)</g_name>
        <g_permissions>$($this.GetDirAccess($dir).GetPermissions())</g_permissions>
      </group>
"@
  }

}

##############################################################################
# MaatAccessGroupMember class : users accessing directories via groups
##############################################################################
class MaatAccessGroupMember {
  hidden [string]$memberDN
  hidden [string]$memberSAN
  hidden [string]$memberName
  hidden [string]$memberDomain
  hidden [string]$memberDescription
  hidden [bool]$memberStatus
  hidden [MaatAccessGroup[]]$memberAccessGroups = @()

  # Constructors
  MaatAccessGroupMember([object]$memberObject) {
    $this.memberDN = $memberObject.m_distinguishedname
    $this.memberSAN = $memberObject.m_san
    $this.memberName = $memberObject.m_name
    $this.memberDomain = $memberObject.m_domain
    $this.memberStatus = $memberObject.m_enabled
    $this.memberDescription = $memberObject.m_description
  }

  # Getter method to return member Distinguished Name
  [string] GetDN() {
    return $this.memberDN
  }

  # Getter method to return member SAN
  [string] GetSAN() {
    return $this.memberSAN
  }

  # Getter for member domain
  [string] GetDomain() {
    return $this.memberDomain
  }

  # Getter method to return member status
  [bool] GetStatus() {
    return $this.memberStatus
  }

  # Method to retreive group name
  [string] GetGroupList() {
    return $this.memberAccessGroups
  }

  [string[]] GetGroupNames() {
    return $this.memberAccessGroups | foreach-object { $_.GetName() }
  }

  [string[]] GetRelatedDirNames() {
    return ($this.memberAccessGroups | foreach-object { $_.GetDirNames() }) | select-object -unique
  }

  # Check if the current user has permissions on a given directory
  [bool] HasPermissionsOnDir([string]$dirName) {
    return ($dirName -in $this.GetRelatedDirNames())
  }

  [bool] IsMemberOf([string]$groupName) {
    return ($this.memberAccessGroups.Where({ $_.GetName() -eq $groupName }).count -gt 0)
  }

  # Get a list of group the current user is a member of and related to the given directory
  [MaatAccessGroup[]] GetMemberGroupsRelatedToDir([MaatDirectory]$dir) {
    return $this.memberAccessGroups.Where({ $_.GivesPermissionsOnDir($dir) })
  }

  # Method to retreive user access groups with given perms over the given dir
  [object] GetDirAccessGroupsByPerm([MaatDirectory]$dir) {
    $res = @{
      R   = @()
      RX  = @()
      RW  = @()
      RWX = @()
    }

    foreach ($gr in $this.GetMemberGroupsRelatedToDir($dir)) {
      $perm = $gr.GetDirAccess($dir).GetPermissions()
      $res[$perm] += $gr
    }

    return $res
  }

  # Method to retreive user highest permissions over a specific directory
  [string] GetDirPermissions([object]$orderedGroups) {
    $perm = ""

    foreach ($p in @("R", "RX", "RW", "RWX")) {
      if ($orderedGroups[$_].count -gt 0) {
        $perm = $p
      }
    }

    return $perm
  }

  # Returns 
  [string[]] GetDirAccessGroupNames([MaatDirectory]$dir) {
    $usrAccessOverDirByPermissions = $this.GetDirAccessGroupsByPerm($dir)
    $usrPermissions = $this.GetDirPermissions($usrAccessOverDirByPermissions)

    return $usrAccessOverDirByPermissions[$usrPermissions] | foreach-object { $_.GetName() }
  }

  # Adds a group to the list of groups the current user is a member of
  [void] AddRelatedAccessGroup([MaatAccessGroup]$newAccessGroup) {
    if ($newAccessGroup.GetName() -notin $this.GetGroupNames()) {
      $this.memberAccessGroups += $newAccessGroup
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml([MaatDirectory]$dir) {
    $memberDesc = $this.memberDescription ? ($this.memberDescription).Replace("&", "&amp;") : ""
    $dirAccessGroupsSimpleXml = $this.GetDirAccessGroupNames($dir) | foreach-object {
      @"
            <g_name>$_</g_name>
"@
    }

    return @"
        <member>
          <m_distinguishedname>$($this.memberDN)</m_distinguishedname>
          <m_san>$($this.memberSAN)</m_san>
          <m_name>$($this.memberName)</m_name>
          <m_domain>$($this.memberDomain)</m_domain>
          <m_status>$($this.memberStatus ? "Enabled" : "Disabled")</m_status>
          <m_access_group>$($dirAccessGroupsSimpleXml)</m_access_group>
          <m_description>$memberDesc</m_description>
        </member>
"@
  }
}

##############################################################################
# MaatChange class : Describes a change in MaatResults
##############################################################################
class MaatChange {
  hidden [string]$changeDescription
  hidden [string]$type
  hidden [string]$oldValue
  hidden [string]$newValue

  #Constructors
  MaatChange([string]$description, [string]$type) {
    $this.changeDescription = $description
    $this.type = $type
  }

  MaatChange([string]$description, [string]$type, $oldValue, $newValue) {
    $this.changeDescription = $description
    $this.type = $type
    $this.oldValue = $oldValue
    $this.newValue = $newValue
  }

  # Getter method to return change description
  [string] GetDescription() {
    return $this.changeDescription
  }

  # Getter method to return the change type
  [string] GetType() {
    return $this.type
  }

  # Getter method to return change previous value
  [string] GetOldValue() {
    return $this.oldValue
  }

  # Getter method to return change previous value
  [string] GetNewValue() {
    return $this.newValue
  }

  # Setter method to set old value
  [void] SetOldValue($value) {
    $this.oldValue = $value
  }

  # Setter method to set new value
  [void] SetNewValue($value) {
    $this.newValue = $value
  }

  # Converts current change to a string
  [string] ToString() {
    $resString = "$($this.changeDescription)"

    if ($this.oldValue -and $this.newValue) {
      $resString = "* $resString : $($this.oldValue) => $($this.newValue)"
    }
    elseif ($this.oldValue) {
      $resString = "- $resString : $($this.oldValue)"
    }
    else {
      $resString = "+ $resString : $($this.newValue)"
    }
    
    return $resString
  }
}

##############################################################################
# MaatComparator class : list changes between MaatResults to compare them
##############################################################################
class MaatComparator {
  hidden [MaatChange[]]$changeList = @()
  hidden [MaatResult]$resultA
  hidden [MaatResult]$resultB

  # Constructors
  MaatComparator([MaatResult]$resA) {
    $this.resultA = $resA
  }

  MaatComparator([MaatResult]$resA, [MaatResult]$resB) {
    $this.resultA = $resA
    $this.resultB = $resB
  }

  # Getter method to return result A
  [MaatResult] GetResultA() {
    return $this.resultA
  }

  # Getter method to return result B
  [MaatResult] GetResultB() {
    return $this.resultB
  }

  # Getter method to return change list
  [MaatChange[]] GetChangeList() {
    return $this.changeList
  }

  # Method returning current comparator changes based on a type
  [MaatChange[]] GetChangesByType([string]$type) {
    return $this.changeList.Where({ $_.GetType() -eq $type })
  }

  # Method to filter duplicate maat directories from a list
  [MaatDirectory[]] GetUniqueDirList([MaatDirectory[]]$dirList) {
    $uniqueDirList = @()

    foreach ($dir in $dirList) {
      $searchDir = $uniqueDirList.Where({ $_.GetName() -eq $dir.GetName() })

      if ($searchDir.count -eq 0) {
        $uniqueDirList += $dir
      }
    }

    return $uniqueDirList
  }

  # Method to compare users access groups 
  [bool] CompareUserAccessGroups([MaatAccessGroup[]]$userAGroups, [MaatAccessGroup[]]$userBGroups) {
    $equal = $true

    $usrAGrNames = $userAGroups | foreach-object { $_.GetName() }
    $usrBGrNames = $userBGroups | foreach-object { $_.GetName() }
    if ($usrAGrNames.count -ne $usrBGrNames.count) {
      $equal = $false

    }
    else {
      foreach ($magName in $usrAGrNames) {
        if ($magName -notin $usrBGrNames) {
          $equal = $false
        }
      }
    }

    return $equal
  }

  # Compare two MaatResult occurrences
  [void] CompareMaatResults() {

    $resADirs = $this.resultA.GetAllUniqueDirectories()
    $resBDirs = $this.resultB.GetAllUniqueDirectories()

    foreach ($dir in $this.GetUniqueDirList(($resADirs + $resBDirs))) {
      $dirSearchInResA = $resADirs.Where({ $_.GetName() -eq $dir.GetName() })
      $dirInResA = $dirSearchInResA[0]

      $dirSearchInResB = $resBDirs.Where({ $_.GetName() -eq $dir.GetName() })
      $dirInResB = $dirSearchInResB[0]
      
      if (($dirSearchInResA.count -gt 0) -and ($dirSearchInResB.count -gt 0)) {
        $usersFromResA = $dirInResA.GetAccessUsers()
        $usersFromResB = $dirInResB.GetAccessUsers()

        foreach ($accessUser in ($usersFromResA + $usersFromResB)) {
          $usrSearchInResA = $usersFromResA.Where({ $_.GetSAN() -eq $accessUser.GetSAN() })
          $usrInResA = $usrSearchInResA[0]

          $usrSearchInResB = $usersFromResB.Where({ $_.GetSAN() -eq $accessUser.GetSAN() })
          $usrInResB = $usrSearchInResB[0]

          # If user is present in both res : check if it changed
          if (($usrSearchInResA.count -gt 0) -and ($usrSearchInResB.count -gt 0)) {
            # Compare permissions
            $usrAGroups = $usrInResA.GetDirAccessGroupsByPerm($dirInResA)
            $usrBGroups = $usrInResB.GetDirAccessGroupsByPerm($dirInResB)

            $usrAPerm = $usrInResA.GetDirPermissions($usrAGroups)
            $usrBPerm = $usrInResB.GetDirPermissions($usrBGroups)
            $permChanged = $usrAPerm -ne $usrBPerm

            # New MaatChange if user permissions changed
            if ($permChanged) {
              $permChange = [MaatChange]::new("$($accessUser.userName) permissions changed over $($dir.GetName())", "user")
              $permChange.SetOldValue($usrInResA.userPermissions)
              $permChange.SetNewValue($usrInResB.userPermissions)
              
              $this.changeList += $permChange
            }

            # Compare access groups
            $accessGroupsAreEquals = $this.CompareUserAccessGroups($usrAGroups[$usrAPerm], $usrBGroups[$usrBPerm])

            # New MaatChange if user access groups changed
            if (!$accessGroupsAreEquals) {
              $accessGroupChange = [MaatChange]::new("$($accessUser.GetSan()) access groups changed over $($dir.GetName())", "user")
              $accessGroupChange.SetOldValue(($usrInResA.accessGroups -join ', '))
              $accessGroupChange.SetNewValue(($usrInResB.accessGroups -join ', '))

              $this.changeList += $accessGroupChange
            }
          }
          # If user is present in old res but not in the new
          elseif (($usrSearchInResA.count -gt 0)) {
            $removedUserChange = [MaatChange]::new("$($usrInResA.GetSAN()) lost access permission over $($dir.GetName())", "user")
            $usrAGroups = $usrInResA.GetDirAccessGroupsByPerm($dirInResA)
            $removedUserChange.SetOldValue($usrInResA.GetDirPermissions($usrAGroups))

            $this.changeList += $removedUserChange
          }
          # Else user is present in new res but not in the old
          else {
            $newUserChange = [MaatChange]::new("$($usrInResB.GetSAN()) gain access permission over $($dir.GetName())", "user")
            $usrBGroups = $usrInResB.GetDirAccessGroupsByPerm($dirInResB)
            $newUserPerm = $usrInResB.GetDirPermissions($usrBGroups)

            $newUserAccessGroups = $usrInResB.GetDirAccessGroupNames($dirInResB)
            $newUserChange.SetNewValue("$newUserPerm ($newUserAccessGroups)")

            $this.changeList += $newUserChange
          }
        }
      }
      else {
        $newDirChange = [MaatChange]::new("New directory monitored", "directory")
        $newDirChange.SetNewValue($dir.GetName())
        $this.changeList += $newDirChange
      }
    }
  }

  # Method to report comparison result
  [void] GetComparisonFeedback () {
    if ($this.changeList.count -gt 0) {
      Write-Host "$($this.changeList.count) changes between $($this.resultA.ToString()) and $($this.resultB.ToString())"
      foreach ($change in $this.changeList) {
        Write-Host $change.ToString()
      }
    }
    else {
      Write-Host "No changes between $($this.resultA.ToString()) and $($this.resultB.ToString())"
    }
  }
}