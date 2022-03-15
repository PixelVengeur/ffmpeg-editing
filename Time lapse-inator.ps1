$sourceDir = Read-Host "Path to the folder containing the footage to speed up (type . for the current folder)"
$temp = Read-Host "Path to save temporary files to"
$pts = Read-Host "Speed multiplier"
$fps = Read-Host "Target FPS"

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
ForEach ($file in Get-ChildItem -Path $sourceDir) {
    if ($file -match "([0-9].mkv)$") {
        echo "Speeding up $file"
        ffmpeg -y -i $sourceDir\$file -hide_banner -loglevel error -max_interleave_delta 0 -filter:v "setpts=PTS/$pts" -an -r $fps -b:v 8000k $temp\Fast$file
    }
}

echo "All footage has been sped up"

# Supprimer les frames en double dans chaque fichier accéléré
#ForEach ($file in Get-ChildItem $temp){
#    if ($file -match "(.mkv)$") {
#        echo "Cleaning up $file"
#        ffmpeg -i $temp\$file -loglevel error -vf mpdecimate,setpts=N/$fps/TB -map 0:v -vsync vfr -max_muxing_queue_size 9999 $temp\Clean$file
#    }
#}

echo "Concatenating sped-up footage"

# Vérifier si list.txt existe
if (-not(Test-Path -Path $temp\list.txt -PathType Leaf)) {
    New-Item -Path $temp -Name list.txt -ItemType file
}
else {
    Clear-Content -Path $temp\list.txt
}

# Ajouter les fichiers accélérés à list.txt
echo "Listing files"
ForEach ($file in Get-ChildItem $temp){
    if ($file -match "(.mkv)$") {
        $filePath ="file $temp\$file"
        $filePath = $filePath -replace '[\\/]', '/'
        Add-Content -Path $temp\list.txt -Value $filePath
    }
}

# Concaténer les fichiers accélérés
echo "Creating the timelapse"
ffmpeg -loglevel error -f concat -safe 0 -i $temp\list.txt -c copy $temp\output.mkv

#Nettoyer le ficheir concaténé
echo "Cleaning up the timelapse"
ffmpeg -i $temp\output.mkv -loglevel error -vf mpdecimate,setpts=N/$fps/TB -map 0:v -vsync vfr -max_muxing_queue_size 9999 $sourceDir\Timelapse.mkv

## CLEANUP
# Supprimer le dossier temp récursivement
$del = Read-Host "Do you want to delete the temporary directory and all its content? (Y/N)"

if ($del -eq "y" -or $del -eq "Y") {
    try {
        Remove-Item $temp -Recurse
    }
    catch {
        "An error occured removing a temporary file"
    }
}
