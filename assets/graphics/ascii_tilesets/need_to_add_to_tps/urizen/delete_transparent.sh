#!/bin/bash
for f in *.png; do
  if [ "$(identify -format "%[opaque]" "$f")" = "False" ]; then
    echo "Deleting $f"
    rm "$f"
  fi
done