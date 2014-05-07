#Set default constant vars
#Set nvmHome to  C:\Program Files\nodejs
[String] $nvmHome = "C:\PSNodeJS\"
[String] $nodeDist = "http://nodejs.org/dist/"
[String] $npmDist = "https://registry.npmjs.org/npm"
[String] $nodeExe = "node.exe"
[String] $nodeVersionFile = "npm-versions.txt"
[String] $OSArch = ""

[Array] $npmVersions = @()

#Temporary variable
[String] $Version = "latest/"

function Install-Node 
{
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -ListOnline) -contains "v$($_)" -or $_ -eq "latest" })]
        [String]$Version = "latest"
    )
    
    $versionCopy = @{$true="latest/"; $false="v$($Version)/"}[$Version -eq "latest"]        

    if((Test-Path "$($nvmHome)$($versionCopy)") -eq $false){
        New-Item "$($nvmHome)$($versionCopy)" -ItemType Directory | Out-Null
    }    
    
    Fetch-HTTP -Uri "$($nodeDist)$($versionCopy)$($OSArch)$($nodeExe)" -OutFile "$($nvmHome)$($versionCopy)$($nodeExe)"
}

function Update-Node
{
    Install-Node
}

function Set-NodeVersion
{
}

function Get-NodeVersion
{
    [CmdletBinding(DefaultParameterSetName="InstalledVersions")]
    Param
    (
        [Parameter(ParameterSetName="InstalledVersions")]
        [Switch]$ListInstalled,
        [Parameter(Mandatory=$false,ParameterSetName="OnlineVersions")]
        [Switch]$ListOnline      
    )

    if($PSCmdlet.ParameterSetName -eq "InstalledVersions")
    {
        if($ListInstalled -eq $true){
            $Output =  ((ls "$($nvmHome)" -Directory -Filter "v*").Name)
            $Output += "latest -> $(node -v)"
        }
        else{
            $Output = (node -v)
        }
    }
    elseif($PSCmdlet.ParameterSetName -eq "OnlineVersions")
    {
        if($ListOnline -eq $true){
            $Output = Get-AllNodeVersions
        }
    }

    Write-Output $Output
}

function Get-AllNodeVersions
{
    [CmdletBinding()]
    Param
    ()

    if($script:npmVersions.Count -eq 0){
        $script:npmVersion = @()

        $nodeVPage = (Fetch-HTTP -Uri "$($nodeDist)").Content        
        
        foreach($nodeVersion in ([regex]::Matches($nodeVPage, '<a\s*href="(?<Node>v[\d]+\.[\d]+.[\d]+)/\s*"\s*>'))){
            $script:npmVersions += $nodeVersion.Groups["Node"].Value      
        }
    }
        
    Write-Output $script:npmVersions
}

#To implement
function Start-Node{
    node $args
}

function Install-Npm
{
   if((Test-Path "$($nvmHome)node_modules\npm\bin\npm-cli.js") -eq $false)
   {
        $npmInfo = (ConvertFrom-Json -InputObject (Fetch-HTTP $npmDist))        

        #Unzip-Archive -Source "$($nvmHome)npm-1.4.9.zip" -Destination $nvmHome
   }
}

#---------------------------------------------------------
# Helper functions
#---------------------------------------------------------
function Get-EnvironmentVar
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Variable,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )
    Write-Output ([System.Environment]::GetEnvironmentVariable($Variable, $Target))
 }

function Set-EnvironmentVar
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Variable,
        [Parameter(Mandatory=$true)]
        [String]$Value,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    [System.Environment]::SetEnvironmentVariable($Variable, $Value, $Target)
    Write-Output (Get-EnvironmentVar $Variable $Target)
 }

function Fetch-HTTP
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [String]$Uri,
        [Parameter(Mandatory=$false, Position=1)]
        [String]$OutFile
    )

    if($env:HTTP_PROXY -eq $null){
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    }
    else{
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Proxy $env:HTTP_PROXY
    }
}

function Unzip-Archive
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

#---------------------------------------------------------
# Aliases
#---------------------------------------------------------
Set-Alias -Name cat -Value Get-Content -option AllScope

#---------------------------------------------------------
# Prereq Tests
#---------------------------------------------------------
if((Get-EnvironmentVar CurNodeVer Machine) -eq $null)
{
    Set-EnvironmentVar "CurNodeVer" "latest" "User"
    $env:CurNodeVer = "latest"
}

if((Test-Path $nvmHome) -eq $false)
{
    New-Item $nvmHome -ItemType Directory
}

if((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq "64-Bit")
{
    $OSArch = "x64/"
}

Install-Npm

#-------------------------------------------------
# Export global functions values and aliases
#---------------------------------------------------------
Export-ModuleMember -Function Install-Node
Export-ModuleMember -Function Update-Node
Export-ModuleMember -Function Set-Node
Export-ModuleMember -Function Start-Node
Export-ModuleMember -Function Get-NodeVersion
Export-ModuleMember -Function Set-NodeVersion
Export-ModuleMember -Function Get-AllNodeVersions
#---------------------------------------------------------

#Make sure everything is installed on local drive
#previously used $home to install to local dir
#in some corporations the $home dir is a network share to sync documents,.. across computers
#in this case using the $home dir introduced significant latency
# -> decided to use a predifined dir on the c:/ drive -> find a better way and location to be sure that i don't install on share and do not need c root dir

#find a way to introduce npmrc -> to point list -g to appdata roaming dir -> this is also used by default node installer