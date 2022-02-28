<#
PLAN
1) Lire les durées de toutes les musiques bout à bout
2) Accélérer via le time lapse-inator à la durée de toutes les musiques -20 secondes. Note: filtre "minterpolate" pour du frame insert
3) Fade in/Fade out
4) Construire la fin de la vidéo : image en fond, floutée, opacité 60%, qui prend toute la largeur, overlay image nette
5) Mouvement de l'image derrière : monter de 1/14e de sa hauteur
6) Mouvement de l'image devant : descendre de 1/5 de sa hauteur 
7) Le tout sur 20 secondes
8) Fade in sur cette séquence en Fade out à la fin (1.5s/4s)
9) Coller le time lapse et le résultat en ajoutant la musique
10) Titres et textes:
    10.1) Créer un fichier avec les time codes de début de chaque segment musical + 3s
    10.2) Générer les textes de musique. Open Sans Bold. Musique en police 40 #FFF, compositeur en police 32 + RGB(192, 192, 192)
    10.3) Template de titre : rectangle qui s'allonge sur 10 frames à gauche
            Frame 11 : texte commence à apparaître, sur 7 frames
            250 frames
            16 frame de fade out texte
            11 frames de réduction rectangle
    10.4) Texte "Total work time": 5s total, fade in 1s, fade out 1s
#> 

# VIDEO


# region Lister toutes les vidéos
# Clear-Content .\videos.txt
# foreach ($file in Get-ChildItem .\videos\* -Include @("*.mp4", "*.mkv")) {
#     # Write-Output "file '${file}'"
#     "file '${file}'" | Out-File -Encoding utf8NoBOM -Append -FilePath .\videos.txt
# }
# endregion


# region Lister tous les audios
# Clear-Content .\audios.txt
# foreach ($file in Get-ChildItem .\musiques\* -Include @("*.wav", "*.mp3")) {
#     # Write-Output "file '${file}'"
#     "file '${file}'" | Out-File -Encoding utf8NoBOM -Append -FilePath .\audios.txt
# }
# endregion


# region Longueur des fichiers audio
# $audioLength = 0
# $audioTotal = 0
# $content = Get-Content -Path .\audios.txt
# foreach ($line in $content) {
#     $audio = $line.Trim("file").Trim().Trim("'")
#     echo $audio
#     $audioTotal++
#     $audioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio
# }
# $audioLength = [math]::ceiling($audioLength)

# Write-Output "Longueur audio : $audioLength secondes"
# endregion


# region Accélérer la vidéo à la durée des audios -20s
## Accélérer la vidéo + fade
$videoLength = 0
$content = Get-Content -Path .\videos.txt
foreach ($line in $content) {
    $video = $line.Trim("file").Trim().Trim("'")
    $duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $video
    $videoLength += $duration
}
$videoLength = [math]::ceiling($videoLength)
Write-Output "Longueur vidéo : $videoLength secondes"

##### TIMELAPSE

### Accélérer la vidéo + fade
$spedUpLength = $audioLength - 18
$fadeOutStart= $audioLength - 20
# ffmpeg -y -i ".\videos\Akebi-chan no Sailor-fuku - S01E07 - VOSTFR 1080p WEB x264 -NanDesuKa (WAKA).mkv" -vf "setpts=($spedUpLength/$videoLength)*PTS, fade=t=in:st=0:d=3, fade=t=out:st=${fadeOutStart}:d=2" -an -sn -max_interleave_delta 0 out.mkv

#### REMUX x265 
# ffmpeg -y -i ".\videos\Akebi-chan no Sailor-fuku - S01E07 - VOSTFR 1080p WEB x264 -NanDesuKa (WAKA).mkv" -vf "setpts=(${audioLength}/${videoLength})*PTS" -c:v libx265 -an -sn -x265-params crf=25 out.mp4

## Fade-in - fade-out
# ffplay -i .\out.mkv -vf "fade=t=in:st=0:d=3, fade=t=out:st=5:d=3"
# endregion

 
# region Écran de fin de vidéo
$video = ".\out.mkv"
$image = ".\img2.jpg"

### Scale image to fit
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $video
$videoW, $videoH = $dimensions.Split("x")
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $image
$imageW, $imageH = $dimensions.Split("x")

Write-Output "Vidéo: $videoW x $videoH, Image: $imageW x $imageH"

$ratio = $videoW / $videoH

if ($imageW -gt $imageH) {
    $newH = [int]$videoH * 1.5
    $newH = [math]::ceiling($newH)
    Write-Output "newH = $newH"
    ffmpeg -y -loglevel error -i $image -vf scale=-1:${newH},setsar=1/1 .\temp\top.jpg
}
else {
    $newW = [int]$videoW / 1.75
    $newW = [math]::ceiling($newW)
    Write-Output "newW = $newW"
    ffmpeg -y -loglevel error -i $image -vf scale=${newW}:-1,setsar=1/1 .\temp\top.jpg
}

ffmpeg -y -loglevel error -i $image -vf scale=${videoW}:-1,boxblur=10,lut=a=val*0.3 .\temp\bottom.jpg

####Squaring out images
ffmpeg -y -loglevel error -i .\temp\top.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\top.jpg
ffmpeg -y -loglevel error -i .\temp\bottom.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\bottom.jpg

### Overlay image and animate
ffmpeg -y -loglevel error -i .\temp\bottom.jpg -i .\temp\top.jpg -filter_complex "[0]boxblur=10[a];
[a][1]overlay=
(main_w - overlay_w)/2
:((main_h - overlay_h)/2 -100) + t*20
:enable='between(t,2,7)'" -c:v libx265 -t 20 -x265-params crf=25 .\overlayed.mp4
# endregion


# ffmpeg -y -ss 00:00:10 -i .\bob2.mkv -c copy -t 10 .\bob3.mkv
# ffmpeg -y -ss 20 -i .\bob1.mkv -c copy -t 10 .\bob4.mkv


# region Texte Musique
# $startTS = 1
# ffplay -i bob1.mkv -vf "[in]
# drawtext=
# text='Music'
# :fontfile=C\\:/Users/Nathan/AppData/Local/Microsoft/Windows/Fonts/OpenSans-Bold.ttf
# :fontcolor=white@0.9
# :fontsize=48
# :alpha='if(lt(t,$startTS),0,if(lt(t,$startTS + 0.5),(t-$startTS)/0.625,if(lt(t,$startTS + 5.5),0.8,if(lt(t,$startTS + 6),(0.5-(t-($startTS + 5.5)))/0.625,0))))'
# :x=50
# :y=(h-text_h)/10*9[out]" -codec:a copy
# endregion

# region Extract text blurbs
# $textTemp = ""
# $textArray = [object[]]::new($audioTotal)
# $counter = 0
# foreach ($line in Get-Content ".\audio.txt")
# {
#     if ($line -ne "")
#     {
#         $textTemp += $line
#     }
#     else
#     {
#         $textArray[$counter] = $textTemp
#         $textTemp = ""
#         $counter++
#     }
# }

# Write-Output $textArray
# endregion


#Fade the beginning and end (video)
#ffplay -i .\bob2.mkv -vf "fade=t=in:st=0:d=1.5, fade=t=out:st=5:d=1.5"

#Fade the end (audio)
#ffplay -i .\bob2.mkv -af "afade=t=out:st=3:d=1"
 

# region Fade transition
# $plan1 = ".\bob3.mkv"
# $plan2 = ".\bob2.mkv"
# $duration = 3 
# $lClip1 = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 .\bob3.mkv
# $offset = $lClip1-$duration -1

# Write-Output $lClip1, $offset

# ffmpeg -y -i $plan1 -i $plan2 -filter_complex "xfade=
# transition=fade
# :duration=$duration
# :offset=$offset" .\distance.mkv
# endregion
