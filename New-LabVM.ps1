<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function New-LabVM
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    # Param1 help description
    [Parameter(Mandatory=$true)]
    $LabVMName,
    
    # Param2 help description
    [Parameter(Mandatory=$true)]
    [string]
    $Template,
    
    # Param2 help description
    [string]
    $IPAddress
  )
  
  Begin
  {
    
    $templatehost = 'host02'
    $newvmhost = 'host01'
    $networkSubnet = '255.255.240.0'
    $networkGateway = '172.16.16.1'
    $networkDns = '172.16.20.2'
    $Connect_vCenter = connect-viserver -server vcenter -credential (Get-Credential)
    
    $OScustomspec = @{
      AdminPassword = 'password'
      ChangeSID = $true
      FullName = $LabVMName
      OrgName = 'Curley Automation Lab'
      TimeZone = 040
      Domain = 'lab.local'
      DomainUserName = 'administrator'
      DomainPassword = 'password'
      Type = 'NonPersistent' 
    } 
    $OScustomnic = @{
      ipMode = 'UseStaticIP'
      ipAddress = $IPAddress
      SubnetMask = $networkSubnet
      Dns = $networkDns
      DefaultGateway = $networkGateway
    }
    $newspec = New-OSCustomizationSpec -Type NonPersistent -OSType Windows `
    -OrgName “Curley Automation Lab” -FullName $labvmname -Domain “lab.local” `
    –DomainUsername “administrator” –DomainPassword “password” -ChangeSid
    write-output $newspec
    $newspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping @OScustomnic
    write-output $newspec 
    $newvm = @{
      Name = $LabVMName
      Datastore = 'SAN01'
      Template = $Template
      vmHost = 'host01'
      OSCustomizationSpec = $newspec
      ErrorAction = 'Stop'
    }
    write-output $newvm
    
  }
  Process
  {
    
    try {
      New-VM @newvm
      
      
    }
    catch{
      'something has gone terribly wrong'
    }
    
  }
  End
  {
    Disconnect-VIServer * -confirm:$false
  }
}