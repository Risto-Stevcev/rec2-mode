# Screencast notes

## Record video

```
$ ffmpeg -video_size 1920x1080 -framerate 25 -f x11grab -i :0.0+0,0 rec2-mode.mp4
```
```
$ screenkey -t 1 -m
```

## Crop it

```
$ ffmpeg -i rec2-mode.mp4 -filter:v "crop=in_w:in_h-90" rec2-mode-cropped.mp4
```

## Convert to gif

```
$ ffmpeg -i rec2-mode-cropped.mp4 \
  -vf "fps=10,scale=iw/2:ih/2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  -loop 0 rec2-mode.gif
```
