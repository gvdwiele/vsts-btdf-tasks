﻿function Deploy-BTDFApplication {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name', HelpMessage = "Msi file must exist")]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$ProgramFilesDir,
        [Parameter(Mandatory)]
        [string]$ProgramName,

        [Parameter(Mandatory = $true)]
        [string]$Environment,

        [string]$BTDeployMgmtDB = 'true',
        [string]$SkipUndeploy = 'true',
        [string]$BTQuickDeploy = 'false'
    )
    Begin {
        . $PSScriptRoot\..\private\Init-BTDFTasks.ps1
    }
    Process {
        if ([string]::IsNullOrWhiteSpace($ProgramFilesDir)) {
            $ProgramFilesDir = $ProgramFiles
        }
        if ([string]::IsNullOrWhiteSpace($ProgramName)) {
            $ProgramName = $Name
        }
        $ApplicationPath = Join-Path $ProgramFilesDir $ProgramName
        if (Test-Path -Path $ApplicationPath -ErrorAction SilentlyContinue) {
            $EnvironmentSettingsPath = Get-ChildItem -Path $ApplicationPath -Recurse -Filter 'EnvironmentSettings' | Select-Object -ExpandProperty FullName -First 1
            $EnvironmentSettings = Join-Path $EnvironmentSettingsPath ('{0}settings.xml' -f $Environment)
            if (!(Test-Path -Path $EnvironmentSettings)) {
                $DeploymentToolsPath = Get-ChildItem -Path $ApplicationPath -Recurse -Filter 'DeployTools' | Select-Object -ExpandProperty FullName -First 1
                $esxargs = [string[]]@(
                    "`"$EnvironmentSettingsPath\\SettingsFileGenerator.xml`""
                    "`"$EnvironmentSettingsPath`""
                )
                $exitCode = (Start-Process -FilePath "`"$DeploymentToolsPath\EnvironmentSettingsExporter.exe`"" -ArgumentList $esxargs -Wait -PassThru).ExitCode
                if ($exitCode -ne 0) {
                    Write-Host "##vso[task.logissue type=error;] Deploy-BTDFApplication Error while calling EnvironmentSettingsExporter, Exit Code: $exitCode"
                }
            }
            Get-Item -Path $EnvironmentSettings -ErrorAction Stop | Out-Null

            $BTDFMSBuild = Get-MSBuildPath
            $BTDFProject = Get-ChildItem -Path $ApplicationPath -Filter '*.btdfproj' -Recurse | Select-Object -ExpandProperty FullName -First 1
            $DeployResults = Get-ChildItem -Path $ApplicationPath -Filter 'DeployResults' -Recurse | Select-Object -ExpandProperty FullName -First 1
            $DeployResults = Join-Path $DeployResults 'DeployResults.txt'

            if ($BTQuickDeploy -eq 'true') {
                $arguments = [string[]]@(
                    "/l:FileLogger,Microsoft.Build.Engine;logfile=`"$DeployResults`""
                    '/p:Configuration=Server'
                    "/p:ENV_SETTINGS=`"$EnvironmentSettings`""
                    '/target:UpdateOrchestration'
                    "`"$BTDFProject`""
                )
            }
            else {
                $arguments = [string[]]@(
                    "/l:FileLogger,Microsoft.Build.Engine;logfile=`"$DeployResults`""
                    '/p:Configuration=Server'
                    "/p:DeployBizTalkMgmtDB=$BTDeployMgmtDB"
                    "/p:ENV_SETTINGS=`"$EnvironmentSettings`""
                    "/p:SkipUndeploy=$SkipUndeploy"
                    '/target:Deploy'
                    "`"$BTDFProject`""
                )
            }

            $cmd = $BTDFMSBuild, ($arguments -join ' ') -join ' '
            Write-Host $cmd
            $exitCode = (Start-Process -FilePath $BTDFMSBuild -ArgumentList $arguments -NoNewWindow -Wait -PassThru).ExitCode
            Write-Host (Get-Content -Path $DeployResults | Out-String)
            if ($exitCode -ne 0) {
                Write-Host ("##vso[task.logissue type=error;] Deploy-BTDFApplication error while calling MSBuild, Exit Code: {0}" -f $exitCode)
                Write-Host ("##vso[task.complete result=Failed;] Deploy-BTDFApplication error while calling MSBuild, Exit Code: {0}" -f $exitCode)
            }
            else {
                Write-Host "##vso[task.complete result=Succeeded;]DONE"
            }
        }
        else {
            Write-Host ("##vso[task.logissue type=error;] BTDF application '{0}' not found at {1}.  Deploy skipped." -f $Name, $ApplicationPath)
            Write-Host ("##vso[task.complete result=Failed;] BTDF application '{0}' not found at {1}.  Deploy skipped." -f $Name, $ApplicationPath)
        }
    }
    End {}
}