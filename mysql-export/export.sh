#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# ===========================================
# .envファイルの読み込みと検証
# ===========================================
if [ ! -f "${ENV_FILE}" ]; then
    echo "エラー: .envファイルが見つかりません"
    echo "以下のコマンドで.env.sampleをコピーして設定してください:"
    echo "  cp ${SCRIPT_DIR}/.env.sample ${ENV_FILE}"
    exit 1
fi

# .envファイルのパーミッションチェック
ENV_PERM=$(stat -c "%a" "${ENV_FILE}")
if [ "${ENV_PERM}" != "600" ] && [ "${ENV_PERM}" != "400" ]; then
    echo "警告: .envファイルのパーミッションが${ENV_PERM}です"
    echo "セキュリティのため、以下のコマンドでパーミッションを変更することを推奨します:"
    echo "  chmod 600 ${ENV_FILE}"
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

# ===========================================
# 必須変数の検証
# ===========================================
if [ -z "${MYSQL_HOST}" ]; then
    echo "エラー: MYSQL_HOSTが設定されていません"
    exit 1
fi

if [ -z "${MYSQL_USER}" ]; then
    echo "エラー: MYSQL_USERが設定されていません"
    exit 1
fi

if [ -z "${DATABASES}" ]; then
    echo "エラー: DATABASESが設定されていません"
    exit 1
fi

# デフォルト値の設定
MYSQL_PORT="${MYSQL_PORT:-3306}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"

# ===========================================
# MySQL接続テスト
# ===========================================
echo "MySQLサーバーへの接続をテストしています..."

MYSQL_OPTS="-h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER}"
if [ -n "${MYSQL_PASSWORD}" ]; then
    export MYSQL_PWD="${MYSQL_PASSWORD}"
fi

if ! mysqladmin ${MYSQL_OPTS} ping &>/dev/null; then
    echo "エラー: MySQLサーバーに接続できません"
    echo "接続情報を確認してください:"
    echo "  ホスト: ${MYSQL_HOST}"
    echo "  ポート: ${MYSQL_PORT}"
    echo "  ユーザー: ${MYSQL_USER}"
    exit 1
fi

echo "接続成功"

# ===========================================
# 出力ディレクトリの作成
# ===========================================
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
EXPORT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"
mkdir -p "${EXPORT_DIR}"

echo "出力先: ${EXPORT_DIR}"

# ===========================================
# データベース構造のエクスポート
# ===========================================
IFS=',' read -ra DB_ARRAY <<< "${DATABASES}"
SUCCESS_COUNT=0
FAIL_COUNT=0

for DB_NAME in "${DB_ARRAY[@]}"; do
    # 前後の空白を除去
    DB_NAME=$(echo "${DB_NAME}" | xargs)

    if [ -z "${DB_NAME}" ]; then
        continue
    fi

    echo -n "エクスポート中: ${DB_NAME} ... "

    OUTPUT_FILE="${EXPORT_DIR}/${DB_NAME}.sql"

    if mysqldump ${MYSQL_OPTS} --no-data --skip-comments "${DB_NAME}" > "${OUTPUT_FILE}" 2>/dev/null; then
        echo "完了"
        ((SUCCESS_COUNT++))
    else
        echo "失敗"
        rm -f "${OUTPUT_FILE}"
        ((FAIL_COUNT++))
    fi
done

# ===========================================
# 結果サマリー
# ===========================================
echo ""
echo "=== エクスポート完了 ==="
echo "成功: ${SUCCESS_COUNT}件"
echo "失敗: ${FAIL_COUNT}件"
echo "出力先: ${EXPORT_DIR}"

if [ ${FAIL_COUNT} -gt 0 ]; then
    exit 1
fi
