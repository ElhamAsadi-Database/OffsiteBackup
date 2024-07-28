# Set your local backup root directory
$localBackupRoot = "F:\BackUp\FullBackup"

# Set the network path
 $networkPath = "\\ftp2\BSSDB\atbssdb\fullbackup"

# Set the username and password
$username = ""
$password = ""

# Create a PSCredential object
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, (ConvertTo-SecureString -String $password -AsPlainText -Force)

# Get all subdirectories under the root backup directory
$subdirectories = Get-ChildItem -Path $localBackupRoot -Directory

foreach ($subdirectory in $subdirectories) {
    # Get the list of backup files in the current subdirectory
    $localBackupDirectory = Join-Path -Path $localBackupRoot -ChildPath $subdirectory.Name
    $backupFiles = Get-ChildItem -Path $localBackupDirectory -Filter "*.bak" | Sort-Object LastWriteTime -Descending

    # Check if there are any backup files
    if ($backupFiles.Count -gt 0) {
        # Get the latest backup file in the current subdirectory
        $latestBackup = $backupFiles[0]

        # Create a PSDrive using New-PSDrive with a standard drive letter 
        $networkDrive = New-PSDrive -Name "Z" -PSProvider FileSystem -Root $networkPath -Credential $credential -Scope Global

        if ($networkDrive) {
            try {
                # Create a subdirectory with the same name in the destination
                $destinationSubdirectory = Join-Path -Path $networkDrive.Root -ChildPath $subdirectory.Name
                New-Item -Path $destinationSubdirectory -ItemType Directory -Force

                # Set the destination path for the backup file
                $destinationPath = Join-Path -Path $destinationSubdirectory -ChildPath $latestBackup.Name

                # Copy the backup file to the destination
                Copy-Item -Path $latestBackup.FullName -Destination $destinationPath -Force
                Write-Host "Copied $($latestBackup.Name) to $($destinationPath)"
            }
            finally {
                # Remove the PSDrive when done
                Remove-PSDrive -Name "Z" -Scope Global -Force
            }
        } else {
            Write-Host "Failed to create the network drive."
        }
    } else {
        Write-Host "No backup files found in $($subdirectory.FullName)."
    }
}
# Function to delete old Full Backup files older than 1 months
function Remove-OldFullBackups {
    param(
        [string]$sourcePath
    )

    # Get all subdirectories under the root backup directory
    $subdirectories = Get-ChildItem -Path $sourcePath -Directory

    foreach ($subdirectory in $subdirectories) {
        # Get the list of backup files in the current subdirectory
        $localBackupDirectory = Join-Path -Path $sourcePath -ChildPath $subdirectory.Name
        $backupFiles = Get-ChildItem -Path $localBackupDirectory -Filter "*.bak" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddMonths(-1) }

        # Check if there are any backup files older than 6 months
        if ($backupFiles.Count -gt 0) {
            foreach ($backupFile in $backupFiles) {
                # Delete the backup file
                Remove-Item -Path $backupFile.FullName -Force
                Write-Host "Deleted $($backupFile.Name) from $($localBackupDirectory)"
            }
        } else {
            Write-Host "No backup files older than 6 months found in $($subdirectory.FullName)."
        }
    }
}

# Delete old Full Backup files older than 1 months
Remove-OldFullBackups -sourcePath $networkPath
