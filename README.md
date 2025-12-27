# Linux Setup Tools

Linux環境のセットアップや設定を自動化・効率化するためのツールコレクションです。

## 収録ツール

| ツール名 | 説明 | ディレクトリ |
| --- | --- | --- |
| **SoftEther VPN Client Setup** | SoftEther VPN Client のインストール、ビルド、接続設定を自動化するスクリプト | [`softether-vpn/`](./softether-vpn/) |

## 使い方

各ツールのディレクトリにある `README.md` またはスクリプトの指示に従ってください。

## 開発について

新しいツールの追加や既存ツールの修正については [CONTRIBUTING.md](./CONTRIBUTING.md) を参照してください。

### プロジェクト構成ルール

*   各ツールは独立したディレクトリに配置する。
*   各ディレクトリには使い方を記載した `README.md` を配置する。
*   設定ファイルが必要な場合は `.env.sample` などを提供し、機密情報をコミットしない。
