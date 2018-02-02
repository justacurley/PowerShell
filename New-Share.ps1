<#
.Synopsis
   Create a folder inside a share
   Set-ACL on the folder
   Set-ACL (auditing) on the folder
.DESCRIPTION
   This script is intended for use with a fileserver set up with one share and multiple folders with different NTFS permissions.
   This does not create a share, but creates a folder inside of a share and sets permissions and audit rules. 
.EXAMPLE
    New-FolderPerm -FolderName "ImpactInitiative" -FolderPath '\\Server\ShareName\' -Admins "domain admins",IS_Group -ACLGroups "HR Group",AV_Group,User1,User2

#>
function New-FolderPerm
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    # Enter the name of the folder you would like to create
    [Parameter(Mandatory=$true,
    Position=0)]
    $FolderName,
    
    #Enter the UNC path of the share that $FolderName will be created in
    [Parameter(Mandatory=$true)]
    $FolderPath,
    
    #Enter the group(s) or users(s) that should have FullControl, separated with commas
    [Parameter(Mandatory=$true)]
    [string[]]
    $Admins,
    
    # Enter the group(s) or user(s) separated with commas
    [string[]]
    $ACLGroups
  )
  
  Begin
  {
    #NewFolder Path
    $NewFolder = join-path $FolderPath -ChildPath $FolderName

    #Modify permissions for ACLGroups
    $colRights = [System.Security.AccessControl.FileSystemRights]::Modify
    #FullControl permissions for Admins
    $colAdmin = [System.Security.AccessControl.FileSystemRights]::FullControl
    #InheritanceFlag and Propogation flag set to this folder, subfolders, and files
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    $PropogationFlag = [System.Security.AccessControl.PropagationFlags]::None
    #Allow rights defined above
    $objType = [System.Security.AccessControl.AccessControlType]::Allow
    
    #Audit rules for ACLGroups
    $AuditFileSystemRights = [System.Security.AccessControl.FileSystemRights]'Delete,ChangePermissions,Write,WriteData,CreateFiles,CreateDirectories,AppendData,Deletesubdirectoriesandfiles'
    $AuditFlags = [System.Security.AccessControl.AuditFlags]::Success  
  }
  Process
  {
    #Create new folder
    new-item $NewFolder -ItemType directory 
    $acl = get-acl $NewFolder
    #disable inheritance
    $acl.SetAccessRuleProtection(1,0)
    $acl | set-acl $NewFolder
    
    #Give admins FullControl on NewFolder
    foreach($ID in $Admins){
      $ID = "domain\$ID"
      $objUser = New-Object System.Security.Principal.NTAccount($ID)
      $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
      ($objUser,$colAdmin,$InheritanceFlag,$PropogationFlag,$objType)
      $acl.AddAccessRule($objACE)
      $acl | set-acl $NewFolder
    }
    
    #loop through each group or user entered as the second param and give that group Modify access
    Foreach ($item in $ACLGroups){
      $item = "usip\$item"
      #Give ACLGroups Modify permissions on NewFolder
      $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
      ($item,$colRights,$InheritanceFlag,$PropogationFlag,$objType)
      $acl.AddAccessRule($objACE)
      $acl | set-acl $NewFolder -Confirm
      
      #Set Audit Rules on NewFolder for ACLGroups
      $AuditIdentityReference = New-Object System.Security.Principal.NTAccount($item)
      $ACE = New-Object System.Security.AccessControl.FileSystemAuditRule($AuditIdentityReference,$AuditFileSystemRights,$InheritanceFlag,$PropogationFlag,$AuditFlags)
      $acl.AddAuditRule($ACE)
      Set-ACL -Path $NewFolder -AclObject $acl -Confirm
    }
    
  }
  End
  {
    get-acl $NewFolder | Select-Object -ExpandProperty Access
  }
}