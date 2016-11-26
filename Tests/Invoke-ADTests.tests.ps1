#Get all of the domain controllers
$DCs = Get-ADDomainController -Filter * | Select -ExpandProperty Name | Select -First 2

Describe "Active Directory Health Checks" {
    #Discovery Test
    Context "Discovery" {
        $DC = Get-ADDomainController -Discover
        It "$($DC.Name)" {
            $DC | Should Not BeNullOrEmpty
        }
    }

    #Replication tests
    Context "Replication" {
        $ReplErrors = Get-ADReplicationPartnerMetadata -Target * -Partition *
        It "Last Replication Result" {
            $ReplErrors | Measure-Object -Property LastReplicationResult -Sum | Select -ExpandProperty Sum | Should Be 0
        }
        It "Consecutive Replication Failures" {
            $ReplErrors | Measure-Object -Property ConsecutiveReplicationFailures -Sum | Select -ExpandProperty Sum | Should Be 0
        }
    }

    #SYSVOL tests
    Context "SYSVOL Disk Space" {
        ForEach ($DC in $DCs)
        {
            $Disk = Get-CimInstance -ComputerName $DC -ClassName "Win32_LogicalDisk" -Filter "DriveType = 3 AND DeviceID = 'C:'"
            [int]$PercentFree = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100,0)
            It $DC {
                $PercentFree | Should BeGreaterThan 24
            }
        }
    }
}

#DCDiag tests
#Heavily modifed from https://gallery.technet.microsoft.com/scriptcenter/Parse-DCDIAG-with-ce430b71
ForEach ($DC in $DCs)
{
    Describe "DCDiag Tests for $DC" {
        $DCDiag = Dcdiag.exe /s:$DC /v /skip:Replications /skip:kccevent /skip:dfsrevent /skip:systemlog | ForEach {
            Switch -RegEx ($_)
            {
	            "Starting"          { $TestName = ($_ -Replace ".*Starting test: ").Trim(); Break }
	            "passed test"       { $TestStatus = "Passed"; Break }
                "failed test"       { $TestStatus = "Failed"; Break }
            }
            If ($TestName -ne $Null -And $TestStatus -ne $Null)
            {
                Context $TestName {
                    It $DC {
                        $TestStatus | Should Be "Passed"
                    }
                }
	            $TestName = $Null
                $TestStatus = $Null
            }
            Write-Output $_
        }
        $DCDiag | Out-File -FilePath $DiagFile
    }
    Describe "DCDiag DNS Tests for $DC" {
        $DCDiag = Dcdiag.exe /s:$DC /v /test:DNS | ForEach {
            Switch -RegEx ($_)
            {
                "passed test Connectivity"   { $TestName = $Null; $TestStatus = $Null; Break }
	            "Starting"                   { $TestName = ($_ -Replace ".*Starting test: ").Trim(); Break }
	            "passed test"                { $TestStatus = "Passed"; Break }
                "failed test"                { $TestStatus = "Failed"; Break }
            }
            If ($TestName -ne $Null -And $TestStatus -ne $Null)
            {
                Context $TestName {
                    It $DC {
                        $TestStatus | Should Be "Passed"
                    }
                }
	            $TestName = $Null
                $TestStatus = $Null
            }
            Write-Output $_
        }
        $DCDiag | Out-File -FilePath $DiagFile -Append
    }
}

