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
        $versionCopy = @{$true="latest"; $false="v$($Version)"}[$Version -eq "latest"]

        $nodeUri = "$($config.NodeWeb)$($versionCopy)/$($config.OSArch)/$($nodeExe)"
        $installPath = "$($config.NodeHome)$($versionCopy)\"
        $outFile = "$($installPath)$($nodeExe)"

        Write-Verbose "Check PSNodeVM environment from provided config."
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
   $config = Get-PSNodeConfig

   #if((Test-Path "$($config.NodeHome)node_modules\npm\bin\npm-cli.js") -eq $false)
   #{
        $npmVersions = ([regex]::Matches((Fetch-HTTP $config.NPMWeb), '(?:href="(npm-(?<NPMVersion>(?:[\d]{1,3}\.){2}(?:[\d]{1,3}))\.zip)")') |
                       %{ [System.Version] $_.Groups["NPMVersion"].Value } |
                       Sort-Object -Descending -Unique |
                       %{ $_.toString()})

        $npmLatest = $npmVersions[0]


        $zipFile = "npm-$npmLatest.zip"

        Fetch-HTTP "$($config.NPMWeb)/$zipFile" -OutFile "$($config.NodeHome)$zipFile"

        Write-Output $npmVersions

        # https://registry.npmjs.org/npm/-/npm-1.4.10.tgz

        #(7zip x "$($config.NodeHome)$tgzFile" -o"$($config.NodeHome)" -y) | Out-Null
        #(7zip x "$($config.NodeHome)$tarFile" -o"$($config.NodeHome)node_modules" -y) | Out-Null

        #Rename-Item "$($config.NodeHome)node_modules\package" "npm"

        #Write-Verbose "Create npmrc file in $($config.NodeHome)node_modules\npm"
        #"prefix=`${APPDATA}\npm" | Out-File "$($config.NodeHome)node_modules\npm\npmrc" -Encoding ascii -Force

        #Write-Verbose "Clean up home folder:"

        #Write-Verbose "Remove: $($config.NodeHome)$tgzFile"
        #Remove-Item "$($config.NodeHome)$tgzFile"

        #Write-Verbose "Remove: $($config.NodeHome)$tarFile"
        #Remove-Item "$($config.NodeHome)$tarFile"
   #}
}

#---------------------------------------------------------
# Node and npm shorthand commands
#---------------------------------------------------------
function node
{
    #Split $args variable to different string -> otherwise $args will be interpreted as one parameter
    ."$((Get-PSNodeConfig).NodeHome)latest\node.exe" $($args -split " ")
}

function npm
{
    node "$((Get-PSNodeConfig).NodeHome)node_modules\npm\bin\npm-cli.js" $args
}

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

    Write-Verbose "Check if script:config variable is present!"

    #will always return the global config object
    if($script:config -eq $null -or $Reset -eq $true)
    {
        Write-Verbose "Check if script:config not present!"

        $fileName = "PSNodeVMConfig.xml"
        $config = @{}
        $configFiles = @("$PSScriptRoot\$fileName";"$PSScriptRoot\..\$fileName";)

        Write-Verbose "Find all config files and create config hash!"
        foreach($path in $configFiles)
        {            
            if(Test-Path $path)
            {
                Write-Verbose "Config file: $path exists!"
                ([xml](Get-Content $path)).PSNodeJSManager.ChildNodes | %{ $config[$_.Name] = $_.InnerText }
            }
        }
        
        Write-Verbose "Check if CPU architecture is defined in config file!"
        if($config.OSArch -eq $null -or $config.OSArch -eq "")
        {
            Write-Verbose "OSArch is not defined in config file determine CPU architecture!"
            $config.OSArch = Get-CPUArchitecture
            Write-Verbose "Current os architecture: $($config.OSArch)"
        }             
        $script:config = $config
    }

    Write-Output $script:config
}

function Setup-PSNodeVMEnvironment
{
    [CmdletBinding()]
    Param()

    Write-Verbose "Get configuration object"
    $config = Get-PSNodeConfig
    Write-Verbose $config

    Write-Verbose "Checking NodeHome path: $($config.NodeHome)"
    if(!(Test-Path $config.NodeHome))
    {
        Write-Verbose "Home Path not set: creating new home folder: $($config.NodeHome)"
        New-Item -Path $config.NodeHome -ItemType Directory | Out-Null
    }

    Write-Verbose "Install latest node version!"
    Install-Node

    Write-Verbose "Install latest npm version to $($config.NodeHome)node_modules\npm"
    Install-NPM

    Write-Verbose "Check if global npm repo is in path: $($env:APPDATA)\npm"
    #Add global npm repo to path-> this all installed modules will still be available
    $path = (([System.Environment]::GetEnvironmentVariable("PATH", "Process")) -split ";")

    if($path -notcontains "$($env:APPDATA)\npm")
    {
        Write-Verbose "Global npm repo not in path!"

        $userString = ([System.Environment]::GetEnvironmentVariable("PATH", "User"))
        $userPath = @{$true=@(); $false=($userString -split ";")}[$userString -eq $null -or $userString -eq ""]
        $userPath += "$($env:APPDATA)\npm"
        [System.Environment]::SetEnvironmentVariable("PATH", ($userPath -join ";"), "User");

        Write-Verbose "Update path"
        $env:PATH = "$([System.Environment]::GetEnvironmentVariable("PATH", "Machine"))"
        $env:PATH += ";$([System.Environment]::GetEnvironmentVariable("PATH", "User"))"
    }
    else
    {
        Write-Verbose "Global npm repo already in path!"
    }

    Write-Verbose "Create node.cmd for npm modules"
    "@IF EXIST `"$($config.NodeHome)latest\node.exe`" ( $($config.NodeHome)latest\node.exe %* )" |
    Out-File -FilePath "$($env:APPDATA)\npm\node.cmd" -Encoding ascii -Force
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

Export-ModuleMember -Function npm
Export-ModuleMember -Function node

#---------------------------------------------------------
