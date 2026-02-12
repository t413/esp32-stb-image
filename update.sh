#!/usr/bin/env bash

# Check if git is installed
if ! command -v git &> /dev/null
then
    echo "git is not installed. Please install git and try again."
    exit 1
fi

# Ensure we're in the correct directory
cd "$(dirname "$0")"

# Ensure the src directory exists
mkdir -p ./src

# Remove any existing files
rm -f ./src/stb_image.h ./src/stb_image_write.h

# Download the latest version of stb_image and stb_image_write
git clone https://github.com/nothings/stb.git stb

# Move the files to the correct location
cp stb/stb_image.h stb/stb_image_write.h ./src

# Clean up
rm -rf stb

echo "Done"
exit 0