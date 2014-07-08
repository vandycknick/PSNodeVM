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
        Log-Verbose "Preparing prerequisites!"
        $config = Get-PSNodeConfig

        Log-Verbose "Check the PSNodeVM current environment with config"
        Check-PSNodeEnv


        $versionCopy = @{$true="latest"; $false="v$($Version)"}[$Version -eq "latest"]

        $nodeUri = "$($config.NodeWeb)$($versionCopy)/$($config.OSArch)/$($nodeExe)"
        $installPath = "$($config.NodeHome)$($versionCopy)\"
        $outFile = "$($installPath)$($nodeExe)"
    }
    Process
    {
        Log-Verbose "Starting install for node version: $versionCopy"

        if((Test-Path $installPath) -eq $false){
            Log-Verbose "The path $installPath does not exist yet. Creating path ..."
            New-Item $installPath -ItemType Directory | Out-Null
        }

        Fetch-HTTP -Uri $nodeUri -OutFile $outFile


        if((Test-Path "$($config.NodeHome)\node.cmd") -eq $false)
        {
            Log-Verbose "Create node.cmd for global access!"
            "@IF EXIST `"%~dp0\latest\node.exe`" ( %~dp0\latest\node.exe %* )" |
            Out-File -FilePath "$($config.NodeHome)\node.cmd" -Encoding ascii -Force
        }

        Log-Verbose "Download complete file saved at: $outFile"
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
        [ValidateScript({(Get-NodeVersion -Installed) -contains "$($_)" -or $_ -eq "latest" })]
        [String]$Version="latest",
        [String]$Params
    )

    $nodeVersion = @{$true="latest"; $false="v$Version"}[$Version -eq "latest"]

    ."$((Get-PSNodeConfig).NodeHome)$($nodeVersion)\node.exe" $($Params -split " ")
}

function Set-NodeVersion
{
    [CmdletBinding()]
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$|latest")]
        [ValidateScript({(Get-NodeVersion -Installed) -contains "$($_)" -or $_ -eq "latest" })]
        [String]$Version = "latest"
    )

    $versionCopy = @{$true="latest"; $false="v$($Version)"}[$Version -eq "latest"]

    Log-Verbose "Set default node version to $Version"

    "@IF EXIST `"%~dp0\$($versionCopy)\node.exe`" ( %~dp0\$($versionCopy)\node.exe %* )" |
    Out-File -FilePath "$($config.NodeHome)\node.cmd" -Encoding ascii -Force
}

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

    Log-Verbose "Get node configuration"
    $config = Get-PSNodeConfig

    if($PSCmdlet.ParameterSetName -eq "InstalledVersions")
    {
        Log-Verbose "ParemeterSetName == InstalledVersions"
        if($Installed -eq $true){

            $localVer += [Array]((ls "$($config.NodeHome)" -Directory -Filter "v*").Name)
            Log-Verbose "Get installed latest version."
            $latest = Write-Output (."$((Get-PSNodeConfig).NodeHome)latest\node.exe"  "-v")
            Log-Verbose "Latest version: $latest"
            $Output = [Array] "latest -> $([regex]::Match($latest, "v(?<Version>[\d]+\.[\d]+.[\d]+)$").Groups["Version"].Value)"
            Log-Verbose "Transform local versions array (vX.X.X) to (X.X.X), sort descending"
            $Output += ($localVer |
                        % { [System.Version]([regex]::Match($_, "v(?<Version>[\d]+\.[\d]+.[\d]+)$").Groups["Version"].Value) } |
                        Sort-Object -Descending -Unique |
                        %{ $_.toString()})
        }
        else{
            $Output = (node -v)
        }
    }
    elseif($PSCmdlet.ParameterSetName -eq "OnlineVersions")
    {
        Log-Verbose "ParemeterSetName == OnlineVersions"

        if($script:nodeVersions.Count -le 0)
        {

            $oldProgressRef = $ProgressPreference

            Log-Verbose "Turn of progres updates: `$ProgressPreference = $ProgressPreference "
            $ProgressPreference = SilentlyContinue

            Log-Verbose "Getting all node versions from $($config.NodeWeb)"
            $nodeVPage = (Fetch-HTTP -Uri "$($config.NodeWeb)").Content

            Log-Verbose "Reset `$ProgressPreference to original value = $oldProgressRef"
            $ProgressPreference = $oldProgressRef

            $script:nodeVersions = ([regex]::Matches($nodeVPage, '(?:href="v(?<NodeVersion>(?:[\d]{1,3}\.){2}[\d]{1,3})\/")') |
                                   %{ [System.Version] $_.Groups["NodeVersion"].Value } |
                                   Sort-Object -Descending -Unique |
                                   %{ $_.toString()})
        }

        Log-Verbose "Output cached node versions array!"
        $Output = $script:nodeVersions
    }

    Write-Output $Output
}

function Get-NPMVersions
{
    [CmdletBinding()]
    Param()
    Log-Verbose "Get node configuration"
    $config = Get-PSNodeConfig

	if($script:npmVersions.Count -le 0)
    {
		Log-Verbose "NPMVersions variable not in cache!"
		Log-Verbose "Get all npm versions from $($config.NPMWeb)"
		$script:npmVersions = ([regex]::Matches((Fetch-HTTP $config.NPMWeb), '(?:href="(npm-(?<NPMVersion>(?:[\d]{1,3}\.){2}(?:[\d]{1,3}))\.zip)")') |
						   %{ [System.Version] $_.Groups["NPMVersion"].Value } |
						   Sort-Object -Descending -Unique |
						   %{ $_.toString()})
	}
	else
	{
		Log-Verbose "NPMVersions already present, serving from cache!"
	}

    Log-Verbose "Return all npm versions!"
    Write-Output $script:npmVersions
}

function Install-Npm
{
   [CmdletBinding()]
   Param
   (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$")]
        [ValidateScript({(Get-NPMVersions) -contains "$($_)" })]
        [AllowEmptyString()]
        [String]$Version
   )
   Begin
   {
        Log-Verbose "Get node configuration"
        $config = Get-PSNodeConfig

        Log-Verbose "Check the PSNodeVM current environment with config"
        Check-PSNodeEnv

        Log-Verbose "Check if global npm repo is in path: $($env:APPDATA)\npm"
        if((Get-Path) -notcontains "$($env:APPDATA)\npm")
        {
            Log-Verbose "Add $($config.NodeHome) to the user path"
            Add-Path "$($env:APPDATA)\npm" "User" | Out-Null
        }

        Log-Verbose "Remove previous node versions"
        Remove-Item "$($config.NodeHome)\node_modules" -Recurse -Force  -ErrorAction SilentlyContinue
        Remove-Item "$($config.NodeHome)\npm.cmd" -Force  -ErrorAction SilentlyContinue


        if($Version -eq $null -or $Version -eq "")
        {
            $npmLatest = (Get-NPMVersions)[0]
        }
        else
        {
            $npmLatest = $Version
        }

        $zipFile = "npm-$npmLatest.zip"

        Log-Verbose "Installing npm version: $zipFile"
   }
   Process
   {
        Fetch-HTTP "$($config.NPMWeb)/$zipFile" -OutFile "$($config.NodeHome)$zipFile"

        Log-Verbose "Downloaded file: $zipFile, extracting to $($config.NodeHome)\node_modules"
        Extract-Zip "$($config.NodeHome)$zipFile" "$($config.NodeHome)"

        Log-Verbose "Create npmrc file in $($config.NodeHome)node_modules\npm"
        "prefix=`${APPDATA}\npm" | Out-File "$($config.NodeHome)node_modules\npm\npmrc" -Encoding ascii -Force

        Log-Verbose "Cleanup zip file: $($config.NodeHome)\$zipFile"
        Remove-Item "$($config.NodeHome)\$zipFile" -Force  -ErrorAction SilentlyContinue
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

    Log-Verbose "Check if script:config variable is present!"

    #will always return the global config object
    if($script:config -eq $null -or $Reset -eq $true)
    {
        Log-Verbose "Variable script:config not present!"

        $fileName = "PSNodeVMConfig.xml"
        $config = @{}
        $configFiles = @("$PSScriptRoot\$fileName";"$PSScriptRoot\..\$fileName";)

        Log-Verbose "Find all config files and create config hash!"
        foreach($path in $configFiles)
        {
            if(Test-Path $path)
            {
                Log-Verbose "Config file: $path exists!"
                ([xml](Get-Content $path)).PSNodeJSManager.ChildNodes | %{ $config[$_.Name] = $_.InnerText }
            }
        }

        Log-Verbose "Check if CPU architecture is defined in config file!"
        if($config.OSArch -eq $null -or $config.OSArch -eq "")
        {
            Log-Verbose "OSArch is not defined in config file determine CPU architecture!"
            $config.OSArch = Get-CPUArchitecture
            Log-Verbose "Current os architecture: $($config.OSArch)"
        }
        $script:config = $config
    }
    else
    {
        Log-Verbose "Variable script:config is present, serving from cache!"
    }

    Write-Output $script:config
}

function Check-PSNodeEnv
{
    [CmdletBinding()]
    Param()

    Log-Verbose "Get configuration object"
    $config = Get-PSNodeConfig

    Log-Verbose "Checking NodeHome path: $($config.NodeHome)"
    if(!(Test-Path $config.NodeHome))
    {
        Log-Verbose "Home Path not set: creating new home folder: $($config.NodeHome)"
        New-Item -Path $config.NodeHome -ItemType Directory | Out-Null
    }

    Log-Verbose "Check if path contains NodeHome: $($config.NodeHome)"
    if((Get-Path) -notcontains "$($config.NodeHome)")
    {
        Log-Verbose "NodeHome not set: add $($config.NodeHome) to the user path"
        Add-Path "$($config.NodeHome)" "User" | Out-Null
    }
    else
    {
        Log-Verbose "NodeHome is already created in path!"
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

function Log-Verbose
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
$npmVersions = @()
$config = $null

#-------------------------------------------------
# Get all node version on module load
#---------------------------------------------------------
Get-NodeVersion -Online

#-------------------------------------------------
# Create aliases
#---------------------------------------------------------
Set-Alias -Name gnv -Value Get-NodeVersion
Set-Alias -Name snv -Value Set-NodeVersion
Set-Alias -Name in -Value Install-Node

#-------------------------------------------------
# Export global functions values and aliases
#---------------------------------------------------------
Export-ModuleMember -Alias * -Function Install-Node, Start-Node, Get-NodeVersion, Set-NodeVersion,
                                        Install-NPM, Get-NPMVersions


#---------------------------------------------------------
