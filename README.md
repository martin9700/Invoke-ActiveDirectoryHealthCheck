# Invoke-ActiveDirectoryHealthCheck
Check health of Active Directory using Pester

# Requirements
1. You must have Pester installed
2. PowerShell 3.0 or higher
3. Must have Domain Admin privileges 
4. Firewalls on all of the DCs must allow PSRemoting
5. DC's must allow PSRemoting

# Modifications (Experimental)
1. Modify $MailSplat at beginning of script to reflect your environment (Need your From address and SMTP Relay)

