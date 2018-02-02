#Offboard a user. 
#Set-Mailbox to shared, Set-ADUser properties to match shared mailbox and hide from GAL, Move-ADObject to shared mailbox OU, Disable-ADAccount, remove from groups, Backup attributes
Function ConvertTo-SharedMailbox 
{
    [CmdletBinding()]
    param(
 
       
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $UPN,
                
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $DC,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.CredentialAttribute()]
        $localCredentials,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.CredentialAttribute()]
        $o365adminCredentials,

        [Parameter(Mandatory=$false)]
        [System.String]
        $W
    )

    #Connect to Exchange Online
    $exchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/?proxymethod=rps' -Credential $o365adminCredentials -Authentication Basic -AllowRedirection
    
    #Connect to MSOnline to remove licenses
    Connect-MsolService -Credential $o365adminCredentials
    $ENT = 'ENTERPRISEPACK_GOV'
    $EMS = 'EMS'
    #Dry Run- Set-Mailbox to shared, Set-ADUser properties to match shared mailbox and hide from GAL, Move-ADObject to shared mailbox OU, Disable-ADAccount, remove from groups
    if (!($w)){
        ForEach ($USR in $UPN){    
            $SAM = ($USR -split '@')[0]
            Invoke-Command -Session $exchangeSession -ArgumentList $usr -ScriptBlock {Set-Mailbox -Identity $args[0] -Type Shared -WhatIf -Verbose}
            Write-Output   "Set-MsolUserLicense -UserPrincipalName $USR -RemoveLicenses $license"
            Set-ADUser -Identity $SAM -Replace @{msExchRemoteRecipientType=100; msExchRecipientTypeDetails=34359738368; msExchHideFromAddressLists='TRUE'} -Server $DC -Credential $localCredentials -WhatIf -Verbose
            Disable-ADAccount -Identity $SAM -Server $DC -Credential $localCredentials -WhatIf -Verbose
            $GUID = Get-ADUser -Identity $SAM -Properties ObjectGUID -Credential $localCredentials | Select-Object -ExpandProperty ObjectGUID
            $MOVE = Move-ADObject -Identity $GUID -TargetPath 'OU=Stand Alone Email Accounts,OU=Exchange,DC=usip,DC=local' -Credential $localCredentials -WhatIf -Verbose
            Invoke-Command -Credential $localCredentials -ComputerName $DC -ArgumentList $GUID -ScriptBlock { $MOVE }
            Get-ADUser -Identity $SAM -Properties memberof -Credential $localCredentials | select -ExpandProperty memberof | % {Remove-ADGroupMember -Identity $_ -Members $SAM -Server $DC -Credential $localCredentials -WhatIf -Verbose}
            #Disconnect from EOL  
        } Remove-PSSession $exchangeSession
    }

    #Wet Run
    else {
        ForEach ($USR in $UPN){ 
            $SAM = ($USR -split '@')[0]
            Write-Host -ForegroundColor Cyan "Setting mailbox type to Shared for    " -NoNewline
            Write-Host "$USR" 

            Invoke-Command -Session $exchangeSession -ArgumentList $usr -ScriptBlock {Set-Mailbox -Identity $args[0] -Type Shared }
            Write-Host -ForegroundColor Cyan "Removing enterprise licenses..."
            Set-MsolUserLicense -UserPrincipalName $USR -RemoveLicenses $ENT
            Write-Host -ForegroundColor Cyan "Removing EMS licenses..."
            Set-MsolUserLicense -UserPrincipalName $USR -RemoveLicenses $EMS
            Write-Host -ForegroundColor Cyan "Setting msExchRemoteRecipientType  to" -NoNewline
            Write-Host " 100" 
            Write-Host -ForegroundColor Cyan "Setting msExchRecipientTypeDetails to" -NoNewline
            Write-Host " 34359738368" 
            Write-Host -ForegroundColor Cyan "Setting msExchHideFromAddressLists to" -NoNewline
            Write-Host " TRUE"

            Set-ADUser ($USR -split '@')[0] -Replace @{msExchRemoteRecipientType=100; msExchRecipientTypeDetails=34359738368; msExchHideFromAddressLists='TRUE'} -Server $DC -Credential $localCredentials

            Write-Host -ForegroundColor Cyan "Setting AD Object to" -NoNewline
            Write-Host " Disabled"

            Disable-ADAccount -Identity ($USR -split '@')[0] -Server $DC -Credential $localCredentials

            Write-Host -ForegroundColor Cyan "Moving AD Object to shared mailbox OU" -NoNewline
            Write-Host " Offboarded Mailboxes"

            $GUID = Get-ADUser -Identity ($USR -split '@')[0] -Properties ObjectGUID -Credential $localCredentials | Select-Object -ExpandProperty ObjectGUID
            $MOVE = Move-ADObject -Identity $GUID -TargetPath 'ou=offboardedmailboxes,OU=Stand Alone Email Accounts,OU=Exchange,DC=usip,DC=local' -Credential $localCredentials
            Invoke-Command -Credential $localCredentials -ComputerName $DC -ArgumentList $GUID -ScriptBlock { $MOVE }

            
            Get-ADUser -Identity $SAM -Properties *  -Credential $localCredentials | Export-Clixml -Path "C:\users\$env:USERNAME\$sam.xml"
            Get-ADUser -Identity $SAM -Properties memberof -Credential $localCredentials | select -ExpandProperty memberof | % {Remove-ADGroupMember -Identity $_ -Members $SAM -Credential $localCredentials -Server $DC -Confirm:$false -Verbose}

            #Disconnect from EOL  
        } Remove-PSSession $exchangeSession
    }
}


