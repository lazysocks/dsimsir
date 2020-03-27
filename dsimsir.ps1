<#
.SYNOPSIS
  Utility to manipulate WIM Images
.DESCRIPTION
  Used to mount, dismount, split, add drivers to, and add standard confignet packages. 

.PARAMETER mount
    Mounts specified WIM to default path <script root>\mount or directory specified using -mountPath.
    Default WIM to mount is <script root>\boot.wim unless otherwise specified using -wimFileName 

.PARAMETER dismount
    Dismounts specified WIM in default path <script root\mount or directory speficied using -mountPath.
    Defaults to discard changes, unless -save is used

.PARAMETER split
    Split specified WIM in default path <script root\boot.wim> unless otherwise specified using -wimFileName
    
.PARAMETER export
    Exports WIM using recovery compression, extension must be *.esd.  Defaults to <script root\boot.esd> unless otherwise specified using -destionationFileName

.PARAMETER clear
    Will clear any corrupted mounted images
   
.INPUTS
  None.
.OUTPUTS
  Split and exported WIM files 
.NOTES
  Version:        1.0
  Author:         Kevin McKinley
  Creation Date:  3/27/20
  Purpose/Change: Initial script development
  
.EXAMPLE
 C:\DISMSIR>.\dismsir.ps1 -mount -wimFileName .\wim\CNNMED.wim -index 1 

 .EXAMPLE
 C:\DISMSIR>.\dismsir.ps1 -dismount -save -mountPath .\mount\

 .EXAMPLE
 C:\DISMSIR>.\dismsir.ps1 -drivers 
 C:\DISMSIR>.\dismsir.ps1 -drivers -driversPath .\drivers\
#>
#set params
[CmdletBinding(DefaultParameterSetName="default")]
param (
    # Mount Action - Mount specified WIM
    [Parameter(ParameterSetName="mount")]
    [Switch]
    $mount=$false,

    # Dismount Action - Dismount specified WIM
    [Parameter(ParameterSetName="dismount")]
    [Switch]
    $dismount=$false,

    # Dismount Action - Save
    [Parameter(ParameterSetName="dismount")]
    [Switch]
    $save=$false,

    # Export Action - Export WIM to ESD for maximum compression
    [Parameter(ParameterSetName="export")]
    [Switch]
    $export=$false,

    # Clear Action - Clear corrupted mount points - ALL
    [Parameter(ParameterSetName="default")]
    [Switch]
    $clear=$false,

    # Driver Action - Adds drivers to mount image
    [Parameter(ParameterSetName="drivers")]
    [Switch]
    $drivers,

    # Driver Path - Path to drivers
    [Parameter(ParameterSetName="drivers")]
    [String]
    $driversPath = "$PSScriptroot\drivers",

    # Install Package
    [Parameter(ParameterSetName="packages")]
    [switch]
    $packages = $false,

    # Install Package
    [Parameter(Mandatory=$true, ParameterSetName="packages")]
    [string]
    $arch,     
    # Filename of Wim Image to Mount
    [Parameter(ParameterSetName="mount")]
    [Parameter(ParameterSetName="split")]
    [Parameter(ParameterSetName="export")]
    [String]
    $wimFileName = "$PSScriptroot\wim\boot.wim",

    # WIM Image Index
    [Parameter(ParameterSetName="mount")]
    [Parameter(ParameterSetName="export")]
    [Int32]
    $index = 1,

    # Path to Mount Directory
    [Parameter(ParameterSetName="mount")]
    [Parameter(ParameterSetName="dismount")]
    [Parameter(ParameterSetName="packages")]
    [String]
    $mountPath = "$PSScriptroot\mount",

    # Split Action - Split specified WIM
    [Parameter(ParameterSetName="split")]
    [Switch]
    $split=$false,

    # Split Size
    [Parameter(ParameterSetName="split")]
    [Int64]
    $Size = 4096,

    # Destination Path
    [Parameter(ParameterSetName="split")]
    [Parameter(ParameterSetName="export")]
    [String]
    $destinationFileName = "$PSScriptroot\export\boot.esd"



)

#variables to change
$stdpackages = @(
        "WinPE-HTA",  
        "WinPE-MDAC",  
        "WinPE-NetFx",  
        "WinPE-Scripting",  
        "WinPE-WMI",  
        "WinPE-PowerShell",  
        "WinPE-DismCmdlets",  
        "WinPE-StorageWMI"  
    )

function trycmd ($cmd) {
    try {
        $cmd
    }
    catch {
        $message = "TRAPPED: {0}: '{1}'" -f ($_.Exception.GetType().FullName), ($_.Exception.Message)
        Write-host $message
    }
}

function mountWIM {
    Write-Host ("Mounting WIM image $wimFileName")
    $cmd = Mount-WindowsImage -Path "$mountPat" -Index $index -ImagePath $wimFileName
    trycmd $cmd
}

function dismountWIM {

    if ($save -ne $false) {
        Write-Host ("Image dismount - Saving..")
        $cmd = Dismount-WindowsImage -Path $mountPath -Save
        trycmd $cmd 
    } else {
        Write-Host ("Image dismount discarding changes")
        $cmd = Dismount-WindowsImage -Path $mountPath -Discard          
        trycmd $cmd
    }
}

function exportWIM {
    #powershell export cmdlet does not support recovery compression, only dism does
    $cmd = & DISM /Export-Image /SourceImageFile:$wimFileName /SourceIndex:$index /DestinationImageFile:$destinationFileName /Compress:recovery
    $cmd
}

function splitWIM {
    $cmd = Split-WindowsImage -ImagePath $wimFileName -SplitImagePath $destinationFileName -FileSize $Size
    trycmd $cmd
}

function clearMount {
    $cmd = Clear-WindowsCorruptMountPoint
    trycmd $cmd
}

#PE Packages
function installPackages($arch, $packages){
    
    if ($arch -eq '386') {
        $path = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\X86\WinPE_OCs"
        foreach($package in $packages) {
            $cmd1 = Add-WindowsPackage -Path $mountPath -PackagePath "$path\$package.cab"
            $cmd2 = Add-WindowsPackage -Path $mountPath -PackagePath "$path\en-us\${package}_en-us.cab"
            trycmd $cmd1
            trycmd $cmd2
        } 
    } elseif ($arch -eq 'amd64') {
        $path = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs" 
        foreach($package in $packages) {
            $cmd1 = Add-WindowsPackage -Path $mountPath -PackagePath "$path\$package.cab"
            $cmd2 = Add-WindowsPackage -Path $mountPath -PackagePath "$path\en-us\${package}_en-us.cab"
            trycmd $cmd1
            trycmd $cmd2
        } 
    } else {
        Write-Host ("No option given!")

    }

}

function addDrivers {
    $cmd1 = Add-WindowsDriver -Path $mountPath -Driver $driversPath -Recurse -Verbose
    trycmd $cmd1
}


if ($mount -eq $true) {
    mountWIM
}

if($dismount -eq $true) {
    dismountWIM
}

if ($export -eq $true) {
    exportWIM
}

if ($drivers -eq $true) {
    addDrivers
}

if ($split -eq $true) {
    splitWIM
}

if ($clear -eq $true) {
    $clearMount
}

if ($package -eq $true) {
    installPackages $arch, $stdpackages
}

