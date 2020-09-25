Function Invoke-MigratevSS2vDS {

    <#
    .SYNOPSIS  
        A PowerShell script to migrate an ESXi Host from a vSS to a vDS.
    .DESCRIPTION
       This script will migrate vmnic0 & vmnic1 and vmk0 from a vSS vSwitch0 to a vDS.
       vmnic0 is mapped to dvUplink1
       vmnic1 is mapped to dvUplink2
       Has had **LIMITED** testing with vSphere ESXi/vCenter/vDS v7.0
    .NOTES
        Version:        1.0.1
        Author:         Martin Cooper
        Github:         mc1903
        Credits:        Luc Dekens for his help via VMTN
    .LINK
        https://github.com/mc1903/Invoke-MigratevSS2vDS
    #>

    [CmdletBinding(
        PositionalBinding = $false
    )]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = 'Please provide the ESXi Host IP/FQDN'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]] $VMHost,

        [Parameter(
            Position = 1,
            Mandatory = $true,
            HelpMessage = 'Please provide the vDS Name'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]] $MgmtvDS,

        [Parameter(
            Position = 2,
            Mandatory = $true,
            HelpMessage = 'Please provide the vDS Port Group'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]] $MgmtvDSPG
    )

        $esx = Get-VMHost -Name $VMHost
        $vds = Get-VDSwitch -Name $MgmtvDS
        $vdspg = Get-VDPortgroup -VDSwitch $MgmtvDS -Name $MgmtvDSPG

        $spec = New-Object VMware.Vim.DVSConfigSpec
        $spec.ConfigVersion = $vds.ExtensionData.Config.COnfigVersion
        $member = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberConfigSpec
        $member.Host = $esx.ExtensionData.MoRef
        $member.Operation = 'add'
        $spec.Host += $member

        $vds.ExtensionData.ReconfigureDvs_Task($spec) | Out-Null

        $hostsystem = Get-View -ViewType HostSystem -Filter @{"Name" = $esx.name}
        $hostconfigmanager = $hostsystem.get_ConfigManager()
        $hostnetworksystem = $hostconfigmanager.get_NetworkSystem()

        $criteria = New-Object VMware.Vim.DistributedVirtualSwitchPortCriteria
        $criteria.UplinkPort = $true
        $_this = Get-View -Id $vds.ExtensionData.MoRef

        $hostport = $_this.FetchDVPorts($criteria) | where {$_.ProxyHost -match $member.Host.ToString()}

        $config = New-Object VMware.Vim.HostNetworkConfig
        $config.Vswitch = New-Object VMware.Vim.HostVirtualSwitchConfig[] (1)
        $config.Vswitch[0] = New-Object VMware.Vim.HostVirtualSwitchConfig
        $config.Vswitch[0].Name = 'vSwitch0'
        $config.Vswitch[0].ChangeOperation = 'edit'
        $config.Vswitch[0].Spec = New-Object VMware.Vim.HostVirtualSwitchSpec
        $config.Vswitch[0].Spec.NumPorts = 128
        $config.Vswitch[0].Spec.Policy = New-Object VMware.Vim.HostNetworkPolicy
        $config.Vswitch[0].Spec.Policy.Security = New-Object VMware.Vim.HostNetworkSecurityPolicy
        $config.Vswitch[0].Spec.Policy.Security.AllowPromiscuous = $false
        $config.Vswitch[0].Spec.Policy.Security.ForgedTransmits = $false
        $config.Vswitch[0].Spec.Policy.Security.MacChanges = $false
        $config.Vswitch[0].Spec.Policy.OffloadPolicy = New-Object VMware.Vim.HostNetOffloadCapabilities
        $config.Vswitch[0].Spec.Policy.OffloadPolicy.TcpSegmentation = $true
        $config.Vswitch[0].Spec.Policy.OffloadPolicy.ZeroCopyXmit = $true
        $config.Vswitch[0].Spec.Policy.OffloadPolicy.CsumOffload = $true
        $config.Vswitch[0].Spec.Policy.ShapingPolicy = New-Object VMware.Vim.HostNetworkTrafficShapingPolicy
        $config.Vswitch[0].Spec.Policy.ShapingPolicy.Enabled = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming = New-Object VMware.Vim.HostNicTeamingPolicy
        $config.Vswitch[0].Spec.Policy.NicTeaming.NotifySwitches = $true
        $config.Vswitch[0].Spec.Policy.NicTeaming.RollingOrder = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria = New-Object VMware.Vim.HostNicFailureCriteria
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.FullDuplex = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.Percentage = 0
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.CheckErrorPercent = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.CheckDuplex = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.CheckBeacon = $false
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.Speed = 10
        $config.Vswitch[0].Spec.Policy.NicTeaming.FailureCriteria.CheckSpeed = 'minimum'
        $config.Vswitch[0].Spec.Policy.NicTeaming.Policy = 'loadbalance_srcid'
        $config.Vswitch[0].Spec.Policy.NicTeaming.ReversePolicy = $true
        $config.Portgroup = New-Object VMware.Vim.HostPortGroupConfig[] (1)
        $config.Portgroup[0] = New-Object VMware.Vim.HostPortGroupConfig
        $config.Portgroup[0].ChangeOperation = 'remove'
        $config.Portgroup[0].Spec = New-Object VMware.Vim.HostPortGroupSpec
        $config.Portgroup[0].Spec.VswitchName = ''
        $config.Portgroup[0].Spec.VlanId = -1
        $config.Portgroup[0].Spec.Name = 'Management Network'
        $config.Portgroup[0].Spec.Policy = New-Object VMware.Vim.HostNetworkPolicy
        $config.Vnic = New-Object VMware.Vim.HostVirtualNicConfig[] (1)
        $config.Vnic[0] = New-Object VMware.Vim.HostVirtualNicConfig
        $config.Vnic[0].Portgroup = ''
        $config.Vnic[0].Device = 'vmk0'
        $config.Vnic[0].ChangeOperation = 'edit'
        $config.Vnic[0].Spec = New-Object VMware.Vim.HostVirtualNicSpec
        $config.Vnic[0].Spec.DistributedVirtualPort = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
        $config.Vnic[0].Spec.DistributedVirtualPort.SwitchUuid = $vds.ExtensionData.Uuid
        $config.Vnic[0].Spec.DistributedVirtualPort.PortgroupKey = $vdspg.ExtensionData.MoRef.Value
        $config.ProxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
        $config.ProxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
        $config.ProxySwitch[0].Uuid = $vds.ExtensionData.Uuid
        $config.ProxySwitch[0].ChangeOperation = 'edit'
        $config.ProxySwitch[0].Spec = New-Object VMware.Vim.HostProxySwitchSpec
        $config.ProxySwitch[0].Spec.Backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
        $config.ProxySwitch[0].Spec.Backing.PnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (2)
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[0].PnicDevice = 'vmnic0'
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[0].UplinkPortKey = $hostport.key[0]
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[0].UplinkPortgroupKey = $hostport.PortgroupKey[0]
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[1].PnicDevice = 'vmnic1'
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[1].UplinkPortKey = $hostport.key[1]
        $config.ProxySwitch[0].Spec.Backing.PnicSpec[1].UplinkPortgroupKey = $hostport.PortgroupKey[1]
        $changeMode = 'modify'
        $_this = Get-View -Id $hostnetworksystem.ToString()
        $_this.UpdateNetworkConfig($config, $changeMode) | Out-Null

}
