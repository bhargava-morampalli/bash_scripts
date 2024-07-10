#!/bin/zsh

# Check if the correct number of command-line arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_folder> <output_folder>"
    exit 1
fi

# Assign command-line arguments to variables
input_folder="$1"
output_folder="$2"

# Create the output subfolder if it doesn't exist
mkdir -p "$output_folder"

# Run the command for each folder in the input folder
for folder in "$input_folder"/*; do
    # Extract folder name
    folder_name=$(basename "$folder")
    
    # Create the output subfolder for the current folder
    mkdir -p "$output_folder/$folder_name"

    # Run the command
    python /home/ubuntu/Assembly-dereplicator/dereplicator.py --threads 32 --distance 0.001 "$folder" "$output_folder/$folder_name"
done
