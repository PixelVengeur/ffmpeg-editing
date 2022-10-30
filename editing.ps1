# TODO Ajouter la valeur du multiplicateur de vitesse du time lapse
# TODO "Total work time"
# TODO Investiguer le -c:v copy dans l'ajout de la musique, il n'est pas pris en compte et donc réencode déjà le fichier

param(
    [string]$image = "",
    [string]$videoFolder = "")


function generateTextBlurb {
    <#
        .SYNOPSIS
            Creates the titles to display on screen when the music changes

        .DESCRIPTION
            The subtitles are composed of the name of the music and its composer. They will both be displayed on hte bottom left. The artist will be under the title, in a smaller font size, both aligned to the left.
            It will generate the text, style it in a font, give it a shadow, a colour, a border and most importantly time it correctly based on the duration of the music files in config/audios.txt

        .PARAMETER startTS
            The TimeStamp at which the title should Start in the video

        .PARAMETER title
            The title of the music

        .PARAMETER artist
            The composer of the music

        .EXAMPLE
            generateTextBlurb -startTS 4 -title "Never gonna give you up" -artist "Rick Astley"

    #>
    param ($startTS, $title, $artist)

    $filterTitle = "drawtext=
    text=${title}
    :shadowx=4
    :shadowy=3
    :shadowcolor=black@0.35
    :borderw=2
    :bordercolor=black@0.25
    :fontfile=/Users/pixel/AppData/Local/Microsoft/Windows/Fonts/LEMONMILK-Regular.otf
    :fontcolor=#ffffff@0.9
    :fontsize=42
    :line_spacing=6
    :alpha='if(lt(t,$startTS),0,if(lt(t,$startTS + 0.5),(t-$startTS)/0.625,if(lt(t,$startTS + 5.5),0.8,if(lt(t,$startTS + 6),(0.5-(t-($startTS + 5.5)))/0.625,0))))'
    :x=50
    :y=(h-text_h)/10*9"
    $filterArtist = "drawtext=
    text=${artist}
    :shadowx=4
    :shadowy=3
    :shadowcolor=black@0.35
    :borderw=2
    :bordercolor=black@0.25
    :fontfile=/Users/pixel/AppData/Local/Microsoft/Windows/Fonts/LEMONMILK-Regular.otf
    :fontcolor=#c0c0c0@0.9
    :fontsize=36
    :line_spacing=15
    :alpha='if(lt(t,$startTS),0,if(lt(t,$startTS + 0.5),(t-$startTS)/0.625,if(lt(t,$startTS + 5.5),0.8,if(lt(t,$startTS + 6),(0.5-(t-($startTS + 5.5)))/0.625,0))))'
    :x=52
    :y=(h-text_h)/10*9 + 50"

    return "$filterTitle, $filterArtist"
}

function checkSubtitleFile {
    <#
        .SYNOPSIS
            Checks if everything is in order with the subtitles file

        .DESCRIPTION
            The file must be valid JSON, and not contain any 'illegal' characters for Powershell.
    #>

    $subtitleFile = "$videoFolder\soustitres.json"

    if (!(Test-Path($subtitleFile))) {
        Write-Error("No subtitles file found")
    }

    if  (!(Get-Content -Path $subtitleFile -Raw | Test-Json)) {
        Write-Error("Subtitles are not valid JSON")
        throw "Subtitles are not valid JSON"
    }

    $json = Get-Content -Path $subtitleFile | ConvertFrom-Json -AsHashtable
    $json.Artists.GetEnumerator() | ForEach-Object {
        $artist =  $_.Value
        $title = $json.Titles[$_.key]

        foreach($banned in @(',', '°', '(', ')','[',']', '"',"{", "}",'ä', 'ü', 'ö', 'ê', 'é', 'è')) {
            if ($artist.IndexOf($banned) -ne -1) {
                Write-Error "<$banned> character present in $artist"
            }
            if ($title.IndexOf($banned) -ne -1) {
                Write-Error "<$banned> character present in $title"
            }
        }
    }
}

function EditVideo {
    <#
        .SYNOPSIS
            Edits the separate video, audio and config files into one time lapse

        .DESCRIPTION
            The subtitles are composed of the name of the music and its composer. They will both be displayed on hte bottom left. The artist will be under the title, in a smaller font size, both aligned to the left.
            It will generate the text, style it in a font, give it a shadow, a colour, a border and most importantly time it correctly based on the duration of the music files in config/audios.txt

        .PARAMETER image
            The final image, to be displayed at the end of the time lapse

        .PARAMETER videoFolder
            The folder containing the .mkv video files, .wav audio files and .json subtitles file

        .EXAMPLE
            EditVideo -image "/path/to/image.png" -videoFolder "/path/to/folder"
    #>

    param(
        [Parameter(Mandatory)]
        [string]$image,
        [string]$videoFolder
        )


    # region Check if files are present
    if (!(Test-Path($image))) {
        Write-Error("Image file path is not a real path")
    }

    if (!(Test-Path($videoFolder))) {
        Write-Error("Video folder path is not a real path")
    }
    #endregion


    # region List all videos in the $videoFolder
    Clear-Content .\config\videos.txt
    foreach ($file in Get-ChildItem $($videoFolder + "\*") -Include @("*.mkv")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\config\videos.txt -Value $filePath
    }
    # endregion


    # region Nombre de frames dupliquées
    Clear-Content .\config\duplicates.txt
    $duplicateFrames = 0

    # TODO Remake that so it works and gives acurate predictions of duplicate frames
    <# $content = Get-Content -Path .\config\videos.txt
     foreach ($line in $content) {
         $videoName = $line.Trim("file").Trim().Trim("'")
         # Lister les frames dupliquées et ajouter au fichier
         Write-Host -NoNewline "`rFinding duplicate frames... $($content.IndexOf($line) + 1)/$($content.Length)" -ForegroundColor Yellow
         ffmpeg -i $videoName -vf mpdecimate -loglevel debug -an -f null - 2>&1 | Select-String -Pattern 'drop_count:\d+' -All | ForEach-Object { $_.Matches[0].Value } > .\config\duplicates.txt
         # Lire la dernière ligne, extraire le nombre de frames droppées, l'ajouter à $duplicateFrames
         Get-Content -Path ".\config\duplicates.txt" -Tail 1 | Select-String -Pattern '\d+' -AllMatches | ForEach-Object { $duplicateFrames += $_.Matches[0].Value }
     }
     Write-Host "`nNombre d'images dupliquées : $duplicateFrames" -ForegroundColor Magenta #>

     Write-Host "Computing estimated time lapse length" -ForegroundColor Magenta

    $videoLength = 0
    $content = Get-Content -Path .\config\videos.txt
    foreach ($line in $content) {
        $videoName = $line.Trim("file").Trim().Trim("'")
        
        # Extract the duration of a file from ffprobe
        $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $videoName
        $videoLength += $duration
    }
    $videoLength = [math]::ceiling($videoLength)

    # Length after a 20x acceleration
    $videoShort = $videoLength/20

    # (Legacy) Substract the number of duplicate frames to the total number of frames to get an estimation of the final length
    $videoShort = ($videoShort * 60 - $duplicateFrames) / 60
    
    Write-Host "Video length: $([math]::Round($videoShort)) secondes ou $([math]::Floor($videoShort/60))m$([math]::ceiling($videoShort%60))s" -ForegroundColor Magenta

    #endregion


    # region List all the audios in the $videoFolder
    Clear-Content .\config\audios.txt
    foreach ($file in Get-ChildItem $($videoFolder + "\*") -Include @("*.wav")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\config\audios.txt -Value $filePath
    }

    if (!(Get-Content -Path .\config\audios.txt)) {
        Write-Error("No music found, aborting")
        Read-Host
        exit
    }
    # endregion
    
    
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
  
    checkSubtitleFile

    # region Accélérer la vidéo
    ## Accélérer la vidéo
    if (($audioLength -gt ($videoLength/20) + 20) -or $audioLength -eq 0)
    {
        Write-Host -ForegroundColor DarkRed "There is not enough video footage to span the entire length of the songs.`nPlease remove some music or add more video files.`n"
        Read-Host "Press any key to exit"
        exit
    }

    #### TIMELAPSE
    $speedUpScript = "$PSScriptRoot\Timelapse-inator.ps1"
    & $speedUpScript -sourceDir "$videoFolder" -temp ".\temp\speedup" -pts 20 -fps 60 -del "Y"
    
    $video = ".\temp\Concatenated.mkv"
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

    Write-Host "Computed speed factor and fades" -ForegroundColor Magenta
    
    # endregion


    # region Compute titles
    $sousTitres = Get-Content -Path $videoFolder\soustitres.json | ConvertFrom-Json

    $counter = 0
    $prevAudioLength = 0
    $subtitleFilter = ""

    foreach ($line in Get-Content .\config\audios.txt)
    {
        $line = $line.Trim("file").Trim().Trim("'")
        $counter++

        $subtitleFilter += generateTextBlurb -startTS $($prevAudioLength + 4) -title $sousTitres.Titles.$counter -artist $sousTitres.Artists.$counter
        $subtitleFilter+= ", "

        $prevAudioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $line
    }

    $subtitleFilter = $subtitleFilter.TrimEnd(", ")
    # echo $subtitleFilter

    Write-Host "Computed titles" -ForegroundColor Magenta
    $outName = $videoFolder.SubString(11)
    
    # endregion

    
    # region Adding all effects
    $dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\Concatenated.mkv
    $videoW, $videoH = $dimensions.Split("x")
    $dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $image
    $imageW, $imageH = $dimensions.Split("x")
    Write-Host "Vidéo: $videoW x $videoH, Image: $imageW x $imageH" -ForegroundColor Blue

    Write-Host "Adjusting speed, adding fades, burning in subtitles, adding watermark" -ForegroundColor Yellow
    # ffmpeg -y -loglevel error -stats -i $video -vf "setpts=PTS*$speedUpFactor,fade=in:st=0:d=3,fade=out:s=${fadeOutStart}:d=1.5" -r 60 -an -sn -max_interleave_delta 0 .\temp\speed.mkv
    
    ffmpeg-bar -y -loglevel info -hide_banner -stats -i $video -i .\images\wm.png -filter_complex "
    [1:v]
    scale=-1:200,
    colorchannelmixer=aa=0.3[ovrl],
    [0:v]setpts=PTS*$speedUpFactor,
    fade=in:st=0:d=3,
    fade=out:s=${fadeOutStart}:d=1.5[video],
    [video][ovrl]overlay=$($videoW - 180):$($videoH - 220),
    $subtitleFilter" -r 60 -an -sn -max_interleave_delta 0 ".\temp\speed.mkv"

    #endregion

    
    # region Écran de fin de vidéo

    ### Scale images to fit
    if (!(Test-Path .\temp\overlay)) {
        New-Item -Path .\temp\overlay -ItemType "directory"
    }
    ffmpeg -y -loglevel error -stats -i $image -vf scale=-1:${videoH}+1200 .\temp\overlay\top.jpg   #+1200 because it'll scroll for 20 seconds at 60 FPS
    ffmpeg -y -loglevel error -stats -i $image -vf scale=${videoW}:-1 .\temp\overlay\bottom.jpg


    ####Squaring out images
    Write-Host "Squaring out images" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -i .\temp\overlay\top.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\overlay\top.jpg
    ffmpeg -y -loglevel error -stats -i .\temp\overlay\bottom.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\overlay\bottom.jpg

    ### Overlay image and animate
    Write-Host "Overlaying images" -ForegroundColor Magenta

    Write-Host "\tBottom" -ForegroundColor Magenta
    ffmpeg-bar -y -loglevel info -stats -r 60 -t 20 -i .\temp\speed.mkv -i .\temp\overlay\bottom.jpg -filter_complex "[1:v]scale=3440*1.1:-1,
    boxblur=15,
    eq=brightness=-0.25[fg],
    [0:v][fg]overlay=0:-420 - t*30" .\temp\overlay\bottom.mkv

    Write-Host "\tTop" -ForegroundColor Magenta
    ffmpeg-bar -y -loglevel info -stats -r 60 -t 20 -i .\temp\overlay\bottom.mkv -i .\temp\overlay\top.jpg -filter_complex "[0:v][1:v]overlay=(W - w)/2:H-h + t*(h-H)/20,
    fade=t=in:st=0:d=1.5,
    fade=t=out:st=17:d=3" .\temp\overlay\overlayed.mkv

    #endregion


    # region Ajouter l'écran de fin à la vidéo
    Write-Host "Concatenating" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\concat.ffmpeg -c copy .\temp\noaudio.mkv 
    # endregion


    # region Ajouter la musique
    if (!(Test-Path .\temp\audio)) {
        New-Item -Path .\temp\audio -ItemType "directory"
    }
    Write-Host "Adding music" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\config\audios.txt -c copy .\temp\audio\output.wav

    $audioFadeStart = $audioLength - 5

    ffmpeg -y -loglevel error -hide_banner -stats -i .\temp\audio\output.wav -af "volume=-6.72dB,afade=t=out:st=${audioFadeStart}:d=5" .\temp\audio\outputFade.wav

    ffmpeg -y -loglevel info -hide_banner -stats -i .\temp\noaudio.mkv -i .\temp\audio\outputFade.wav -map 0:v -map 1:a -c:v copy ".\out\$outName.mkv"

    # endregion


    # region Reencode
    
    if ($videoFolder.Contains("F:\Blender\"))
    {
        $filename = $videoFolder.Replace("F:\Blender\", "")
    }
    else
    {
        $filename = "OUT[" + -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_}) + "]"
    }

    Write-Host "AV1 reencode" -ForegroundColor Magenta
    ffmpeg -y -loglevel info -hide_banner -stats -i ".\out\$outName.mkv" -c:v libsvtav1 -preset 6 -crf 30 -b:v 0 -svtav1-params tune=0 "C:\Users\pixel\Desktop\To_upload\$filename.webm"

    # Write-Host "VP9 reencode" -ForegroundColor Magenta
    # Write-Host "`tFirst pass" -ForegroundColor Magenta
    # ffmpeg -y -loglevel error -hide_banner -stats -i .\out\output.mkv -c:v libvpx-vp9 -pass 1 -b:v 5M -sc_threshold 0 -speed 4 -row-mt 1 -tile-columns 4 -f webm NUL $null

    # Write-Host "`tSecond pass" -ForegroundColor Magenta
    # ffmpeg -y -loglevel error -hide_banner -stats -i .\out\output.mkv -c:v libvpx-vp9 -pass 2 -b:v 5M -sc_threshold 0 -row-mt 1 -speed 2 -tile-columns 4 "C:\Users\pixel\Desktop\To_upload\$filename.webm"

    # endregion


    # region Cleanup
    # Remove-Item .\temp -Recurse
    #endregion
}


# Main
EditVideo -image $image -videoFolder $videoFolder