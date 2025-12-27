# MySQL構造エクスポートツール

MySQLサーバーに接続し、指定した複数のデータベースのテーブル構造（CREATE TABLE文）をエクスポートするツール。

## 機能

- 複数データベースの一括エクスポート
- テーブル構造（スキーマ）のみをエクスポート（データは含まない）
- データベースごとに個別のSQLファイルとして出力
- タイムスタンプ付きディレクトリで出力を整理

## 必要条件

- MySQLクライアント（`mysql`, `mysqladmin`, `mysqldump`コマンド）
- エクスポート対象データベースへの読み取り権限

## 使用方法

### 1. 設定ファイルの準備

```bash
cp .env.sample .env
chmod 600 .env
```

### 2. .envファイルを編集

```bash
# MySQL接続設定
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=your_password

# エクスポート対象データベース（カンマ区切り）
DATABASES=app_db,user_db,analytics_db

# 出力ディレクトリ
OUTPUT_DIR=./output
```

### 3. スクリプトの実行

```bash
./export.sh
```

## 出力例

```
output/
└── 2025-12-27_143000/
    ├── app_db.sql
    ├── user_db.sql
    └── analytics_db.sql
```

## 環境変数

| 変数名 | 必須 | デフォルト | 説明 |
|--------|------|------------|------|
| MYSQL_HOST | Yes | - | MySQLサーバーのホスト名 |
| MYSQL_PORT | No | 3306 | MySQLサーバーのポート番号 |
| MYSQL_USER | Yes | - | MySQLユーザー名 |
| MYSQL_PASSWORD | No | - | MySQLパスワード |
| DATABASES | Yes | - | エクスポート対象データベース（カンマ区切り） |
| OUTPUT_DIR | No | ./output | 出力先ディレクトリ |
