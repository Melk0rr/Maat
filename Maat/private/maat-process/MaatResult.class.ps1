class MaatResult {
  [MaatDirectory[]]$resDirectories
  [datetime]$resDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

  MaatResult([xml]$xmlResult) {

  }

  MaatResult([object[]]$xmlResult) {
    
  }

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

class MaatDirectory {
  [string]$dirName
  [string]$dirPath
  [MaatAccessGroup[]]$dirAccessGroups
  [MaatAccessGroup[]]$dirAclGroups

  MaatDirectory () {

  }

  [string] ToXml() {
    $dirAccessGroupsXml = foreach ($accessGroup in $this.dirAccessGroups) {
      $accessGroup.ToXml()
    }

    $dirAclGroupsXml = foreach ($aclGroup in $this.dirAclGroups) {
      $aclGroup.ToXml()
    }

    return @"
    <dir>
      <dir_name>$($this.dirName)</dir_name>
      <dir_path>$($this.dirPath)</dir_path>
      <dir_access_groups>
      $dirAccessGroupsXml
      </dir_access_groups>
      <dir_acl_groups>
      $dirAclGroupsXml
      </dir_acl_groups>
    </dir>
  
"@
  }
}

class MaatAccessGroup {
  [string]$groupName
  [string]$groupPermissions
  [MaatAccessGroupMember[]]$groupMembers

  MaatAccessGroup() {

  }

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

class MaatAccessGroupMember {
  [string]$memberDN
  [string]$memberSAN
  [string]$memberName
  [string]$memberDomain
  [datetime]$memberLastChange
  [datetime]$memberPwdLastChange
  [string]$memberDescription
  [MaatAccessGroup]$memberAccessGroup

  MaatAccessGroupMember() {

  }

  [string] ToXml() {
    $memberDesc = $this.memberDescription ? ($this.memberDescription).Replace("&", "&amp;") : ""
    return @"
      <member>
        <m_distinguishedname>$($this.memberDN)</m_distinguishedname>
        <m_name>$($this.memberDN)</m_name>
        <m_domain>$($this.memberDomain)</m_domain>
        <m_last_change>$($this.memberLastChange)</m_last_change>
        <m_last_pwdchange>$($this.memberPwdLastChange)</m_last_pwdchange>
        <m_description>$memberDesc</m_description>
      </member>
"@
  }
}