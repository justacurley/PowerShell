#Connect to sharepoint online and grab data from a "new user" form that HR fills out
#Feed the result to New-User.ps1 to create a new AD user and licensed o365 user.

function Get-SPONewUser { 

    [CmdletBinding()]
    param(
        [System.Management.Automation.CredentialAttribute()]
        $o365AdminCredential,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ID
        
    )# param end

    Add-Type -Path 'C:\Program Files\SharePoint Online Management Shell\Microsoft.Online.SharePoint.PowerShell\Microsoft.SharePoint.Client.dll'
    Add-Type -Path 'C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Publishing.dll'
    Add-Type -Path 'C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll'

    $Site = "https://domain.sharepoint.com/sites/IS"
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($Site)
    $Creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($o365AdminCredential.UserName,$o365AdminCredential.Password)
    $Context.Credentials = $Creds

    $Web = $Context.Web
    $Context.Load($Web)
    $Context.ExecuteQuery()
    $Lists = $web.Lists
    $Context.Load($Lists)
    $Context.ExecuteQuery()
    $siteitems = @()
    foreach ($list in $lists){
   
        if ($list.Title -eq 'New User'){
            $camlQuery = New-Object Microsoft.SharePoint.Client.CamlQuery
            $allitems = $list.getitems($camlQuery)
            $context.load($allitems)
            $context.ExecuteQuery()
            
      
            foreach ($item in $allitems)
            {
           
                $prp = [Ordered]@{
                    'SurName' = $item.FieldValues.Last_x0020_Name
                    'GivenName' = $item.FieldValues.First_x0020_Name
                    'EmploymentStatus' = $item.FieldValues.Employment_x0020_Status
                    'StartDate' = $item.FieldValues.Start_x0020_Date
                    'Title' =  $item.FieldValues.Title
                    'Division' = $item.FieldValues.Division
                    'Department' = $item.FieldValues.Department
                    'VP/AVP' = $item.FieldValues.VP_x002f_AVP.Email
                    'Manager' = $item.FieldValues.Manager.Email   
                    'DepartmentPOC' = $item.FieldValues.Department_x0020_POC.Email  
                    'WorkLocation' = $item.FieldValues.Work_x0020_Location     
                    'HQLocation' = $item.FieldValues.HQ_x0020_Seat_x0020_Assignment
                    'CellPhone' = $item.FieldValues.Cell_x0020_Phone
                    'ISComputer' = $item.FieldValues.IS_x0020_Computer
                    'EmailAccount' = $item.FieldValues.Email_x0020_Account
                    'DistributionGroup' = $item.FieldValues.IS_x0020_Email_x0020_Distrubtion
                    'ISNetworkAccount' = $item.FieldValues.IS_x0020_Network_x0020_Account
                    'ISExtension' = $item.FieldValues.IS_x0020_Extension
                    'LibraryGW' = $item.FieldValues.Library_x0020_Services_x0020_via
                    'Badge' = $item.FieldValues.USIP_x0020_Access_x0020_Badge
                    'Approval' = $item.FieldValues.Newusert
                    'OrgorGov' = $item.FieldValues.Org_x0020_or_x0020_Gov
                    'ID'  = $item.FieldValues.ID 
                    'phone' = $item.FieldValues.Phone
                    'ticket' = $item.FieldValues.Ticket_x0020_Number
                    'StaffDirectory' = $item.FieldValues.Staff_x0020_Directory
                                    }
                $obj = New-Object -TypeName psobject -Property $prp
                $siteitems+=$obj
            }
        }
    }
    $siteitems  | Where-Object {$_.ID-eq $ID}
}