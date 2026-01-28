#!/bin/bash

# Usage: ./build_video.sh input.gif fps
if [ "$#" -ne 2 ]; then
    echo "Usage: ./build_video.sh <input.gif> <fps>"
    echo "Example: ./build_video.sh myvideo.gif 30"
    exit 1
fi

INPUT_GIF="$1"
FPS="$2"

# Derive output name from input filename
OUT_NAME=$(basename "$INPUT_GIF" .gif)

# Check if input file exists
if [ ! -f "$INPUT_GIF" ]; then
    echo "Error: Input file '$INPUT_GIF' not found"
    exit 1
fi

# Find EtcTool (check current dir first, then PATH)
if [ -f "./EtcTool" ]; then
    ETCTOOL="./EtcTool"
elif command -v EtcTool &> /dev/null; then
    ETCTOOL="EtcTool"
else
    echo "Error: EtcTool not found in current directory or PATH"
    exit 1
fi

echo "Building BSVideo: $OUT_NAME.bsv"
echo "Input: $INPUT_GIF at ${FPS} FPS"
echo "Using: $ETCTOOL"

# Clean up and create out directory
rm -rf out
mkdir -p out/frames_png out/frames_ktx

# Extract frames from GIF
echo "→ Extracting frames..."
ffmpeg -i "$INPUT_GIF" -vf "scale=512:512:force_original_aspect_ratio=increase,crop=512:512,mpdecimate,setpts=N/FRAME_RATE/TB,fps=$FPS" out/frames_png/frame%04d.png -y

# Check if frames were created
if [ -z "$(ls -A out/frames_png)" ]; then
    echo "Error: No frames extracted from GIF"
    exit 1
fi

# Convert PNG frames to KTX
echo "→ Converting to KTX format..."
for png in out/frames_png/*.png; do
    base=$(basename "$png" .png)
    echo "  Processing $base..."
    "$ETCTOOL" "$png" -format RGBA8 -errormetric rgba -effort 50 -mipmaps 11 -output "out/frames_ktx/${base}.ktx"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to convert $png"
        exit 1
    fi
done

# Create metadata file
echo "→ Creating metadata..."
cat > out/frames_ktx/metadata.json << EOF
{
  "fps": $FPS,
  "format": "ktx",
  "resolution": "512x512"
}
EOF

# Pack into BSV file
echo "→ Packing BSV archive..."
if [ -z "$(ls -A out/frames_ktx/*.ktx 2>/dev/null)" ]; then
    echo "Error: No KTX files found in out/frames_ktx/"
    exit 1
fi

cd out/frames_ktx
zip -r "../../${OUT_NAME}.bsv" .
cd ../..

echo "✓ Created ${OUT_NAME}.bsv (${FPS} FPS)"
echo "  Intermediate files kept in out/"
