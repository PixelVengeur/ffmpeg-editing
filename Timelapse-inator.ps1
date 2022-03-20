
param([string]$sourceDir = "",
[string]$temp = "",
[Int32]$pts = -1,
[Int32]$fps = -1,
[string]$del = "")

#region __main__
if ($sourceDir -eq "")
{
    $sourceDir = Read-Host "Path to the folder containing the footage to speed up (type . for the current folder)"
}

if ($temp -eq "")
{
    $temp = Read-Host "Path to the temporary folder"
}

if ($pts -eq -1)
{
    $pts = Read-Host "Speed multiplier"
}

if ($fps -eq -1)
{
    $fps = Read-Host "Target FPS"
}
#endregion

if ($sourceDir -eq $temp) {
    $temp = "$sourceDir/temp"
}

# Vérifier le dossier contenant les vidéos
if (-not(Test-Path -Path $sourceDir -PathType Container)) {
    Write-Host "Unable to locate $sourceDir"
    Exit 1
}

# Vérifier si le dossier temp existe
if (-not(Test-Path -Path $temp -PathType Container)) {
    Write-Host "Creating $temp"
    New-Item -Path $temp -ItemType "directory"
}

# Accélérer chaque vidéo une à une
ForEach ($file in Get-ChildItem -Path $sourceDir -Name -Include @("*.mkv")) {
    Write-Host "Speeding up $file" -ForegroundColor Yellow
    ffmpeg -y -i "$sourceDir\$file" -hide_banner -loglevel error -stats -max_interleave_delta 0 -filter:v "setpts=PTS/$pts" -an -r $fps $temp\Fast$file
}

Write-Host "All footage has been sped up`nConcatenating sped-up footage" -ForegroundColor Yellow

# Vérifier si list.txt existe
if (-not(Test-Path -Path $temp\list.txt -PathType Leaf)) {
    New-Item -Path $temp -Name list.txt -ItemType file
}
else {
    Clear-Content -Path $temp\list.txt
}

# Ajouter les fichiers accélérés à list.txt
Write-Host "Listing files" -ForegroundColor Yellow
ForEach ($file in Get-ChildItem $temp\* -Include @("*.mkv")) {
    $filePath ="file '$file'"
    # $filePath = $filePath -replace '[\\/]', '/'
    Add-Content -Path $temp\list.txt -Value $filePath
}

# Concaténer les fichiers accélérés
Write-Host "Creating the timelapse" -ForegroundColor Yellow
ffmpeg -y -loglevel error -stats -f concat -safe 0 -i ${temp}\list.txt -c copy $temp\output.mkv

#Nettoyer le fichier concaténé
Write-Host "Cleaning up the timelapse" -ForegroundColor Yellow
ffmpeg -y -i $temp\output.mkv -loglevel error -stats -vf mpdecimate,setpts=N/$fps/TB -map 0:v -vsync vfr -max_muxing_queue_size 9999 $temp\Timelapse.mkv

## CLEANUP
# Supprimer le dossier temp récursivement
if ($del -eq "")
{
    $del = Read-Host "Do you want to delete the temporary directory and all its content? (Y/N)"
}

if ($del -eq "y" -or $del -eq "Y") {
    try {
        Remove-Item $temp -Recurse
    }
    catch {
        "An error occured removing a temporary file"
    }
}

return "$sourceDir\Timelapse.mkv"
