<#
.SYNOPSIS
    v1.2 - KYBER Server Asset Importer
    - Added: Multi-file import support for plugins (space-separated paths).
    - Fixed: Detection of .tar files without extensions (exported from mod tools).
    - Added: Feedback message for large MOD extraction to prevent user panic.
    - Validates file extensions (.tar, .kbplugin).
    - Interactive Y/n switch for parent folder detection.
    - Volume Discovery with "New Volume" clarification.
    - Rsync progress bars for Game Files and Modules.
#>

# --- 1. SETUP AND MENU ---
Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   KYBER Server Asset Importer (v1.2)     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "1. Import Mod Collection (.tar)"
Write-Host "2. Import Plugin (.kbplugin) - Supports multiple files!"
Write-Host "3. Import Kyber Module (Folder or Kyber.dll)"
Write-Host "4. Import Game Files (Entire Folder)"
Write-Host "Q. Quit"
Write-Host "------------------------------------------"

$selection = Read-Host "Select an option"

switch ($selection) {
    "1" { $type = "MOD";    $needsFolder = $false; $validExt = ".tar"; $allowMultiple = $false }
    "2" { $type = "PLUGIN"; $needsFolder = $false; $validExt = ".kbplugin"; $allowMultiple = $true }
    "3" { $type = "MODULE"; $needsFolder = $true;  $validExt = $null; $allowMultiple = $false }
    "4" { $type = "GAME";   $needsFolder = $true;  $validExt = $null; $allowMultiple = $false }
    "Q" { exit }
    Default { Write-Host "Invalid selection."; exit }
}

# --- 2. COLLECT AND VALIDATE INPUT ---
Write-Host "`n[$type] Selected." -ForegroundColor Yellow

if ($allowMultiple) {
    Write-Host "TIP: You can drag multiple files separated by spaces!" -ForegroundColor Cyan
}

$inputPath = (Read-Host "Enter path(s) (drag and drop here)").Trim('"')

# Parse multiple paths (handles both quoted and unquoted paths)
$sourcePaths = @()
if ($allowMultiple) {
    # Split by quotes and spaces, filter empty entries
    $rawPaths = $inputPath -split '"\s+"' -split '\s+' | Where-Object { $_ -ne "" }
    foreach ($path in $rawPaths) {
        $cleanPath = $path.Trim('"').Trim()
        if ($cleanPath) {
            $sourcePaths += $cleanPath
        }
    }
} else {
    $sourcePaths = @($inputPath)
}

# Validate all paths exist
$invalidPaths = @()
foreach ($path in $sourcePaths) {
    if (-not (Test-Path $path)) {
        $invalidPaths += $path
    }
}

if ($invalidPaths.Count -gt 0) {
    Write-Host "ERROR: The following path(s) not found:" -ForegroundColor Red
    $invalidPaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit
}

Write-Host "`nFound $($sourcePaths.Count) file(s) to import." -ForegroundColor Green

# --- VALIDATE EACH FILE ---
foreach ($sourcePath in $sourcePaths) {
    $item = Get-Item $sourcePath
    $isActuallyFolder = $item -is [System.IO.DirectoryInfo]

    # --- SMART FOLDER / FILE SANITY CHECKS ---
    if ($needsFolder -and -not $isActuallyFolder) {
        $parentFolder = Split-Path $sourcePath -Parent
        Write-Host "`n[!] Option '$type' requires a folder, but you selected a file." -ForegroundColor Yellow
        $conf = Read-Host "Would you like to switch to parent directory: $parentFolder? (Y/n)"
        
        if ($conf -eq "" -or $conf.ToLower() -eq "y") {
            $sourcePaths = @($parentFolder)
            break
        } else {
            Write-Host "Aborted." -ForegroundColor Red; exit
        }
    } 
    elseif (-not $needsFolder -and $isActuallyFolder) {
        Write-Host "ERROR: Option '$type' requires a specific file ($validExt), but you provided a folder: $sourcePath" -ForegroundColor Red
        exit
    }
    elseif (-not $needsFolder -and -not $isActuallyFolder) {
        $currentExt = [System.IO.Path]::GetExtension($sourcePath)
        
        # Special handling for MOD files - check if it's a tar without extension
        if ($type -eq "MOD" -and [string]::IsNullOrEmpty($currentExt)) {
            Write-Host "File has no extension. Checking if it's a valid tar archive..." -ForegroundColor Yellow
            
            # Read only first 512 bytes to check for tar signature (handles large files)
            try {
                $fileStream = [System.IO.File]::OpenRead($sourcePath)
                $buffer = New-Object byte[] 512
                $bytesRead = $fileStream.Read($buffer, 0, 512)
                $fileStream.Close()
                
                if ($bytesRead -lt 262) {
                    Write-Host "ERROR: File is too small to be a valid tar archive." -ForegroundColor Red
                    exit
                }
                
                # Check for "ustar" signature at byte offset 257 (tar format identifier)
                $ustarSignature = [System.Text.Encoding]::ASCII.GetString($buffer[257..261])
                
                if ($ustarSignature -eq "ustar") {
                    Write-Host "SUCCESS: Valid tar archive detected (exported without extension)." -ForegroundColor Green
                    # Continue processing - this is valid
                } else {
                    Write-Host "ERROR: File does not appear to be a valid tar archive." -ForegroundColor Red
                    Write-Host "Expected tar signature not found. Please verify the file." -ForegroundColor Red
                    exit
                }
            }
            catch {
                Write-Host "ERROR: Unable to read file for validation: $_" -ForegroundColor Red
                exit
            }
        }
        elseif ($currentExt -ne $validExt) {
            Write-Host "ERROR: Invalid file type for '$sourcePath'! Expected $validExt but got $currentExt" -ForegroundColor Red
            exit
        }
    }
}

# --- 3. VOLUME DISCOVERY ---
Write-Host "`n--- Current Docker Volumes ---" -ForegroundColor Gray
docker volume ls --format "{{.Name}}"
Write-Host "-------------------------------" -ForegroundColor Gray

Write-Host "TIP: You can type an existing volume name to update it," -ForegroundColor Cyan
Write-Host "     OR type a NEW name to create a brand new volume." -ForegroundColor Cyan

$volName = Read-Host "`nEnter the destination Docker Volume name"

if ([string]::IsNullOrWhiteSpace($volName)) {
    Write-Host "ERROR: Volume name cannot be empty." -ForegroundColor Red; exit
}

$existingVolumes = docker volume ls --format "{{.Name}}"
if ($volName -notin $existingVolumes) {
    Write-Host "Volume '$volName' not found. Docker will create it automatically." -ForegroundColor Yellow
}

# --- 4. EXECUTION ---
Write-Host "`nStarting import process..." -ForegroundColor Green

$successCount = 0
$failCount = 0

foreach ($sourcePath in $sourcePaths) {
    $fileName = Split-Path $sourcePath -Leaf
    Write-Host "`n[$($sourcePaths.IndexOf($sourcePath) + 1)/$($sourcePaths.Count)] Processing: $fileName" -ForegroundColor Cyan

    if ($type -eq "MODULE" -or $type -eq "GAME") {
        Write-Host "Using RSYNC to sync files. Watch progress below:" -ForegroundColor Gray
        docker run --rm `
            -v "${sourcePath}:/source" `
            -v "${volName}:/dest" `
            alpine sh -c "apk add --no-cache rsync && rsync -ah --info=progress2 --no-inc-recursive /source/ /dest/"
    }
    elseif ($type -eq "MOD") {
        Write-Host "Extracting archive... Large mod collections (4GB+) may take a few minutes." -ForegroundColor Yellow
        Write-Host "Please do not close this window until you see SUCCESS." -ForegroundColor Gray
        docker run --rm -v "${sourcePath}:/archive.tar" -v "${volName}:/dest" alpine tar -xf /archive.tar -C /dest
    }
    else {
        Write-Host "Copying plugin file..." -ForegroundColor Gray
        docker run --rm -v "${sourcePath}:/source/$fileName" -v "${volName}:/dest" alpine cp "/source/$fileName" /dest/
    }

    if ($?) { 
        Write-Host "  ? SUCCESS: $fileName imported" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  ? FAILED: $fileName" -ForegroundColor Red
        $failCount++
    }
}

# --- 5. SUMMARY ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "IMPORT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Destination: $volName" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host "`nSome imports failed. Check your Docker Desktop status." -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")