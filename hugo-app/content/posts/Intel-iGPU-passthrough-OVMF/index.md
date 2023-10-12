+++
title = 'Intel iGPU Passthrough for OVMF'
date = 2023-09-26T01:54:10Z

+++




# Why passthrough an Integrated GPU? 

Why pass an iGPU to a VM ? Because i wanted to , duh... 

Well in my particular case, i wanted to use the integrated Display/Laptop Displays the outputs for my VM and because i wanted to use all the available screen real estate possible ,while running a headless hypervisor underneath -Proxmox in this case.


# Prerequisites

This guide is mostly for Proxmox users and assumes that you have the following other requirements as well:

- Intel iGPUs on CPUs from Haswell to CometLake should work this (i've tested with Haswell,Broadwell).
- Proxmox 7.X (I assume Proxmox 8.X should work ,but i have not tested it myself).
- Access to your UEFI firmware blobs/updates .
- For the guest operating systems, i've tested Windows 10 and Windows 11.
- A linux environment with Podman where you can compile

# Guide

There will be two parts to the guide, the first is preparing the necessary files ,then compiling your own version of OVMF with the Intel GOP (Graphics Output Protocol) driver and VBT (Video BIOS Tables) files. 

The second part describes setting up Proxmox and the virtual machine configuration files
## vBios ROM override

### Q35 virtual machines
For q35 virtual machines download the following vBIOS rom override https://github.com/patmagauran/i915ovmfPkg/releases/tag/V0.2.1. 

I have also had success compiling it myself and will link my compiled here if you want to skip the hassle of doing it: [i915ovmf.rom](i915ovmf.rom). 

Otherwise feel free to compile it yourself from the repository linked, i will not discuss this in the guide as it is not that critical.
 
### i440fx virtual machines
For i440fx virtual machines ,download the following file from : [vbios_gvt_uefi.rom](https://web.archive.org/web/20201020144354/http://120.25.59.132:3000/vbios_gvt_uefi.rom) 

## Extract and compile OVMF

You can either choose to extract the files yourself from the BIOS files or download based on the architecture of your CPU it from here: https://winraid.level1techs.com/t/efi-lan-bios-intel-gopdriver-modules/33948/2

### Extracting IntelGopDriver.efi and Vbt.bin from your bios:

Download this tool as we are going to need this to extract the necessary files from here: https://github.com/LongSoft/UEFITool


Then download your BIOS/Firmware update files from your motherboard/OEM manufacturer. Quite often these are installer setups that can be extracted or zip file that contain a .efi or .bin file or named something else.

After scouring the interwebs, i found some BIOS/Firmware update files for my Clevo NP850EP6  and here's what a valid file i choose looks like for example.

![UEFITool_VALID](UEFITool_VALID.png)




With those .efi/.bin files in mind , you can search for the following with UEFITool

#### IntelGopDriver.efi:

If the GUID was not identified by UEFITools, open with the search by pressing Ctrl+F and try unicode text searching  "**``Intel(R) Gop Driver``**", or hex searching **``4900 6e00 7400 6500 6c00 2800 5200 2900 2000 4700 4f00 5000 2000 4400 7200 6900 7600 6500 7200``**  as shown below
![UEFITool_VALID](IntelGOPsearch.png)

Once you have identified it, right click on it and click on **'Extract body'**  as shown below 
![Alt text](ExtractBody.png)

And name it IntelGopDriver.efi, keep this file handy.

#### Vbt.bin:
Similar to IntelGopDriver.efi perform the above steps to search for and extract  **``Vbt.bin``**.

Some pointers to search for it is to try non unicode text searching **``$VBT``**, or hex searching **``2456 4254``** the file is usually began with non unicode **``$VBT <codename>``**, such as **``$VBT SKYLAKE``**


Once you have identified it, right click on it and click on **'Extract body'** and name it **``"Vbt.bin"``**

#### Compile custom OVMF with Intel GOP/VBT

Once we have the **``"IntelGopDriver.efi"``** and **``"Vbt.bin"``** files extracted ,copy them to a Linux environment of your choice that has **Podman** installed, it will be needed for the next step for compiling your own OVMF EFI image.

Once you have Podman ready ,go ahead and clone the **kethen/edk2-build-intel-gop** repo.

```
git clone https://github.com/Kethen/edk2-build-intel-gop

```

Copy the **``"IntelGopDriver.efi"``** and **``"Vbt.bin"``** files into newly created folder named **``gop``** in the cloned repo directory and then build the image
```
cd edk2-build-intel-gop
mkdir gop
cp <intel gop driver efi> gop/IntelGopDriver.efi
cp <intel gop vbt> gop/Vbt.bin
```

Build the image with the following command
```
bash build_ovmf.sh
```

The built OVMF files can be found in **``edk2/Build/OvmfX64/DEBUG_GCC5/FV/``** directory,the files you are searching for are **``OVMF_CODE.fd``** and **``OVMF_VAR.fd``**. Copy these files to your Proxmox host.

### Enabling IOMMU in Linux
Enable IOMMU by doing the following

Assuming that you are using Proxmox and not using ZFS on root. Edit the kernel cmdline at:
```
vim /etc/default/grub
```
Edit the following line: **``GRUB_CMDLINE_LINUX_DEFAULT=``** and add the following arguments 

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

An explanation for the arguments for kernel cmd line
**``intel_iommu=on``** enable IOMMU for Intel chipsets.

**``intel_iommu=pt``** enables turns on IOMMU tagging only for devices configured for pass through, allowing the host to ignore it for local host-only devices (hereby improving performance in certain cases)

And then apply the changes to the GRUB configuration with the following commandline.
```
update-grub
```
### Blacklisting Intel kernel modules

Add these lines to to mo blacklist the Intel i915 drivers from loading at **``/etc/modprobe.d/blacklist.conf``**

```
blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi
blacklist i915
```

### Enable I/O interrupt remapping and ignore MSRs

Run the following the commands to enable allow I/O interrupt remapping and ignore MSRs

```
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```


### Blacklisting the PCI devices

Get the PCI Vendor/Device ids to be blacklisted with ``lspci``. Usually in my experience Intel iGPUs are always located at ``00:02.0``
```
lspci -n -s 00:02.0
```
For example 
> ``00:02.0 0300: 8086:3e9b``

**``8086:3e9b``** is the PCI id that we need and then we add to the line below and 


```
echo "options vfio-pci ids=<PCI_ID> "> /etc/modprobe.d/vfio.conf
```

### Update initramfs and reboot

And finally apply all the above changes by updating the initramfs and rebooting for the changes to take effect
```
update-initramfs -u
```

### Proxmox Virtual machine configuration



## For Q35 virtual machines


Assuming you have moved the **``i915ovmf.rom``** to **``/usr/share/kvm``**  Then **``OVMF_CODE.fd``** and **``OVMF_VAR.fd``** to a folder at **``/root/OVMF``**

Set your BIOS type in your Proxmox VM configuration to be SeaBIOS in order to prevent a conflict with custom arguments we set below 

And then set your display type to none in your Proxmox VM configuration as well.


Add the following lines to your Proxmox VM configuration located at **``/etc/pve/qemu-server/<VMID.conf>``** where VMID is the VM id of your Proxmox virtual machine

```
args: -device vfio-pci,host=00:02.0,bus=pci.0,addr=0x2,x-igd-opregion=on,x-igd-gms=1,romfile=i915ovmf.rom  -drive 'if=pflash,unit=0,format=raw,readonly,file=/root/OVMF/OVMF_CODE.fd' -drive 'if=pflash,unit=1,format=raw,id=drive-efidisk0,file=/root/bios/OVMF/OVMF_VARS.fd'
```



This is what  a sample Proxmox configuration could look like
```
args: -device vfio-pci,host=00:02.0,bus=pci.0,addr=0x2,x-igd-opregion=on,x-igd-gms=1,romfile=i915ovmf.rom  -drive 'if=pflash,unit=0,format=raw,readonly,file=/root/bios/OVMFintelGOP/OVMF_CODE.fd' -drive 'if=pflash,unit=1,format=raw,id=drive-efidisk0,file=/root/bios/OVMFintelGOP/OVMF_VARS.fd' 
balloon: 0
bios: seabios
boot: order=virtio0;net0
cores: 4
cpu: host
localtime: 0
machine: pc-q35-7.2
memory: 8192
name: q35-iGPU
net0: virtio=8E:A6:82:97:9C:C1,bridge=vmbr0
numa: 0
ostype: win11
scsihw: virtio-scsi-single
sockets: 1
tablet: 0
vga: none
virtio0: cephrbd-aus:vm-109-disk-0,cache=unsafe,iothread=1,size=32G

```

## For i440fx virtual machines


Assuming you have moved the **``vbios_gvt_uefi.rom``** to **``/usr/share/kvm``**  Then from the custom compiled OVMF ,the files **``OVMF_CODE.fd``** and **``OVMF_VAR.fd``** to a folder at **``/root/OVMF``**

Add the following lines to your Proxmox VM configuration located at **``/etc/pve/qemu-server/<VMID.conf>``** where VMID is the VM id of your Proxmox virtual machine


```
args: -device vfio-pci,host=00:02.0,bus=pci.0,addr=0x2,x-igd-opregion=on,x-igd-gms=1,romfile=vbios_gvt_uefi.rom -drive 'if=pflash,unit=0,format=raw,readonly,file=/root/bios/OVMFintelGOP/OVMF_CODE.fd' -drive 'if=pflash,unit=1,format=raw,id=drive-efidisk0,file=/root/bios/OVMFintelGOP/OVMF_VARS.fd' 
```
This is what  a sample Proxmox configuration could look like


```
args: -device vfio-pci,host=00:02.0,bus=pci.0,addr=0x2,x-igd-opregion=on,x-igd-gms=1,romfile=vbios_gvt_uefi.rom -drive 'if=pflash,unit=0,format=raw,readonly,file=/root/bios/OVMFintelGOP/OVMF_CODE.fd' -drive 'if=pflash,unit=1,format=raw,id=drive-efidisk0,file=/root/bios/OVMFintelGOP/OVMF_VARS.fd' 
balloon: 0
bios: seabios
boot: order=virtio0;ide2
cores: 4
cpu: host
ide2: none,media=cdrom
localtime: 0
machine: pc-i440fx-7.2
memory: 2048
meta: creation-qemu=7.2.0,ctime=1689492646
name: i440fx-iGPU
net0: virtio=36:26:74:C2:9A:72,bridge=vmbr0,firewall=1
numa: 0
ostype: win11
scsihw: virtio-scsi-single
sockets: 1
tablet: 0
vga: none
virtio0: local-lvm:vm-120-disk-0,cache=unsafe,iothread=1,size=32G
```
### Additional step for i440fx virtual machines 

Edit /usr/share/perl5/PVE/QemuServer.pm  and add this line

``` 
$bridges->{2} = 1 if $vmid != [VMID ]; 

```

Where VMID is the VMID of your virtual machine ,so for example my VMID of iGPU virtual machine is 140.

You will the find the block at line 4130 and here is an example modification

```
    if (!$q35) {
        # add pci bridges
        if (min_version($machine_version, 2, 3)) {
           $bridges->{1} = 1;
           #$bridges->{2} = 1;  disabled
           $bridges->{2} = 1 if $vmid != 140;       #Legacy IGD passthrough fix
        }

        $bridges->{3} = 1 if $scsihw =~ m/^virtio-scsi-single/;

    }
```


Now just refresh the change by running the following
```
pvedaemon restart
```








### Explanation of the QEMU arguments used


A little explanation for QEMU arguments 


- `-device vfio-pci,host=00:02.0,bus=pci.0,addr=0x2`: Passthrough the iGPU at PCI address 00:2.0 on PCI Bus 0 at Device 2 (just matching what a physical machine sees  )
- `x-igd-opregion=on` It exposes opregion (VBT included) to guest driver so that the guest driver could parse display connector information from. This property is mandatory for the Windows VM to enable display output.
- `x-igd-gms=1`This argument specifies sets a value multiplied by 32 as the amount of pre-allocated memory (in units of MB) to support IGD in VGA modes
- `romfile=i915ovmf.rom`: Specifies a ROM file for the device, in this case we are using the i915ovmf.rom or vbios_gvt_uefi.rom that we accquired earlier.

- `-drive 'if=pflash,unit=0,format ..... F/OVMF_VARS.fd' ` : This argument is how we passthrough the custom compiled OVMF image that we compiled ourselves for iGPU passthrough 

### Configuration complete

That's about the configuration you should need for iGPU passthrough in Proxmox.


When you boot your machine ,you should be greeted with the Tiano-core boot screen if you followed all the steps and everything worked out alright.

Feel free to install intel drivers once you have working passthrough.

I've had success with Haswell,Broadwell,Skylake,Coffeelake iGPUs

### Other notes
Broadwell also has issues with kernels newer than 5.3 ,so downgrade the kernel.You’ll see `Disabling IOMMU for graphics on this chipset` in the dmesg, and the integrated GPU will not be visible for passthrough.

[https://github.com/torvalds/linux/commit/1f76249cc3bebd6642cb641a22fc2f302707bfbb](https://github.com/torvalds/linux/commit/1f76249cc3bebd6642cb641a22fc2f302707bfbb)




