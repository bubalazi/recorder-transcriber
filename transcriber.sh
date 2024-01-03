#!/bin/bash

readonly NVIDIA_CODEC="hevc_nvenc"
readonly CPU_CODEC="libx264"

# Default values
model_size="medium"
resolution="640x480"
language="bg"

# Parse command-line arguments
while getopts "a:i:o:r:m:" opt; do
  case $opt in
    a) audio_file="$OPTARG"
    ;;
    i) image_file="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Check if required arguments are provided
if [ -z "$audio_file" ] || [ -z "$image_file" ] ; then
    echo "Usage: $0 -a <audio_file> -i <image_file>"
    exit 1
fi





# Check CUDA availability for FFmpeg
check_cuda_availability() {
    # if ffmpeg -hide_banner -hwaccel cuda -f lavfi -i nullsrc &> /dev/null; then
    if ffmpeg -hide_banner -encoders | grep NVIDIA &> /dev/null; then
        echo "-hwaccel cuda -c:v hevc_nvenc"
    else
        echo ""
    fi
}

transcribe_audio_cli() {
    audio_file=$1
    model_size=$2
    lang=$3
    INPUT_NAME=$4

    echo "Transcribing audio using Whisper CLI with model size '${model_size}'."
    whisper --model $model_size "$audio_file" --language $lang -o $INPUT_NAME -f srt
    echo "Transcription completed and saved to '${INPUT_NAME}'."
}

# Create video from image
create_video_from_image() {
    image_file=$1
    duration=$2
    video_file=$3
    resolution=$4
    ffmpeg_extra_args=$(check_cuda_availability)
    echo $ffmpeg_extra_args
    echo "Start creating video from still image..."
    ffmpeg -v warning -loop 1 -i "$image_file" -r 1 -c:v $NVIDIA_CODEC -t "$duration" -pix_fmt yuv420p -vf "scale=$resolution" "$video_file"
    echo "Done creating video from still image..."
}

# Combine audio, video and subtitles
mux_all_streams() {
    audio_file=$1
    video_file=$2
    subtitles=$3
    output_file=$4

    ffmpeg_extra_args=$(check_cuda_availability)
    echo "Start muxing video and audio streams..." 
    ffmpeg -i "$video_file" -i "$audio_file" -i $subtitles \
        -c:v copy -c:a copy -c:s mov_text \
        -map 0 -map 1 -map 2 \
        -metadata:s:s:0 language=eng \
        $output_file
  
}

# # Add subtitles to video
# add_subtitles_to_video() {
#     video_file=$1
#     subtitles_file=$2
#     final_video=$3
#     ffmpeg_extra_args=$(check_cuda_availability)

#     ffmpeg -v warning -i "$video_file" -vf "subtitles=$subtitles_file" -c:a copy -c:v libx264 "$final_video"
# }

# Get audio duration
get_audio_duration() {
    audio_file=$1
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file"
}

INPUT_NAME="${audio_file%.*}"

# Transcribe audio
transcribe_audio_cli "$audio_file" "$model_size" "$language" "$INPUT_NAME"
subtitles_file="${INPUT_NAME}/${INPUT_NAME}.srt"

# Get duration of the audio file
duration=$(get_audio_duration "$audio_file")

# Create video from image
temp_video_file="${INPUT_NAME}/${INPUT_NAME}_temp.mp4"
create_video_from_image "$image_file" "$duration" "$temp_video_file" "$resolution"

# # Combine audio and video
combined="$INPUT_NAME/${INPUT_NAME}_transcripted.mp4"
mux_all_streams "$audio_file" "$temp_video_file" "$subtitles_file" "$combined"

# # Add subtitles to video
# add_subtitles_to_video "$combined_video_file" "$subtitles_file" "$INPUT_NAME/${INPUT_NAME}_transcripted.mp4"

# Move audio file to it's dedicated directory
mv $audio_file $INPUT_NAME
# Cleanup temporary files
rm "$temp_video_file"
