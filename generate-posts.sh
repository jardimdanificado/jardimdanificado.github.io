#!/usr/bin/env bash
set -euo pipefail

DIR=$(dirname "$0")
cd "$DIR"

OUT='posts.json'

posts=()

for md in posts/*.md; do
  [ -f "$md" ] || continue
  slug=$(basename "$md" .md)

  date=$(grep -m 1 -i '^date:' "$md" | sed -E 's/^date:[[:space:]]*//I' | tr -d '\r')
  title=$(grep -m 1 -i '^title:' "$md" | sed -E 's/^title:[[:space:]]*//I' | tr -d '\r')

  if [ -z "$title" ]; then
    title=$(grep -m 1 '^# ' "$md" | sed -E 's/^# //')
  fi

  # remover aspas ao redor (title: "..." ou title: '...')
  title="${title#\"}"
  title="${title%\"}"
  title="${title#\'}"
  title="${title%\'}"

  if [ -z "$title" ]; then
    title="$slug"
  fi

  if [ -z "$date" ]; then
    date=""
  fi

  title_escaped=$(printf '%s' "$title" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
  date_escaped=$(printf '%s' "$date" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
  slug_escaped=$(printf '%s' "$slug" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')

  posts+=("{\"slug\":${slug_escaped},\"title\":${title_escaped},\"date\":${date_escaped}}")
done

# sort by date desc if date is present
# simple: we keep filename order (Bash glob already sorted). Optionally we can sort.

printf '[\n' > "$OUT"
first=true
for p in "${posts[@]}"; do
  if [ "$first" = true ]; then
    printf '  %s\n' "$p" >> "$OUT"
    first=false
  else
    printf ',\n  %s\n' "$p" >> "$OUT"
  fi
done
printf ']\n' >> "$OUT"

echo "Gerado $OUT com ${#posts[@]} posts"
