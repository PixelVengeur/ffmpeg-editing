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


#TODO 
# Fade transition
ffmpeg -y -i .\bob1.mkv -i .\bob2.mkv -filter_complex "xfade=transition=fade:duration=2.5:offset=8.75" .\distance.mkv

# Blur image
# ffplay -i .\bob1.mkv -vf "boxblur=10"

# Overlay image
# Animate image position



# ffmpeg -y -ss 10 -i .\bob1.mkv -c copy -t 10 .\bob3.mkv
# ffmpeg -y -ss 20 -i .\bob1.mkv -c copy -t 10 .\bob4.mkv