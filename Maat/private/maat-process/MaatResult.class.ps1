####################################################
# Class describing Maat result
class MaatResult {
  [string]$resTitle = ""
  [MaatDirectory[]]$resDirectories = @()
  [MaatAccessGroup[]]$uniqueAccessGroups = @()
  [MaatAccessGroupMember[]]$uniqueAccessUsers = @()
  [string]$resDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

  # Constructors
  MaatResult([string]$title) {
    $this.resTitle = $title
  }

  MaatResult([xml]$xmlContent) {
    foreach ($xmlDir in $xmlContent.SelectNodes("//dir")) {
      $this.resDirectories += [MaatDirectory]::new($xmlDir, $this)
    }
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
  [MaatDirectory] GetAllUniqueDirectories() {
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

  # Adds a new unique maat directory
  [void] AddDir([MaatDirectory]$newDir) {
    if ($this.GetDirByName($newDir.GetName())) {
      Write-Host "A directory with the name $($newDir.GetName()) is already in this result"
      return
    }

    $this.resDirectories += $newDir
  }

  # Unique access group factory
  [MaatAccessGroup] GetUniqueAccessGroupByXml([System.Xml.XmlElement]$groupXmlContent) {
    $uniqueAccessGroup = $null
    $searchUniqueAccessGroup = $this.GetAccessGroupByName($groupXmlContent.g_name)

    if (!$searchUniqueAccessGroup) {
      $uniqueAccessGroup = [MaatAccessGroup]::new($groupXmlContent, $this)
      $this.uniqueAccessGroups += $uniqueAccessGroup
    }
    else {
      $uniqueAccessGroup = $searchUniqueAccessGroup[0]
    }

    return $uniqueAccessGroup
  }

  [MaatAccessGroup] GetUniqueAccessGroupByName([string]$groupName, [string]$groupPermissions) {
    $uniqueAccessGroup = $null
    $searchUniqueAccessGroup = $this.GetAccessGroupByName($groupName)

    if (!$searchUniqueAccessGroup) {
      $uniqueAccessGroup = [MaatAccessGroup]::new($groupName, $groupPermissions, $this)
      $this.uniqueAccessGroups += $uniqueAccessGroup
    }
    else {
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

  # Compare two MaatResult occurrences
  [bool] CompareMaatResults([MaatResult]$resultToCompare) {
    [MaatChange[]]$changes = @()
    $oldDirs = $resultToCompare.GetAllUniqueDirectories()
    $newDirs = $this.GetAllUniqueDirectories()

    foreach ($dir in ($oldDirs + $newDirs)) {
      $dirInOldRes = $oldDirs.Where({ $_.GetName() -eq $dir.GetName() })
      $dirInNewRes = $newDirs.Where({ $_.GetName() -eq $dir.GetName() })
      
      if (($dirInOldRes.count -gt 0) -and ($dirInNewRes.count -gt 0)) {
        $oldDirReport = $dirInOldRes[0].GetAccessReport()
        $newDirReport = $dirInNewRes[0].GetAccessReport()

        foreach ($accessUser in ($newDirReport + $oldDirReport)) {
          $usrInOldRes = $oldDirReport.Where({ $_.userName -eq $accessUser.userName })
          $usrInNewRes = $newDirReport.Where({ $_.userName -eq $accessUser.userName })

          # If user is present in both res : check if it changed
          if (($usrInOldRes.count -gt 0) -and ($usrInNewRes.count -gt 0)) {
            $permChanged = $usrInOldRes[0].userPermissions -ne $usrInNewRes[0].userPermissions
            $accessGroupChanged = $usrInOldRes[0].accessGroups -ne $usrInNewRes[0].accessGroups

            # New MaatChange if user permissions changed
            if ($permChanged) {
              $permChange = [MaatChange]::new("$($accessUser.userName) permissions changed over $($dir.GetName())")
              $permChange.SetOldValue($usrInOldRes[0].userPermissions)
              $permChange.SetNewValue($usrInNewRes[0].userPermissions)
              
              $changes += $permChange
            }

            # New MaatChange if user access groups changed
            if ($accessGroupChanged) {
              $accessGroupChange = [MaatChange]::new("$($accessUser.userName) access groups changed over $($dir.GetName())")
              $accessGroupChange.SetOldValue(($usrInOldRes[0].accessGroups -join ', '))
              $accessGroupChange.SetNewValue(($usrInNewRes[0].accessGroups -join ', '))

              $changes += $accessGroupChange
            }
          }
          # If user is present in old res but not in the new
          elseif (($usrInOldRes.count -gt 0)) {
            $removedUserChange = [MaatChange]::new("$($usrInOldRes[0].userName) lost access permission over $($dir.GetName())")
            $removedUserChange.SetOldValue($usrInOldRes[0].userPermissions)

            $changes += $removedUserChange
          }
          # Else user is present in new res but not in the old
          else {
            $newUserChange = [MaatChange]::new("$($usrInNewRes[0].userName) gain access permission over $($dir.GetName())")
            $newUserChange.SetNewValue($usrInNewRes[0].userPermissions)

            $changes += $newUserChange
          }
        }
      }
      else {
        $newDirChange = [MaatChange]::new("New directory monitored")
        $newDirChange.SetNewValue($dir.GetName())
        $changes += $newDirChange
      }
    }

    return ($changes.count -eq 0)
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

####################################################
# Class describing directory behavior
class MaatDirectory {
  [string]$dirName
  [string]$dirPath
  [MaatAccessGroup[]]$dirAccessGroups = @()
  [MaatResult]$resultRef

  # Constructors
  MaatDirectory([System.Xml.XmlElement]$dirXmlContent, [MaatResult]$result) {
    $this.dirName = $dirXmlContent.dir_name
    $this.dirPath = $dirXmlContent.dir_path
    $this.resultRef = $result

    foreach ($accessGroupXml in $dirXmlContent.SelectNodes("*/group")) {
      [MaatAccessGroup]$uniqueRelatedAccessGroup = $this.resultRef.GetUniqueAccessGroupByXml($accessGroupXml)
      $uniqueRelatedAccessGroup.AddRelatedDirectory($this)
      
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

  # Method printing accesses for every related users
  [object[]] GetAccessReport() {
    $usersReportList = @()
    
    foreach ($usr in $this.GetAccessUsers()) {
      $usersReportList += $usr.GetSimpleReport($this)
    }

    return $usersReportList
  }

  # Give feedback on the current dir accesses
  [void] GetAccessFeedback() {
    $accessReport = $this.GetAccessReport()
    Write-Host "`n$($accessReport.count) user(s) have access to $($this.dirName) :"

    foreach ($usr in $accessReport) {
      Write-Host "$($usr.userName): $($usr.userPermissions) ($($usr.accessGroups -join ', '))"
    }
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $dirAccessGroupsXml = foreach ($accessGroup in $this.dirAccessGroups) {
      $accessGroup.ToXml()
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

####################################################
# Class describing access group behavior
class MaatAccessGroup {
  [string]$groupName
  [string]$groupPermissions = ""
  [MaatDirectory[]]$groupDirectories = @()
  [MaatAccessGroupMember[]]$groupMembers = @()
  [MaatResult]$resultRef

  # Constructors
  MaatAccessGroup([System.Xml.XmlElement]$groupXmlContent, [MaatResult]$result) {
    $this.groupName = $groupXmlContent.g_name
    $this.groupPermissions = $groupXmlContent.g_permissions
    $this.resultRef = $result

    foreach ($accessGroupMemberXml in $groupXmlContent.SelectNodes("*/member")) {
      $uniqueRelatedMember = $this.resultRef.GetUniqueAccessGroupMember($accessGroupMemberXml)
      $uniqueRelatedMember.AddRelatedAccessGroup($this)

      $membersDN = $this.groupMembers | foreach-object { $_.GetDN() }
      if (!($uniqueRelatedMember.GetDN() -in $membersDN)) {
        $this.groupMembers += $uniqueRelatedMember
      }
    }
  }

  MaatAccessGroup([string]$name, [string]$permissions, [MaatResult]$result) {
    $this.groupName = $name
    $this.groupPermissions = $permissions
    $this.resultRef = $result
  }

  # Getter method to return access group name
  [string] GetName() {
    return $this.groupName
  }

  # Getter method to return access group permissions
  [string] GetPermissions() {
    return $this.groupPermissions
  }

  # Get the list of directories that the current group gives access on
  [MaatDirectory[]] GetDirectoryList() {
    return $this.groupDirectories
  }

  # Get the current MaatResult
  [MaatResult] GetResultRef() {
    return $this.resultRef
  }

  [string[]] GetMembersDN() {
    return $this.groupMembers | foreach-object { $_.GetDN() }
  }

  # Return the names of related directories
  [string[]] GetDirNames() {
    return $this.groupDirectories | foreach-object { $_.GetName() }
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberBySAN([string]$memberSAN) {
    return $this.groupMembers.Where({ $_.GetSan() -eq $memberSAN })[0]
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberByDN([string]$memberDN) {
    return $this.groupMembers.Where({ $_.GetDN() -eq $memberDN })[0]
  }

  [bool] GivesPermissionsOnDir([string]$dirName) {
    return ($dirName -in $this.GetDirNames())
  }

  # Adds a directory to the list of related dir the group gives access on
  [void] AddRelatedDirectory([MaatDirectory]$newRelatedDir) {
    if ($this.GivesPermissionsOnDir($newRelatedDir.GetName())) {
      Write-Host "$($newRelatedDir.GetName()) is already related to $($this.groupName)"
      return
    }

    $this.groupDirectories += $newRelatedDir
  }

  # Method to add a group member
  [void] AddMember([MaatAccessGroupMember]$newMember) {
    if ($newMember.GetDN() -in $this.GetMembersDN()) {
      Write-Host "Member $($newMember.GetSAN()) is already a member of $($this.groupName)"
      return
    }

    $this.groupMembers += $newMember
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $groupMemberXml = foreach ($member in $this.groupMembers) {
      $member.ToXml()
    }

    return @"
      <group>
        <g_name>$($this.groupName)</g_name>
        <g_permissions>$($this.groupPermissions)</g_permissions>
        <g_members>
        $groupMemberXml
        </g_members>
      </group>
"@
  }

}

####################################################
# Class describing access group member behavior
class MaatAccessGroupMember {
  [string]$memberDN
  [string]$memberSAN
  [string]$memberName
  [string]$memberDomain
  [string]$memberLastChange
  [string]$memberLastPwdChange
  [string]$memberDescription
  [MaatAccessGroup[]]$memberAccessGroups = @()

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
    return $this.memberAccessGroups | foreach-object { $_.GetDirNames() }
  }

  # Check if the current user has permissions on a given directory
  [bool] HasPermissionsOnDir([string]$dirName) {
    return ($dirName -in $this.GetRelatedDirNames())
  }

  [bool] IsMemberOf([string]$groupName) {
    return ($this.memberAccessGroups.Where({ $_.GetName() -eq $groupName }).count -gt 0)
  }

  # Get a list of group the current user is a member of and related to the given directory
  [MaatAccessGroup] GetMemberGroupsRelatedToDir([MaatDirectory]$dir) {
    return $this.memberAccessGroups.Where({ $dir.GetName() -in $_.GetDirNames() })[0]
  }

  # Method to retreive user access groups with given perms over the given dir
  [object] GetDirAccessGroupsByPerm([MaatDirectory]$dir) {
    $res = @{
      R  = @()
      RW = @()
    }

    foreach ($gr in $this.GetMemberGroupsRelatedToDir($dir)) {
      if ($gr.GetPermissions() -eq "RW") {
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

  # Method to return a short report on the current user accesses on a given dir
  [object] GetSimpleReport([MaatDirectory]$dir) {
    $usrAccessOverDirByPermissions = $this.GetDirAccessGroupsByPerm($dir)
    $usrPermissions = $this.GetDirPermissions($dir)
    $usrAccessHighestGroups = $usrAccessOverDirByPermissions[$usrPermissions] | foreach-object { $_.GetName() }

    return @{
      userName        = $this.GetSAN()
      userPermissions = $usrPermissions
      accessGroups    = $usrAccessHighestGroups
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

class MaatChange {
  [string]$changeDescription
  [type]$oldValue
  [type]$newValue

  #Constructors
  MaatChange([string]$description) {
    $this.changeDescription = $description
  }

  MaatChange([string]$description, $oldValue, $newValue) {
    $this.changeDescription = $description
    $this.oldValue = $oldValue
    $this.newValue = $newValue
  }

  # Getter method to return change description
  [string] GetDescription() {
    return $this.changeDescription
  }

  # Getter method to return change previous value
  [type] GetOldValue() {
    return $this.oldValue
  }

  # Getter method to return change previous value
  [type] GetNewValue() {
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
      $resString = "* $resString : $($this.oldValue) => $($this.newValue) *"
    }
    elseif ($this.oldValue) {
      $resString = "- $resString : $($this.oldValue) -"
    }
    else {
      $resString = "+ $resString : $($this.newValue) +"
    }
    
    return $resString
  }
}