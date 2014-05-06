#Set default constant vars
#Set nvmHome to  C:\Program Files\nodejs
[String] $nvmHome = "C:\PSNodeJS\"
[String] $nodeDist = "http://nodejs.org/dist/"
[String] $npmDist = "$nodeDist/npm/"
[String] $nodeExe = "node.exe"
[String] $OSArch = ""
$npmVersions = @()

#Temporary variable
[String] $Version = "latest/"

function Get-EnvironmentVar
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Variable,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target
    )
    $Target = @{$true="Process";$false=$Target}[$Target -eq $null -or $Target -eq ""]
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
        [String]$Target
    )

    Begin
    {
        $Target = @{$true="Process";$false=$Target}[$Target -eq $null -or $Target -eq ""]
    }
    Process
    {
        [System.Environment]::SetEnvironmentVariable($Variable, $Value, $Target)
    }
    End
    {
        Write-Output (Get-EnvironmentVar $Variable $Target)
    }
    
 }

function Install-Node 
{
    [CmdletBinding()]
    Param
    (
        [ValidateScript({
            
        })]

        [String]$Version = ""
    )

    $Version = @{$true="latest/"; $false="$Version"}[$Version -eq $null -or $Version -eq ""]

    if((Test-Path "$($nvmHome)$($version)") -eq $false){
        New-Item "$($nvmHome)$($version)" -ItemType Directory | Out-Null
    }

    if($env:HTTP_PROXY -eq $null){
        curl "$($nodeDist)$($Version)$($OSArch)$($nodeExe)" -OutFile "$($nvmHome)$($Version)$($nodeExe)"
    }
    else{
        curl "$($nodeDist)$($Version)$($OSArch)$($nodeExe)" -OutFile "$($nvmHome)$($Version)$($nodeExe)" -Proxy $env:HTTP_PROXY
    }
}

function Update-Node
{
    Install-Node
}

function Change-Node
{
}

function Parse-VersionNumber
{
    Param
    (
        [ValidatePattern("^[\d]+\.[\d]+.[\d]+$")]
        [ValidateScript({ $npmVersions.Node -contains "v$($_)" })]
        [String]$Version
    )

    Write-Output $Version
}

function Return-Versions
{
    Write-Output $npmVersions
}

#To implement
function Start-Node{
    node $args
}

#NPM wrapper function that start npm in node with args
function npm 
{
    node "$($nvmHome)\node_modules\npm\bin\npm-cli.js" $args
}


#Set alias in module so curl always references to Invoke-WebRequest
Set-Alias -Name curl -Value Invoke-WebRequest -Option AllScope
set-alias -Name cat -Value Get-Content -option AllScope
Set-Alias -Name node -Value "$($nvmHome)$($Version)$($nodeExe)"

#Run Prereq Test
if((Get-EnvironmentVar CurNodeVer Machine) -eq $null)
{
    #Set-EnvironmentVar "CurNodeVer" "latest" "Machine"
    #$env:CurNodeVer = "latest"
    Write-Output "var not created"
}

if((Test-Path $nvmHome) -eq $false)
{
    New-Item $nvmHome -ItemType Directory
}

if((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq "64-Bit")
{
    $OSArch = "x64/"
}
    
$matchedV = [regex]::Matches((cat .\npm-versions.txt), "(?<Node>v[\d]+\.[\d]+.[\d]+)\s(?<NPM>[\d]+\.[\d]+.[\d]+)")

foreach($m in $matchedV){
    $npmVersions += (@{ "Node"=$m.Groups["Node"].Value; "NPM"=$m.Groups["NPM"].Value })      
}
#-------------------------------------------------

#Set-Alias -Name npm -Value "$($nvmHome)npm.cmd"

#Export functions, vars ans alias
Export-ModuleMember -Function Install-Node
Export-ModuleMember -Function Update-Node
Export-ModuleMember -Function Change-Node
Export-ModuleMember -Function Start-Node
Export-ModuleMember -Function Return-Versions
Export-ModuleMember -Function Parse-VersionNumber

#Make sure everything is installed on local drive
#previously used $home to install to local dir
#in some corporations the $home dir is a network share to sync documents,.. across computers
#in this case using the $home dir introduced significant latency
# -> decided to use a predifined dir on the c:/ drive -> find a better way and location to be sure that i don't install on share and do not need c root dir

#find a way to introduce npmrc -> to point list -g to appdata roaming dir -> this is also used by default node installer
Export-ModuleMember -Alias node
Export-ModuleMember -Function npm

Export-ModuleMember -Variable npmVersions