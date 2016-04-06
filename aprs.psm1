<#
.SYNOPSIS
APRS Module

.OUTPUTS


.PARAMETER 

.EXAMPLE

Get-Aprsdata -callsign XXXXXX -filter "m/200" -longitude "3411.58N" -latitude "11816.10W" -altitude "000000"
Get-Aprsdata -callsign XXXXXX -filter "m/200" -longitude "3411.58N" -latitude "11816.10W" -altitude "000000" -kmlpath c:\data\aprs.kml


.NOTES
Written by: Anthony Geoffron

Change Log
V0.1 11/18/2015 - Initial version
V0.2 04/05/2016 - Some cleanup 

New-ModuleManifest -Path C:\data\aprs.psd1 -Author "Anthony Geoffron" -ModuleVersion 0.2 -Description "Aprs Module" -RootModule Aprs
   

#>

$moduleversion = "0.2"

#####################################
# Connect to APRS Tier 2 Server
#####################################
function Connect-aprs {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [ValidateSet("noam.aprs2.net","soam.aprs2.net","euro.aprs2.net","asia.aprs2.net","aunz.aprs2.net")]
    [string]$aprshost,
    [int]$port=14580
)
   
    [System.Net.Sockets.TcpClient]$socket = $null

    try
    {
        $socket = new-object System.Net.Sockets.TcpClient($aprsHost, $port)
        return $Socket
    }
    catch
    {
        "Unable to connect to host {0}:{1}" -f $aprshost,$Port
        return
    }
}


#####################################
# Send Message via Socket
#####################################
function Send-SocketMsg {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$msg,
    [Parameter(Mandatory=$True)]
    [System.Net.Sockets.TcpClient]$Socket
)
    $stream = $socket.GetStream() 
    $writer = new-object System.IO.StreamWriter $stream

    $enc = [system.Text.Encoding]::UTF8
    $byte_msg = $enc.GetBytes($msg) 
    
    $writer.WriteLine($msg) 
    $writer.Flush() 
    #$Sent = $Socket.Send($byte_msg)

        
    return Get-SocketOutput -socket $Socket

}

#####################################
# Send APRS Auth String
#####################################
function Send-AprsAuth {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$callsign, 
    [Parameter(Mandatory=$True)]
    [string]$pass,
    [Parameter(Mandatory=$True)]
    [System.Net.Sockets.TcpClient]$Socket
)

    $aprs_msg = "user $($callsign) pass $($pass) vers $($moduleversion) PowershellModule`r`n"

    write-verbose $aprs_msg
    Send-SocketMsg -msg $aprs_msg -Socket $Socket
    Get-SocketOutput -socket $Socket

}


#####################################
# Send APRS Coordinate
#####################################
function Send-AprsCoordinate {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$lat,
    [Parameter(Mandatory=$True)]
    [string]$long,
    [Parameter(Mandatory=$True)]
    [string]$alt,
    [Parameter(Mandatory=$True)]
    [string]$callsign,
    [Parameter(Mandatory=$True)]
    [System.Net.Sockets.TcpClient]$socket
)

    $code="Test only"
    $coord = "!$($long)/$($lat)>$($code) /A=$($alt)`r`n"
    $aprs_msg = "$($callsign)>APRS,TCPIP*:$($coord)`r`n"
    write-verbose $aprs_msg
    Send-SocketMsg -msg $aprs_msg -Socket $socket
  
}

#####################################
# Send APRS Filter Command
#####################################
function Send-AprsFilter {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$filter,
    [Parameter(Mandatory=$True)]
    [System.Net.Sockets.TcpClient]$socket
)

    $aprs_msg = "#filter $($filter)`r`n"
    write-verbose $aprs_msg
    Send-SocketMsg -msg $aprs_msg -Socket $socket
  
}

#####################################
# Get Socket output buffer
#####################################
function Get-SocketOutput  {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [System.Net.Sockets.TcpClient]$socket
)
    $stream = $socket.GetStream() 
    $buffer = new-object System.Byte[] 1024 
    $encoding = new-object System.Text.AsciiEncoding

    $outputBuffer = "" 
    $foundMore = $false

    do 
    { 
        start-sleep -m 1000
        $foundmore = $false 
        $stream.ReadTimeout = 1000

        do 
        { 
            try 
            { 
                $read = $stream.Read($buffer, 0, 1024)

                if($read -gt 0) 
                { 
                    $foundmore = $true 
                    $outputBuffer += ($encoding.GetString($buffer, 0, $read)) 
                } 
            } catch { $foundMore = $false; $read = 0 } 
        } while($read -gt 0) 
    } while($foundmore)

    $outputBuffer 
}

#####################################
# Get APRS passcode from callsign 
# Powershell adapted from https://github.com/magicbug/PHP-APRS-Passcode
#####################################
Function Get-AprsPasscode {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$callsign 
)
    $hash = 0x73e2; 
    $i=0
    Do
    {
        $hash = $hash -bxor (([int][char]$callsign[$i]) -shl 8)
        $hash = $hash -bxor ([int][char]$callsign[$i+1])
        $i += 2;
    } while($i -lt $callsign.Length)

    return $hash  -band 0x7fff; 
}


function Get-Aprsdata {
[CmdletBinding()]
Param(
    [string]$filter="m/200",
    [Parameter(Mandatory=$True)]
    [string]$callsign,
    [Parameter(Mandatory=$True)]
    [string]$latitude,
    [Parameter(Mandatory=$True)]
    [string]$longitude,
    [Parameter(Mandatory=$True)]
    [string]$altitude,
    [string]$kmlpath
)


    $socket = Connect-aprs -aprshost "noam.aprs2.net" -port 14580 -verbose
    if($socket -ne $null)
    {
        Send-AprsAuth -callsign $callsign -pass (Get-AprsPasscode $callsign) -Socket $socket -Verbose
        Send-AprsCoordinate -callsign $callsign -long $longitude -lat $latitude -alt $altitude -Socket $socket -Verbose
        Send-AprsFilter -filter $filter -socket $socket -Verbose
        
        Do
        {
            $buffer = Get-SocketOutput -socket $socket
            $x=0
            $buffer.split("'r'n") | %{ 
                $x++
               
               if($kmlpath -ne "") 
               {    
                    # With KML file
                    write
                    Decode-Coordinate -in $_ -kmlpath $kmlpath
               } else
               {
                    # Without KML file
                    Decode-Coordinate -in $_
               }
               
            }
            Sleep(1)
        }
        while($true)
    }
}




[array]$global:coord = $null

Function Decode-Coordinate {
[CmdletBinding()]
Param(
    [string]$in,
    [string]$kmlpath
    
)


    $matches = 0;
    if($in -cmatch "[!=/zh@][0-9]{4}.[0-9]{2}[NS][/SDI][0-9]{5}.[0-9]{2}[EW]")
    { 
        $lat = $matches[0].split($matches[0][9])[0]
        $lat = $lat.substring(1,$lat.Length-1); 
        $long = $matches[0].split($matches[0][9])[1];

        $callsign = $in.Substring(0,$in.IndexOf(">"))
        if($callsign.Length -lt 5 -or $callsign.Length -gt 9) { $callsign ="unkwown" }

        $Object = New-Object PSObject    
        $Object | add-member Noteproperty Callsign $callsign
        $Object | add-member Noteproperty Latitude $lat
        $Object | add-member Noteproperty Longitude $long
 
        $global:coord += $Object

        #Generate the KML file
        if($kmlpath -ne "") {
            Generate-kml -local_coord $global:coord -kmlpath $kmlpath
        }
        #$global:coord
        $Object
    }
    
    else {
        write-verbose $in
    }

   
}


Function Generate-kml {
Param(
    [array]$local_coord,
    [string]$kmlpath
)

$data_start = @"
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document> http://maps.google.com/mapfiles/kml/pal2/icon13.png

"@
$local_coord | %{

$result = Generate-kmlCoordinate -lat $_.latitude -long $_.longitude
$placement += @"
   <Placemark><name>$($_.callsign)</name><Point><coordinates>$($result.t_longitude),$($result.t_latitude),0</coordinates></Point></Placemark>

"@
}
$data_end=@"
</Document></kml>
"@

    $data_start,$placement,$data_end | out-file $kmlpath
}


Function Generate-kmlCoordinate {
Param(
    [string]$lat,
    [string]$long
)
    #$t_long = "-$($long.Substring(0,3)).$($long.Substring(3,2))"
    $d_long = [int]$long.Substring(0,3)
    $m_long = [double]($long.Substring(3,2))/60 + [double]($long.Substring(6,2)/3600)
    $t_long = $d_long+ $m_long

    #$t_lat = "-$($lat.Substring(0,2)).$($lat.Substring(2,2))"
    $d_lat = [int]$lat.Substring(0,2)
    $m_lat = [double]($lat.Substring(2,2))/60 + [double]($lat.Substring(5,2)/3600)
    $t_lat = $d_lat+ $m_lat

    $t_long_final =  $t_long.ToString()
    $t_lat_final =  $t_lat.ToString()

    if($long -match "W")
    {
        $t_long_final = "-" +  $t_long.ToString()
    }
  
    if($lat -match "S")
    {
         $t_lat_final = "-" + $t_lat.ToString()
    } 


    $Object = New-Object PSObject    
    $Object | add-member Noteproperty t_latitude $t_lat_final
    $Object | add-member Noteproperty t_longitude $t_long_final
    $Object
}



Export-ModuleMember -function Get-AprsData
Export-ModuleMember -function Send-AprsFilter
Export-ModuleMember -function Connect-Aprs
Export-ModuleMember -function Send-AprsAuth 
Export-ModuleMember -function Send-AprsCoordinate

Export-ModuleMember -function Get-AprsPasscode
Export-ModuleMember -function Get-socketoutput
