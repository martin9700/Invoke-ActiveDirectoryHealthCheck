<#
.SYNOPSIS
    Run Replication and DCDiag test on Active Directory and test using the Pester framework
.DESCRIPTION
    Run Replication and DCDiag test on Active Directory and test using the Pester framework

    Tests include replication backlog, standard and DNS DCDiag tests.  DCDiag logs are kept, by default for 12
    months, but you can change that using the $KeepLogs parameter.  

    Email: you can also have the report emailed to you, but you will need to edit the script and change the
    $MailSplat settings to match your environment.

.PARAMETER To
    Email address you would like to send the report to.
.PARAMETER KeepLogs
    How many months you want the DCDiag logs to be kept.
.INPUTS
    None
.OUTPUTS
    None
.EXAMPLE
    .\Invoke-ADOPTest.ps1

.EXAMPLE
    .\Invoke-ADOPTest.ps1 -To noone@yourcompany.com -KeepLogs 24

    Send the report to noone@yourcompany.com and keep the logs for 24 months

.NOTES
    Author:             Martin Pugh
      
    Changelog:
        11/24/16        MLP - Initial Release
        11/29/16        MLP - Added comment based help.  Using PSRemoting to run DCDiag on the domain
                              controller (required for a clean run).  Added parameters.  Renamed to
                              ADOPTest.  Changed Import-Module to import locally, so Pester must be pre-
                              installed.  Added Transcript logging.

#>
[CmdletBinding()]
Param (
    [string[]]$To,
    [int]$KeepLogs = 12
)

$MailSplat = @{
    To         = $To
    BodyAsHtml = $true
}

Import-Module Pester -ErrorAction Stop

#Logging but without verbose preference "Continue"
$LogPath = Join-Path -Path (Split-Path $MyInvocation.MyCommand.Path) -ChildPath "Logs"
If (-not (Test-Path $LogPath))
{
    New-Item $LogPath -ItemType Directory | Out-Null
}
Get-ChildItem "$LogPath\*.log" | Where LastWriteTime -LT (Get-Date).AddDays(-15) | Remove-Item -Confirm:$false
$LogPathName = Join-Path -Path $LogPath -ChildPath "$($MyInvocation.MyCommand.Name)-$(Get-Date -Format 'MM-dd-yyyy').log"
Start-Transcript $LogPathName -Append


#Clean out old DCDiag Reports
$DiagPath = Join-Path -Path (Split-Path $Script:MyInvocation.MyCommand.Path) -ChildPath "Diag Reports"
If (-not (Test-Path $DiagPath))
{
    New-Item -Path $DiagPath -ItemType Directory | Out-Null
}
Get-ChildItem -Path $DiagPath\*.log | Where LastWriteTime -lt (Get-Date).AddMonths(-$KeepLogs) | Remove-Item -Force -Confirm:$false

#Define log path
$DiagFile = Join-Path -Path $DiagPath -ChildPath "DCDiag-{0}-$(Get-Date -Format 'MM-dd-yyyy').log"

#Invoke Pester - see .\Tests\Invoke-ADTests.tests.ps1
$Tests = Invoke-Pester -PassThru

#Process results and create report
$Failed = @($Tests | Select -ExpandProperty TestResult | Where Result -eq "Failed")
$Passed = $Tests | Select -ExpandProperty TestResult | Where Result -eq "Passed" | Sort Name,Context | Select @{Name="Test Name";Expression={ $_.Name }},Context,Result,Time | ConvertTo-Html -Fragment

$Summary = $Tests | Select @{Name="Tests Run";Expression={ $_.TotalCount }},
    @{Name="Passed";Expression={ $_.PassedCount }},
    @{Name="Failed";Expression={ $_.FailedCount }},
    @{Name="Skipped";Expression={ $_.SkippedCount }},
    @{Name="Run Time";Expression={ $_.Time }} | ConvertTo-Html -Fragment

If ($Failed.Count -gt 0)
{
    $Failed = $Failed | Sort Name,Context | Select @{Name="Test Name";Expression={ $_.Name }},Context,Result,Time | ConvertTo-Html -Fragment
    $Failed = $Failed -replace "<td>Failed</td>","<td style='background-color: red'>Failed</td>"
    $FailedHTML = @"
<div>Failed Tests</div>
$Failed
<br/>
<br/>
"@
}

$DomainName = Get-ADDomain | Select -ExpandProperty NetBIOSName
$HTML = @"
<html>
<header>
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TR:Hover TD {Background-Color: #C1D5F8;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #514a79;color: white;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;width: 5%; vertical-align: top}
.trodd {background-color: #BDB9B9;}
.treven {background-color: white;}
DIV { background-color: #c2b5c7; color: black; font-size: 150%; font-weight: bold; border-style: solid; border-color: black; border-width: 1px;}
</style> 
<title>
Active Directory Operational Test
</title>
</header>
<body>
<p>
<h1>Active Directory Operational Test</h1>
<br/>
<div>$DomainName Summary</div>
$Summary
<br/>
<br/>
$FailedHTML
<div>Successful Tests</div>
$Passed
<br/><br/><h5>Run Date: $(Get-Date)</h5></p>
"@

$HTMLPath = Join-Path -Path (Split-Path $MyInvocation.MyCommand.Path) -ChildPath "ADOpTest.html"
$HTML | Out-File $HTMLPath -Encoding ascii

#Send email if desired
If ($To)
{
    Send-MailMessage -Body $HTML -Subject "Active Directory Operational Test for $DomainName" @MailSplat
}
