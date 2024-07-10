#!/bin/bash

# Parent directory containing all the folders
parent_dir="/home/ubuntu/ska2_analysis/isolation_types"

# Loop through all directories in the parent directory
for dir in "$parent_dir"/*/ ; do
    if [ -d "$dir" ]; then
        # Get the base name of the directory (folder name)
        folder_name=$(basename "$dir")
        echo "Processing directory: $folder_name"
        
        # Change to the directory
        cd "$dir"
        
        # Run the first command
        echo "Running ska align..."
        ska align *.fasta --threads 32 | gzip -c - > "${folder_name}_seqs.aln.gz"
        
        # Run the second command
        echo "Running snp-dists..."
        snp-dists -b "${folder_name}_seqs.aln.gz" > "${folder_name}_matrix.tsv"
        
        # Change back to the parent directory
        cd "$parent_dir"
        
        echo "Finished processing $folder_name"
        echo "------------------------"
    fi
done

echo "All directories processed."