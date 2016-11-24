﻿$MailSplat = @{
    To         = "mpugh@athenahealth.com"
    From       = "no-reply@athenahealth.com"
    Subject    = "Active Directory Operational Test"
    SMTPServer = "hub.corp.athenahealth.com"
    BodyAsHtml = $true
}

Import-Module \\opsadmin101\Scripts\Modules\Pester
Import-Module \\opsadmin101\Scripts\Modules\HTML.Automation

Set-Location -Path (Split-Path $MyInvocation.MyCommand.Path)
$Tests = Invoke-Pester -PassThru

$Failed = @($Tests | Select -ExpandProperty TestResult | Where Result -eq "Failed" | Sort Context,Name | Select @{Name="Test Name";Expression={ $_.Context }},Name,Result,Time | ConvertTo-Html -Fragment) # | Set-CellColor -Property Result -Color Red -Filter "Result -eq 'Failed'")
$Passed = $Tests | Select -ExpandProperty TestResult | Where Result -eq "Passed" | Sort Context,Name | Select @{Name="Test Name";Expression={ $_.Context }},Name,Result,Time | ConvertTo-Html -Fragment

$Summary = $Tests | Select @{Name="Tests Run";Expression={ $_.TotalCount }},
    @{Name="Passed";Expression={ $_.PassedCount }},
    @{Name="Failed";Expression={ $_.FailedCount }},
    @{Name="Skipped";Expression={ $_.SkippedCount }},
    @{Name="Run Time";Expression={ $_.Time }} | ConvertTo-Html -Fragment

If ($Failed.Count -gt 0)
{
    $Failed = $Failed -replace "<td>Failed</td>","<td style='background-color: red'>Failed</td>"
    $FailedHTML = @"
<div>Failed Tests</div>
$Failed
<br/>
<br/>
"@
}

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
<div>Summary</div>
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

Send-MailMessage -Body $HTML @MailSplat