#!/bin/bash

# 指定したプルリクエストの情報を収集する

set -eu -o pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/../constants.bash"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <PR_NUMBER>" >&2
  exit 1
fi

pr_number="$1"

output_path="$OUTPUT_ROOT_DIR/collect_pull_request_details_output.md"

document="# プルリクエスト #${pr_number}"
append_text() {
  document="${document}\n\n$1"
}
append_title() {
  append_text "## $1"
}
append_codeblock() {
  append_text "\`\`\`\n$1\n\`\`\`"
}
function write_document() {
  # \n を改行に変換
  echo "$document" | awk '{ gsub(/\\n/, "\n"); print }' >"$output_path"
}

# プルリクエストの情報
detail_text=$(gh pr view "$pr_number")
append_codeblock "$detail_text"

comments_text=$(gh pr view "$pr_number" --comments)
append_title "コメント"
append_codeblock "$comments_text"

all_text="${detail_text}\n\n${comments_text}"

# リンクされている URL を抽出
github_urls=()
other_urls=()
echo "$all_text" | grep -oE "https?://[^ )\"]+" | while read -r url; do
  if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+) ]]; then
    github_urls+=("$url")
  else
    other_urls+=("$url")
  fi
done

# 関連するIssue/PRの情報を集める
entries=() # "owner|repo|number" の形式で保持
for url in "${github_urls[@]}"; do
  if [[ "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+) ]]; then
    entries+=("${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[4]}")
  fi
done

# `#数字` を抽出
plain_ids=$(echo "$all_text" | grep -oE '(^|[[:space:]])#[0-9]+([[:space:]]|$)' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
for id in $plain_ids; do
  num="${id#\#}"
  entries+=("${OWNER}|${REPO}|${num}")
done

# 重複を除去と自分のPRを除外
mapfile -t entries <<<"$(
  printf "%s\n" "${entries[@]}" |
    sort |
    uniq |
    grep -v "^${OWNER}|${REPO}|${pr_number}$"
)"

# リンクされた Issue や プルリクエスト
append_title "リンクされた Issue や プルリクエスト"

process_linked() {
  local owner="$1"
  local repo="$2"
  local num="$3"
  echo "  ${owner}/${repo}#${num} の情報を取得します..."

  local entry_type details_json
  if details_json=$(gh pr view "$num" --json title,body,comments --repo "$owner/$repo" 2>/dev/null); then
    entry_type="PR"
  elif details_json=$(gh issue view "$num" --json title,body,comments --repo "$owner/$repo" 2>/dev/null); then
    entry_type="Issue"
  else
    echo "  ${owner}/${repo}#${num} の情報を取得に失敗しました。"
    return
  fi

  local title body comments_json
  title=$(echo "$details_json" | jq -r '.title')
  body=$(echo "$details_json" | jq -r '.body')
  comments_json=$(echo "$details_json" | jq -r '.comments')

  if [ -n "$comments_json" ]; then
    local comment
    while IFS= read -r comment; do
      body="$body"$'\n'"$comment"
    done < <(echo "$comments_json" | jq -r '.[].body')
  fi

  append_codeblock "${entry_type}: $title ($owner/$repo/#$num)\n\n$body"
}
for entry in "${entries[@]}"; do
  IFS='|' read -r entry_owner entry_repo entry_num <<<"$entry"
  process_linked "$entry_owner" "$entry_repo" "$entry_num"
done

# その他のURL
if [ ${#other_urls[@]} -gt 0 ]; then
  append_title "その他のURL"
  for url in "${other_urls[@]}"; do
    append_text "${url}"
  done
fi

# 出力
write_document
