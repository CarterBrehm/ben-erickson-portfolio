#!/bin/bash

# Search the entire repository for images
REPO_DIR="$(dirname -- "$0")"

# Find all images recursively and group by parent folder
find "$REPO_DIR" -type f \( -name '*.jpg' -o -name '*.png' \) | \
  sed "s|^$REPO_DIR/||" | \
  jq -Rn '
    reduce inputs as $item ({};
      ($item | split("/") | .[:-1] | join("/")) as $folder |
      ($folder | split("/") | last) as $folder_name |
      if $folder == "" then
        .root.images += [$item] |
        .root.title = "root" |
        .root.index = "."
      else
        .folders[$folder].images += [$item] |
        .folders[$folder].title = $folder_name |
        .folders[$folder].index = $folder
      end
    )
  ' > image_list.json

echo "Image paths have been saved to image_list.json"