#Set default constant vars
#Set nvmHome to  C:\Program Files\nodejs

$config = (Import-PSNodeJSManagerConfig).PSNodeJSManager

[String] $nodeExe = "node.exe"
[Array] $npmVersions = @()

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
        $versionCopy = @{$true="latest\"; $false="v$($Version)\"}[$Version -eq "latest"]        

        $nodeUri = "$($config.NodeWeb)$($versionCopy)$($config.OSArch)$($nodeExe)"
        $installPath = "$($config.NodeHome)$($versionCopy)"
        $outFile = "$($installPath)$($nodeExe)"
    }
    Process
    {
        Write-Verbose "Starting install for node version: $versionCopy"

        if((Test-Path $installPath) -eq $false){
            Write-Verbose "The path $installPath does not exist yet. Creating path ..."
            New-Item $installPath -ItemType Directory | Out-Null
        }    

        Write-Verbose "$nodeUri"
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

    if($PSCmdlet.ParameterSetName -eq "InstalledVersions")
    {
        if($ListInstalled -eq $true){
            $Output =  ((ls "$($config.NodeHome)" -Directory -Filter "v*").Name)
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

        $nodeVPage = (Fetch-HTTP -Uri "$($config.NodeWeb)").Content        
        
        $regex = '<a\s*href="(?<NodeV>(?:v[\d]{1,3}(?:.[\d]{1,3}){2})|(?:latest))\/\s*"\s*>'

        foreach($nodeVersion in ([regex]::Matches($nodeVPage, $regex))){
            $script:npmVersions += $nodeVersion.Groups["NodeV"].Value      
        }
    }
        
    Write-Output $script:npmVersions
}

#To implement
function Start-Node{
    
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -ListInstalled) -contains "v$($_)" -or $_ -eq "latest" })]
        [String]$Version = "latest",
        [String]$Params   
    )

    $env:DefaultNode = $Version
   
    node $Params
}

function Install-Npm
{
   if((Test-Path "$($config.NodeHome)node_modules\npm\bin\npm-cli.js") -eq $false)
   {
        $npmInfo = (ConvertFrom-Json -InputObject (Fetch-HTTP $config.NPMWeb))        

        #Unzip-Archive -Source "$($nvmHome)npm-1.4.9.zip" -Destination $nvmHome        
   }

   return $npmInfo
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

function get-config
{
    Write-Output $config
}

#---------------------------------------------------------
# Aliases
#---------------------------------------------------------
Set-Alias -Name cat -Value Get-Content -option AllScope

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