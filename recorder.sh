#!/bin/bash

# Script to record audio from a specified PulseAudio virtual sink and automatically stop recording when the sink is idle.

# Usage: ./record.sh <virtual_sink_name> <output_name> <idle_duration>

# Checks if the required number of arguments is provided
if [ $# -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: $0 <virtual_sink_name> <output_name>"
    exit 1
fi

# Assigning command line arguments to variables
VIRTUAL_SINK="$1"
OUTPUT_NAME="$2"
IDLE_DURATION=2

echo "Recording from sink: $VIRTUAL_SINK"
echo "Output file name: $OUTPUT_NAME.mp3"

# Function to get the current state of the virtual sink
get_sink_state() {
    STATE=$(pactl list sinks | grep -B 1 "Name: $VIRTUAL_SINK" | awk '/State:/ {print $2}';)
    echo $STATE
}

# Start recording
echo "Starting recording..."
(parec -d ${VIRTUAL_SINK}.monitor | lame -r -V0 - "${OUTPUT_NAME}.mp3") &
RECORD_PID=$!
echo "Recording started with PID: $RECORD_PID"

# Monitor the sink for idle state
idle_counter=0
while true; do
    sink_state=$(get_sink_state)

    if [ "$sink_state" = "IDLE" ]; then
        ((idle_counter++))
        echo "Sink $VIRTUAL_SINK is idle for $idle_counter second(s)"
    else
        idle_counter=0
        echo "Sink $VIRTUAL_SINK is running"
    fi

    # Check if idle duration has been met
    if [ "$idle_counter" -ge "$IDLE_DURATION" ]; then
        echo "Sink $VIRTUAL_SINK has been idle for $IDLE_DURATION seconds. Stopping recording."
        kill -- -$(ps -o pgid= $RECORD_PID | grep -o '[0-9]*')
        wait "$RECORD_PID"
        echo "Recording stopped."
        break
    fi

    sleep 3
done
