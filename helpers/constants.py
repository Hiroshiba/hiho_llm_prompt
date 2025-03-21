import os
import re
import subprocess

OUTPUT_ROOT_DIR = "hiho_docs/"


# リモートの名称
def get_remote():
    remotes = subprocess.check_output(["git", "remote"], encoding="utf-8").splitlines()
    return "upstream" if "upstream" in remotes else "origin"


REMOTE = get_remote()


# オーナー
def get_owner(remote):
    url = subprocess.check_output(
        ["git", "remote", "get-url", remote], encoding="utf-8"
    ).strip()
    m = re.search(r".*[:/](?P<owner>[^/]+)/[^/]+$", url)
    if m:
        return m.group("owner")
    else:
        raise ValueError(f"Failed to get owner from {url}")


OWNER = get_owner(REMOTE)


# リポジトリ名
def get_repo_name():
    toplevel = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], encoding="utf-8"
    ).strip()
    return os.path.basename(toplevel)


REPO = get_repo_name()
