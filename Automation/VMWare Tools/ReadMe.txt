Tools used to manage VMs in a VMWare environment (ESX-6.7)
DeleteSnapshotChoose.ps1 -  Connects to ESXi 6 or above host and allows for group deletion of snapshots and single deletion if snapshots number or order is different from a set server/domain controller. 

CheckVMDriveSize.ps1 - Checks VM Provisioned drive sizes

CheckVMsForUSBVirtualHardware.ps1 - Checks for USB Virtual hardware on VMs

Export_ALL_OVF_Get_VMX.ps1 - Shuts down all VMs, deletes snapshots, disconnects CD drives, exports VMs, saves VMX file, powers all VMs back on

PowerOff-All.ps1 - Powers off all VMs, allows for ordered primary servers, and unordered secondary servers

PowerOn-All.ps1 - Powers on all VMs, allows for ordered primary servers, and unordered secondary servers

SnapshotAllVMs.ps1 - Disconnects CD drives then snapshot all VMs for domain, ESX 6 or above

