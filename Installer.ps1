param(
    [Parameter(Position = 0, Mandatory = $true)]
    [Alias("n")]
    [string]$scriptName,

    [Parameter(Position = 1, Mandatory = $true)]
    [Alias("i")]
    [string]$install
)
Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
$filePath = $($MyInvocation.MyCommand.Path)
$scriptRoot = Split-Path $filePath -Parent
$scriptPath = "$scriptRoot\StreamMonitor.ps1"
. .\Helpers.ps1 -n $scriptName
$settings = Get-Settings

# This script modifies the global_prep_cmd setting in the Sunshine configuration file

function Test-UACEnabled {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $uacEnabled = Get-ItemProperty -Path $key -Name 'EnableLUA'
    return [bool]$uacEnabled.EnableLUA
}


$isAdmin = [bool]([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')

# If the user is not an administrator and UAC is enabled, re-launch the script with elevated privileges
if (-not $isAdmin -and (Test-UACEnabled)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$filePath`" -n `"$scriptName`" -i `"$install`""
    exit
}

function Test-AndRequest-SunshineConfig {
    param(
        [string]$InitialPath
    )

    # Check if the initial path exists
    if (Test-Path $InitialPath) {
        Write-Host "File found at: $InitialPath"
        return $InitialPath
    }
    else {
        # Show error message dialog
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [System.Windows.Forms.MessageBox]::Show("Sunshine configuration could not be found. Please locate it.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)  | Out-Null

        # Open file dialog
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Title = "Open sunshine.conf"
        $fileDialog.Filter = "Configuration files (*.conf)|*.conf"
        $fileDialog.InitialDirectory = [System.IO.Path]::GetDirectoryName($InitialPath)

        if ($fileDialog.ShowDialog() -eq "OK") {
            $selectedPath = $fileDialog.FileName
            # Check if the selected path is valid
            if (Test-Path $selectedPath) {
                Write-Host "File selected: $selectedPath"
                return $selectedPath
            }
            else {
                Write-Error "Invalid file path selected."
            }

        }
        else {
            Write-Error "Sunshine Configuiration file dialog was canceled or no valid file was selected."
            exit 1
        }
    }
}
        
# Define the path to the Sunshine configuration file
$confPath = Test-AndRequest-SunshineConfig -InitialPath  "C:\Program Files\Sunshine\config\sunshine.conf"
$scriptRoot = Split-Path $scriptPath -Parent



# Get the current value of global_prep_cmd from the configuration file
function Get-GlobalPrepCommand {

    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $confPath

    # Find the line that contains the global_prep_cmd setting
    $globalPrepCmdLine = $config | Where-Object { $_ -match '^global_prep_cmd\s*=' }

    # Extract the current value of global_prep_cmd
    if ($globalPrepCmdLine -match '=\s*(.+)$') {
        return $matches[1]
    }
    else {
        Write-Information "Unable to extract current value of global_prep_cmd, this probably means user has not setup prep commands yet."
        return [object[]]@()
    }
}

# Remove any existing commands that contain the scripts name from the global_prep_cmd value
function Remove-Command {
    # Get the current value of global_prep_cmd as a JSON string
    $globalPrepCmdJson = Get-GlobalPrepCommand -ConfigPath $confPath

    # Convert the JSON string to an array of objects
    $globalPrepCmdArray = $globalPrepCmdJson | ConvertFrom-Json
    $filteredCommands = @()

    # Remove any existing matching Commands
    for ($i = 0; $i -lt $globalPrepCmdArray.Count; $i++) {
        if (-not ($globalPrepCmdArray[$i].do -like "*$scriptName*")) {
            $filteredCommands += $globalPrepCmdArray[$i]
        }
    }

    return [object[]]$filteredCommands
}


# Set a new value for global_prep_cmd in the configuration file
function Set-GlobalPrepCommand {
    param (

        # The new value for global_prep_cmd as an array of objects
        [object[]]$Value
    )

    if ($null -eq $Value) {
        $Value = [object[]]@()
    }


    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $confPath

    # Get the current value of global_prep_cmd as a JSON string
    $currentValueJson = Get-GlobalPrepCommand -ConfigPath $confPath

    # Convert the new value to a JSON string
    $newValueJson = ConvertTo-Json -InputObject $Value -Compress

    # Replace the current value with the new value in the config array
    try {
        $config = $config -replace [regex]::Escape($currentValueJson), $newValueJson
    }
    catch {
        # If it failed, it probably does not exist yet.
        # In the event the config only has one line, we will cast this to an object array so it appends a new line automatically.

        if ($Value.Length -eq 0) {
            [object[]]$config += "global_prep_cmd = []"
        }
        else {
            [object[]]$config += "global_prep_cmd = $($newValueJson)"
        }
    }



    # Write the modified config array back to the file
    $config | Set-Content -Path $confPath -Force
}
function ReorderScriptCommands($commands, $targetScript, $allScripts) {
    # Create a list to store commands that might be reordered
    $reorderedCommands = New-Object System.Collections.Generic.List[object]
    $reorderedCommands.AddRange($commands)

    # Find the index of the target script within the list of all scripts
    $nextScriptIndex = $allScripts.IndexOf($targetScript) + 1
    $previousScriptIndex = $allScripts.IndexOf($targetScript) - 1

    # Find the command that includes the target script in its 'do' property
    $targetCommand = $commands | Where-Object { $_.do -like "*$targetScript*" }
    $hasReordered = $false

    # Ensure the previous script index is non-negative
    if ($previousScriptIndex -lt 0) {
        $previousScriptIndex = 0
    }

    # Handle reordering for the previous script's command if it exists
    if ($previousScriptIndex -gt 0) {
        $previousScript = $allScripts[$previousScriptIndex]
        $previousCommand = $commands | Where-Object { $_.do -like "*$previousScript*" }
        if ($commands.IndexOf($previousCommand) -gt $commands.IndexOf($targetCommand)) {
            # Move the previous command to the position before the target command
            $reorderedCommands.Remove($previousCommand)
            $reorderedCommands.Insert($commands.IndexOf($targetCommand), $previousCommand)
            $hasReordered = $true
        }
    }

    # Handle reordering for the next script's command if it exists
    if ($nextScriptIndex -lt $allScripts.Count) {
        $nextScript = $allScripts[$nextScriptIndex]
        $nextCommand = $commands | Where-Object { $_.do -like "*$nextScript*" }
        if ($commands.IndexOf($nextCommand) -lt $commands.IndexOf($targetCommand)) {
            # Move the next command to the position after the target command
            $reorderedCommands.Remove($nextCommand)
            $reorderedCommands.Insert($commands.IndexOf($targetCommand) + 1, $nextCommand)
            $hasReordered = $true
        }
    }

    # Recursively call the function if any reorder has occurred
    if ($hasReordered) {
        return ReorderScriptCommands $reorderedCommands.ToArray() $nextScript $allScripts
    }
    else {
        # Return the reordered list of commands if no further reordering is needed
        return $reorderedCommands.ToArray()
    }
}

function Add-Command {

    # Remove any existing commands that contain the scripts name from the global_prep_cmd value
    $globalPrepCmdArray = Remove-Command -ConfigPath $confPath

    $command = [PSCustomObject]@{
        do       = "powershell.exe -executionpolicy bypass -file `"$($scriptPath)`" -n $scriptName"
        elevated = "false"
        undo     = "powershell.exe -executionpolicy bypass -file `"$($scriptRoot)\Helpers.ps1`" -n $scriptName -t 1"
    }

    # Add the new object to the global_prep_cmd array
    [object[]]$globalPrepCmdArray += $command

    return [object[]]$globalPrepCmdArray
}
$commands = @()
if ($install -eq 1) {
    $commands = Add-Command
}
else {
    $commands = Remove-Command 
}

if ($settings.installationOrderPreferences.enabled) {
    $commands = OrderCommands -commands $commands -scriptName $scriptName -scriptNames $settings.installationOrderPreferences.scriptNames
}

Set-GlobalPrepCommand $commands

$sunshineService = Get-Service -ErrorAction Ignore | Where-Object { $_.Name -eq 'sunshinesvc' -or $_.Name -eq 'SunshineService' }
# In order for the commands to apply we have to restart the service
$sunshineService | Restart-Service  -WarningAction SilentlyContinue
Write-Host "If you didn't see any errors, that means the script installed without issues! You can close this window."

