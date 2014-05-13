function Extract-Zip
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [String]$Source,
        [ValidateScript({ Test-Path $_ })]
        [String]$Destination = (Get-Location).Path
    )

    Unblock-File $Source

    Add-Type -AssemblyName  System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory(((ls $Source).FullName), $Destination)
}

function Extract-TGZ
{
    
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [String]$Source,
        [ValidateScript({ Test-Path $_ })]
        [String]$Destination = (Get-Location).Path
    )


    #Probably also needs unblocking
    Add-Type -Path "$PSScriptRoot\Assemblies\ICSharpCode.SharpZipLib.dll"

    $inStream = [System.IO.File]::OpenRead("C:\Users\Nick\Downloads\npm-1.4.9.tar")
    $gzipStream = New-Object ICSharpCode.SharpZipLib.GZip.GZipInputStream($inStream)
    $tarArchive = [ICSharpCode.SharpZipLib.Tar.TarArchive]::CreateInputTarArchive($gzipStream)


    $tarArchive.ExtractContents("C:\Users\Nick\Downloads\npm\")
    $tarArchive.Close()
    $gzipStream.Close()
    $inStream.Close()
}

function Extract-GZIP
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [String]$Source,
        [ValidateScript({ Test-Path $_ })]
        [String]$Destination = (Get-Location).Path
    )


    #Probably also needs unblocking
    Add-Type -Path "$PSScriptRoot\Assemblies\ICSharpCode.SharpZipLib.dll"

    $dataBuffer = New-Object Byte[] 4096
    $fs = New-Object System.IO.FileStream("C:\Users\Nick\Downloads\npm-1.4.9.tgz", 
                                           [System.IO.FileMode]::Open, 
                                           [System.IO.FileAccess]::Read)
    $gzipStream = New-Object ICSharpCode.SharpZipLib.GZip.GZipInputStream($fs)
    $fnout = [System.IO.Path]::Combine("C:\Users\Nick\Downloads\npm", "C:\Users\Nick\Downloads\npm-1.4.9")
    $fsout = [system.io.file]::Create("C:\Users\Nick\Downloads\npm-1.4.9.tar")
    [ICSharpCode.SharpZipLib.Core.StreamUtils]::Copy($gzipStream, $fsout, $dataBuffer)

    $fsout.Dispose()
    $gzipStream.Dispose()
    $fs.Dispose()
}

function Extract-Tar
{
    $inStream = [System.IO.File]::OpenRead("C:\Users\Nick\Downloads\npm-1.4.9.tar")

    $tarArchive = [ICSharpCode.SharpZipLib.Tar.TarArchive]::CreateInputTarArchive($inStream)

    $tarArchive.ExtractContents("C:\Users\Nick\Downloads\npm")
    
    $tarArchive.Close();
    $inStream.Close();
}
