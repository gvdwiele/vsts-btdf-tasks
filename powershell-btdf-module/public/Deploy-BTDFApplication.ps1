function Deploy-BTDFApplication {
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
		[string]$SharedEnvironmentSetttingsPath,

        [string]$BTDeployMgmtDB = 'true',
        [string]$SkipUndeploy = 'true',
        [string]$BTQuickDeploy = 'false',
        [string]$BtsAccount=''
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

            if(![string]::IsNullOrWhiteSpace($SharedEnvironmentSetttingsPath))
			{
				$esxargs = [string[]]@(
				" Merge "
				"/i:`"$SharedEnvironmentSetttingsPath`""
				"/i:`"$EnvironmentSettingsPath\\ProjectSettingsFileGenerator.xml`""
				"/o:`"$EnvironmentSettingsPath\\SettingsFileGenerator.xml`""
				)
				
				Write-Host "Merging shared settings spreadsheet with project settings spreadsheet, arguments= $esxargs"
				$BaseLibraryPath = Get-ChildItem -Path $ApplicationPath -Recurse -Filter 'solvIT.BaseLibrary.Build' | Select-Object -ExpandProperty FullName -First 1	
				$exitCode = (Start-Process -FilePath "`"$BaseLibraryPath\EnvironmentSettingsExporter.exe`"" -ArgumentList $esxargs -Wait -PassThru).ExitCode
				if ($exitCode -ne 0) {
					Write-Host "##vso[task.logissue type=error;] Redeploy-BTDFApplication Error while calling SHARED EnvironmentSettingsExporter, Exit Code: $exitCode"
				}
			}

            $esxargs = [string[]]@(
                    "`"$EnvironmentSettingsPath\\SettingsFileGenerator.xml`""
                    "`"$EnvironmentSettingsPath`""
                )
            Write-Host "Exporting settings from spreadsheet, arguments= $esxargs"

            $DeploymentToolsPath = Get-ChildItem -Path $ApplicationPath -Recurse -Filter 'DeployTools' | Select-Object -ExpandProperty FullName -First 1
            $exitCode = (Start-Process -FilePath "`"$DeploymentToolsPath\EnvironmentSettingsExporter.exe`"" -ArgumentList $esxargs -Wait -PassThru).ExitCode
            if ($exitCode -ne 0) {
                Write-Host "##vso[task.logissue type=error;] Deploy-BTDFApplication Error while calling EnvironmentSettingsExporter, Exit Code: $exitCode"
            }
            $EnvironmentSettings = Join-Path $EnvironmentSettingsPath ('{0}settings.xml' -f $Environment)

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
            "/p:BT_DEPLOY_MGMT_DB=$BTDeployMgmtDB"
            "/p:DeployBizTalkMgmtDB=$BTDeployMgmtDB"
            "/p:BTSACCOUNT=`"$BtsAccount`""
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
				$exception = "Deploy-BTDFApplication error while calling MSBuild, Exit Code: $($exitCode)"
				throw $exception
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
