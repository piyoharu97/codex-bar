# 次のバージョンを公開する

1. ソースを修正し、VERSIONを例 `1.6.1`、BUILD_NUMBERを例 `9` に更新。
2. `docs/RELEASE_NOTES.md` に今回の変更を記載。
3. `./Tools/check.sh` で確認し、変更をmainへ保存。
4. GitHub ActionsがUniversalアプリ・ZIP・SHA-256ファイルを生成し、`v1.6.1` のタグとReleaseを公開。VERSIONと一致するタグをpushしても実行できます。
5. Actionsが成功したこと、ReleasesにZIPが添付されたことを確認。

初回公開やActionsを使わない場合は、手元で `./Tools/package-release.sh` を実行し、GitHubのReleases → Draft a new releaseからタグを指定してZIPと.sha256を添付してください。
自動生成するタグと手動Releaseの二重作成は避けてください。

Apple公証は現時点で組み込んでいません。Developer ID署名と公証を導入する場合は、署名鍵や公証用認証をGitHub Secretsに置き、ソースや配布物に埋め込まないでください。
一般配布用の秘密鍵をアプリのアップデート確認用トークンとして使うことも避けてください。
