function Backup-ODFBData {
 
    <#
            .SYNOPSIS
            Copies OneDrive for Business data from one user to another in the cloud. Requires Sharegate module
 
            .DESCRIPTION
            Given a designated o365 backup account, copy all files from backup source to destination, generate a log, and e-mail as attachment.
            A lot going on here, this is a bit hacky, but I didn't have any other reliable way of ensuring departing users OneDrive files would be backed up
            without syncing them locally.
 
            .PARAMETER  BackupUser
            The o365 account used as backup destination-Use UserPrincipalName
 
            .PARAMETER  UsertoBackup
            The o365 account used as source.-Use UserPrincipalName

            .PARAMETER $domain
            Your $domain domain (i.e. contoso-admin.sharepoint.com)
  
            .OUTPUTS
            Export-CSV to Send-MailMessage
 
            .NOTES
            Requires Sharegate PS Module
            20150811 - As of today, no one has created a cmdlet to create Document Libraries in a ODFB site, so it must be done manually.

            .LINKS
            http://sharegate.com
 

    #>
 
    [CmdletBinding()]
    param(
 
        # parameter options
        # validation
        # cast
        # name and default value
 
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $BackupUser="bup01@$domain.onmicrosoft.com",

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $UserToBackup,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $domain,

        [System.Management.Automation.CredentialAttribute()]
        $o365AdminCredential,

        [System.Management.Automation.CredentialAttribute()]
        $o365BackupUserCredential

              
    )# param end
    
    
 
    #Functions
    
    #Add BackupUser as sitecollectionadmin to source onedrive site
    function Add-OneDrivePermissions ($UserToBackup,$BackupUser, $SPOUrl, $domain, $o365AdminCredential) 
    {
        write-host -ForegroundColor Green "Connecting to $domain-ADMIN.SHAREPOINT.COM"
        Connect-SPOService -Url $SPOUrl -Credential $o365AdminCredential -Verbose
        $usertobackup = $usertobackup.Replace('@','_').replace('.','_')
        $Site = Get-SPOSite -Identity "https://$domain-my.sharepoint.com/personal/$usertobackup" -Verbose
        write-host -ForegroundColor Green "Connecting to ODFB site for $usertobackup"
        if ($site)
        { 
            write-host -ForegroundColor Green "Setting permissions"
            Set-SPOUser -Site $Site.URL -LoginName $backupuser -IsSiteCollectionAdmin $true -Verbose
        }
        else
        {
            Throw "Could not connect to site"
        }
    }
    #Check if OneDrive site exists
    function Get-OneDrive ($user,$credential)
    {
        $site = connect-site -Url ("https://$domain-my.sharepoint.com/personal/"+$user.replace('@','_').replace('.','_')) -Credential $credential 
        $site.Description -ne ""
    }

    #Create a new subsite for 
    Function New-Subsite ($bup01Credentials,$name)
    {
        $name = $name.ToUpper()
        #Add references to SharePoint client assemblies and authenticate to Office 365 site
        Add-Type -Path "C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.dll"
        Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Publishing.dll"
        Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"

        #Parent site and credentials
        $Site = "https://$domain-my.sharepoint.com/personal/bup01_$domain_onmicrosoft_com"
        $Context = New-Object Microsoft.SharePoint.Client.ClientContext($Site)
        $Creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($bup01Credentials.UserName,$bup01Credentials.Password)
        $Context.Credentials = $Creds

        #Create SubSite
        $WCI = New-Object Microsoft.SharePoint.Client.WebCreationInformation
        $WCI.WebTemplate = "BDR#0"
        $WCI.Description = "$name ODFB backup. This site should remain read-only to users"
        $WCI.Title = "$name"
        $WCI.Url = "$name"
        $WCI.Language = "1033"
        $SubWeb = $Context.Web.Webs.Add($WCI)
        try {  $Context.ExecuteQuery()}
        catch { Write-Host -ForegroundColor RED "Could not create subsite $name, it probably already exists"   
        Continue   
         }
    }


    #Modules
    #--------------------------------------------------#
    Import-Module Microsoft.Online.Sharepoint.Powershell -DisableNameChecking
    Import-Module Sharegate

    #Variables
    #--------------------------------------------------#
    
    $SPOUrl = "https://$domain-admin.sharepoint.com/"
    $ResultPath = '\\FS01\Logs_Reports\ODFBBackup'
    $SMTP = "mailserver"
    $DeltaSyncUsers = @()
   
    #Main Function
    #--------------------------------------------------#
    Foreach ($user in $UserToBackup)
    { 
    Write-Host -ForegroundColor Cyan "Starting backup process for $user"

        $Date = get-date -Format MMddyyyy-hhmm
        #Confirm user has a ODFB site before attempting to set permissions
        if ((Get-OneDrive -user $user -credential $o365AdminCredential) -eq $true)
        { 
            write-host -ForegroundColor Cyan "Found OneDrive site for $user"
            #Add backupuser as site collection admin on usertobackup ODFB site
            Add-OneDrivePermissions -UserToBackup $User -BackupUser $BackupUser -SPOUrl $SPOUrl -domain '$domain' -o365AdminCredential $o365AdminCredential
            #Connect to SPO Sites and Lists
            #Connect to ODFB for user to be backed up
            $SourceSite = Connect-Site -URL ("https://$domain-my.sharepoint.com/personal/"+$user.replace('@','_').replace('.','_')) -Credential $o365BackupUserCredential -ErrorVariable SSE
            #Get Documents folder from SourceSite
            $SourceList = Get-List -Site $SourceSite -Name Documents -ErrorVariable SLE
            #Create the ODFB backup site for the user
            write-host -ForegroundColor Cyan "Created ODFB subsite for $user"
            New-Subsite -bup01Credentials $o365BackupUserCredential -name ($user.split('@')[0])
            
            #Connect to ODFB site for backup destination 
            #THE NAME OF THIS SUBSITE MUST MATCH THE SAMACCOUNTNAME OF THE USER BEING BACKED UP
            #("https://$domain-my.sharepoint.com/personal/"+$BackupUser.replace('@','_').replace('.','_')+"/"+$user.Split('@')[0])
            $DestSite   = Connect-Site -URL ("https://$domain-my.sharepoint.com/personal/"+$BackupUser.replace('@','_').replace('.','_')+"/"+$user.Split('@')[0]) -Credential $o365BackupUserCredential -ErrorVariable DSE
            #Get Documents folder from DestSite
            $DestList   = Get-List -Site $DestSite -Name Documents -ErrorVariable DLE
        
            #If sharegate was able to connect to everything, proceed    
            if ($SourceSite -and $SourceList -and $DestSite -and $DestList)
            {
            
                #Display info
                Write-Host "Source:"$SourceList.Site
                Write-Host "Destination:"$DestList.Site
                #Write-Output $SourceList,$DestList
                #Copy content
                write-host -ForegroundColor Cyan "Copying Content..."
                $result = Copy-Content -SourceList $SourceList -DestinationList $DestList 
                write-host -ForegroundColor Green "Done"
                #Export the report
                write-host -ForegroundColor Cyan "Exporting Report..."
                Export-Report -CopyResult $Result -Path "$ResultPath\$user-$Date.xlsx"
                #Convert the report to CSV
                $ExcelWB = new-object -comobject excel.application
                $Workbook = $ExcelWB.Workbooks.Open("$ResultPath\$user-$Date.xlsx")
                $Workbook.SaveAs("$ResultPath\$user-$Date.csv",6)
                $Workbook.Close($false)
                $ExcelWB.quit()
                $csv = import-csv "$ResultPath\$user-$date.csv" | Group-Object Status | select count,name
                #E-mail Report
                Send-MailMessage -From ODFBBackup@$domain.org -To Admin@$domain.org -Subject "$user ODFB Offboarding Report" -Body ($csv | out-string) -Attachments "$ResultPath\$user-$Date.xlsx" -SmtpServer $mailserver.$domain.local -Port 25
            }
            #Send an e-mail reporting failure
            else
            {
                Write-Output $SSE,$SLE,$DSE,$DLE
                Send-MailMessage -From ODFBBackup@$domain.org -To Admin@$domain.org -Subject "$user ODFB cannot connect" -Body "$user Failed" -SmtpServer $mailserver.$domain.local -Port 25
            }
        }
        else
        {
            Write-host -ForegroundColor Red "Failed to find onedrive"
            Send-MailMessage -From ODFBBackup@$domain.org -To Admin@$domain.org -Subject "$user ODFB DNE" -Body "$user does not have an ODFB site." -SmtpServer $mailserver.$domain.local -Port 25
        }
        #--------------------------------------------------#
    }
    
}# function end

