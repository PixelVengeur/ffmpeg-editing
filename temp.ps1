
    if (!(Test-Path($image))) {
        Write-Error("Image file path is not a real path")
    }

    if (!(Test-Path($videoFolder))) {
        Write-Error("Video folder path is not a real path")
    }

    if (!(Test-Path("$videoFolder\soustitres.json"))) {
        Write-Error("No subtitles file found")
    }
    #endregion


    # region Lister toutes les vidéos
    Clear-Content .\config\videos.txt
    foreach ($file in Get-ChildItem $($videoFolder + "\*") -Include @("*.mkv")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\config\videos.txt -Value $filePath
    }
    # endregion


    # region Lister tous les audios
    Clear-Content .\config\audios.txt
    foreach ($file in Get-ChildItem $($videoFolder + "\*") -Include @("*.wav")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\config\audios.txt -Value $filePath
    }

    if (Get-Content -Path .\config\audios.txt -eq "") {
        Write-Error("No music found, consider aborting")
    }
    # endregion


    # region Nombre de frames dupliquées
    Clear-Content .\config\duplicates.txt
    $duplicateFrames = 0
    $content = Get-Content -Path .\config\videos.txt
    foreach ($line in $content) {
        $videoName = $line.Trim("file").Trim().Trim("'")
        # Lister les frames dupliquées et ajouter au fichier
        Write-Host -NoNewline "`rFinding duplicate frames... $($content.IndexOf($line) + 1)/$($content.Length)" -ForegroundColor Yellow
        ffmpeg -i $videoName -vf mpdecimate -loglevel debug -an -f null - 2>&1 | Select-String -Pattern 'drop_count:\d+' -All | ForEach-Object { $_.Matches[0].Value } > .\config\duplicates.txt
        # Lire la dernière ligne, extraire le nombre de frames droppées, l'ajouter à $duplicateFrames
        Get-Content -Path ".\config\duplicates.txt" -Tail 1 | Select-String -Pattern '\d+' -AllMatches | ForEach-Object { $duplicateFrames += $_.Matches[0].Value }
    }
    Write-Host "`nNombre d'images dupliquées : $duplicateFrames" -ForegroundColor Magenta

    $videoLength = 0
    $content = Get-Content -Path .\config\videos.txt
    foreach ($line in $content) {
        $videoName = $line.Trim("file").Trim().Trim("'")
        # Write-Output $videoName
        $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $videoName
        $videoLength += $duration
    }
    $videoLength = [math]::ceiling($videoLength)
    # Durée après accélération x20
    $videoShort = $videoLength/20
    # Soustraction des images dupliquées
    $videoShort = ($videoShort * 60 - $duplicateFrames) / 60
    Write-Host "Longueur vidéo : $([math]::Round($videoShort)) secondes ou $([math]::Floor($videoShort/60))m$([math]::ceiling($videoShort%60))s" -ForegroundColor Magenta


    #endregion


    # region Longueur des fichiers audio
    $audioLength = 0
    $audioTotal = 0
    $content = Get-Content -Path .\config\audios.txt
    foreach ($line in $content) {
        $audio = $line.Trim("file").Trim().Trim("'")
        $audioTotal++
        $audioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio
    }
    $audioLength = [math]::ceiling($audioLength)

    Write-Host "Longueur audio : $audioLength secondes ou $([math]::Floor($audioLength/60))m$($audioLength%60)s" -ForegroundColor Magenta
    # endregion

    # exit

    # region Accélérer la vidéo à la durée des audios -20s
    ## Accélérer la vidéo + fade
    if (($audioLength -gt ($videoLength/20) + 20) -or $audioLength -eq 0)
    {
        Write-Host -ForegroundColor DarkRed "There is not enough video footage to span the entire length of the songs.`nPlease remove some music or add more video files.`n"
        Read-Host "Press any key to exit"
        exit
    }

    #### TIMELAPSE
    $speedUpScript = "$PSScriptRoot\Timelapse-inator.ps1"
    & $speedUpScript -sourceDir "$videoFolder" -temp ".\temp\speedup" -pts 20 -fps 60 -del "Y"
    
    $video = ".\temp\Timelapse.mkv"
    $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $video
    Write-Host "Longueur vidéo post traitement = $duration secondes ou $([math]::Floor($duration/60))m$($duration%60)s" -ForegroundColor Magenta

    $speedUpFactor = $audioLength / ([Int32]$duration + 20)
    # Write-Host -ForegroundColor Blue "$speedUpFactor, $duration"
    $target = [math]::Round($speedUpFactor * $duration)
    Write-Host -ForegroundColor Magenta "Durée cible: $target secondes ou $([math]::Floor($target/60))m$($target%60)s"
   
    #### Compute the fade out 
    $frames = ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $video
    $framerate = [math]::ceiling($frames / $duration)
    $fadeOutStart = ($frames - 1.5 * ($framerate / $speedUpFactor))

    Write-Host "Speeding up and adding fades" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -i $video -vf "setpts=PTS*$speedUpFactor,fade=in:st=0:d=3,fade=out:s=${fadeOutStart}:d=1.5" -r 60 -an -sn -max_interleave_delta 0 .\temp\speed.mkv
    
    # endregion


    # region Écran de fin de vidéo

    ### Scale image to fit
    $dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\speed.mkv
    $videoW, $videoH = $dimensions.Split("x")
    $dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $image
    $imageW, $imageH = $dimensions.Split("x")
    # Write-Host "$imageW, $imageH" -ForegroundColor Blue

    # Write-Host "Vidéo: $videoW x $videoH, Image: $imageW x $imageH"

    if (($imageW - $imageH) -gt 0) {
        # echo OK
        # $ratio = $imageW / $imageH
        ffmpeg -y -loglevel error -stats -i $image -vf scale=-1:${videoH}*1.25 .\temp\top.jpg
    }
    else {
        # $ratio = $imageH / $imageW
        ffmpeg -y -loglevel error -stats -i $image -vf scale=${videoW}*0.65:-1 .\temp\top.jpg
    }


    Write-Host "Scaling end credits" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -i $image -vf scale=${videoW}*1.15:-1,boxblur=15,eq=brightness=-0.25 .\temp\bottom.jpg

    ####Squaring out images
    Write-Host "Squaring out images" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -i .\temp\top.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\top.jpg
    ffmpeg -y -loglevel error -stats -i .\temp\bottom.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\bottom.jpg

    ### Overlay image and animate
    Write-Host "Overlaying images" -ForegroundColor Magenta

    #### Bottom
    $bottomDimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\bottom.jpg
    $bottomW, $bottomH = $bottomDimensions.Split("x")

    $hiddenHeight = ($videoH - $bottomH) * 0.1
    $pps = $hiddenHeight / 10

    Write-Host "`tBottom" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -loop 1 -r 60 -i .\temp\bottom.jpg -i .\temp\speed.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 - ${hiddenHeight}) + t*$pps" -r 60 -t 20 .\temp\bottom.mkv


    #### Top
    $topDimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\top.jpg
    $topW, $topH = $topDimensions.Split("x")

    $hiddenHeight = ($videoH - $topH) * 0.5
    $pps = $hiddenHeight/10

    Write-Host "`tTop" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -loop 1 -r 60 -i .\temp\top.jpg -i .\temp\bottom.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 + $hiddenHeight) - t*$pps,
    fade=t=in:st=0:d=1.5,
    fade=t=out:st=17:d=3" -r 60 -t 20 .\temp\overlayed.mkv

    #endregion

    
    # region Ajouter l'écran de fin à la vidéo
    Write-Host "Concatenating" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\concat.ffmpeg -c copy .\temp\output.mkv 
    # endregion


    # region Ajouter la musique
    Write-Host "Adding music" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\config\audios.txt -c copy .\temp\output.wav

    $audioFadeStart = $audioLength - 5

    ffmpeg -y -loglevel error -stats -i .\temp\output.wav -af "volume=-6.72dB,afade=t=out:st=${audioFadeStart}:d=5" .\temp\outputFade.wav

    ffmpeg -y -loglevel error -stats -i .\temp\output.mkv -i .\temp\outputFade.wav -map 0:v -map 1:a -c:v copy .\temp\nosub.mkv

    # endregion