<#
.SYNOPSIS
    v1.0 Final - KYBER Server Asset Importer
    - Added: Feedback message for large MOD extraction to prevent user panic.
    - Validates file extensions (.tar, .kbplugin).
    - Interactive Y/n switch for parent folder detection.
    - Volume Discovery with "New Volume" clarification.
    - Rsync progress bars for Game Files and Modules.
#>

# --- 1. SETUP AND MENU ---
Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   KYBER Server Asset Importer (v1.0)     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "1. Import Mod Collection (.tar)"
Write-Host "2. Import Plugin (.kbplugin)"
Write-Host "3. Import Kyber Module (Folder or Kyber.dll)"
Write-Host "4. Import Game Files (Entire Folder)"
Write-Host "Q. Quit"
Write-Host "------------------------------------------"

$selection = Read-Host "Select an option"

switch ($selection) {
    "1" { $type = "MOD";    $needsFolder = $false; $validExt = ".tar" }
    "2" { $type = "PLUGIN"; $needsFolder = $false; $validExt = ".kbplugin" }
    "3" { $type = "MODULE"; $needsFolder = $true;  $validExt = $null }
    "4" { $type = "GAME";   $needsFolder = $true;  $validExt = $null }
    "Q" { exit }
    Default { Write-Host "Invalid selection."; exit }
}

# --- 2. COLLECT AND VALIDATE INPUT ---
Write-Host "`n[$type] Selected." -ForegroundColor Yellow
$sourcePath = (Read-Host "Enter path (drag and drop here)").Trim('"')

if (-not (Test-Path $sourcePath)) {
    Write-Host "ERROR: Path not found." -ForegroundColor Red; exit
}

$item = Get-Item $sourcePath
$isActuallyFolder = $item -is [System.IO.DirectoryInfo]

# --- SMART FOLDER / FILE SANITY CHECKS ---
if ($needsFolder -and -not $isActuallyFolder) {
    $parentFolder = Split-Path $sourcePath -Parent
    Write-Host "`n[!] Option '$type' requires a folder, but you selected a file." -ForegroundColor Yellow
    $conf = Read-Host "Would you like to switch to parent directory: $parentFolder? (Y/n)"
    
    if ($conf -eq "" -or $conf.ToLower() -eq "y") {
        $sourcePath = $parentFolder
    } else {
        Write-Host "Aborted." -ForegroundColor Red; exit
    }
} 
elseif (-not $needsFolder -and $isActuallyFolder) {
    Write-Host "ERROR: Option '$type' requires a specific file ($validExt), but you provided a folder." -ForegroundColor Red
    exit
}
elseif (-not $needsFolder -and -not $isActuallyFolder) {
    $currentExt = [System.IO.Path]::GetExtension($sourcePath)
    if ($currentExt -ne $validExt) {
        Write-Host "ERROR: Invalid file type! Expected $validExt but got $currentExt" -ForegroundColor Red
        exit
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
Write-Host "`nStarting helper container..." -ForegroundColor Green

if ($type -eq "MODULE" -or $type -eq "GAME") {
    Write-Host "Using RSYNC to sync files. Watch progress below:" -ForegroundColor Gray
    docker run --rm `
        -v "${sourcePath}:/source" `
        -v "${volName}:/dest" `
        alpine sh -c "apk add --no-cache rsync && rsync -ah --info=progress2 --no-inc-recursive /source/ /dest/"
}
elseif ($type -eq "MOD") {
    # ADDED: Feedback for large TAR archives
    Write-Host "Extracting archive... Large mod collections (4GB+) may take a few minutes." -ForegroundColor Yellow
    Write-Host "Please do not close this window until you see SUCCESS." -ForegroundColor Gray
    docker run --rm -v "${sourcePath}:/archive.tar" -v "${volName}:/dest" alpine tar -xf /archive.tar -C /dest
}
else {
    $fileName = Split-Path $sourcePath -Leaf
    Write-Host "Copying plugin file..." -ForegroundColor Gray
    docker run --rm -v "${sourcePath}:/source/$fileName" -v "${volName}:/dest" alpine cp "/source/$fileName" /dest/
}

if ($?) { 
    Write-Host "`nSUCCESS! Asset imported to $volName" -ForegroundColor Cyan 
} else {
    Write-Host "`nERROR: The Docker command failed. Check your Docker Desktop status." -ForegroundColor Red
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")