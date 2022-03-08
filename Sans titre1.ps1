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
$image = "C:\Users\Nathan\OneDrive\Images\Teasing Master VG.png"

# region Lister toutes les vidéos
Clear-Content .\videos.txt
foreach ($file in Get-ChildItem .\videos\* -Include @("*.mp4", "*.mkv")) {
    # Write-Output "file '${file}'"
    "file '${file}'" | Out-File -Encoding utf8NoBOM -Append -FilePath .\videos.txt
}
# endregion


# region Lister tous les audios
Clear-Content .\audios.txt
foreach ($file in Get-ChildItem .\musiques\* -Include @("*.wav")) {
    # Write-Output "file '${file}'"
    "file '${file}'" | Out-File -Encoding utf8NoBOM -Append -FilePath .\audios.txt
}
# endregion


# region Longueur des fichiers audio
$audioLength = 0
$audioTotal = 0
$content = Get-Content -Path .\audios.txt
foreach ($line in $content) {
    $audio = $line.Trim("file").Trim().Trim("'")
    echo $audio
    $audioTotal++
    $audioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $audio
}
$audioLength = [math]::ceiling($audioLength)

Write-Output "Longueur audio : $audioLength secondes"
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
Write-Output "Longueur vidéo : $videoLength secondes"

#### TIMELAPSE
$video = ".\videos\sortie.mkv" ##### À REMPLACER PAR LE TIMELAPSE
$duration = ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $video

### Accélérer la vidéo + fade
$speedUpFactor = $audioLength / $videoLength
$tempVal = $videoLength - (20/$speedUpFactor)
# Write-Output("videoLength = $videoLength,
# speedUpFactor = $speedUpFactor")

#### Cut the number of frames to length desired
Write-Output "Cutting to length"
# ffmpeg -y -loglevel error -i $video -t $tempVal -c:v copy .\temp\trimmed.mkv

#### Compute the fade out 
$frames = ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 .\temp\trimmed.mkv
$framerate = [math]::ceiling($frames / $duration)
$fadeOutStart = ($frames - 1.5 * ($framerate / $speedUpFactor))

Write-Output "Speeding up and adding fades"
# ffmpeg -y -loglevel error -i .\temp\trimmed.mkv -vf "setpts=PTS*$speedUpFactor,fade=in:st=0:d=3,fade=out:s=${fadeOutStart}:d=1.5" -r 60 -an -sn -max_interleave_delta 0 .\temp\speed.mkv

#### REMUX x265 
# ffmpeg -y -i $video -vf "setpts=($speedUpFactor)*PTS,fade=in:st=0:d=3,fade=out:s=${fadeOutStart}:d=1.5" -c:v libx265 -an -sn -x265-params crf=17 out.mp4

# endregion
 

# region Écran de fin de vidéo

### Scale image to fit
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\speed.mkv
$videoW, $videoH = $dimensions.Split("x")
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $image
$imageW, $imageH = $dimensions.Split("x")

# Write-Output "Vidéo: $videoW x $videoH, Image: $imageW x $imageH"

if ($imageW -gt $imageH) {
    $ratio = $imageW / $imageH
    ffmpeg -y -loglevel error -i $image -vf scale=-1:${videoH}*1.15 .\temp\top.jpg
}
else {
    $ratio = $imageH / $imageW
    ffmpeg -y -loglevel error -i $image -vf scale=${videoW}*0.65:-1 .\temp\top.jpg
}


Write-Output("Scaling end credits")
ffmpeg -y -loglevel error -i $image -vf scale=${videoW}*1.02:-1,boxblur=15,eq=brightness=-0.25 .\temp\bottom.jpg

####Squaring out images
Write-Output("Squaring out images")
ffmpeg -y -loglevel error -i .\temp\top.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\top.jpg
ffmpeg -y -loglevel error -i .\temp\bottom.jpg -vf scale='trunc(ih*dar/2)*2:trunc(ih/2)*2',setsar=1/1 .\temp\bottom.jpg

### Overlay image and animate
Write-Output("Overlaying images")

#### Bottom
$bottomDimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\bottom.jpg
$bottomW, $bottomH = $bottomDimensions.Split("x")

$hiddenHeight = ($videoH - $bottomH) * 0.1
$pps = $hiddenHeight / 15

Write-Output("`tBottom")
ffmpeg -y -loglevel error -loop 1 -i .\temp\bottom.jpg -i .\temp\speed.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 - ${hiddenHeight}) + t*$pps" -r 60 -t 20 .\temp\bottom.mkv


#### Top
$topDimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 .\temp\top.jpg
$topW, $topH = $topDimensions.Split("x")

$hiddenHeight = ($videoH - $topH) * 0.5
$hiddenHalf = $hiddenHeight / 2
$pps = $hiddenHeight / 15

Write-Output("`tTop")
ffmpeg -y -loglevel error -loop 1 -i .\temp\top.jpg -i .\temp\bottom.mkv -filter_complex "[1][0]overlay=(main_w - overlay_w)/2:((main_h - overlay_h)/2 + $hiddenHalf) - t*$pps,
fade=t=in:st=0:d=1.5,
fade=t=out:st=17:d=3" -r 60 -t 20 .\temp\overlayed.mkv

#endregion


# region Ajouter l'écran de fin à la vidéo
Write-Output "Concatenating"
ffmpeg -y -loglevel error -f concat -safe 0 -i .\concat.ffmpeg -c copy .\temp\output.mkv 
# endregion


# region Ajouter la musique
Write-Output "Adding music"
ffmpeg -y -loglevel error -f concat -safe 0 -i .\audios.txt -c copy .\temp\output.wav

$audioFadeStart = $audioLength - 5

ffmpeg -y -loglevel error -i .\temp\output.wav -af "afade=t=out:st=${audioFadeStart}:d=5" .\temp\outputFade.wav

ffmpeg -y -loglevel error -i .\temp\output.mkv -i .\temp\outputFade.wav -map 0:v -map 1:a -c:v copy output.mkv

## TODO : problème de longueur du fichier vidéo, à fixer
# endregion


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
