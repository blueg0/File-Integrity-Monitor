Write-Host ""
Write-Host "What would you like to do?"
Write-Host "A) Collect new baseline"
Write-Host "B) Monitor files with saved baseline"

$response = Read-Host -Prompt "Choose A or B "

Function CalculateFileHash($filepath) {
    try {
        $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
        return $filehash
    }
    catch {
        Write-Host "Error calculating hash for $filepath. Skipping..." -ForegroundColor Yellow
        return $null
    }
}

Function EraseBaselineIfAlreadyExist() {
    $baselineExists = Test-Path -Path .\baseline.txt
    if ($baselineExists) {
        Remove-Item -Path .\baseline.txt
    }
}

Function LogChange($message) {
    "$message at $(Get-Date)" | Out-File -FilePath .\file_changes.log -Append
}

if ($response.ToUpper() -eq "A") {
    # Collect new baseline
    Write-Host "Collecting new baseline..."
    EraseBaselineIfAlreadyExist

    # Ensure the directory exists
    if (!(Test-Path -Path .\Files)) {
        Write-Host "Directory '.\Files' does not exist. Please create it or choose another directory."
        exit
    }

    # Collect file hashes
    $files = Get-ChildItem -Path .\Files
    "$($files.Count) files found. Collecting baseline with timestamp..." | Out-File -FilePath .\baseline.txt -Append
    Add-Content -Path .\baseline.txt -Value "Timestamp: $(Get-Date)"

    foreach ($file in $files) {
        $hash = CalculateFileHash $file.FullName
        if ($null -ne $hash) {
            "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath ./baseline.txt -Append
        }
    }
    Write-Host "Baseline collected successfully in baseline.txt"
} elseif ($response.ToUpper() -eq "B") {
    # Monitor files based on saved baseline
    if (!(Test-Path -Path .\baseline.txt)) {
        Write-Host "Baseline file not found. Please create a baseline first."
        exit
    }

    # Load file|hash from baseline into dictionary
    Write-Host "Loading baseline..."
    $dict = @{}
    $FileHash = Get-Content -Path .\baseline.txt
   
    foreach ($f in $FileHash[2..($FileHash.Count - 1)]){

            $dict[$f.Split("|")[0]] = $f.Split("|")[1]
        }
    

    # Set monitoring interval
    $monitorInterval = Read-Host -Prompt "Enter monitoring interval in seconds (e.g., 2)"
    $monitorInterval = [int]$monitorInterval

    # Monitor files
    Write-Host "Monitoring started. Press Ctrl+C to stop."
    while ($true) {
        Start-Sleep -Seconds $monitorInterval

        # Get the current files and their hashes
        $files = Get-ChildItem -Path .\Files

        # Track changes
        $currentFiles = @{}
        foreach ($file in $files) {
            $hash = CalculateFileHash $file.FullName
            if ($null -ne $hash) {
                $currentFiles[$hash.Path] = $hash.Hash

                # New file
                if ($null -eq $dict[$hash.Path]) {
                    Write-Host "$($hash.Path) has been created" -ForegroundColor Green
                    LogChange "$($hash.Path) has been created"
                }
                # Modified file
                elseif ($dict[$hash.Path] -ne $hash.Hash) {
                    Write-Host "$($hash.Path) has been changed" -ForegroundColor Yellow
                    LogChange "$($hash.Path) has been modified"
                }
            }
        }

        # Detect deleted files
        foreach ($key in $dict.Keys) {
            if (-not (Test-Path -Path $key)) {
                Write-Host "$($key) has been deleted" -ForegroundColor DarkRed
                Log-Change "$($key) has been deleted"
            }
        }

    }
} else {
    Write-Host "Invalid Input"
}
