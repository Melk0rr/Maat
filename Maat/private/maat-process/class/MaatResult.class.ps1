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

  # Getter method to return res title
  [string] GetTitle() {
    return $this.resTitle
  }

  # Getter method to return result date
  [string] GetDate() {
    return $this.resDate
  }

  # Getter method for the debug mode
  [bool] GetDebugMode() {
    return $this.debugMode
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

  # Method to return AD groups matching group names in configuration
  [object[]] GetADGroupsFromConfig([string[]]$serverList) {
    $accessGroupNames = $this.rawConfiguration.SelectNodes("//g_name").innerText | select-object -unique
    $adGroups = Get-AccessADGroups -GroupList $accessGroupNames -ServerList $serverList

    return $adGroups
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
    $resString = "$($this.GetTitle())($($this.GetDate()))"
    return $resString
  }

  [void] SaveXml([string]$path, [bool]$override = $false) {
    $xmlResults = New-Object xml
    $xmlResults.PreserveWhiteSpace = $true
    $xmlResults.innerXML = $this.ToXml()

    $resultOutPath = "$path\$($this.resTitle)"
    if (!$override) {
      $resultOutPath += ("$($this.resDate)" -split " ")[0].Replace('-', '')
    }

    $xmlResults.Save("$resultOutPath.xml")
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
# MaatDirectory class : directories accessed by users through groups
##############################################################################
class MaatDirectory {
  hidden [string]$dirName
  hidden [string]$dirPath
  hidden [MaatAccessGroup[]]$dirAccessGroups = @()
  hidden [MaatResult]$resultRef

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

  [string] GetPath() {
    return $this.dirPath
  }

  # Getter method to return current dir result instance reference
  [MaatResult] GetResultRef() {
    return $this.resultRef
  }

  # Getter method to return the list of access groups
  [MaatAccessGroup[]] GetAccessGroups() {
    return $this.dirAccessGroups
  }

  [string[]] GetAccessGroupNames() {
    return $this.dirAccessGroups | foreach-object { $_.GetName() }
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

  # Method to return not built in directory ACL accesses
  [object[]] GetNonBuiltInACLAccesses() {
    $acl = Get-ACL -Path $this.GetPath()
    $nonBuiltIn = $acl.Access.Where({ ($_.IdentityReference -notlike "*NT*\SYST*") -and ($_.IdentityReference -notlike "BUILTIN\*") })

    return $nonBuiltIn
  }

  # Give feedback on the current dir accesses
  [void] GetAccessFeedback() {
    $accessUsers = $this.GetAccessUsers()
    Write-Host "`n$($accessUsers.count) user(s) have access to $($this.dirName) :"

    foreach ($usr in $accessUsers) {
      $usrAccessOverDirByPermissions = $usr.GetDirAccessGroupsByPerm($this)
      $usrPermissions = $usr.GetDirPermissions($this)
      $usrAccessHighestGroups = $usrAccessOverDirByPermissions[$usrPermissions] | foreach-object { $_.GetName() }

      Write-Host "$($usr.GetSAN()): $usrPermissions ($($usrAccessHighestGroups -join ', '))"
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $dirAccessGroupsXml = foreach ($accessGroup in $this.dirAccessGroups) {
      $accessGroup.ToXml($this)
    }

    return @"
    <dir>
      <dir_name>$($this.dirName)</dir_name>
      <dir_path>$($this.dirPath)</dir_path>
      <dir_access_groups>
      $dirAccessGroupsXml
      </dir_access_groups>
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
  hidden [string]$type = "config"

  # Constructors
  MaatAccess([MaatDirectory]$dir, [string]$perm, [string]$type) {
    if ($perm -notin "R", "RW") {
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

  # Getter method to return access type
  [string] GetAccessType() {
    return $this.type
  }

  # Setter method to change permission value
  [void] SetPermissions([string] $perm) {
    if ($perm -in "R", "RW") {
      $this.permissions = $perm
    }
  }

  # Method to update access permissions if the provided permissions are highest
  [bool] UpdatePermissions([string]$perm) {
    $permChanged = $false
    if (($this.permissions -ne "RW") -and ($perm -eq "RW")) {
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
      Write-Host "MaatAccessGroup::$($this.groupName) already has access to $($access.GetDirectory().GetName()): $($accessCheck.GetPermissions())"
      if ($update) {
        $accessUpdated = $accessCheck.UpdatePermissions($access.GetPermissions())
        if ($accessUpdated) {
          Write-Host "MaatAccessGroup::Access updated with new permissions: $($access.GetPermissions())"
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
      Write-Host "MaatAccessGroup::$($subGroup.GetName()) is already a sub group of $($this.GetName())"
      return
    }

    $this.subGroups += $subGroup
    if ($withInheritance) {
      $this.accesses | foreach-object {
        $subGroup.AddAccess($_)
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
      if ($this.GetResultRef().GetDebugMode() -eq $true) {
        Write-Host "Member $($newMember.GetSAN()) is already a member of $($this.groupName)"
      }
      return
    }

    $this.groupMembers += $newMember
  }

  # Add members to current group based on an AD group members
  [void] SetAccessMembersFromADGroup([object]$adGroup) {
    foreach ($accessUsr in $adGroup.members) {
      # Formatting some basic informations about the group members
      try {
        $memberADObject = Get-ADUser $accessUsr -Server (Split-DN $accessUsr).domain -Properties Description, EmailAddress, Modified, PasswordLastSet
        $memberProperties = @{
          m_distinguishedname = $accessUsr
          m_san               = $memberADObject.samAccountName
          m_name              = $memberADObject.name
          m_domain            = (Split-DN $accessUsr).Domain
          m_last_change       = $memberADObject.modified
          m_last_pwdchange    = $memberADObject.passwordLastSet
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
    $groupMemberXml = foreach ($member in $this.groupMembers) {
      $member.ToXml()
    }

    return @"
      <group>
        <g_name>$($this.groupName)</g_name>
        <g_permissions>$($this.GetDirAccess($dir).GetPermissions())</g_permissions>
        <g_members>
        $groupMemberXml
        </g_members>
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
  hidden [string]$memberLastChange
  hidden [string]$memberLastPwdChange
  hidden [string]$memberDescription
  hidden [MaatAccessGroup[]]$memberAccessGroups = @()

  # Constructors
  MaatAccessGroupMember([object]$memberObject) {
    $this.memberDN = $memberObject.m_distinguishedname
    $this.memberSAN = $memberObject.m_san
    $this.memberName = $memberObject.m_name
    $this.memberDomain = $memberObject.m_domain
    $this.memberLastChange = $memberObject.m_last_change
    $this.memberLastPwdChange = $memberObject.m_last_pwdchange
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
      R  = @()
      RW = @()
    }

    foreach ($gr in $this.GetMemberGroupsRelatedToDir($dir)) {
      if ($gr.GetDirAccess($dir).GetPermissions() -eq "RW") {
        $res.RW += $gr
      }
      else {
        $res.R += $gr
      }
    }

    return $res
  }

  # Method to retreive user permissions over a specific directory
  [string] GetDirPermissions([MaatDirectory]$dir) {
    $userDirAccessGroupsByPerm = $this.GetDirAccessGroupsByPerm($dir)
    return ($userDirAccessGroupsByPerm.RW.count -gt 0) ? "RW" : "R"
  }

  # Adds a group to the list of groups the current user is a member of
  [void] AddRelatedAccessGroup([MaatAccessGroup]$newAccessGroup) {
    if ($newAccessGroup.GetName() -notin $this.GetGroupNames()) {
      $this.memberAccessGroups += $newAccessGroup
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $memberDesc = $this.memberDescription ? ($this.memberDescription).Replace("&", "&amp;") : ""
    return @"
        <member>
          <m_distinguishedname>$($this.memberDN)</m_distinguishedname>
          <m_san>$($this.memberSAN)</m_san>
          <m_name>$($this.memberName)</m_name>
          <m_domain>$($this.memberDomain)</m_domain>
          <m_last_change>$($this.memberLastChange)</m_last_change>
          <m_last_pwdchange>$($this.memberLastPwdChange)</m_last_pwdchange>
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
            $usrAPerm = $usrInResA.GetDirPermissions($dirInResA)
            $usrBPerm = $usrInResB.GetDirPermissions($dirInResB)
            $permChanged = $usrAPerm -ne $usrBPerm

            # New MaatChange if user permissions changed
            if ($permChanged) {
              $permChange = [MaatChange]::new("$($accessUser.userName) permissions changed over $($dir.GetName())", "user")
              $permChange.SetOldValue($usrInResA.userPermissions)
              $permChange.SetNewValue($usrInResB.userPermissions)
              
              $this.changeList += $permChange
            }

            # Compare access groups
            $usrAGroups = $usrInResA.GetDirAccessGroupsByPerm($dirInResA)
            $usrBGroups = $usrInResB.GetDirAccessGroupsByPerm($dirInResB)
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
            $removedUserChange.SetOldValue($usrInResA.GetDirPermissions($dirInResA))

            $this.changeList += $removedUserChange
          }
          # Else user is present in new res but not in the old
          else {
            $newUserChange = [MaatChange]::new("$($usrInResB.GetSAN()) gain access permission over $($dir.GetName())", "user")
            $newUserPerm = $usrInResB.GetDirPermissions($dirInResB)
            $newUserAccessGroups = $usrInResB.GetDirAccessGroupsByPerm($dirInResB)[$newUserPerm] | foreach-object { $_.GetName() }
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