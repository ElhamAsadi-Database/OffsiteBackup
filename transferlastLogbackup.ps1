# Set your local backup root directory
$localBackupRoot = "F:\BackUp\LogBackup"

# Set the network path
$networkPath = "\\ftp2\LogBackup"

# Set the username and password
$username = ""
$password = ""

# Create a PSCredential object
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, (ConvertTo-SecureString -String $password -AsPlainText -Force)

# Function to create network drive and copy files
function Copy-LogBackups {
    param (
        [string]$sourcePath,
        [string]$destinationPath,
        [System.Management.Automation.PSCredential]$credential
    )

    # Get all subdirectories under the root backup directory
    $subdirectories = Get-ChildItem -Path $sourcePath -Directory

    foreach ($subdirectory in $subdirectories) {
        # Get the list of backup files in the current subdirectory
        $localBackupDirectory = Join-Path -Path $sourcePath -ChildPath $subdirectory.Name
        $backupFiles = Get-ChildItem -Path $localBackupDirectory -Filter "*.trn" | Sort-Object LastWriteTime -Descending

        # Check if there are any backup files
        if ($backupFiles.Count -gt 0) {
            foreach ($backupFile in $backupFiles) {
                # Create a PSDrive using New-PSDrive with a standard drive letter 
                $networkDrive = New-PSDrive -Name "Z" -PSProvider FileSystem -Root $destinationPath -Credential $credential -Scope Global -ErrorAction SilentlyContinue

                if ($networkDrive -eq $null) {
                    Write-Host "Failed to create the network drive. Removing existing drives and retrying..."
                    Remove-PSDrive -Name "Z" -Scope Global -Force -ErrorAction SilentlyContinue
                    $networkDrive = New-PSDrive -Name "Z" -PSProvider FileSystem -Root $destinationPath -Credential $credential -Scope Global
                }

                if ($networkDrive) {
                    try {
                        # Create a subdirectory with the same name in the destination
                        $destinationSubdirectory = Join-Path -Path $networkDrive.Root -ChildPath $subdirectory.Name
                        New-Item -Path $destinationSubdirectory -ItemType Directory -Force | Out-Null

                        # Set the destination path for the backup file
                        $destinationFilePath = Join-Path -Path $destinationSubdirectory -ChildPath $backupFile.Name

                        # Copy the backup file to the destination
                        Copy-Item -Path $backupFile.FullName -Destination $destinationFilePath -Force
                        Write-Host "Copied $($backupFile.Name) to $($destinationFilePath)"
                    }
                    finally {
                        # Remove the PSDrive when done
                        Remove-PSDrive -Name "Z" -Scope Global -Force
                    }
                } else {
                    Write-Host "Failed to create the network drive after retrying."
                }
            }
        } else {
            Write-Host "No backup files found in $($subdirectory.FullName)."
        }
    }
}

# Call the function to copy log backup files
Copy-LogBackups -sourcePath $localBackupRoot -destinationPath $networkPath -credential $credential

# Function to delete old log backup files older than 7 days
function Remove-OldLogBackups {
    param(
        [string]$sourcePath
    )

    # Get all subdirectories under the root backup directory
    $subdirectories = Get-ChildItem -Path $sourcePath -Directory

    foreach ($subdirectory in $subdirectories) {
        # Get the list of backup files in the current subdirectory
        $localBackupDirectory = Join-Path -Path $sourcePath -ChildPath $subdirectory.Name
        $backupFiles = Get-ChildItem -Path $localBackupDirectory -Filter "*.trn" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }

        # Check if there are any backup files older than 7 days
        if ($backupFiles.Count -gt 0) {
            foreach ($backupFile in $backupFiles) {
                # Delete the backup file
                Remove-Item -Path $backupFile.FullName -Force
                Write-Host "Deleted $($backupFile.Name) from $($localBackupDirectory)"
            }
        } else {
            Write-Host "No backup files older than 7 days found in $($subdirectory.FullName)."
        }
    }
}

# Delete old log backup files older than 7 days
Remove-OldLogBackups -sourcePath $networkPath
