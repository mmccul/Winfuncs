# Winfuncs
Useful functions for Windows

## fixnet
Apple's macOS has a really nifty feature where you can define different network configurations based on a pre-declared location.  You can even assign different parameters to different SSID wireless networks.  I wanted similar functionality, but there doesn't seem to be anything similar.

fixnet is my attempt to create similar functionality in concept.  GUI coding isn't my speciality, so the configuration file is all done by XML.  Why XML?  Because powershell works with it very well, and it's better suited for the problem I'm solving than other syntaxes.  No having to worry about "is this an array or a single element?" That's free in XML.
