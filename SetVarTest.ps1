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

function Get-Path
{
    Param
    (
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )
    Write-Output ((Get-EnvironmentVar Path $Target) -split ";")
}

function Set-Path
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$PathVar,
        [Parameter(Mandatory=$false)]
        [String]$Value = $PathVar,
        [ValidateSet("User", "Machine", "Process")]
        [String]$Target="Process"
    )

    #Comma in ArrayList constructor is to prevent powershell to add an unpacked array
    #Powershell natively unpacks an array the , in powershell is an array constructor
    #So what internally happens i guess is that powershell unpacks the array and reassambles it again
    $Path = New-Object System.Collections.ArrayList(,(Get-Path -Target $Target))

    if(($Index = $Path.IndexOf($PathVar)) -ge 0){
        
        $Path[$Index] = $Value
        Write-Output $Index
    }else{
        $Path.Add($Value);
    }

    $Path.Remove("")
    
    $Path | Write-Output
}

#Get-Path
Set-Path "C:\PSNodeJS\"