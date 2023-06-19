function Get-TimeDiff ([datetime]$t1, [datetime]$t2) {
  $rawDiff = $t2 - $t1

  # Time properties we want to retreive from the above substraction
  $timeProps = @(
    [pscustomobject]@{ name = 'Days'        ; abr = 'd'  },
    [pscustomobject]@{ name = 'Hours'       ; abr = 'h'  },
    [pscustomobject]@{ name = 'Minutes'     ; abr = 'm'  },
    [pscustomobject]@{ name = 'Seconds'     ; abr = 's'  },
    [pscustomobject]@{ name = 'Milliseconds'; abr = 'ms' }
  )

  # For each property if not zero : add it to the stack
  $diffStack = @()
  foreach ($p in $timeProps) {
    $pName, $pAbr = $p.name, $p.abr
    if ($rawDiff.$pName -gt 0) { $diffStack += "$($rawDiff.$pName)$pAbr" }
  }

  return ($diffStack -join ', ')
}