#Get all of the domain controllers
$DCs = Get-ADDomainController -Filter * | Select -ExpandProperty Name #| Select -First 2

#Get TextInfo object to get the ToTitleCase method
$TextInfo = (Get-Culture).TextInfo

Describe "Active Directory Health Checks" {
    #Discovery Test
    Context "Domain Discovery" {
        $DC = Get-ADDomainController -Discover
        It "Found Domain Controller" {
            $DC | Should Not BeNullOrEmpty
        }
    }

    #Replication tests
    Context "Domain Replication" {
        $ReplErrors = Get-ADReplicationPartnerMetadata -Target * -Partition *
        It "Last Replication Result" {
            $ReplErrors | Measure-Object -Property LastReplicationResult -Sum | Select -ExpandProperty Sum | Should Be 0
        }
        It "Consecutive Replication Failures" {
            $ReplErrors | Measure-Object -Property ConsecutiveReplicationFailures -Sum | Select -ExpandProperty Sum | Should Be 0
        }
    }

    #DCDiag DNS Tests
    Context "DNS Diagnostics" {
        $DC = Get-ADDomainController -Discover
        $ResultFilePath = $DiagFile -f "DNS-$DC"
        $DCDiag = Dcdiag.exe /s:$DC /v /test:DNS | ForEach {
            Switch -RegEx ($_)
            {
                "passed test Connectivity"   { $TestName = $Null; $TestStatus = $Null; Break }
                "running (?<Zone>partition|enterprise) tests on : (?<PartTest>.*)" { 
                    $PartitionTest = "$($TextInfo.ToTitleCase($Matches.Zone))-$($Matches.PartTest): "
                    Break 
                }
	            "Starting"                   { $TestName = ($_ -Replace ".*Starting test: ").Trim(); Break }
	            "passed test"                { $TestStatus = "Passed"; Break }
                "failed test"                { $TestStatus = "Failed"; Break }
            }
            If ($TestName -ne $Null -And $TestStatus -ne $Null)
            {
                $Name = $PartitionTest + $TestName
                It $Name {
                        $TestStatus | Should Be "Passed"
                }
	            $TestName = $Null
                $TestStatus = $Null
            }
            Write-Output $_
        }
        $DCDiag | Out-File -FilePath $ResultFilePath
    }

    #Server tests
    ForEach ($DC in $DCs)
    {
        Context $DC {
            #SYSVOL Test
            $Disk = Get-CimInstance -ComputerName $DC -ClassName "Win32_LogicalDisk" -Filter "DriveType = 3 AND DeviceID = 'C:'"
            [int]$PercentFree = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100,0)
            It "SysVol Space" {
                $PercentFree | Should BeGreaterThan 24
            }

            #DCDiag Tests
            #Heavily modifed from https://gallery.technet.microsoft.com/scriptcenter/Parse-DCDIAG-with-ce430b71
            $ResultFilePath = $DiagFile -f $DC
            $DCDiag = Dcdiag.exe /s:$DC /v /skip:Replications /skip:kccevent /skip:dfsrevent /skip:systemlog | ForEach {
                Switch -RegEx ($_)
                {
	                "Starting"          { $TestName = ($_ -Replace ".*Starting test: ").Trim(); Break }
                    "running (?<Zone>partition|enterprise) tests on : (?<PartTest>.*)" { 
                        $PartitionTest = "$($TextInfo.ToTitleCase($Matches.Zone))-$($Matches.PartTest): "
                        Break 
                    }
	                "passed test"       { $TestStatus = "Passed"; Break }
                    "failed test"       { $TestStatus = "Failed"; Break }
                }
                If ($TestName -ne $Null -And $TestStatus -ne $Null)
                {
                    $Name = $PartitionTest + $TestName
                    It $Name {
                        $TestStatus | Should Be "Passed"
                    }
	                $TestName = $Null
                    $TestStatus = $Null
                }
                Write-Output $_
            }
            $DCDiag | Out-File -FilePath $ResultFilePath
        }
    }
}
