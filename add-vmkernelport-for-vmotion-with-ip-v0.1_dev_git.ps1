<#
.Synopsis
   Script to improve vMotion Network.
.DESCRIPTION
   This script will delete a single vmkernel adapter used for vMotion and create two vmKernel adapters to inprove vMotion Network
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.BASED ON:
#https://blog.yahyazahedi.com/2019/10/19/add-vmkernel-adapter-to-a-number-of-esxi-host/
#https://collectingwisdom.com/powershell-split-string-multiple-delimiters/
#https://www.cloudaccess.net/cloud-control-panel-ccp/157-dns-management/322-subnet-masks-reference-table.html
#https://www.business.com/articles/powershell-interactive-menu/
#https://collectingwisdom.com/powershell-split-string-multiple-delimiters/
#https://vdc-repo.vmware.com/vmwb-repository/dcr-public/85a74cac-7b7b-45b0-b850-00ca08d1f238/ae65ebd9-158b-4f31-aa9c-4bbdc724cc38/doc/Set-NicTeamingPolicy.html
.INFORMATION ABOUT SUBNET MASK:
Possible subnet masks

Network Bits	Subnet Mask	Number of Subnets	Number of Hosts
/8	255.0.0.0	0	16777214
/9	255.128.0.0	2 (0)	8388606
/10	255.192.0.0	4 (2)	4194302
/11	255.224.0.0	8 (6)	2097150
/12	255.240.0.0	16 (14)	1048574
/13	255.248.0.0	32 (30)	524286
/14	255.252.0.0	64 (62)	262142
/15	255.254.0.0	128 (126)	131070
/16	255.255.0.0	256 (254)	65534
/17	255.255.128.0	512 (510)	32766
/18	255.255.192.0	1024 (1022)	16382
/19	255.255.224.0	2048 (2046)	8190
/20	255.255.240.0	4096 (4094)	4094
/21	255.255.248.0	8192 (8190)	2046
/22	255.255.252.0	16384 (16382)	1022
/23	255.255.254.0	32768 (32766)	510
/24	255.255.255.0	65536 (65534)	254
/25	255.255.255.128	131072 (131070)	126
/26	255.255.255.192	262144 (262142)	62
/27	255.255.255.224	524288 (524286)	30
/28	255.255.255.240	1048576 (1048574)	14
/29	255.255.255.248	2097152 (2097150)	6
/30	255.255.255.252	4194304 (4194302)	2

.AUTHOR
   Juliano Alves de Brito Ribeiro (Find me at: julianoalvesbr@live.com or https://github.com/julianoabr or https://www.linkedin.com/in/julianoabr)
.VERSION HISTORY
0.1 Initial version
.LAST UPDATE
  10/28/2024
.ENVIRONMENT
   PROD VERSION
.NEXT UPGRADE
  0.2 - Include progress bar and verification that a ESXi already has two vmkernel ports for vMotion
  0.3 - Work with dVS and more than 2 physical nics

.TOTHINK



#>

Clear-Host

Set-PowerCLIConfiguration -InvalidCertificateAction Prompt -Confirm:$false -Verbose

Set-PowerCLIConfiguration -WebOperationTimeoutSeconds 900 -Verbose -Confirm:$false -ErrorAction Continue

#VALIDATE MODULE
$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
    Write-Host "The Module Vmware.VimAutomation.Core is already loaded" -ForegroundColor White -BackgroundColor DarkYellow
    
}#if validate module
else{
    
    Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
}#else validate module

#FUNCTION TO PAUSE SCRIPT
function Pause-PSScript
{

   Read-Host 'Pressione [ENTER] para continuar' | Out-Null

}

#VALIDATE IF OPTION IS NUMERIC
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric

#FUNCTION CONNECT TO VCENTER
function Connect-vCenterSrv
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Manual','Auto')]
        $methodToConnect = 'Manual',

        [Parameter(Mandatory=$true,
                   Position=1)]
        [System.String[]]$vCenterSrvList, 
                
        [Parameter(Mandatory=$false,
                   Position=2)]
        [System.String]$dnsSuffix,
        
        [Parameter(Mandatory=$false,
                   Position=3)]
        [System.Boolean]$LastConnectedSrvs = $false,

        [Parameter(Mandatory=$false,
                   Position=4)]
        [ValidateSet('http','https')]
        [System.String]$connectionProtocol,

        [Parameter(Mandatory=$false,
                   Position=5)]
        [ValidateSet('80','443')]
        [System.String]$port = '443'
    )

#VALIDATE IF YOU ARE CONNECTED TO ANY VCENTER
if ((Get-Datacenter -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Host "You are not connected to any vCenter" -ForegroundColor White -BackgroundColor DarkMagenta

}#end of If
else{
        
        Write-Host -NoNewLine "You are connected to a vCenter Server. " -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host -NoNewline "I will disconnect you before continue" -ForegroundColor White -BackgroundColor Red
            
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

}#end of else validate if you are connected. 


if ($methodToConnect -eq 'Auto'){
        
    foreach ($vCenterSrv in $vCenterSrvList){
            
        $Script:workingvCenterSrv = ""
        
        $Script:workingvCenterSrv = $vCenterSrv + '.' + $dnssuffix

        $vcSAInfo = Connect-VIServer -Server $Script:workingvCenterSrv -Port $Port -WarningAction Continue -ErrorAction Stop

   }#end of foreach vcenter list
       
}#end of If Method to Connect
else{
        
    $workingLocationNum = ""
        
    $tmpWorkingLocationNum = ""
        
    $Script:workingvCenterSrv = ""
        
    $iterator = 0

    #MENU SELECT VCENTER
    foreach ($vCenterSrv in $vCenterSrvList){
	   
        $vcServerValue = $vCenterSrv
	    
        Write-Output "            [$iterator].- $vcServerValue ";	
	            
        $iterator++	
                
        }#end foreach	
                
            Write-Output "            [$iterator].- Exit this script ";

            while(!(isNumeric($tmpWorkingLocationNum)) ){
	                
                $tmpWorkingLocationNum = Read-Host "Type vCenter Number that you want to connect to"
                
            }#end of while

                $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($iterator-1))  ){
	                
                    $Script:workingvCenterSrv = $vCenterSrvList[$WorkingLocationNum]
                
                }#end of IF
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script." -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        $Script:vcSAInfo = Connect-VIServer -Server $Script:workingvCenterSrv -Port $port -WarningAction Continue -ErrorAction Stop -Verbose
  
    
    }#end of Else Method to Connect

}#End of Function Connect to vCenter

function Show-PSMenuSubnetMask
{
     param (
           [string]$Title = ‘Choose your Subnet Mask’
     )
     Clear-Host

     Write-Host “================ $Title ================” -ForegroundColor White -BackgroundColor DarkGreen
     Write-Host "`n"   
     Write-Host “Mask /8	255.0.0.0: Press ‘1’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /9	255.128.0.0: Press ‘2’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /10 255.192.0.0: Press ‘3’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /11 255.224.0.0: Press ‘4’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /12 255.240.0.0: Press ‘5’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /13 255.248.0.0: Press ‘6’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /14 255.252.0.0: Press ‘7’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /15 255.254.0.0: Press ‘8’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /16 255.255.0.0: Press ‘9’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /17 255.255.128.0: Press ‘10’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /18 255.255.192.0: Press ‘11' for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /19 255.255.224.0: Press ‘12’ for this option.” -ForegroundColor White -BackgroundColor Blue 
     Write-Host “Mask /20 255.255.240.0: Press ‘13’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /21 255.255.248.0: Press ‘14’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /22 255.255.252.0: Press ‘15’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /23 255.255.254.0: Press ‘16’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /24 255.255.255.0: Press ‘17’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /25 255.255.255.128: Press ‘18’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /26 255.255.255.192: Press ‘19’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /27 255.255.255.224: Press ‘20’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /28 255.255.255.240: Press ‘21’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host “Mask /29 255.255.255.248: Press ‘22’ for this option.” -ForegroundColor White -BackgroundColor Blue
     Write-Host “Mask /30 255.255.255.252: Press ‘23’ for this option.” -ForegroundColor Blue -BackgroundColor White
     Write-Host "`n"
     Write-Host “Q: Press ‘Q’ to quit.” -ForegroundColor White -BackgroundColor Red
}#End of Function Show-PSMenu


#DEFINE VCENTER LIST
$vcServerList = @();

#ADD OR REMOVE vCenters accordin to your needs and environment
$vcServerList = ('server1','server2','server3','server4','server5','server6') | Sort-Object


Do
{
 
    $tmpMethodToConnect = Read-Host -Prompt "Type (Manual) if you want to choose vCenter to Connect. Type (Auto) if you want to Type the Name of vCenter to Connect"

        if ($tmpMethodToConnect -notmatch "^(?:manual\b|auto\b)"){
    
            Write-Host "You typed an invalid word. Type only (manual) or (auto)" -ForegroundColor White -BackgroundColor Red
    
        }
        else{
    
            Write-Host "You typed a valid word. I will continue =D" -ForegroundColor White -BackgroundColor DarkBlue
    
        }
    
}While ($tmpMethodToConnect -notmatch "^(?:manual\b|auto\b)")#end of do while


if ($tmpMethodToConnect -match "^\bauto\b$"){

    $tmpDnsSuffix = Read-Host "Write the suffix of VC that you want to connect (host.intranet or uolcloud.intranet)"

    $tmpVC = Read-Host "Write the hostname of vCenter that you want to connect"

    Connect-vCenterSrv -vCenterSrvList $tmpVC -dnsSuffix $tmpDnsSuffix -methodToConnect Auto

}#end of IF
else{

   Connect-vCenterSrv -vCenterSrvList $vcServerList -methodToConnect $tmpMethodToConnect  -Verbose

}#end of Else

#Get Some Info About vCenter Connected

$vcSAName = $vcSAInfo.Name
$vcSAVersion = $vcSAInfo.Version
$vcSABuild = $vcSAInfo.Build


#CREATE CLUSTER LIST
$vCClusterList = @()

$vCClusterList = (Vmware.VimAutomation.Core\Get-Cluster | Select-Object -ExpandProperty Name| Sort-Object)

$tmpWorkingClusterNum = ""

$WorkingCluster = ""

[System.Int32]$iterator = 0

#CREATE CLUSTER MENU LIST
foreach ($vCCluster in $vCClusterList){
	   
        $vCClusterValue = $vCCluster
	    
        Write-Output "            [$iterator].- $vCClusterValue ";	
	    
        $iterator++	
        
}#end foreach	

        Write-Output "            [$iterator].- Exit this script ";

While(!(isNumeric($tmpWorkingClusterNum)) ){
	        
    $tmpWorkingClusterNum = Read-Host "Type Cluster Number that you want to improve vMotion Network"
        
}#end of while

            $workingClusterNum = ($tmpWorkingClusterNum / 1)

        if(($workingClusterNum -ge 0) -and ($workingClusterNum -le ($iterator-1))  ){
	        
            $WorkingCluster = $vcClusterList[$workingClusterNum]
        
        }#end of If
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else

Clear-Host

$esxiHostListName = @()

$EsxiHostListName = (Vmware.VimAutomation.Core\Get-Cluster -Name $WorkingCluster | Vmware.VimAutomation.Core\Get-VMHost | Select-Object -ExpandProperty Name | Sort-Object)

[System.Int32]$esxiHostCount = $esxiHostListName.count

Do
{
     Show-PSMenuSubnetMask
     $inputSubnetMask = Read-Host “Please select your Subnet Mask”
     switch ($inputSubnetMask)
     {
           ‘1’ {
                $tmpvMotionSubnetMask = '255.0.0.0'
                ‘You choose option #1, /8	255.0.0.0’
           }#End of 1 
           ‘2’ {
                $tmpvMotionSubnetMask = '255.128.0.0'
                ‘You choose option #2, /9	255.128.0.0’
           }#End of 2
           ‘3’ {
                $tmpvMotionSubnetMask = '255.192.0.0'
                ‘You choose option #3, /10 255.192.0.0’
           }#End of 3
           ‘4’ {
                $tmpvMotionSubnetMask = '255.224.0.0'
                ‘You choose option #4, /11 255.224.0.0’
           }#End of 4
           ‘5’ {
                $tmpvMotionSubnetMask = '255.240.0.0'
                ‘You choose option #5, /12 255.240.0.0’
           }#End of 5
           ‘6’ {
                $tmpvMotionSubnetMask = '255.248.0.0'
                ‘You choose option #6, /13 255.248.0.0’
           }#End of 6
           ‘7’ {
                $tmpvMotionSubnetMask = '255.252.0.0'
                ‘You choose option #7, /14 255.252.0.0’
           }#End of 7 
           ‘8’ {
                $tmpvMotionSubnetMask = '255.254.0.0'
                ‘You choose option #8, /15 255.254.0.0’
           }#End of 8
           ‘9’ {
                $tmpvMotionSubnetMask = '255.255.0.0'
                ‘You choose option #9, /16 255.255.0.0’
           }#End of 9
           ‘10’ {
                $tmpvMotionSubnetMask = '255.255.128.0'
                ‘You choose option #10, /17	255.255.128.0’
           }#End of 10
           ‘11’ {
                $tmpvMotionSubnetMask = '255.255.192.0'
                ‘You choose option #11, /18	255.255.192.0’
           }#End of 11
           ‘12’ {
                $tmpvMotionSubnetMask = '255.255.224.0'
                ‘You choose option #12, /19	255.255.224.0’
           }#End of 12
           ‘13’ {
                $tmpvMotionSubnetMask = '255.255.240.0'
                ‘You choose option #13, /20	255.255.240.0’
           }#End of 13
           ‘14’ {
                $tmpvMotionSubnetMask = '255.255.248.0'
                ‘You choose option #14, /21	255.255.248.0’
           }#End of 14
           ‘15’ {
                $tmpvMotionSubnetMask = '255.255.252.0'
                ‘You choose option #15, /22	255.255.252.0’
           }#End of 15
           ‘16’ {
                $tmpvMotionSubnetMask = '255.255.254.0'
                ‘You choose option #16, /23	255.255.254.0’
           }#End of 16
           ‘17’ {
                $tmpvMotionSubnetMask = '255.255.255.0'
                ‘You choose option #17, /24	255.255.255.0’
           }#End of 17
           ‘18’ {
                $tmpvMotionSubnetMask = '255.255.255.128'
                ‘You choose option #18, /25	255.255.255.128’
           }#End of 18
           ‘19’ {
                $tmpvMotionSubnetMask = '255.255.255.192'
                ‘You choose option #19, /26	255.255.255.192’
           }#End of 19
           ‘20’ {
                $tmpvMotionSubnetMask = '255.255.255.224'
                ‘You choose option #20, /27	255.255.255.224’
           }#End of 20
           ‘21’ {
                $tmpvMotionSubnetMask = '255.255.255.240'
                ‘You choose option #21, /28	255.255.255.240’
           }#End of 21
           ‘22’ {
                $tmpvMotionSubnetMask = '255.255.255.248'
                ‘You choose option #22, /29	255.255.255.248’
           }#End of 22
           ‘23’ {
                $tmpvMotionSubnetMask = '255.255.255.252'
                ‘You choose option #23, /30	255.255.255.252’
           }#End of 23
           ‘Q’ {
                Return
           }#End of Quit
     }#End of Switch
     Pause
}#End of Do
While ($inputSubnetMask -eq ‘Q’)#End of Menu to choose subnet mask


#MENU TO RUN ON A CLUSTER OR A SINGLE ESXi Host
Do {
    Write-Output "

===================== MAIN MENU CREATE VMKERNEL ADAPTER  =====================

YOU ARE CONNECTED TO:

VCenter Name: $vcSAName
Version: $vcSAVersion
Build:   $vcSABuild
Cluster Name: $workingCluster
Number of ESXi Hosts of this cluster: $esxiHostCount

1 = Run Action on a Single ESXi Host (Options on NEXT MENU)

2 = Run Action on a Cluster (Options on NEXT MENU)

3 = Exit of this Menu

================================================================================"

$choiceRange = Read-host -prompt "Select an Option & Press Enter"

} until ($choiceRange -eq "1" -or $choiceRange -eq "2" -or $choiceRange -eq "3")

#####################################################################################

#RUN ACTIONS ON A SINGLE HOST OR A CLUSTER
Switch ($choiceRange)
{
    1{
    
    
    #FOR TEST PURPOSE ONLY
    #$esxiHost = Get-VMHost -Name "tb-b6-daas-hyper-aa01.host.intranet"

    $esxiHostListName = @()
    
    $tmpEsxiHostLocationNum = ""
    
    $EsxiLocation = ""
    
    $x = 0

    $EsxiHostListName = (Vmware.VimAutomation.Core\Get-Cluster -Name $WorkingCluster | Vmware.VimAutomation.Core\Get-VMHost | Select-Object -ExpandProperty Name | Sort-Object)

    foreach ($esxiHostName in $esxiHostListName){
	  
    $esxiHostNameValue = $esxiHostName
	
     Write-Output "            [$x].- $esxiHostNameValue ";	
	     $x++	
        }#end foreach	
        Write-Output "            [$x].- Exit this script ";

        while(!(isNumeric($tmpEsxiHostLocationNum)) ){
	        
            $tmpEsxiHostLocationNum = Read-Host "Type Number of ESXi Host that you need to create vmkernel Adapters for vMotion"
            
        }#end of while

            $EsxiLocationNum = ($tmpEsxiHostLocationNum / 1)

        if(($EsxiLocationNum -ge 0) -and ($EsxiLocationNum -le ($x-1))){
	        
            $EsxiLocation = $esxiHostListName[$EsxiLocationNum]

        }#end of If
        else{
            
            Write-Host "Exit selected, or Invalid choice number. Script halted" -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else


        $esxiHost = $EsxiLocation

        [System.String]$vSwitchName = 'vSwitch0'

        $vSwitchStdObj = Get-VirtualSwitch -VMHost $esxiHost -Name $vSwitchName

        $numberOfPhysNic = $vSwitchStdObj.Nic.Count
     
        #validate if host has 2 or more physical nics    
        if ($numberOfPhysNic -lt 2){

            Write-Host "You can't create two vmkernel adapters for vMotion for Host: $esxiHost, because vSwitch: $vSwitchName has only $numberofPhysNic Physical Nic" -ForegroundColor White -BackgroundColor Red

        }#enf of If
        elseif($numberofPhysNic -eq 2){
    
            Write-Host "You can create two vmkernel adapters for vMotion for Host: $esxiHost, because vSwitch: $vSwitchName has $numberofPhysNic Physical Nics" -ForegroundColor White -BackgroundColor Green

            $esxiHostObj = Get-VMHost -Name $esxiHost

            #INPUT THE 3 FIRST OCTETS OF YOUR NETWORKS
            [System.String]$3FirstOctectsvMotionNet = '192.168.0.'

            #Input the number of last octect of first vmkernel vMotion Adapter(even)
            [System.int32]$lastIPOctectEvenvMotionNet = 2

            #Input the number of last octect of first vmkernel vMotion Adapter(odd)
            [System.Int32]$lastIPOctectOddvMotionNet = 3

                      
	    #GET INFO RELATED TO EXISTING VMOTION ADAPTER
            $vmkvMotionAdapter = $esxiHostObj | get-vmhostnetworkadapter | Where-Object -FilterScript {$PSItem.IP -like '192.168.0*'}

            [System.Int32]$vmkvMotionAdapterMTU = $vmkvMotionAdapter.Mtu	

	    #Remove Single vMotion vmKernel Adapter
            $vmkvMotionAdapter | Remove-VMHostNetworkAdapter -Confirm:$true -Verbose

     	    #Remove Port Group
            $vmkPortGroup = $esxiHostObj | Get-VirtualPortGroup | Where-Object -FilterScript {$PSItem.Name -like 'vMotion*'}

            Remove-VirtualPortGroup -VirtualPortGroup $vmkPortGroup -Confirm:$true -Verbose

            #Create two new vMotion vmKernel Adapters

            [System.String]$vPortGroupAName = 'vMotion-01'

            [System.String]$vPortGroupBName = 'vMotion-02'

            [System.String]$vlanvMotionPGID = '210'

            $vMotionSubnetMask = $tmpvMotionSubnetMask

            $vPortGroupAObj =  New-VirtualPortGroup -VirtualSwitch $vSwitchStdObj -Name $vPortGroupAName -VLanId $vlanvMotionPGID

            Write-Host "These are the active NICs in order:" -ForegroundColor DarkGreen -BackgroundColor White

            ($vPortGroupAObj | Get-NicTeamingPolicy).ActiveNic

            Write-Host "These are the active policies in Port Group A:" -ForegroundColor DarkGreen -BackgroundColor White

            $vPortGroupAPolicy = $vPortGroupAObj | Get-NicTeamingPolicy -Verbose

            $vPortGroupAPolicy | Format-Table -AutoSize 

            $vPortGroupAPolicy | Set-NicTeamingPolicy -MakeNicActive 'vmnic0' -Verbose

            $vPortGroupAPolicy | Set-NicTeamingPolicy -MakeNicStandby 'vmnic1' -Verbose

            $vPortGroupBObj =  New-VirtualPortGroup -VirtualSwitch $vSwitchStdObj -Name $vPortGroupBName -VLanId $vlanvMotionPGID -Verbose

            Write-Host "These are the active NICs in order:" -ForegroundColor DarkGreen -BackgroundColor White

            ($vPortGroupBObj | get-nicteamingPolicy).ActiveNic

            $vPortGroupBPolicy = $vPortGroupBObj | Get-NicTeamingPolicy

            Write-Host "These are the active policies in Port Group A:" -ForegroundColor DarkGreen -BackgroundColor White

            $vPortGroupBPolicy | Format-Table -AutoSize

            $vPortGroupBPolicy | Set-NicTeamingPolicy -MakeNicActive 'vmnic1' -Verbose

            $vPortGroupBPolicy | Set-NicTeamingPolicy -MakeNicStandby 'vmnic0' -Verbose
                   
            $vMotionALastIPOctect = $lastIPOctectEvenvMotionNet.ToString()

            $vMotionBLastIPOctect = $lastIPOctectOddvMotionNet.ToString()
    
            $vMotionAIP = $3FirstOctectsvMotionNet + $vMotionALastIPOctect

            $vMotionBIP = $3FirstOctectsvMotionNet + $vMotionBLastIPOctect
            
            #create New Port Groups - vMotion-A and vMotion-B

            New-VMHostNetworkAdapter -VMHost $esxiHost -PortGroup $vPortGroupAName -VirtualSwitch $vSwitchStdObj -Mtu $vmkvMotionAdapterMTU -IP $vMotionAIP -SubnetMask $vMotionSubnetMask -VMotionEnabled $true -Verbose
        
            New-VMHostNetworkAdapter -VMHost $esxiHost -PortGroup $vPortGroupBName -VirtualSwitch $vSwitchStdObj -Mtu $vmkvMotionAdapterMTU -IP $vMotionBIP -SubnetMask $vMotionSubnetMask -VMotionEnabled $true -Verbose
            
            }#end of ElseIf
        else{
            
                Write-Host "Host named: $esxiHostName has: $numberOfPhysNic in his vSwitch0 and this script only create two new vmkernel ports in this version" -ForegroundColor White -BackgroundColor Red
            
            }#end of Else

    }#end of 1
    2{
    
    Write-Host "Before Continue I will put DRS Automation Level in Manual Mode to evict vMotion during the changes of vMotion Network" -ForegroundColor White -BackgroundColor Red

    $ClusterObj = Vmware.VimAutomation.Core\Get-Cluster -Name $WorkingCluster

    VMware.VimAutomation.Core\Set-Cluster -Cluster $ClusterObj -DrsAutomationLevel Manual -Confirm:$false -Verbose

    #INPUT THE 3 FIRST OCTETS OF YOUR NETWORKS
    [System.String]$3FirstOctectsvMotionNet = '192.168.0.'

    #Input the number of last octect of first vmkernel vMotion Adapter(even)
    [System.int32]$lastIPOctectEvenvMotionNet = 2

    #Input the number of last octect of first vmkernel vMotion Adapter(odd)
    [System.Int32]$lastIPOctectOddvMotionNet = 3

    
#Create vmkernel adapters for each host
foreach ($esxiHost in $esxiHostListName)
{
    
    [System.String]$vSwitchName = 'vSwitch0'

    $vSwitchStdObj = Get-VirtualSwitch -VMHost $esxiHost -Name $vSwitchName

    $numberOfPhysNic = $vSwitchStdObj.Nic.Count
     
    #validate if host has 2 or more physical nics    
    if ($numberOfPhysNic -lt 2){

        Write-Host "You can't create two vmkernel adapters for vMotion for Host: $esxiHost, because you have only $numberofPhysNic Physical Nic" -ForegroundColor White -BackgroundColor Red

    }#enf of If
    elseif($numberofPhysNic -eq 2){
    
        Write-Host "You can create two vmkernel adapters for vMotion for Host: $esxiHost, because you have $numberofPhysNic Physical Nics" -ForegroundColor White -BackgroundColor Green

        $esxiHostObj = Get-VMHost -Name $esxiHost

        #GET INFO RELATED TO EXISTING VMOTION ADAPTER
        $vmkvMotionAdapter = $esxiHostObj | get-vmhostnetworkadapter | Where-Object -FilterScript {$PSItem.IP -like '10.143.38*'}

        [System.Int32]$vmkvMotionAdapterMTU = $vmkvMotionAdapter.Mtu
        
        #Remove Single vMotion vmKernel Adapter
        $vmkvMotionAdapter | Remove-VMHostNetworkAdapter -Confirm:$true -Verbose

        #Remove Port Group
        $vmkPortGroup = $esxiHostObj | Get-VirtualPortGroup | Where-Object -FilterScript {$PSItem.Name -like 'vMotion*'}

        Remove-VirtualPortGroup -VirtualPortGroup $vmkPortGroup -Confirm:$true -Verbose

        #Create two new vMotion vmKernel Adapters

        [System.String]$vPortGroupAName = 'vMotion-01'

        [System.String]$vPortGroupBName = 'vMotion-02'

        [System.String]$vlanvMotionPGID = '210'

        $vMotionSubnetMask = $tmpvMotionSubnetMask

        $vPortGroupAObj =  New-VirtualPortGroup -VirtualSwitch $vSwitchStdObj -Name $vPortGroupAName -VLanId $vlanvMotionPGID

        Write-Host "These are the active NICs in order:" -ForegroundColor DarkGreen -BackgroundColor White

        ($vPortGroupAObj | Get-NicTeamingPolicy).ActiveNic

        Write-Host "These are the active policies in Port Group A:" -ForegroundColor DarkGreen -BackgroundColor White

        $vPortGroupAPolicy = $vPortGroupAObj | Get-NicTeamingPolicy

        $vPortGroupAPolicy | Format-Table -AutoSize 

        $vPortGroupAPolicy | Set-NicTeamingPolicy -MakeNicActive 'vmnic0'

        $vPortGroupAPolicy | Set-NicTeamingPolicy -MakeNicStandby 'vmnic1'

        $vPortGroupBObj =  New-VirtualPortGroup -VirtualSwitch $vSwitchStdObj -Name $vPortGroupBName -VLanId $vlanvMotionPGID

        Write-Host "These are the active NICs in order:" -ForegroundColor DarkGreen -BackgroundColor White

        ($vPortGroupBObj | get-nicteamingPolicy).ActiveNic

        $vPortGroupBPolicy = $vPortGroupBObj | Get-NicTeamingPolicy

        Write-Host "These are the active policies in Port Group A:" -ForegroundColor DarkGreen -BackgroundColor White

        $vPortGroupBPolicy | Format-Table -AutoSize

        $vPortGroupBPolicy | Set-NicTeamingPolicy -MakeNicActive 'vmnic1'

        $vPortGroupBPolicy | Set-NicTeamingPolicy -MakeNicStandby 'vmnic0'
                   
        $vMotionALastIPOctect = $lastIPOctectEvenvMotionNet.ToString()

        $vMotionBLastIPOctect = $lastIPOctectOddvMotionNet.ToString()
       

        $vMotionAIP = $3FirstOctectsvMotionNet + $vMotionALastIPOctect

        $vMotionBIP = $3FirstOctectsvMotionNet + $vMotionBLastIPOctect
    

        #create New Port Groups - vMotion-A and vMotion-B

        New-VMHostNetworkAdapter -VMHost $esxiHost -PortGroup $vPortGroupAName -VirtualSwitch $vSwitchStdObj -Mtu 9000 -IP $vMotionAIP -SubnetMask $vMotionSubnetMask -VMotionEnabled $true -Verbose
        
        New-VMHostNetworkAdapter -VMHost $esxiHost -PortGroup $vPortGroupBName -VirtualSwitch $vSwitchStdObj -Mtu 9000 -IP $vMotionBIP -SubnetMask $vMotionSubnetMask -VMotionEnabled $true -Verbose

        $lastIPOctectEvenvMotionNet +=2

        Write-Host "The Last IP octect of Next vMotion Adapter (Even Numbers) will be:$lastIPOctectEvenvMotionNet" -ForegroundColor White -BackgroundColor DarkBlue

        $lastIPOctectOddvMotionNet +=2

        Write-Host "The Last IP octect of Next vMotion Adapter (Odd Numbers) will be: $lastIPOctectOddvMotionNet" -ForegroundColor White -BackgroundColor DarkBlue
                  
    }#end of ElseIf
    else{
    
        Write-Host "Host named: $esxiHostName has: $numberOfPhysNic in his vSwitch0 and this script only create two new vmkernel ports in this version" -ForegroundColor White -BackgroundColor Red
    
    }#end of Else


}#End of ForEach Host

    Write-Host "Before Finish I will put DRS Automation Level in Fully Automated Mode Again" -ForegroundColor White -BackgroundColor Red

    $ClusterObj = Vmware.VimAutomation.Core\Get-Cluster -Name $WorkingCluster

    VMware.VimAutomation.Core\Set-Cluster -Cluster $ClusterObj -DrsAutomationLevel FullyAutomated -Confirm:$false -Verbose

    
    }#end of 2
    3{
    
     Write-Output " "
    
     Write-Host "Exit of Menu..." -ForegroundColor White -BackgroundColor Yellow
    
     Exit
        
    
    }#end of 3
    
}#end Main Switch


Write-Host "Finishing of this Script. Powershell Rocks..." -ForegroundColor White -BackgroundColor Yellow



#Commands in analysis
#$vportGrpObj.ExtensionData.ComputedPolicy.NicTeaming.NicOrder.ActiveNic

#$vportGrpObj.ExtensionData.ComputedPolicy.NicTeaming.NicOrder.StandbyNic

#$nicPolicy = Get-VirtualPortGroup -VMHost tb-b6-daas-hyper-aa01.host.intranet -Name vMotion-01 | Get-NicTeamingPolicy
