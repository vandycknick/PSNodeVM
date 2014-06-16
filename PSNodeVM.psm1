#---------------------------------------------------------
# PSNodeVM Global Functions
#---------------------------------------------------------
function Install-Node
{
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -Online) -contains "$($_)" -or $_ -eq "latest" })]
        [String]$Version = "latest"
    )

    Begin
    {
        Write-Verbose "Preparing prerequisites!"
        $config = Get-PSNodeConfig

        Write-Verbose "Check the PSNodeVM current environment with config"
        Check-PSNodeEnv

        
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


        if((Test-Path "$($config.NodeHome)\node.cmd") -eq $false)
        {
            Write-Verbose "Create node.cmd for global access!"
            "@IF EXIST `"%~dp0\latest\node.exe`" ( %~dp0\latest\node.exe %* )" |
            Out-File -FilePath "$($config.NodeHome)\node.cmd" -Encoding ascii -Force        
        }

        Write-Verbose "Download complete file saved at: $outFile"
    }
}

#TO-DO: Implement uninstall-node function -> and export as global function
function Uninstall-Node{}
function Start-Node
{

    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -ListInstalled) -contains "v$($_)" -or $_ -eq "latest" })]
        [String]$Version="latest",
        [String]$Params
    )

    $nodeVersion = @{$true="latest"; $false="v$Version"}[$Version -eq "latest"]

    ."$((Get-PSNodeConfig).NodeHome)$($nodeVersion)\node.exe" $($Params -split " ")
}

#TO-DO: Implement Set-NodeVersion function -> and export the function
function Set-NodeVersion 
{}

function Get-NodeVersion
{
    [CmdletBinding(DefaultParameterSetName="InstalledVersions")]
    Param
    (
        [Parameter(ParameterSetName="InstalledVersions")]
        [Switch]$Installed,
        [Parameter(Mandatory=$false,ParameterSetName="OnlineVersions")]
        [Switch]$Online
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

        if($script:nodeVersions.Count -le 0)
        {
            Write-Verbose "Getting all node versions from $($config.NodeWeb)"
            $nodeVPage = (Fetch-HTTP -Uri "$($config.NodeWeb)").Content

            $script:nodeVersions = ([regex]::Matches($nodeVPage, '(?:href="v(?<NodeVersion>(?:[\d]{1,3}\.){2}[\d]{1,3})\/")') |
                                   %{ [System.Version] $_.Groups["NodeVersion"].Value } |
                                   Sort-Object -Descending -Unique |
                                   %{ $_.toString()})
        }

        Write-Verbose "Output cached node versions array!"
        $Output = $script:nodeVersions
    }

    Write-Output $Output
}

#TO-DO: implement alias functions -> and export as global function
function Get-NodeAlias {}
function Set-NodeAlias {}
function Remove-NodeAlias {}

function Install-Npm
{
   [CmdletBinding()]
   Param()

   Begin
   {
        $config = Get-PSNodeConfig
        
        Write-NodeVerbose "Check the PSNodeVM current environment with config"
        Check-PSNodeEnv

        Write-NodeVerbose "Check if global npm repo is in path: $($env:APPDATA)\npm"
        if((Get-Path) -notcontains "$($env:APPDATA)\npm")
        {
            Write-NodeVerbose "Add $($config.NodeHome) to the user path"
            Add-Path "$($env:APPDATA)\npm" "User" | Out-Null
        }

        Write-NodeVerbose "Remove previous node versions"
        Remove-Item "$($config.NodeHome)\node_modules" -Recurse -Force  -ErrorAction SilentlyContinue
        Remove-Item "$($config.NodeHome)\npm.cmd" -Force  -ErrorAction SilentlyContinue

        Write-NodeVerbose "Get all npm versions from $($config.NPMWeb)"
        $npmVersions = ([regex]::Matches((Fetch-HTTP $config.NPMWeb), '(?:href="(npm-(?<NPMVersion>(?:[\d]{1,3}\.){2}(?:[\d]{1,3}))\.zip)")') |
                       %{ [System.Version] $_.Groups["NPMVersion"].Value } |
                       Sort-Object -Descending -Unique |
                       %{ $_.toString()})

        $npmLatest = $npmVersions[0]
        $zipFile = "npm-$npmLatest.zip"

        Write-NodeVerbose "Latest npm version: $zipFile"
   }
   Process
   {
        Fetch-HTTP "$($config.NPMWeb)/$zipFile" -OutFile "$($config.NodeHome)$zipFile"

        Write-NodeVerbose "Downloaded file: $zipFile, extracting to $($config.NodeHome)\node_modules"
        Extract-Zip "$($config.NodeHome)$zipFile" "$($config.NodeHome)"

        Write-NodeVerbose "Create npmrc file in $($config.NodeHome)node_modules\npm"
        "prefix=`${APPDATA}\npm" | Out-File "$($config.NodeHome)node_modules\npm\npmrc" -Encoding ascii -Force

        Write-NodeVerbose "Cleanup zip file: $($config.NodeHome)\$zipFile"
        Remove-Item "$($config.NodeHome)\$zipFile" -Force  -ErrorAction SilentlyContinue

        Write-Output $npmVersions
   }
}

#---------------------------------------------------------
# Node and npm shorthand commands
#---------------------------------------------------------
#function node
#{
#    #Split $args variable to different string -> otherwise $args will be interpreted as one parameter
#    ."$((Get-PSNodeConfig).NodeHome)latest\node.exe" $($args -split " ")
#}

#function npm
#{
#    node "$((Get-PSNodeConfig).NodeHome)node_modules\npm\bin\npm-cli.js" $args
#}

#---------------------------------------------------------
#PSNodeVM Private Functions
#---------------------------------------------------------
function Get-PSNodeConfig
{
    [CmdletBinding()]
    Param
    (
        [switch]$Reset
    )

    Write-NodeVerbose "Check if script:config variable is present!"

    #will always return the global config object
    if($script:config -eq $null -or $Reset -eq $true)
    {
        Write-NodeVerbose "Variable script:config not present!"

        $fileName = "PSNodeVMConfig.xml"
        $config = @{}
        $configFiles = @("$PSScriptRoot\$fileName";"$PSScriptRoot\..\$fileName";)

        Write-NodeVerbose "Find all config files and create config hash!"
        foreach($path in $configFiles)
        {            
            if(Test-Path $path)
            {
                Write-NodeVerbose "Config file: $path exists!"
                ([xml](Get-Content $path)).PSNodeJSManager.ChildNodes | %{ $config[$_.Name] = $_.InnerText }
            }
        }
        
        Write-NodeVerbose "Check if CPU architecture is defined in config file!"
        if($config.OSArch -eq $null -or $config.OSArch -eq "")
        {
            Write-NodeVerbose "OSArch is not defined in config file determine CPU architecture!"
            $config.OSArch = Get-CPUArchitecture
            Write-NodeVerbose "Current os architecture: $($config.OSArch)"
        }             
        $script:config = $config
    }
    else
    {
        Write-NodeVerbose "Variable script:config is present, serving from cache!"
    }

    Write-Output $script:config
}

function Check-PSNodeEnv
{
    [CmdletBinding()]
    Param()

    Write-NodeVerbose "Get configuration object"
    $config = Get-PSNodeConfig

    Write-NodeVerbose "Checking NodeHome path: $($config.NodeHome)"
    if(!(Test-Path $config.NodeHome))
    {
        Write-NodeVerbose "Home Path not set: creating new home folder: $($config.NodeHome)"
        New-Item -Path $config.NodeHome -ItemType Directory | Out-Null
    }

    Write-NodeVerbose "Check if path contains NodeHome: $($config.NodeHome)"
    if((Get-Path) -notcontains "$($config.NodeHome)")
    {
        Write-NodeVerbose "NodeHome not set: add $($config.NodeHome) to the user path"
        Add-Path "$($config.NodeHome)" "User" | Out-Null
    }
    else
    {
        Write-NodeVerbose "NodeHome is already created in path!"
    }

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

function Get-CPUArchitecture
{
   $arch = (@{
                $true="x64";
                $false="";
            }[(Get-CimInstance Win32_OperatingSystem).OSARchitecture -eq "64-bit"])
      
   Write-Output $arch
}

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

function Get-Path
{
    [CmdletBinding()]
    Param
    (
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )  
    Write-Output ([Array]([System.Environment]::GetEnvironmentVariable("PATH", $Target)) -split ";")
}

function Add-Path
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$PathVar,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    [System.Environment]::SetEnvironmentVariable("PATH", "$((Get-Path $Target) -join ";");$PathVar", $Target)
    Remove-Path "" User
    Write-Output ($env:Path = ((Get-Path Machine) + (Get-Path User) -join ";"))
}


function Remove-Path
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$PathVar,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    $curPath = [System.Collections.ArrayList]([Array](Get-Path $Target))
    $curPath.Remove($PathVar)

    $targetPath = $($curPath -join ";")

    if($curPath.Count -eq 1 -and $curPath[0] -eq "")
    {
        $targetPath = ""
    }

    [System.Environment]::SetEnvironmentVariable("PATH", $targetPath, $Target)

    Write-Output ($env:Path = ((Get-Path Machine) + (Get-Path User) -join ";"))
}

function Write-NodeVerbose
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [String]$LogMessage
    )
    
    $Stack = Get-PSCallStack
    
    Write-Verbose "$($Stack[1].Command): $LogMessage"
}

#---------------------------------------------------------
# Set global module variables | TO-DO find better implementation
#---------------------------------------------------------
$nodeExe = "node.exe"
$nodeVersions = @()
$config = $null

#---------------------------------------------------------
# Aliases
#---------------------------------------------------------
#Set-Alias -Name 7zip -Value "$($env:ProgramFiles)\7-Zip\7z.exe"

#-------------------------------------------------
# Export global functions values and aliases
#---------------------------------------------------------
Export-ModuleMember -Function Install-Node
Export-ModuleMember -Function Start-Node
Export-ModuleMember -Function Get-NodeVersion
Export-ModuleMember -Function Set-NodeVersion
Export-ModuleMember -Function Get-PSNodeConfig

Export-ModuleMember -Function Install-NPM
Export-ModuleMember -Function Get-CPUArchitecture
Export-ModuleMember -Function Get-PSNodeConfig
Export-ModuleMember -Function Get-Path
Export-ModuleMember -Function Add-Path
Export-ModuleMember -Function Remove-Path

Export-ModuleMember -Function npm
Export-ModuleMember -Function node

#---------------------------------------------------------
