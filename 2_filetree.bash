#!/bin/bash

# shellcheck disable=SC1091
source "$(dirname "$0")/constants.bash"

output_path="$OUTPUT_ROOT_DIR/filetree.txt"

# Git 管理下のファイル一覧を取得
readarray -t files < <(
  git ls-files |
    grep -v ".png$" |
    grep -v ".snap$" |
    grep -v ".woff2$" |
    sort -V
)

# テキストファイルのみをフィルター
filtered=()
for file in "${files[@]}"; do
  if file "$file" | grep -q "text"; then
    filtered+=("$file")
  fi
done
files=("${filtered[@]}")
unset filtered

# Git 管理下のファイル一覧を取得し、ソートする
printf '%s\n' "${files[@]}" | awk '
BEGIN { FS="/" }
{
  # 各パス（例: dir/subdir/file）の各要素を順次出力する
  for(i=1; i<=NF; i++){
    indent = "";
    for(j=1; j<i; j++){
      indent = indent "  ";
    }
    # 現在のパートまでのパスを再構築
    path = "";
    for(k=1; k<=i; k++){
      path = (k==1) ? $k : path "/" $k;
    }
    # 同じパスは一度だけ出力する（すでに出力済みならスキップ）
    if(!(path in seen)){
      print indent $i;
      seen[path] = 1;
    }
  }
}
' >"$output_path"
