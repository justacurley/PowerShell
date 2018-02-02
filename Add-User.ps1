

Function Replicate-AD { 
    if (!($localcredentials)){$localcredentials=Get-Credential}
    $DC = 'domaincontrollers1','domaincontrollers2'
    foreach ($controller in $DC)
    { 
        $controller
        $x=0
        start-sleep -Seconds 10
        while ($x -lt 3)
        { 
            $x = $x+1
            write-host -ForegroundColor red $x
            Invoke-Command -ComputerName $controller -Credential $localcredentials -ScriptBlock { cmd /c "repadmin /syncall /AdeP" }
        
        }
    }
}
#Perform delta sync on azure active directory sync server
Function Sync-AD {
    if (!($localcredentials)){$localcredentials=Get-Credential}
    Invoke-Command -ComputerName hq-aadsync -Credential $localcredentials -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
}
#Connect to MSO
Function Connect-ExchangeOnline {
    $livecred=$o365adminCredentials 
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri 'https://outlook.office365.com/powershell-liveid/?proxymethod=rps' -Credential $LiveCred -Authentication Basic -AllowRedirection
    import-pssession $Session
}
Function Add-User
{
    [CmdletBinding()]
    param(
 
        # parameter options
        # validation
        # cast
        # name and default value
        
        [Parameter(
                Mandatory=$true,
                ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        #[System.Management.Automation.PSCustomObject]
        $User,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.CredentialAttribute()]
        $localCredentials,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.CredentialAttribute()]
        $o365adminCredentials
        
            
    )
    
    $OrgOrGov = $User.OrgorGov.ToLower() 
    $DOMAIN_CONTROLLER = 'DOMAINCONTROLLER'
    $EXCHANGE_SERVER = 'SMTP SERVER'
    
    ##Format some AD attribs
    $givenname = $user.givenname.Substring(0,1).ToUpper()+$user.givenname.Substring(1).ToLower()
    $surname = $user.surname.Substring(0,1).ToUpper()+$user.surname.Substring(1).ToLower()
    $samaccountname = $GivenName.Substring(0,1).ToLower()+$surname.ToLower()
    $displayname = $surname+', '+$givenname
    $userprincipalname = "$samaccountname@usip$OrgOrGov"
    $description = "This user will start on $($user.StartDate)"
    $title = $user.title
    $department = $user.department
    $manager = $user.manager
    $office = $user.HQLocation
    $worklocation = $user.WorkLocation
    $company = 'company'
    $remoteroutingaddress = "$samaccountname@COMPANY.mail.onmicrosoft.com"
    $OU = 'ou=staff,dc=usip,dc=local'
    
    $Relationship = $user.EmploymentStatus
    $ticket = $User.ticket
    $tick = "[TICK:"+$ticket+"]"
    $Extension = $User.ISExtension

    if ($User.phone -eq $null){"Remote"} else {$FullPhone = "555-555" + $User.Phone}
    $ipPhone = $User.Phone

    ##Clean start##
    Get-PSSession | Remove-PSSession

    ##Configure distribution groups
    switch ($Relationship){
        Contractor-PSC {
            write-host -ForegroundColor Cyan 'OK'
            $DefaultGroups = 'DFS_Redirect_Group','relationship_contractor','psc contractors'
        }
        Contractor-SOW {
            write-host -ForegroundColor Cyan 'OK'
            $DefaultGroups = 'DFS_Redirect_Group','relationship_contractor','contractors'
        }
        Employee {
            write-host -ForegroundColor Cyan 'OK'
            $DefaultGroups = 'DFS_Redirect_Group','relationship_employee','employees'
        }

        ## changed 3rd group from 'usip-contractors' to 'Research Assistants' AC 9/12/2017
        RA {
            write-host -ForegroundColor Cyan 'OK'
            $DefaultGroups = 'DFS_Redirect_Group','relationship_RA','RAS'
        } 
        Fellow {
            write-host -ForegroundColor Cyan 'OK'
            $DefaultGroups = 'DFS_Redirect_Group','relationship_fellow','contractors'
        }
        Default {
            Write-Host -ForegroundColor Red "$Relationship is not an acceptible value. Valid values are CONTRACTOR-PSC, CONTRACTOR-SOW, EMPLOYEE, RA, OR FELLOW"
            return  
        }   
    }

    #Configure office. If the hqoffice location = remote, then the work location will be the value of the office attrib
    switch ($office) {
    Remote { $office = $worklocation }
    Default { }
    }

    
    #Manager exists
    $tryManGN = $manager.split('@')[0]
    
        Write-Host -ForegroundColor Yellow 'Confirming manager exists in AD...'
    
    ### Had issue with timeout at 3 secounds so bumpped it up to 5
    Start-Sleep -Seconds 5
    if ($manager = Get-ADUser -Filter {SamAccountName -eq $tryManGN}){
        $manager = $manager.samaccountname
        Write-Host -ForegroundColor Cyan 'OK'
    }
    else { 
        Write-Host -ForegroundColor Red "Could not find a manager in AD with firstname $tryManGN lastname $tryManSN. Exiting"
        return
    }

    
    #Staff directory
    if ($user.StaffDirectory -eq 'Yes'){
        $DefaultGroups = $DefaultGroups+'StaffDirectory'
    }
    Start-Sleep -Seconds 3

   # Print out attrib values to confirm write
        Write-Host -ForegroundColor White 'Firstname.............' -NoNewline 
        Write-Host -ForegroundColor Cyan $givenname
        Write-Host -ForegroundColor White 'Lastname..............' -NoNewline 
        Write-Host -ForegroundColor Cyan $surname
        Write-Host -ForegroundColor White 'Displayname...........' -NoNewline 
        Write-Host -ForegroundColor Cyan $displayname
        Write-Host -ForegroundColor White 'SamAccountName........' -NoNewline
        Write-Host -ForegroundColor Cyan $samaccountname
        Write-Host -ForegroundColor White 'UserPrincipalName.....' -NoNewline
        Write-Host -ForegroundColor Cyan $userprincipalname
        Write-Host -ForegroundColor White 'Employment Status.....' -NoNewLine
        Write-Host -ForegroundColor Cyan $Relationship
        Write-Host -ForegroundColor White 'Title.................' -NoNewline
        Write-Host -ForegroundColor Cyan $title
        Write-Host -ForegroundColor White 'Manager...............' -NoNewline
        Write-Host -ForegroundColor Cyan $manager
        Write-Host -ForegroundColor White 'Office................' -NoNewline
        Write-Host -ForegroundColor Cyan $office
        Write-Host -ForegroundColor White 'Department............' -NoNewline
        Write-Host -ForegroundColor Cyan $department
        Write-Host -ForegroundColor White 'Company...............' -NoNewline
        Write-Host -ForegroundColor Cyan $company
        Write-Host -ForegroundColor White 'Default Groups........' -NoNewline
        Write-Host -ForegroundColor Cyan $DefaultGroups
        Write-Host -ForegroundColor White 'Org Unit..............' -NoNewline
        Write-Host -ForegroundColor Cyan $OU
        Write-Host -ForegroundColor White 'Phone.................' -NoNewline
        Write-Host -ForegroundColor Cyan $FullPhone
        Write-Host -ForegroundColor White 'IP Phone..............' -NoNewline
        Write-Host -ForegroundColor Cyan $ipPhone
        Write-Host -ForegroundColor White 'Ticket................' -NoNewline
        Write-Host -ForegroundColor Cyan $tick     
        Write-Host -ForegroundColor White 'Name................. ' -NoNewline
        Write-Host -ForegroundColor Cyan $givenname $surname `@ $ipPhone
        Write-Host -ForegroundColor White 'IS Extension......... ' -NoNewline
        Write-Host -ForegroundColor Cyan $Extension



    #Confirm before writing
        Write-Host -ForegroundColor Yellow 'Type N if any of the above information is incorrect. Type Y to continue'
    $confirm  = Read-Host 'Y/N'
    if ($confirm -ne 'Y')
    {return}
    else {
        Write-Host -ForegroundColor Cyan 'OK'
        Write-Host -ForegroundColor Cyan '.........................................'
        Write-Host -ForegroundColor Cyan '.........................................'
        Write-Host -ForegroundColor Cyan '.........................................'
        Write-Host -ForegroundColor Cyan '.........................................'
        Write-Host -ForegroundColor Cyan '.........................................'
        Write-Host -ForegroundColor Cyan '.........................................'

        #Create AD Object
        #Add to groups
        #Enable Remote Mailbox
        Write-Host -ForegroundColor Cyan 'Trying to create account...'
        try { 
            New-ADUser -GivenName $givenname -Surname $surname -SamAccountName $samaccountname `
            -UserPrincipalName $userprincipalname -DisplayName $displayname -Name $displayname `
            -Manager $manager -Office $office -Department $department -Description $description `
            -path $OU -AccountPassword (ConvertTo-SecureString -AsPlainText 'TempPass1' -Force) `
            -Enabled $true -EmailAddress $userprincipalname -Company $company -Title $title `
            -OfficePhone $FullPhone -Server $DOMAIN_CONTROLLER -Credential $localCredentials -Confirm 
           

            Write-Host -ForegroundColor Cyan 'OK'
            Write-Host -ForegroundColor Cyan 'User account has been created on DC2COLO. Go make edits if necessary.'
            pause
        }
        catch {
            $_.Exception.Message
            $_.Exception.ItemName
            break
        }

        #Add user to distribution groups
        try {
            Write-Host -ForegroundColor Cyan 'Trying to add user to default groups...'
            $DefaultGroups | % {Add-ADGroupMember -Identity $_ -Members $samaccountname -Server $DOMAIN_CONTROLLER -Credential $localCredentials -Verbose}
            Write-Host -ForegroundColor Cyan 'OK'
        }
        catch{
            Write-Host -ForegroundColor Red "Something went wrong adding the user to groups, you may need to manually add them."
            $_.Exception.Message
            $_.Exception.ItemName
        }
        #Add AD attributes to enable the user object as a remote mailbox in o365
            Write-Host -ForegroundColor Cyan 'Trying to enable Remote Mailbox...'

        try {
            $so = New-PSSessionOption -SkipCACheck:$true -SkipCNCheck:$true -SkipRevocationCheck:$true
            $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$EXCHANGE_SERVER/powershell/ -Credential $localCredentials -SessionOption $so
            Import-PSSession $Session
            Enable-RemoteMailbox -Identity $samaccountname -RemoteRoutingAddress $remoteroutingaddress | Out-Null
            Get-PSSession | Remove-PSSession
            Start-Sleep -Seconds 5
            Write-Host -ForegroundColor Cyan 'OK'
        }
        catch {
            $_.Exception.Message
            $_.Exception.ItemName
            break
        }
      
        #Replicate AD and Sync to o365
      
        #Write-Host -ForegroundColor Cyan 'User is ready to be synced to office 365. Double check everything is in place before continuing.'
        #Pause

            Write-Host -ForegroundColor Cyan 'Replicating Active Directory'
        Replicate-AD | Out-Null
            Write-Host -ForegroundColor Cyan 'OK'
            Write-Host
        start-sleep -Seconds 5
            Write-Host -ForegroundColor Cyan 'Syncing to office 365...'
        Sync-AD #| Out-Null
            Write-Host -ForegroundColor Cyan 'OK'
            Write-Host
        
        #Wait for user to appear in o365
            Write-Host -ForegroundColor Cyan 'Trying to connect to MSOnline...'
        Connect-MsolService -Credential $o365adminCredentials
            Write-Host -ForegroundColor Cyan 'OK'
            Write-Host -ForegroundColor Cyan 'It will take a few minutes for the user to appear in O365...'
        Start-Sleep -Seconds 180
        do {
            Get-MsolUser -UserPrincipalName $userprincipalname -ErrorAction SilentlyContinue
        }
        while (!(Get-MsolUser -UserPrincipalName $userprincipalname -ErrorAction SilentlyContinue))
            Write-Host -ForegroundColor Cyan 'OK'
      

            Write-Host -ForegroundColor Cyan '.........................................'
            Write-Host -ForegroundColor Cyan '.........................................'
            Write-Host -ForegroundColor Cyan '.........................................'
            Write-Host -ForegroundColor Cyan '.........................................'
            Write-Host -ForegroundColor Cyan '.........................................'
            Write-Host -ForegroundColor Cyan '.........................................'
        

        #Set usage location
            Write-Host -ForegroundColor Cyan 'Setting up licensing'
            Write-Host -ForegroundColor Cyan 'Trying to set usage location to US...'
        Start-Sleep -Seconds 3
        Set-MsolUser -UserPrincipalName $userprincipalname -UsageLocation 'US'
        if ((Get-MsolUser -UserPrincipalName $userprincipalname | select -exp usagelocation) -eq 'US') {
            Write-Host -ForegroundColor Cyan 'OK'
        }
        else {
            Write-Host -ForegroundColor Red 'Could not set Usage Location. License the user manually.'
            return
        }
        Write-Host
        
        #Licensing. Do not enable Enterprise pack RMS, because we are using intune RMS
            Write-Host -ForegroundColor Cyan 'Trying to set o365 license...'
        start-sleep -Seconds 3
        $365SKU = New-MsolLicenseOptions -AccountSkuId :ENTERPRISEPACK_GOV -DisabledPlans RMS_S_ENTERPRISE_GOV 
        Set-MsolUserLicense -UserPrincipalName $userprincipalname -LicenseOptions $365SKU -AddLicenses :ENTERPRISEPACK_GOV
        Set-MsolUserLicense -UserPrincipalName $userprincipalname -AddLicenses usip:EMS
        $licensestatus = Get-MsolUser -UserPrincipalName $userprincipalname
        if ( ($licensestatus.Licenses[0]) -and ($licensestatus.Licenses[1]) )
        {
            Write-Host -ForegroundColor Cyan 'OK'
            Write-Host -ForegroundColor Cyan 'Successfully applied the following licenses'
            Write-Output $licensestatus.Licenses[0].ServiceStatus
            Write-Output $licensestatus.Licenses[1].ServiceStatus
        } 
        else {
            Write-Host -ForegroundColor Red 'Failed to set licenses. License the user manually.'
        return
        }
       
       #Wait for mailbox to be created and then enable litigation hold
           Write-Host 
           Write-Host -ForegroundColor Cyan 'It will take a few minutes for the mailbox to be created...'
           Write-Host -ForegroundColor Cyan 'Removing any PSRemoting sessions opens'
       Start-Sleep -Seconds 3
       Get-PSSession | Remove-PSSession
           Write-Host -ForegroundColor Cyan 'OK'
           Write-Host
           Write-Host -ForegroundColor Cyan 'Connecting to Exchange Online with provided o365 admin credentials...'
       Connect-ExchangeOnline | out-null
       if ( (Get-PSSession).ConfigurationName -eq 'Microsoft.Exchange' ){
            Write-Host -ForegroundColor Cyan 'OK'
       }
       else {
            Write-Host -ForegroundColor Red 'Failed to connect to Exchange Online. Exiting'
       return
       }
           Write-Host
           Write-Host -ForegroundColor Cyan 'It will take a few minutes for the mailbox to be created...'
        do {
            Get-Mailbox -Identity $userprincipalname -ErrorAction SilentlyContinue
        }
        while (!(Get-Mailbox -Identity $userprincipalname -ErrorAction SilentlyContinue))
            Write-Host -ForegroundColor Cyan 'OK'

        ## configure IP Phone number
            Write-Host -ForegroundColor Cyan 'Configuring IP Phone'
        Start-Sleep -Seconds 1
            If ($Extension -eq 'No'){ 
                Write-Host 'No IP phone to add.' -ForegroundColor Yellow
                }
            else{
                start-Sleep -Seconds 1
                Get-ADUser -Identity $samaccountname -Server $DOMAIN_CONTROLLER 
                Set-ADUser -Identity $samaccountname -Replace @{ipPhone = "$ipPhone"}
                }

            Write-Host -ForegroundColor Cyan 'Tying to enabled litigation hold...'
        Set-Mailbox -Identity $userprincipalname -LitigationHoldEnabled $true | out-null
            if ((get-mailbox -Identity $userprincipalname).litigationholdenabled -eq $true){
            Write-Host -ForegroundColor Cyan 'OK'
            }

        ## Send email to close the ticket in Kace
            if($tick -eq $null){$tick = Read-Host -Prompt "Please enter ticket number..."
            }
            
            Send-MailMessage -To Helpdesk@DOMAIN.org -SmtpServer $EXCHANGE_SERVER -Subject $tick -Credential $o365adminCredentials -From helpdesk@DOMAIN.org -Body `
            "@status=closed 
             @owner=acurley 
             @resolution=Account Created
            "
            
            Write-Host -ForegroundColor Green 'User Created... If a ticket number was provided it has been closed.'
    }   
 


}