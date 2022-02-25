#foreach($file in Get-ChildItem .\* -Include @("*.mp4", "*.mkv"))
#{
    #echo $file
#    echo "file '$file'" >> videos.txt
#}

#ffmpeg -y -f concat -safe 0 -i videos.txt -vf 'setpts=0.05*PTS' -r 24 -s 800x600 -c:v libx265 -c:a copy -x265-params crf=17 out.mkv


# Get length of all audio files combined
# $audioLength = 0
# $audioTotal = 0
# foreach($file in Get-ChildItem .\* -Include @("*.wav"))
# {
#     $audioTotal++
#     $audioLength += ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $file
# }
# $audioLength = [math]::ceiling($audioLength)

# Write-Output $audioTotal


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


# Extract text blurbs
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


#Fade the beginning and end (video)
# ffplay -i .\bob2.mkv -vf "fade=t=in:st=0:d=1.5, fade=t=out:st=5:d=1.5"

#Fade the end (audio)
# ffplay -i .\bob2.mkv -af "afade=t=out:st=3:d=1"

 
## Fade transition
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



## Blur image
# ffplay -i .\bob1.mkv -vf "boxblur=10"

$video = ".\bob1.mkv"
$image = ".\img.jpg"

## Scale image to fit

# ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $video
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $video
$videoW, $videoH = $dimensions.Split("x")
$dimensions = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $image
$imageW, $imageH = $dimensions.Split("x")

echo $videoW, $videoH, $imageW, $imageH

$ratio = $videoW/$videoH

if ($imageW -gt $imageH)
{
    $newH = [int]$videoH * 1.5
    echo $newH
    ffmpeg -y -i $image -vf scale=-1:${newH} out.jpg
}
else
{
    $newW = [int]$videoW/1.75
    echo $newW
    ffmpeg -y -i $image -vf scale=${newW}:-1 out.jpg
}


# ffmpeg -y -loglevel error -i .\img.jpg -vf scale=$$videoW}*3/4:-1 out.jpg

## Overlay image

ffmpeg -y -loglevel error -i $video -i .\out.jpg -filter_complex "[0:v][1:v] overlay=
(main_w - overlay_w)/2
:((main_h - overlay_h)/2 -200) + t*50
:enable='between(t,1,8)'" out.mkv

## Animate image position


# ffmpeg -y -ss 00:00:10 -i .\bob2.mkv -c copy -t 10 .\bob3.mkv
# ffmpeg -y -ss 20 -i .\bob1.mkv -c copy -t 10 .\bob4.mkv
