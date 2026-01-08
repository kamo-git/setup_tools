#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
MYSQL_CREDS_FILE=""

# クリーンアップ関数
cleanup() {
    if [ -n "${MYSQL_CREDS_FILE}" ] && [ -f "${MYSQL_CREDS_FILE}" ]; then
        rm -f "${MYSQL_CREDS_FILE}"
    fi
}

# 終了時のクリーンアップを設定
trap cleanup EXIT

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
if [[ "$OSTYPE" == "darwin"* ]]; then
    ENV_PERM=$(stat -f "%Lp" "${ENV_FILE}")
else
    ENV_PERM=$(stat -c "%a" "${ENV_FILE}")
fi
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
# MySQL認証情報ファイルの作成
# ===========================================
MYSQL_CREDS_FILE=$(mktemp -t mysql_creds.XXXXXX)
chmod 600 "${MYSQL_CREDS_FILE}"

cat > "${MYSQL_CREDS_FILE}" <<EOF
[client]
host='${MYSQL_HOST}'
port='${MYSQL_PORT}'
user='${MYSQL_USER}'
EOF

if [ -n "${MYSQL_PASSWORD}" ]; then
    echo "password='${MYSQL_PASSWORD}'" >> "${MYSQL_CREDS_FILE}"
fi

# ===========================================
# MySQL接続テスト
# ===========================================
echo "MySQLサーバーへの接続をテストしています..."

if ! mysqladmin --defaults-extra-file="${MYSQL_CREDS_FILE}" ping &>/dev/null; then
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
    # 前後の空白を除去（パラメータ展開を使用）
    DB_NAME="${DB_NAME#"${DB_NAME%%[![:space:]]*}"}"
    DB_NAME="${DB_NAME%"${DB_NAME##*[![:space:]]}"}"

    if [ -z "${DB_NAME}" ]; then
        continue
    fi

    echo -n "エクスポート中: ${DB_NAME} ... "

    OUTPUT_FILE="${EXPORT_DIR}/${DB_NAME}.sql"

    if ERROR_MSG=$(mysqldump --defaults-extra-file="${MYSQL_CREDS_FILE}" --no-data --skip-comments "${DB_NAME}" 2>&1 > "${OUTPUT_FILE}"); then
        echo "完了"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "失敗: ${ERROR_MSG}"
        rm -f "${OUTPUT_FILE}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
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
