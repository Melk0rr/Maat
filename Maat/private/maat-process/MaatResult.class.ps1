####################################################
# Class describing Maat result
class MaatResult {
  [MaatDirectory[]]$resDirectories = @()
  [MaatAccessGroup[]]$uniqueAccessGroups = @()
  [MaatAccessGroupMember[]]$uniqueAccessUsers = @()
  [datetime]$resDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

  # Constructors
  MaatResult() {}

  MaatResult([xml]$xmlContent) {
    foreach ($xmlDir in $xmlContent.SelectNodes("//dir")) {
      $this.resDirectories += [MaatDirectory]::new($xmlDir, $this)
    }
  }

  [MaatDirectory] GetDirByName([string]$dirName) {
    return $this.resDirectories.Where({ $_.GetName() -eq $dirName })
  }

  [MaatAccessGroup] GetAccessGroupByName([string]$groupName) {
    return $this.uniqueAccessGroups.Where({ $_.GetName() -eq $groupName })
  }

  [MaatAccessGroupMember] GetAccessGroupMemberByDN([string]$memberDN) {
    return $this.uniqueAccessUsers.Where({ $_.GetDN() -eq $memberDN })
  }

  [MaatAccessGroup[]] GetAllUniqueAccessGroups() {
    return $this.uniqueAccessGroups
  }

  [MaatAccessGroupMember[]] GetAllUniqueAccessGroupMembers() {
    return $this.uniqueAccessUsers
  }

  [void] AddDir([MaatDirectory]$newDir) {
    if ($this.GetDirByName($newDir.GetName())) {
      Write-Host "A directory with the name $($newDir.GetName()) is already in this result"
      return
    }

    $this.resDirectories += $newDir
  }

  # Unique access group factory
  [MaatAccessGroup] GetUniqueAccessGroup([System.Xml.XmlElement]$groupXmlContent) {
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

  # Method to convert current instance into xml string
  [string] ToXml() {
    $directoriesXml = foreach ($dir in $this.resDirectories) {
      $dir.ToXml()
    }

    return @"
<?xml version="1.0" encoding="utf-8"?>
<date>$($this.date)</date>
<directories>
$directoriesXml
</directories>
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

    foreach ($accessGroupXml in $dirXmlContent.SelectNodes("*\group")) {
      [MaatAccessGroup]$uniqueRelatedAccessGroup = $this.resultRef.CreateUniqueAccessGroup($accessGroupXml)
      $uniqueRelatedAccessGroup.AddRelatedDirectory($this)
      $this.dirAccessGroups += $uniqueRelatedAccessGroup
    }
  }

  # Getter method to return dir name
  [string] GetName() {
    return $this.dirName
  }

  # Getter method to return current dir result instance reference
  [MaatResult] GetResultRef() {
    return $this.resultRef
  }

  # Getter method to return the list of access groups
  [MaatAccessGroup[]] GetAccessGroups() {
    return $this.dirAccessGroups
  }

  [MaatAccessGroupMember[]] GetAccessUsers() {
    return $this.resultRef.GetAllUniqueAccessGroupMembers().Where({ $_.HasPermissionsOnDir($this.dirName) })
  }

  # Method to retreive an access group based on a group name
  [MaatAccessGroup] GetGroupByName([string]$groupName) {
    return $this.dirAccessGroups.Where({ $_.GetName() -eq $groupName })
  }

  # Method to add an access group
  [void] AddAccessGroup([MaatAccessGroup]$newAccessGroup) {
    if ($newAccessGroup.GetName() -in $this.dirAccessGroups.GetName()) {
      Write-Host "Access group $($newAccessGroup.GetName()) is already in $($this.dirName) access groups"
      return
    }

    $this.dirAccessGroups += $newAccessGroup
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

    foreach ($accessGroupMemberXml in $groupXmlContent.SelectNodes("*\member")) {
      $uniqueRelatedMember = $this.resultRef.GetUniqueAccessGroupMember($accessGroupMemberXml)
      $uniqueRelatedMember.AddRelatedAccessGroup($this)

      if (!($uniqueRelatedMember.GetDN() -in $this.groupMembers.GetDN())) {
        $this.groupMembers += $uniqueRelatedMember
      }
    }
  }

  # Getter method to return access group name
  [string] GetName() {
    return $this.groupName
  }

  # Getter method to return access group permissions
  [string] GetPermissions() {
    return $this.groupPermissions
  }

  [MaatDirectory[]] GetDirectoryList() {
    return $this.groupDirectories
  }

  [MaatResult] GetResultRef() {
    return $this.resultRef
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberBySAN([string]$memberSAN) {
    return $this.groupMembers.Where({ $_.GetSan() -eq $memberSAN })
  }

  # Method to retreive a member based on a given SAN
  [MaatAccessGroupMember] GetMemberByDN([string]$memberDN) {
    return $this.groupMembers.Where({ $_.GetDN() -eq $memberDN })
  }

  [void] AddRelatedDirectory([MaatDirectory]$newRelatedDir) {
    if ($newRelatedDir.GetName() -in $this.groupDirectories.GetName()) {
      Write-Host "$($newRelatedDir.GetName()) is already related to $($this.groupName)"
      return
    }

    $this.groupDirectories += $newRelatedDir
  }

  # Method to add a group member
  [void] AddMember([MaatAccessGroupMember]$newMember) {
    if ($newMember.GetDN() -in $this.groupMembers.GetDN()) {
      Write-Host "Member $newMember is already a member of $($this.groupName)"
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
  [datetime]$memberLastChange
  [datetime]$memberLastPwdChange
  [string]$memberDescription
  [MaatAccessGroup[]]$memberAccessGroups = @()

  # Constructors
  MaatAccessGroupMember([object]$memberObject) {
    $this.memberDN = $memberObject.m_distinguishedname
    $this.memberSAN = $memberObject.m_san
    $this.memberName = $memberObject.m_name
    $this.memberDomain = $memberObject.m_domain
    $this.memberLastChange = Get-Date $memberObject.m_last_change
    $this.memberLastPwdChange = Get-Date $memberObject.m_last_pwdchange
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

  [bool] HasPermissionsOnDir([MaatDirectory]$dir) {
    return ($dir.GetName() -in $this.memberAccessGroups.GetDirectoryList().GetName())
  }

  [MaatAccessGroup] GetMemberGroupsRelatedToDir([MaatDirectory]$dir) {
    return $this.memberAccessGroups.Where({ $dir.GetName() -in $_.GetDirectoryList().GetName() })
  }

  # Method to retreive user permissions over a specific directory
  [string] GetDirPermissions([MaatDirectory]$dir) {
    [MaatAccessGroup[]]$groupsRelatedToDir = $this.GetMemberGroupsRelatedToDir($dir)
    
    $permissions = $null
    if ($groupsRelatedToDir.count -gt 0) {
      $permissions = "R"
      foreach ($gr in $groupsRelatedToDir) {
        if ($permissions -ne $gr.GetPermissions()) {
          $permissions = ($gr.GetPermissions() -eq "RW") ? $gr.GetPermissions() : $permissions
        }
      }
    }

    return $permissions
  }

  [void] AddRelatedAccessGroup([MaatAccessGroup]$newAccessGroup) {
    if ($newAccessGroup.GetName() -in $this.memberAccessGroups.GetName()) {
      Write-Host "$($newAccessGroup.GetName()) is already related to $($this.memberSAN)"
      return
    }

    $this.memberAccessGroups += $newAccessGroup
  }

  # Method to convert current instance into xml string
  [string] ToXml() {
    $memberDesc = $this.memberDescription ? ($this.memberDescription).Replace("&", "&amp;") : ""
    return @"
      <member>
        <m_distinguishedname>$($this.memberDN)</m_distinguishedname>
        <m_san>$($this.memberSAN)</m_san>
        <m_name>$($this.memberDN)</m_name>
        <m_domain>$($this.memberDomain)</m_domain>
        <m_last_change>$($this.memberLastChange)</m_last_change>
        <m_last_pwdchange>$($this.memberLastPwdChange)</m_last_pwdchange>
        <m_description>$memberDesc</m_description>
      </member>
"@
  }
}