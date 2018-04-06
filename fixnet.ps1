<# 
  Fix the network

  Uses (currently hard coded) C:\Users\mmccul\bin\netconfig.xml)
  Needs to be in the format

  <config>
    <netdata> <!-- one or more of these -->
      <ssid />
      <v4>
        <ip />
        <defgw />
        <netmask />
      </v4>
      <dns>
        <srvr>
          <ip /> <!-- one or more of these -->
        </srvr>
        <searchpath /> <!-- one or more of these -->
      </dns>
    </netdata>
  </config>

  Add additional netdata stanzas.  Each ssid is exactly matched.  If found,
  sets the network parameters exactly as set, useful for static networks.

  If IPv4 is missing, rely on DHCP
  If DNS is missing (or only one provided, ignore/don't set.
    Makes little sense to set static IP without setting DNS, but you can.

  Haven't yet built the setting of v6 manually or other oddities there
#>

<# First, get command line parameters

CHANGE THIS VALUE HERE!


Param ( `
  [string]$cfgfile = "C:\Users\mmccul\bin\netconfig.xml" `
)

#>

$cfgfile = "C:\Users\mmccul\bin\netconfig.xml" `
<# 

END CHANGE

#>

$adapterstatus=Get-NetAdapter -Name "Wi-Fi"

if ( $adapterstatus.Status -eq "Disconnected" ) {
  write-host "No connected Wi-Fi - Aborting!"
  start-sleep -Seconds 3
  exit
}

<# Escalate to admin rights if we don't have it already #>
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
      Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

<# 
  We only work (for now) on "Wi-Fi" interface.  Maybe later that will just
  be a default
#>

$curnet=get-netconnectionprofile `
  -InterfaceAlias "Wi-Fi" 

$index=$curnet.InterfaceIndex

$netdata=[XML](Get-Content $cfgfile)

$found=0
$i=0
foreach ( $ssid in $netdata.config.netdata.ssid) {
    if ( $curnet.Name -eq $ssid ) {
        if ( $netdata.config.netdata[$i].v4.ip ) {
            $ip=$netdata.config.netdata[$i].v4
            $family="IPv4"
            $destpre="0.0.0.0/0"

            write-host "Static IP"
            Remove-NetRoute `
              -InterfaceIndex $index `
              -DestinationPrefix $destpre `
              -Confirm:$false

            remove-netipaddress `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Confirm:$false

            set-netipinterface `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Dhcp Disabled

            new-netipaddress `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -IPAddress $ip.ip `
              -PrefixLength $ip.netmask `
              -DefaultGateway $ip.defgw 

            if ( $netdata.config.netdata[$i].dns ) {
                if ( $netdata.config.netdata[$i].dns.searchpath ) {
                    write-host "Set static DNS searchpath"
                    set-dnsclientglobalsetting `
                      -SuffixSearchList $netdata.config.netdata[$i].dns.searchpath
                }
                if ( $netdata.config.netdata[$i].dns.srvr ) {
                    write-host "Set Static DNS"
                    $out=set-dnsclientserveraddress `
                      -InterfaceIndex $index `
                      -ServerAddresses $netdata.config.netdata[$i].dns.srvr.ip
                }
            } else {
                write-host "Default DNS"
                set-dnsclientserveraddress `
                  -InterfaceIndex $index ` 
                  -ServerAddresses "8.8.8.8"
            }
        } else {
            write-host "Dynamic IP"

            $out=set-dnsclientserveraddress `
              -InterfaceIndex $index `
              -ResetServerAddress

            $out=set-netipinterface `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Dhcp Enabled

            ipconfig /renew "Wi-Fi"
            start-path "http://www.example.com/"
        }

        if ( $netdata.config.netdata[$i].v6.ip ) {
            $ip=$netdata.config.netdata[$i].v6
            $family="IPv6"
            $destpre="::/0"
            
            write-host "Static IPv6"
            $out=Remove-NetRoute `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -DestinationPrefix $destpre `
              -Confirm:$false

            $out=remove-netipaddress `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Confirm:$false

            $out=set-netipinterface `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Dhcp Disabled

            $out=new-netipaddress `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -IPAddress $ip.ip `
              -PrefixLength $ip.netmask `
              -DefaultGateway $ip.defgw
        } else {
            write-host "Dynamic IPv6"
            <# Broken! 
            $out=set-netipinterface `
              -InterfaceIndex $index `
              -AddressFamily $family `
              -Dhcp Enabled
            #>
        }

        if ( $netdata.config.netdata[$i].dns ) {
            if ( $netdata.config.netdata[$i].dns.searchpath ) {
                write-host "Set DNS searchpath"
                set-dnsclientglobalsetting `
                  -SuffixSearchList $netdata.config.netdata[$i].dns.searchpath
            }
            if ( $netdata.config.netdata[$i].dns.srvr ) {
                write-host "Static DNS"
                $out=set-dnsclientserveraddress `
                  -InterfaceIndex $index `
                  -ServerAddresses $netdata.config.netdata[$i].dns.srvr.ip
            }
        }
        if ( -Not $netdata.config.netdata[$i].dns -And
             -Not $netdata.config.netdata[$i].v4 -And
             -Not $netdata.config.netdata[$i].v6 ) {
            
            write-host "No DNS, No v4, No v6"
            $out=set-dnsclientserveraddress `
             -InterfaceIndex $index `
             -ResetServerAddress
 
            $out=set-netipinterface `
             -InterfaceIndex $index `
             -Dhcp Enabled

             ipconfig /renew "Wi-Fi"
        }
        $found=1
        break
    }
    $i=$i + 1
}


if ( $found -eq 0 ) {
    write-host "Default DHCP"
    $out=set-dnsclientserveraddress `
     -InterfaceIndex $index `
     -ResetServerAddress
 
    $out=set-netipinterface `
     -InterfaceIndex $index `
     -Dhcp Enabled

     ipconfig /renew "Wi-Fi"
     start-path "http://www.example.com/"
} 
 
