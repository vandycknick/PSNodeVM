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



function nvm 
{
    [CmdletBinding()]
    Param
    (
    )

    Begin
    {
    
    }

    Process
    {
    
    }

    End
    {

    }
}

#Prereq checks
 if((Get-EnvironmentVar CurNodeVer Machine) -eq $null)
 {
    #[System.Environment]::SetEnvironmentVariable("CurNodeVer", "Stable", "Machine")
    Write-Output "var not ccreated"
 }

Write-Output "PSNodeVersion module imported"