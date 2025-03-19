#!/bin/bash
set -eu -o pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/constants.bash"

output_path="$OUTPUT_ROOT_DIR/introduction.md"

document="# イントロダクション"
function append_text() {
  document="${document}\n\n$1"
}
function append_title() {
  append_text "## $1"
}
function append_codeblock() {
  append_text "\`\`\`\n$1\n\`\`\`"
}
function write_document() {
  # \n を改行に変換
  printf "%b" "$document\n" >"$output_path"
}

if [ -f README.md ]; then
  append_title "README"
  append_codeblock "$(cat README.md)"
fi

if [ -f CONTRIBUTING.md ]; then
  append_title "CONTRIBUTING"
  append_codeblock "$(cat CONTRIBUTING.md)"
fi

# .github リポジトリの README.md
text="$(gh api repos/"$OWNER"/.github/contents/profile/README.md --jq '.content' | base64 -d || true)"
if [ -n "$text" ]; then
  append_title "プロジェクト全体の概略"
  append_codeblock "$text"
fi

# wikipedia の情報
if [ -f "$OUTPUT_ROOT_DIR/wikipedia_summary.txt" ]; then
  append_title "Wikipedia の情報"
  append_codeblock "$(cat "$OUTPUT_ROOT_DIR/wikipedia_summary.txt")"
fi

# 書き込む
write_document
