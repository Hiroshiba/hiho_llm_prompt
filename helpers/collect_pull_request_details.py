"""
指定したプルリクエストの情報を収集する
"""

import re
import json
import subprocess
from pathlib import Path
import argparse
from helpers.constants import OWNER, REPO, OUTPUT_ROOT_DIR


def main() -> None:
    args = parse_args()
    pr_number: str = args.pr_number

    owner: str = OWNER
    repo: str = REPO
    output_root: Path = Path(OUTPUT_ROOT_DIR)

    output_path = output_root / "collect_pull_request_details_output.md"

    doc_builder = DocumentBuilder(output_path)
    doc_builder.append_text(f"# プルリクエスト #{pr_number}")

    # プルリクエストの情報
    detail_text = run_gh_command(["pr", "view", pr_number])
    doc_builder.append_codeblock(detail_text)

    comments_text = run_gh_command(["pr", "view", pr_number, "--comments"])
    doc_builder.append_title("コメント")
    doc_builder.append_codeblock(comments_text)

    all_text = f"{detail_text}\n\n{comments_text}"

    # リンクされている URL を抽出
    github_urls, other_urls = extract_urls(all_text)
    entries = extract_github_entries(github_urls)

    for num in extract_plain_ids(all_text):
        entries.append((owner, repo, num))

    entries = list(set(entries))
    if (owner, repo, pr_number) in entries:
        entries.remove((owner, repo, pr_number))

    # プルリクエストの議論
    doc_builder.append_title("プルリクエストの議論")
    doc_builder.append_text(get_pull_request_discussions(pr_number))

    # リンクされた Issue や プルリクエスト の情報
    doc_builder.append_title("リンクされた Issue や プルリクエスト")
    for entry_owner, entry_repo, entry_num in entries:
        process_linked(entry_owner, entry_repo, entry_num, doc_builder)

    # その他のURL
    if len(other_urls) > 0:
        doc_builder.append_title("その他のURL")
        for url in other_urls:
            doc_builder.append_text(url)

    doc_builder.write_document()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("pr_number", type=str)
    return parser.parse_args()


class DocumentBuilder:
    def __init__(self, output_path: Path) -> None:
        self.document: str = ""
        self.output_path: Path = output_path

    def append_text(self, text: str) -> None:
        self.document += f"\n\n{text}"

    def append_title(self, title: str) -> None:
        self.append_text(f"## {title}")

    def append_codeblock(self, code: str) -> None:
        self.append_text(f"```\n{code}\n```")

    def write_document(self) -> None:
        self.output_path.write_text(self.document + "\n", encoding="utf-8")


def run_gh_command(args: list[str]) -> str:
    result = subprocess.run(
        ["gh"] + args, capture_output=True, text=True, encoding="utf-8"
    )
    return result.stdout.strip()


def extract_urls(text: str) -> tuple[list[str], list[str]]:
    urls = re.findall(r'https?://[^\s)"\\]+', text)
    github_urls: list[str] = []
    other_urls: list[str] = []
    for url in urls:
        if re.match(r"^https://github\.com/[^/]+/[^/]+/(issues|pull)/\d+$", url):
            github_urls.append(url)
        else:
            other_urls.append(url)
    return github_urls, other_urls


def extract_github_entries(github_urls: list[str]) -> list[tuple[str, str, str]]:
    entries: list[tuple[str, str, str]] = []
    for url in github_urls:
        m = re.match(r"^https://github\.com/([^/]+)/([^/]+)/(issues|pull)/(\d+)$", url)
        if m:
            entries.append((m.group(1), m.group(2), m.group(4)))
    return entries


def extract_plain_ids(text: str) -> list[str]:
    return re.findall(r"#(\d+)\b", text)


def get_pull_request_discussions(pr_number: str) -> str:
    comments_json = run_gh_command(
        ["api", f"repos/{OWNER}/{REPO}/pulls/{pr_number}/comments"]
    )
    comments = json.loads(comments_json)

    # データの抽出
    discussions = [
        {
            "発言者": comment.get("user", {}).get("login", "Unknown"),
            "ファイルパス": comment.get("path", "N/A"),
            "行数": comment.get("position", "N/A"),
            "コメント": comment.get("body", "").replace("\n", " "),
        }
        for comment in comments
    ]

    # ファイルパスと行数でソート
    sorted_discussions = sorted(
        discussions, key=lambda x: (x["ファイルパス"], str(x["行数"]))
    )

    # 表の作成
    table_header = "| 発言者 | ファイルパス | 行数 | コメント |\n|---|---|---|---|\n"
    table_rows = [
        f"| {item['発言者']} | {item['ファイルパス']} | {item['行数']} | {item['コメント']} |"
        for item in sorted_discussions
    ]
    markdown_table = table_header + "\n".join(table_rows)

    return markdown_table


def process_linked(
    owner: str, repo: str, num: str, doc_builder: "DocumentBuilder"
) -> None:
    result = fetch_details(owner, repo, num)
    if result is None:
        return
    details, entry_type = result

    title: str = details.get("title", "")
    body: str = details.get("body", "") or ""
    comments: list[dict] = details.get("comments", [])
    for c in comments:
        body += f"\n{c.get('body', '')}"
    doc_builder.append_codeblock(
        f"{entry_type}: {title} ({owner}/{repo}/#{num})\n\n{body}"
    )


def fetch_details(owner: str, repo: str, num: str) -> tuple[dict, str] | None:
    pr_result = subprocess.run(
        [
            "gh",
            "pr",
            "view",
            num,
            "--json",
            "title,body,comments",
            "--repo",
            f"{owner}/{repo}",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if pr_result.returncode == 0:
        return json.loads(pr_result.stdout), "PR"

    issue_result = subprocess.run(
        [
            "gh",
            "issue",
            "view",
            num,
            "--json",
            "title,body,comments",
            "--repo",
            f"{owner}/{repo}",
        ],
        capture_output=True,
        text=True,
    )
    if issue_result.returncode == 0:
        return json.loads(issue_result.stdout), "Issue"

    return None


if __name__ == "__main__":
    main()
