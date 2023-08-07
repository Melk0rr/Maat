function Convert-DirDataToXML {
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

  function Get-DirGroupXML {
    param(
      [object] $GroupObject
    )
    $groupObjectMembersXML = @()

    foreach ($grObjMember in $groupObject.GroupMembers) {
      $memberDesc = $grObjMember.UserDescription ? ($grObjMember.UserDescription).Replace("&", "&amp;") : ""
      $groupObjectMembersXML += @"

          <member>
            <m_distinguishedname>$($grObjMember.UserDN)</m_distinguishedname>
            <m_name>$($grObjMember.UserName)</m_name>
            <m_domain>$($grObjMember.UserDomain)</m_domain>
            <m_last_change>$($grObjMember.UserLastChange)</m_last_change>
            <m_last_pwdchange>$($grObjMember.UserLastPwdChange)</m_last_pwdchange>
            <m_description>$memberDesc</m_description>
          </member>
"@
    }

    return @"
      <group>
        <g_name>$($GroupObject.GroupName)</g_name>
        <g_permissions>$($GroupObject.GroupPermissions)</g_permissions>
        <g_members>
        $groupObjectMembersXML
        </g_members>
      </group>
    
"@
  }



  $directoryXMLList = @()

  foreach ($dirObject in $DirData) {
    $dirConfigGroupXMLList = @()
    if ($dirObject.DirConfigAccess) {
      foreach ($dirConfigGroupObject in $dirObject.DirConfigAccess) {
        $dirConfigGroupXMLList += Get-DirGroupXML $dirConfigGroupObject
      }
    }

    $dirACLGroupXMLList = @()
    if ($dirObject.DirACLAccess) {
      foreach ($dirACLGroupObject in $dirObject.DirACLAccess) {
        $dirACLGroupXMLList += Get-DirGroupXML $dirACLGroupObject
      }
    }

    $directoryXMLList += @"
  <dir>
    <dir_name>$($dirObject.DirName)</dir_name>
    <dir_path>$($dirObject.DirPath)</dir_path>
    <dir_access_groups>
    $dirConfigGroupXMLList
    </dir_access_groups>
    <dir_acl_groups>
    $dirACLGroupXMLList
    </dir_acl_groups>
  </dir>

"@
  }

  $innerXml = @"
<?xml version="1.0" encoding="utf-8"?>
<directories>
$directoryXMLList
</directories>
"@

  $xmlResults = New-Object xml
  $xmlResults.PreserveWhiteSpace = $true
  $xmlResults.innerXML = $innerXml

  return $xmlResults
}