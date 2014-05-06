$e = "C:\Windows\system32\WindowsPowerShell\v1.0\;C:\Python34\;C:\Python34\Scripts;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\PROGRA~1\IBM\SQLLIB\BIN;C:\PROGRA~1\IBM\SQLLIB\FUNCTION;C:\Program Files (x86)\Belgium Identity Card;C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\;C:\Program Files\Microsoft SQL Server\100\Tools\Binn\;C:\Program Files\Microsoft SQL Server\100\DTS\Binn\;C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\VSShell\Common7\IDE\;C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\PrivateAssemblies\;C:\Program Files (x86)\Microsoft SQL Server\100\DTS\Binn\;C:\Program Files\Microsoft Windows Performance Toolkit\;C:\Program Files (x86)\IBM\WebSphere MQ\bin64;C:\Program Files (x86)\IBM\WebSphere MQ\bin;C:\Program Files (x86)\IBM\WebSphere MQ\tools\c\samples\bin;C:\Program Files (x86)\Microsoft Team Foundation Server 2010 Power Tools\;C:\Program Files (x86)\Microsoft Team Foundation Server 2010 Power Tools\Best Practices Analyzer\;C:\Program Files (x86)\ZANTAZ\EAS Outlook Addin\bin;C:\Program Files\Microsoft\Web Platform Installer\;C:\Program Files (x86)\Microsoft ASP.NET\ASP.NET Web Pages\v1.0\;C:\Program Files (x86)\Windows Kits\8.0\Windows Performance Toolkit\;C:\Program Files\Microsoft SQL Server\110\Tools\Binn\;C:\Program Files (x86)\Microsoft Application Virtualization Client;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files (x86)\Git\bin;C:\Program Files\nodejs"
#$e = "C:\Windows\system32\WindowsPowerShell\v1.0\;C:\Python34\;C:\Python34\Scripts;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\PROGRA~1\IBM\SQLLIB\BIN;C:\PROGRA~1\IBM\SQLLIB\FUNCTION;C:\Program Files (x86)\Belgium Identity Card;C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\;C:\Program Files\Microsoft SQL Server\100\Tools\Binn\;C:\Program Files\Microsoft SQL Server\100\DTS\Binn\;C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\VSShell\Common7\IDE\;C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE\PrivateAssemblies\;C:\Program Files (x86)\Microsoft SQL Server\100\DTS\Binn\;C:\Program Files\Microsoft Windows Performance Toolkit\;C:\Program Files (x86)\IBM\WebSphere MQ\bin64;C:\Program Files (x86)\IBM\WebSphere MQ\bin;C:\Program Files (x86)\IBM\WebSphere MQ\tools\c\samples\bin;C:\Program Files (x86)\Microsoft Team Foundation Server 2010 Power Tools\;C:\Program Files (x86)\Microsoft Team Foundation Server 2010 Power Tools\Best Practices Analyzer\;C:\Program Files (x86)\ZANTAZ\EAS Outlook Addin\bin;C:\Program Files\Microsoft\Web Platform Installer\;C:\Program Files (x86)\Microsoft ASP.NET\ASP.NET Web Pages\v1.0\;C:\Program Files (x86)\Windows Kits\8.0\Windows Performance Toolkit\;C:\Program Files\Microsoft SQL Server\110\Tools\Binn\;C:\Program Files (x86)\Microsoft Application Virtualization Client;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files (x86)\Git\bin;H:\NodeJS"

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


Set-EnvironmentVar "PATH" $e "Machine"