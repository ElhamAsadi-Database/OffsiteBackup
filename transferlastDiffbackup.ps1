# Set your local backup root directory
$localBackupRoot = "F:\BackUp\DifferentialBackup"

# Set the network path
$networkPath = "\\ftp2\DifferentialBackup"

# Set the username and password
$username = ""
$password = ""

# Create a PSCredential object
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, (ConvertTo-SecureString -String $password -AsPlainText -Force)

# Add the IP address to TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "172.17.100.3" -Force

# Function to delete old Differential Backup files older than 1 week
function Remove-OldDifferentialBackups {
    param(
        [string]$sourcePath
    )

    # Get all subdirectories under the root backup directory
    $subdirectories = Get-ChildItem -Path $sourcePath -Directory

    foreach ($subdirectory in $subdirectories) {
        # Get the list of backup files in the current subdirectory
        $localBackupDirectory = Join-Path -Path $sourcePath -ChildPath $subdirectory.Name
        $backupFiles = Get-ChildItem -Path $localBackupDirectory -Filter "*.bak" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }

        # Check if there are any backup files older than 1 week
        if ($backupFiles.Count -gt 0) {
            foreach ($backupFile in $backupFiles) {
                # Delete the backup file
                Remove-Item -Path $backupFile.FullName -Force
                Write-Host "Deleted $($backupFile.Name) from $($localBackupDirectory)"
            }
        } else {
            Write-Host "No backup files older than 1 week found in $($subdirectory.FullName)."
        }
    }
}

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
        $networkDrive = New-PSDrive -Name "Z" -PSProvider FileSystem -Root $networkPath -Credential $credential -Scope Global -ErrorAction SilentlyContinue

        if ($networkDrive -eq $null) {
            Write-Host "Failed to create the network drive. Removing existing drives and retrying..."
            Remove-PSDrive -Name "Z" -Scope Global -Force -ErrorAction SilentlyContinue
            $networkDrive = New-PSDrive -Name "Z" -PSProvider FileSystem -Root $networkPath -Credential $credential -Scope Global
        }

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
            Write-Host "Failed to create the network drive after retrying."
        }
    } else {
        Write-Host "No backup files found in $($subdirectory.FullName)."
    }
}

# Delete old Differential Backup files older than 1 week
Remove-OldDifferentialBackups -sourcePath $networkPath
