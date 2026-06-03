#!/usr/bin/env bash

buildpack_dir_from_script() {
  local script_path
  script_path="$1"
  cd "$(dirname "$script_path")/.." && pwd
}

copy_fonts_to_directory() {
  local source_dir target_dir count
  source_dir="$1"
  target_dir="$2"
  count=0

  mkdir -p "$target_dir"

  while IFS= read -r -d '' font_file; do
    cp "$font_file" "$target_dir/"
    count=$((count + 1))
  done < <(find "$source_dir" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.ttc" \) -print0)

  echo "$count"
}

