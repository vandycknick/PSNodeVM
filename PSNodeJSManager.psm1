function Import-PSNodeJSManagerConfig
{
    $fileName = "PSNodeJSManagerConfig.xml"
    $path = @{$true="$PSScriptRoot\..\$fileName"; $false="$PSScriptRoot\$fileName"}[(Test-Path "$PSScriptRoot\..\$fileName")]
    
    $config = ([xml](Get-Content $path)) 

    Write-Output $config
}

function Setup-PSNodeJSManagerEnvironment
{

}