$server = "" 
$out = New-Object System.Text.StringBuilder 
$out.AppendLine("ServerName,EventID,TimeCreated,UserName,File_or_Folder,AccessMask") 
$ns = @{e = "http://schemas.microsoft.com/win/2004/08/events/event"} 
foreach ($svr in $server) 
    {    $evts = Get-WinEvent -computer $svr -FilterHashtable @{logname="security";id="4663"} -oldest

    foreach($evt in $evts) 
        { 
        $xml = [xml]$evt.ToXml()

        $SubjectUserName = Select-Xml -Xml $xml -Namespace $ns -XPath "//e:Data[@Name='SubjectUserName']/text()" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty Value

        $ObjectName = Select-Xml -Xml $xml -Namespace $ns -XPath "//e:Data[@Name='ObjectName']/text()" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty Value

        $AccessMask = Select-Xml -Xml $xml -Namespace $ns -XPath "//e:Data[@Name='AccessMask']/text()" | Select-Object -ExpandProperty Node | Select-Object -ExpandProperty Value

        $out.AppendLine("$($svr),$($evt.id),$($evt.TimeCreated),$SubjectUserName,$ObjectName,$AccessMask")

        #Write-Host $svr 
        Write-Host $evt.id,$evt.TimeCreated,$SubjectUserName,$ObjectName,$AccessMask

        } 
    } 
$out.ToString() | out-file -filepath "D:\Powershell\FileAudit\out.txt"

<#
AccessMask Value

Constant

Description

0 (0x0)

FILE_READ_DATA

Grants the right to read data from the file.

0 (0x0)

FILE_LIST_DIRECTORY

Grants the right to read data from the file. For a directory, this value grants the right to list the contents of the directory.

1 (0x1)

FILE_WRITE_DATA

Grants the right to write data to the file.

1 (0x1)

FILE_ADD_FILE

Grants the right to write data to the file. For a directory, this value grants the right to create a file in the directory.

4 (0x4)

FILE_APPEND_DATA

Grants the right to append data to the file. For a directory, this value grants the right to create a subdirectory.

4 (0x4)

FILE_ADD_SUBDIRECTORY

Grants the right to append data to the file. For a directory, this value grants the right to create a subdirectory.

8 (0x8)

FILE_READ_EA

Grants the right to read extended attributes.

16 (0x10)

FILE_WRITE_EA

Grants the right to write extended attributes.

32 (0x20)

FILE_EXECUTE

Grants the right to execute a file.

32 (0x20)

FILE_TRAVERSE

Grants the right to execute a file. For a directory, the directory can be traversed.

64 (0x40)

FILE_DELETE_CHILD

Grants the right to delete a directory and all the files it contains (its children), even if the files are read-only.

128 (0x80)

FILE_READ_ATTRIBUTES

Grants the right to read file attributes.

256 (0x100)

FILE_WRITE_ATTRIBUTES

Grants the right to change file attributes.

65536 (0x10000)

DELETE

Grants the right to delete the object.

131072 (0x20000)

READ_CONTROL

Grants the right to read the information in the security descriptor for the object.

262144 (0x40000)

WRITE_DAC

Grants the right to modify the DACL in the object security descriptor for the object.

524288 (0x80000)

WRITE_OWNER

Grants the right to change the owner in the security descriptor for the object.

1048576 (0x100000)

SYNCHRONIZE

Grants the right to use the object for synchronization.
#>