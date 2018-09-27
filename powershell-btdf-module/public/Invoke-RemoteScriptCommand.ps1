function Invoke-RemoteScriptCommand {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName= "p1",HelpMessage = "Name of the remote computer where the script will be executed.")]
        [string]$ComputerName,
        [Parameter(Mandatory = $true, ParameterSetName= "p1",HelpMessage = "The user account for authenticating on the remote computer.")]
        [string]$UserName,
        [Parameter(Mandatory= $true, ParameterSetName= "p1",HelpMessage = "The password for the user account for authenticating on the remote computer.")]
        [string]$Password,
        [Parameter(Mandatory = $true, ParameterSetName= "p1",HelpMessage = "The script block to invoke on the remote computer.")]
        [string]$ScriptBlock
    )
    Begin {
    }
    Process {

        $SecurePassword=Convertto-SecureString $Password -AsPlainText -Force
        $MyCredentials=New-object System.Management.Automation.PSCredential $UserName,$SecurePassword
        $script = [scriptblock]::Create($ScriptBlock)
        Invoke-Command -ComputerName $ComputerName -Authentication Credssp -ScriptBlock $script -credential $MyCredentials
    }
    End {}
}
