
Function ConvertTo-SharedMailbox 
<#PSScriptInfo
        .Synopsis
        Converts user mailbox to shared in hybrid exchange environment
        .Description
        Connects to Exch Online and MsolService. Set mailbox to Shared and SendAsCopy, remove licenses, update AD attributes
        .Example
        Test
        ConvertTo-SharedMailbox -UPN test@contoso.com -users user1,user2 -localcredentials (get-credential -message 'on prem domain admin') -o365adminCredentials (get-credential -message 'o365 admin')
        Write
        ConvertTo-SharedMailbox -UPN test@contoso.com -users user1,user2 -localcredentials (get-credential -message 'on prem domain admin') -o365adminCredentials (get-credential -message 'o365 admin') -W $true
        .Author
        Alex Curley 
        .Version
        1.0
        .GUID
        60894b04-326e-4760-9866-fecd6b917f36
                   
#>
{
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $UPN,
        [parameter(mandatory=$false)]
        [system.string[]]
        $Users,
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
    
    #Check users
    if ($Users){
        Write-Host -ForegroundColor Cyan "Checking if users exist in AD"
        foreach ($user in $users){
            try{
                get-aduser -Identity $user | out-null
                Write-Host -ForegroundColor Cyan "Found" -NoNewLine
                Write-Host -ForegroundColor White " $User"
            }
            catch {
                Write-Host -ForegroundColor Red "Could not find $user. Exiting"
                return;
            }
        }
    }
    
    #Connect Exchange Online
    Function Connect-ExchangeOnline {
        Write-Host -ForegroundColor Magenta "Attempting to connect to Exchange Online"
        $EOSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/?proxymethod=rps' -Credential $o365AdminCredentials -Authentication Basic -AllowRedirection
        Import-PSSession $EOSession -AllowClobber -DisableNameChecking
    } 
    try { 
        Connect-ExchangeOnline | Out-Null
        Write-Host -ForegroundColor Cyan 'OK'
    }
    catch {
        Write-Host -ForegroundColor Red 'Could not connect to Exchange Online. Exiting.'
        return;
    }
    
    #Connect to MSOnline to remove licenses
    Write-Host -ForegroundColor Magenta 'Attempting to connecto to MsolService'
    
    try { 
        Connect-MsolService -Credential $o365adminCredentials -ErrorAction Stop
        Write-Host -ForegroundColor Cyan 'OK'
    }
    catch {
        Write-Host -ForegroundColor Red 'Could not connect to MsolService. Exiting.'
        Write-Error -Message "$_" -ErrorAction Stop
        return;
    }
      
    #License packs to remove
    $ENT = 'DOMAIN:SKU'
    $EMS = 'DOMAIN:SKU'
    
    #Domain Controller
    $DC = 'YOURDC'
    
    #OU to move ad user to
    $OU = 'YOUROU'

    #Dry Run- Set-Mailbox to shared and messagecopy for sendas, Set-ADUser properties to match shared mailbox, Disable AD object, Move-ADObject to shared mailbox OU, Remove Licenses, and add FullAccess/SendAs permissions
    if (!($w)){          
        $SAM = ($upn -split '@')[0]
        
        Set-Mailbox -Identity $upn -Type Shared -MessageCopyForSendOnBehalfEnabled $true -WhatIf -Verbose
        
        Set-ADUser -Identity $SAM -Replace @{msExchRemoteRecipientType=100; msExchRecipientTypeDetails=34359738368} -Server $DC -WhatIf -Verbose            
        
        Disable-ADAccount -Identity $SAM -Server $DC -WhatIf -Verbose            
        
        $GUID = Get-ADUser -Identity $SAM -Properties ObjectGUID | Select-Object -ExpandProperty ObjectGUID
        $MOVE = Move-ADObject -Identity $GUID -TargetPath $OU -WhatIf -Verbose
        Invoke-Command -Credential $localCredentials -ComputerName $DC -ArgumentList $GUID -ScriptBlock { $MOVE }            
        
        Write-Output   "Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $ENT"
        Write-Output   "Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $EMS"
        
        if ($Users){
            foreach ($User in $Users){
                Write-Host -ForegroundColor Cyan "Assigning $user FullAccess and SendAs rights on $Alias"                
                Add-MailboxPermission -Identity $upn -AccessRights FullAccess -User $user -Confirm:$false -whatif 
                Add-RecipientPermission -Identity $upn -AccessRights SendAs -Trustee $user -Confirm:$false  -whatif         
            }
        }
        #Disconnect from EOL  
        Get-PSSession | Remove-PSSession -Verbose
    } 
    

    #Wet/write run
    else {
        
        $SAM = ($upn -split '@')[0]            
        Write-Host -ForegroundColor Cyan "Setting mailbox type to Shared for" -NoNewline
        Write-Host "$upn" 

        
        Set-Mailbox -Identity $upn -Type Shared -MessageCopyForSendOnBehalfEnabled $true -Verbose
            
        Write-Host -ForegroundColor Cyan "Setting msExchRemoteRecipientType  to" -NoNewline
        Write-Host " 100" 
        Write-Host -ForegroundColor Cyan "Setting msExchRecipientTypeDetails to" -NoNewline
        Write-Host " 34359738368" 
        
        
        Set-ADUser $sam -Replace @{msExchRemoteRecipientType=100; msExchRecipientTypeDetails=34359738368} -Server $DC

        Write-Host -ForegroundColor Cyan "Setting AD Object to" -NoNewline
        Write-Host " Disabled"       
        Disable-ADAccount -Identity $sam -Server $DC

        Write-Host -ForegroundColor Cyan "Moving AD Object to shared mailbox OU" -NoNewline
        Write-Host " Standalone Email Accounts"              
        $GUID = Get-ADUser -Identity $sam -Properties ObjectGUID | Select-Object -ExpandProperty ObjectGUID
        $MOVE = Move-ADObject -Identity $GUID -TargetPath $OU 
        Invoke-Command -Credential $localCredentials -ComputerName $DC -ArgumentList $GUID -ScriptBlock { $MOVE }

        
        Write-Host -ForegroundColor Cyan "Removing Enterprise licenses..."
        Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $ENT
        Write-Host -ForegroundColor Cyan "Removing EMS licenses..."
        Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $EMS
            
        
        if ($Users){
            foreach ($User in $Users){
                Write-Host -ForegroundColor Cyan "Assigning $user FullAccess and SendAs rights on $Alias"
                Add-MailboxPermission -Identity $upn -AccessRights FullAccess -User $user -Confirm:$false 
                Add-RecipientPermission -Identity $upn -AccessRights SendAs -Trustee $user -Confirm:$false                              
            }
        }

        #Disconnect from EOL  
        Get-PSSession | Remove-PSSession -Verbose
    }
}


