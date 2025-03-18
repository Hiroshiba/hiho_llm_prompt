# 定数

OUTPUT_ROOT_DIR="hiho_docs/"
readonly OUTPUT_ROOT_DIR
export OUTPUT_ROOT_DIR

# リモートの名称
if git remote | grep -q upstream; then
  REMOTE=upstream
else
  REMOTE=origin
fi
readonly REMOTE
export REMOTE

# オーナー
OWNER=$(git remote get-url "$REMOTE" | sed -n 's#.*[:/]\([^/]*\)/[^/]*$#\1#p')
readonly OWNER
export OWNER
