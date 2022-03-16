﻿<#
PLAN
10) Titres et textes:
    10.3) Template de titre : rectangle qui s'allonge sur 10 frames à gauche
            Frame 11 : texte commence à apparaître, sur 7 frames
            250 frames
            16 frame de fade out texte
            11 frames de réduction rectangle
    10.4) Texte "Total work time": 5s total, fade in 1s, fade out 1s
#> 

$ourbals = 1

if ($ourbals -eq 1)
{
    # VIDEO
    $image = "C:\Users\Nathan\OneDrive\Images\Teasing Master VG.png"

    # region Lister toutes les vidéos
    Clear-Content .\videos.txt
    foreach ($file in Get-ChildItem .\videos\* -Include @("*.mkv")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\videos.txt -Value $filePath
    }
    # endregion


    # region Lister tous les audios
    Clear-Content .\audios.txt
    foreach ($file in Get-ChildItem .\musiques\* -Include @("*.wav")) {
        $filePath ="file '$file'"
        # Write-Host "file '${filePath}'"
        Add-Content -Path .\audios.txt -Value $filePath
    }
    # endregion


    # region Longueur des fichiers audio
    $audioLength = 0
    $audioTotal = 0
    $content = Get-Content -Path .\audios.txt
    foreach ($line in $content) {
        $audio = $line.Trim("file").Trim().Trim("'")
        $audioTotal++
        $audioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio
    }
    $audioLength = [math]::ceiling($audioLength)

    Write-Host "Longueur audio : $audioLength secondes ou $([math]::Floor($audioLength/60))m$($audioLength%60)s" -ForegroundColor Magenta
    # endregion


    # region Accélérer la vidéo à la durée des audios -20s
    ## Accélérer la vidéo + fade
    $videoLength = 0
    $content = Get-Content -Path .\videos.txt
    foreach ($line in $content) {
        $videoName = $line.Trim("file").Trim().Trim("'")
        $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $videoName
        $videoLength += $duration
    }
    $videoLength = [math]::ceiling($videoLength)
    $videoShort = $videoLength/20
    Write-Host "Longueur vidéo : $videoShort secondes ou $([math]::Floor($videoShort/60))m$($videoShort%60)s" -ForegroundColor Magenta

    if ($audioLength > ($videoLength/20))
    {
        Write-Host -ForegroundColor DarkRed "There is not enough video footage to span the entire length of the songs.`nPlease remove some music or add more video files."
    }

    #### TIMELAPSE
    $speedUpScript = "$PSScriptRoot\Timelapse-inator.ps1"
    # $returnValue = & $speedUpScript -sourceDir ".\videos" -temp ".\temp\speedup" -pts 20 -fps 60 -del "N"
    # Write-Host -ForegroundColor Green "returnValue = $returnValue"

    $video = ".\temp\speedup\Timelapse.mkv"
    $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $video
    Write-Host "duration = $duration" -ForegroundColor Green

    $speedUpFactor = $audioLength / ([Int32]$duration + 20)
    Write-Host -ForegroundColor Blue "$speedUpFactor, $duration"
    $target = $speedUpFactor * $duration
    Write-Host -ForegroundColor Magenta "Target length: $target"
    # $videoCut = $audioLength - 20
    # Write-Host -ForegroundColor Green "videoCut = $videoCut"
    # exit

    #### Cut the number of frames to length desired
    # Write-Host "Cutting to length" -ForegroundColor Magenta
    # ffmpeg -y -loglevel error -stats -i $video -t $videoCut -c:v copy .\temp\trimmed.mkv
    # exit

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

    # Write-Host "Vidéo: $videoW x $videoH, Image: $imageW x $imageH"

    if ($imageW -gt $imageH) {
        $ratio = $imageW / $imageH
        ffmpeg -y -loglevel error -stats -i $image -vf scale=-1:${videoH}*1.15 .\temp\top.jpg
    }
    else {
        $ratio = $imageH / $imageW
        ffmpeg -y -loglevel error -stats -i $image -vf scale=${videoW}*0.65:-1 .\temp\top.jpg
    }


    Write-Host "Scaling end credits" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -i $image -vf scale=${videoW}*1.02:-1,boxblur=15,eq=brightness=-0.25 .\temp\bottom.jpg

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
    $pps = $hiddenHeight / 15

    Write-Host "`tBottom" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -loop 1 -i .\temp\bottom.jpg -i .\temp\speed.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 - ${hiddenHeight}) + t*$pps" -r 60 -t 20 .\temp\bottom.mkv


    #### Top
    $topDimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\top.jpg
    $topW, $topH = $topDimensions.Split("x")

    $hiddenHeight = ($videoH - $topH) * 0.5
    $pps = $hiddenHeight /10

    Write-Host "`tTop" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -loop 1 -i .\temp\top.jpg -i .\temp\bottom.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 + $hiddenHeight) - t*$pps,
    fade=t=in:st=0:d=1.5,
    fade=t=out:st=17:d=3" -r 60 -t 20 .\temp\overlayed.mkv

    ##TODO "Total work time"

    #endregion


    # region Ajouter l'écran de fin à la vidéo
    Write-Host "Concatenating" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\concat.ffmpeg -c copy .\temp\output.mkv 
    # endregion


    # region Ajouter la musique
    Write-Host "Adding music" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -stats -f concat -safe 0 -i .\audios.txt -c copy .\temp\output.wav

    $audioFadeStart = $audioLength - 5

    ffmpeg -y -loglevel error -stats -i .\temp\output.wav -af "afade=t=out:st=${audioFadeStart}:d=5" .\temp\outputFade.wav

    ffmpeg -y -loglevel error -stats -i .\temp\output.mkv -i .\temp\outputFade.wav -map 0:v -map 1:a -c:v copy .\temp\nosub.mkv

    # endregion

    function generateTextBlurb {    
        param ($startTS, $title, $artist)
    
        $tempVal = ""
    
        $filterTitle = "drawtext=
        text=${title}
        :shadowx=4
        :shadowy=3
        :shadowcolor=black@0.35
        :borderw=2
        :bordercolor=black@0.25
        :fontfile=C\\:/Users/Nathan/AppData/Local/Microsoft/Windows/Fonts/OpenSans-Bold.ttf
        :fontcolor=#ffffff@0.9
        :fontsize=48
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
        :fontfile=C\\:/Users/Nathan/AppData/Local/Microsoft/Windows/Fonts/OpenSans-Bold.ttf
        :fontcolor=#c0c0c0@0.9
        :fontsize=36
        :alpha='if(lt(t,$startTS),0,if(lt(t,$startTS + 0.5),(t-$startTS)/0.625,if(lt(t,$startTS + 5.5),0.8,if(lt(t,$startTS + 6),(0.5-(t-($startTS + 5.5)))/0.625,0))))'
        :x=50
        :y=(h-text_h)/10*9 + 40"
        return "$filterTitle,$filterArtist"
    }

    # region Texte Musique
    $sousTitres = Get-Content -Path .\soustitres.json | ConvertFrom-Json

    $counter = 0
    $prevAudioLength = 0
    $subtitleFilter = ""

    foreach ($line in Get-Content .\audios.txt)
    {
        $line = $line.Trim("file").Trim().Trim("'")
        $counter++

        $subtitleFilter += generateTextBlurb -startTS $($prevAudioLength + 4) -title $sousTitres.Titles.$counter -artist $sousTitres.Artists.$counter
        $subtitleFilter+= ", "

        $prevAudioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $line
    }

    $subtitleFilter = $subtitleFilter.TrimEnd(", ")
    # echo $subtitleFilter
    exit
    Write-Host "Burning in subtitles and watermark`nH.265 remux" -ForegroundColor Magenta
    ffmpeg -y -loglevel error -hide_banner -stats -i .\temp\nosub.mkv -i .\wm.png -filter_complex "[1:v]scale=-1:240 [ovrl],[0:v][ovrl]overlay=20:20" -codec:v libx265 -crf 18 -preset medium -codec:a copy .\out\output.mp4
    # endregion
}


# ffplay -y -loglevel error -stats -i .\temp\nosub.mkv -vf "" -codec:v libx265 -crf 18 -preset medium -codec:a copy
# ffmpeg -y -loglevel error -stats -i .\temp\overlayed.mkv -i .\img.png -filter_complex "[1:v]scale=-1:170 [ovrl],[0:v][ovrl]overlay=10:10" -codec:v libx265 -crf 18 -preset medium -codec:a copy output.mp4