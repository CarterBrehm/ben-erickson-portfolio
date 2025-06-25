#!/bin/bash

# Search the entire repository for images
REPO_DIR="$(dirname -- "$0")"

# Generate fresh image data
generate_fresh_data() {
    find "$REPO_DIR" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.JPG' -o -name '*.PNG' \) | \
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
        ) |
        # Make images unique
        if .root then .root.images |= unique else . end |
        if .folders then .folders = (.folders | map_values(.images |= unique)) else . end
    '
}

# Main execution
if [ -f "image_list.json" ] && [ -s "image_list.json" ] && jq empty image_list.json >/dev/null 2>&1; then
    # Existing valid file - preserve custom metadata
    OLD_DATA=$(cat image_list.json)
    NEW_DATA=$(generate_fresh_data)

    # Merge: use new image lists but preserve old titles/indexes where they exist
    echo "$NEW_DATA" | jq --argjson old "$OLD_DATA" '
        . as $new |
        $old as $existing |
        $new |
        # Handle root if it exists in both
        if ($existing | has("root")) and ($new | has("root")) then
            .root.title = ($existing.root.title // .root.title) |
            .root.index = ($existing.root.index // .root.index)
        else . end |
        # Handle folders
        if ($existing | has("folders")) and ($new | has("folders")) then
            .folders = (.folders | to_entries | map(
                if $existing.folders[.key] then
                    .value.title = ($existing.folders[.key].title // .value.title) |
                    .value.index = ($existing.folders[.key].index // .value.index)
                else . end
            ) | from_entries)
        else . end
    ' > image_list.json
else
    # No existing file or invalid - create fresh
    generate_fresh_data > image_list.json
fi

echo "Image paths have been saved to image_list.json"