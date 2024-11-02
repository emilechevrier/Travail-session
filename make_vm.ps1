# Define parameters for the VM
$VMName = "MyWindowsVM"                 # Name of the VM
$VMPath = "C:\HyperV\$VMName"           # Location where the VM files will be stored
$VHDPath = "$VMPath\$VMName.vhdx"       # Path for the VHD file
$ISOPath = "C:\Path\To\Your\Windows.iso" # Path to the Windows ISO file
$MemoryStartupBytes = 4GB                # Startup memory for the VM
$SwitchName = "Default Switch"           # Name of the Virtual Switch

# Create VM directory if it doesn't exist
if (-not (Test-Path -Path $VMPath)) {
    New-Item -ItemType Directory -Path $VMPath
}

# Create a new virtual machine
New-VM -Name $VMName -MemoryStartupBytes $MemoryStartupBytes -BootDevice CD -Path $VMPath -SwitchName $SwitchName

# Create a new virtual hard disk
New-VHD -Path $VHDPath -SizeBytes 60GB -Dynamic

# Attach the virtual hard disk to the VM
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

# Attach the ISO file to the VM's DVD drive
Add-VMDvdDrive -VMName $VMName -Path $ISOPath

# Start the VM
Start-VM -Name $VMName

Write-Host "Virtual Machine '$VMName' created and started successfully."
