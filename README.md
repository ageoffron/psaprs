# psaprs
APRS  Amateur Radio Powershell Module

An Attempt to decode APRS traffic using Powershell.
This was a quick implementation for a proof of concept, the code needs some polishing and additional testing.


Usage:
The following command will sign you in, at a given longitude, latitude and setup a filter of 20 miles.

Get-Aprsdata -callsign XXXXXX -filter "m/20" -longitude "3411.58N" -latitude "11816.10W" -altitude "000000"

This will output all APRS traffic within 20 miles of your coordinates.


Optionaly, you can generate a realtime KML file, and open it up with Google Earth
Get-Aprsdata -callsign XXXXXX -filter "m/20" -longitude "3411.58N" -latitude "11816.10W" -altitude "000000" -kmlpath c:\tmp\aprs.kml


The code needs some review.

