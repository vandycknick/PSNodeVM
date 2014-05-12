#---------------------------------------------------------
# PSNodeVM Functions
#---------------------------------------------------------
function Install-Node 
{
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -ListOnline) -contains "v$($_)" -or $_ -eq "latest" })]
        [String]$Version = "latest"
    )

    Begin
    {   
        $config = Get-PSNodeConfig
        $versionCopy = @{$true="latest"; $false="v$($Version)"}[$Version -eq "latest"]        

        $nodeUri = "$($config.NodeWeb)$($versionCopy)/$($config.OSArch)/$($nodeExe)"
        $installPath = "$($config.NodeHome)$($versionCopy)\"
        $outFile = "$($installPath)$($nodeExe)"
    }
    Process
    {
        Write-Verbose "Starting install for node version: $versionCopy"

        if((Test-Path $installPath) -eq $false){
            Write-Verbose "The path $installPath does not exist yet. Creating path ..."
            New-Item $installPath -ItemType Directory | Out-Null
        }    

        Fetch-HTTP -Uri $nodeUri -OutFile $outFile
        Write-Verbose "Download complete file saved at: $outFile"
    }
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
    
    $config = Get-PSNodeConfig
    
    if($PSCmdlet.ParameterSetName -eq "InstalledVersions")
    {
        Write-Verbose "ParemeterSetName == InstalledVersions"
        if($ListInstalled -eq $true){
            $Output =  [Array]((ls "$($config.NodeHome)" -Directory -Filter "v*").Name)
            $Output += "latest -> $(node -v)"
        }
        else{
            $Output = (node -v)
        }
    }
    elseif($PSCmdlet.ParameterSetName -eq "OnlineVersions")
    {
        Write-Verbose "ParemeterSetName == OnlineVersions"

        if($script:nodeVersions.Count -eq 0)
        {
            Write-Verbose "Getting all node versions from $($config.NodeWeb)"
            $script:nodeVersions = @()

            $nodeVPage = (Fetch-HTTP -Uri "$($config.NodeWeb)").Content        
        
            $regex = '<a\s*href="(?<NodeV>(?:v[\d]{1,3}(?:.[\d]{1,3}){2})|(?:latest))\/\s*"\s*>'

            Write-Verbose "Cachinge response in nodeVersions global script variable"
            foreach($nodeVersion in ([regex]::Matches($nodeVPage, $regex))){
                $script:nodeVersions += $nodeVersion.Groups["NodeV"].Value      
            }
        }

        Write-Verbose "Output cached node versions array!"
        $Output = $script:nodeVersions 
    }

    Write-Output $Output
}

function Start-Node{
    
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -ListInstalled) -contains "v$($_)" -or $_ -eq "latest" })]
        [String]$Version,
        [String]$Params   
    )

    if($Version -ne $null)
    {
        $env:DefaultNode = $Version
    }

    node $Params
}

function Install-Npm
{
   $config = Get-PSNodeConfig

   if((Test-Path "$($config.NodeHome)node_modules\npm\bin\npm-cli.js") -eq $false)
   {
        $npmInfo = (ConvertFrom-Json -InputObject (Fetch-HTTP $config.NPMWeb))        

        #Unzip-Archive -Source "$($nvmHome)npm-1.4.9.zip" -Destination $nvmHome        
   }

   Write-Output $npmInfo
}

#---------------------------------------------------------
#PSNodeJSManager Functions
#---------------------------------------------------------
function Get-PSNodeConfig
{
    #will always return the global config object
    if($script:config -eq $null)
    {
        $script:config = (Import-PSNodeJSManagerConfig).PSNodeJSManager
    }

    Write-Output $script:config
}

function Import-PSNodeJSManagerConfig
{
    $fileName = "PSNodeJSManagerConfig.xml"
    $path = @{$true="$PSScriptRoot\..\$fileName"; $false="$PSScriptRoot\$fileName"}[(Test-Path "$PSScriptRoot\..\$fileName")]
    
    $config = ([xml](Get-Content $path)) 

    Write-Output $config
}

function Setup-PSNodeJSManagerEnvironment
{
    [CmdletBinding()]
    Param()

    Write-Verbose "Get configuration object"
    $config = Get-PSNodeConfig
    Write-Verbose $config

    Write-Verbose "Resetting DefaultNode environment var to latest!"
    $env:DefaultNode = (Set-EnvironmentVar DefaultNode latest User)

    Write-Verbose "Checking NodeHome path: $($config.NodeHome)"
    if(!(Test-Path $config.NodeHome))
    {
        Write-Verbose "Home Path not set: creating new home folder: $($config.NodeHome)"
        New-Item -Path $config.NodeHome -ItemType Directory | Out-Null
    }

    Write-Verbose "Install latest node version!"
    Install-Node

    Write-Verbose "Copy $PSScriptRoot\Config\node.cmd to $($config.NodeHome)"
    Copy-Item "$PSScriptRoot\Config\node.cmd" $config.NodeHome
    
    Write-Verbose "Copy $PSScriptRoot\Config\npm.cmd to $($config.NodeHome)"
    Copy-Item "$PSScriptRoot\Config\npm.cmd" $config.NodeHome

    if((Get-Path -Target User) -notcontains $config.NodeHome)
    {
        Write-Verbose "Adding $($config.NodeHome) to the current users path"
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

 function Remove-EnvironmentVar
 {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Variable,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    [System.Environment]::SetEnvironmentVariable($Variable, "", $Target)
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

function Get-Path
{
    Param
    (
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    $Path = ((Get-EnvironmentVar Path $Target) -split ";")

    Write-Output $Path
}

function Set-Path
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$PathVar,
        [Parameter(Mandatory=$true)]
        [String]$Value,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    $Path = Get-Path -Target $Target

    foreach($p in $Path){
        if($p -eq $PathVar){
            $p = $Value
        }
    }

    Write-Output $Path
}

function Get-CPUArchitecture
{
   $arch = (@{
                $true="x64";
                $false="";
            }[(Get-CimInstance Win32_OperatingSystem).OSARchitecture -eq "64-bit"])
            
   Write-Output $arch
}

#---------------------------------------------------------
# Set global module variables | TO-DO find better implementation
#---------------------------------------------------------
(Get-PSNodeConfig).OSArch = [string](Get-CPUArchitecture)

$nodeExe = "node.exe"
$nodeVersions = @()

#---------------------------------------------------------
# Testing functions only |Remove on live
#---------------------------------------------------------


#---------------------------------------------------------
# Aliases
#---------------------------------------------------------
Set-Alias -Name cat -Value Get-Content -option AllScope

#-------------------------------------------------
# Export global functions values and aliases
#---------------------------------------------------------
Export-ModuleMember -Function Install-Node
Export-ModuleMember -Function Update-Node
Export-ModuleMember -Function Set-Node
Export-ModuleMember -Function Start-Node
Export-ModuleMember -Function Get-NodeVersion
Export-ModuleMember -Function Set-NodeVersion

Export-ModuleMember -Function Setup-PSNodeJSManagerEnvironment

Export-ModuleMember -Function Get-Path
Export-ModuleMember -Function Install-NPM
Export-ModuleMember -Function Get-CPUArchitecture
Export-ModuleMember -Function Get-PSNodeConfig


#---------------------------------------------------------