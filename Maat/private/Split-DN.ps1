function Split-DN ([string] $dn) {
  [string[]]$splitDN = $dn -split ','
  [string[]]$domDCs = $splitDN.Where({ $_ -like "DC=*" })
  [string[]]$domOUs = $splitDN.Where({ $_ -like "OU=*" })
  [string[]]$domCNs = $splitDN.Where({ $_ -like "CN=*" })

  return [PSCustomObject]@{
    CN     = $domCNs ? $domCNs[0].Replace("CN=", "") : $null
    OUs    = $domOUs ? $domOUs.Replace("OU=", "") : $null
    Domain = $domDCs ? ($domDCs.Replace("DC=", "") -join '.') : $null
  }
}