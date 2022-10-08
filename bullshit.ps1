$videoFolder = "F:\Blender\SombraHoop"
# $video = "C:\Users\pixel\Desktop\SombraHoop\2022-08-07_22-03-22.mkv"
# # $image = "C:\Users\pixel\Desktop\To_upload\TracerMaidPiss - WM.png"
# $image = "Z:\Projects\SombraHoop\Final\SombraHoop - WM.png"

ffmpeg -y -loglevel info -stats -i .\temp\noaudio.mkv -i .\temp\audio\outputFade.wav -map 0:v -map 1:a -c:v copy ".\out\$outName.mkv"