#!/bin/bash
set -e

# ==========================================
# SoftEther VPN Client 自動セットアップスクリプト (openSUSE対応 / 固定IP版)
# ==========================================

# --- 環境設定 ---
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo "エラー: 設定ファイル $ENV_FILE が見つかりません。"
    echo ".env.sample をコピーして .env を作成し、設定を記述してください。"
    echo "実行例: cp .env.sample .env && nano .env"
    exit 1
fi

# .env のパーミッション/所有者チェック (セキュリティ対策)
if [ -O "$ENV_FILE" ]; then
    # ファイル所有者が自分(実行ユーザー)の場合
    CURRENT_PERM=$(stat -c "%a" "$ENV_FILE")
    if [ "$CURRENT_PERM" -gt 600 ] && [ "$CURRENT_PERM" -ne 600 ] && [ "$CURRENT_PERM" -ne 400 ]; then
        echo "警告: $ENV_FILE のパーミッションが $CURRENT_PERM です。セキュリティのため 600 (自分のみ読み書き可) に変更します。"
        chmod 600 "$ENV_FILE"
    fi
else
    echo "警告: $ENV_FILE の所有者が実行ユーザーと異なります。内容を信頼できるか確認してください。"
fi

# 設定読み込み
source "$ENV_FILE"

# 必須変数のチェック
if [ -z "$VPN_SERVER_HOST" ] || [ -z "$VPN_USER" ]; then
    echo "エラー: .env ファイル内の必須設定 (VPN_SERVER_HOST, VPN_USER 等) が空です。"
    exit 1
fi

# 固定IP設定のチェック
if [ "$USE_STATIC_IP" = "true" ] && [ -z "$VPN_STATIC_IP" ]; then
    echo "エラー: 固定IPモード (USE_STATIC_IP=true) ですが、VPN_STATIC_IP が設定されていません。"
    echo ".env ファイルを確認してください。"
    exit 1
fi

# root権限チェック
if [ "$(id -u)" -ne 0 ]; then
    echo "エラー: このスクリプトはroot権限(sudo)で実行してください。"
    echo "使用法: sudo ./setup_softether.sh"
    exit 1
fi

# vpncmdのパス定義
VPNCMD="$INSTALL_DIR/vpncmd"

# ==========================================
# 1. インストール確認とインストール処理
# ==========================================

if [ -x "$VPNCMD" ] && [ -x "$INSTALL_DIR/vpnclient" ]; then
    echo "=== SoftEther VPN Client は既にインストールされています ==="
    echo "インストール先: $INSTALL_DIR"
    echo "インストール工程をスキップし、設定・接続フェーズへ移行します。"
else
    echo "=== SoftEther VPN Client が見つかりません。インストールを開始します ==="

    echo "--- 必要なパッケージをインストールします (openSUSE) ---"
    if command -v zypper &> /dev/null; then
        # 固定IPの場合はdhcp-clientは必須ではないが、iproute2等は必要
        zypper -n install gcc make wget tar
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y build-essential wget
    elif command -v yum &> /dev/null; then
        yum groupinstall -y "Development Tools"
        yum install -y wget
    else
        echo "警告: サポートされていないパッケージマネージャです。ビルドツールが不足している可能性があります。"
    fi

    echo "--- SoftEther VPN Client をダウンロードしています ---"
    TEMP_DIR=$(mktemp -d)
    # スクリプト終了時に一時ディレクトリを削除するトラップを設定
    trap 'rm -rf "$TEMP_DIR"' EXIT

    cd "$TEMP_DIR"
    echo "ダウンロード先: $DL_URL"
    wget -O softether-vpnclient.tar.gz "$DL_URL"

    echo "--- アーカイブを展開しています ---"
    tar xzvf softether-vpnclient.tar.gz
    cd vpnclient

    echo "--- ビルドを実行します (ライセンスに自動同意) ---"
    yes 1 | make

    echo "--- インストール先へ配置します ---"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"
    cp -r * "$INSTALL_DIR/"
    
    # 権限設定
    cd "$INSTALL_DIR"
    chmod 600 *
    chmod 700 vpnclient
    chmod 700 vpncmd

    echo "--- インストール完了 ---"
fi

# ==========================================
# 2. サービスの起動処理 (再接続のため再起動)
# ==========================================

echo "=== VPN Client サービスの起動処理 ==="
# プロセスチェック
if pgrep -f "$INSTALL_DIR/vpnclient" > /dev/null; then
    echo "既存のサービスが実行中です。一旦停止しています..."
    "$INSTALL_DIR/vpnclient" stop
    sleep 2
fi

echo "サービスを開始します..."
"$INSTALL_DIR/vpnclient" start
sleep 2

# ==========================================
# 3. 設定と接続 (vpncmd)
# ==========================================

echo "=== vpncmd で設定を行います ==="

# vpncmd に標準入力からコマンドを渡すための関数
# 使用法: exec_vpncmd_stdin <<EOF
# CommandArg1
# CommandArg2
# EOF
exec_vpncmd_stdin() {
    "$VPNCMD" localhost /CLIENT /IN <&0
}

echo "--- 仮想NIC ($NIC_NAME) の設定 ---"
# NicCreateを試行。成功すれば作成完了。
# 失敗した場合（終了コード非0）、既に存在するとみなしてNicEnableを実行。
# 注: NicCreate等は機密情報を含まないため引数渡しでも許容範囲だが、統一感を出すため必要に応じて変更可能。
# ここでは単純なコマンドなのでそのまま実行するが、エラーハンドリングのため関数を使わずに直接呼ぶ
if "$VPNCMD" localhost /CLIENT /CMD NicCreate "$NIC_NAME" > /dev/null 2>&1; then
    echo "仮想NIC $NIC_NAME を新規作成しました。"
else
    echo "仮想NIC $NIC_NAME の作成をスキップしました（既に存在します）。設定を有効化します..."
    "$VPNCMD" localhost /CLIENT /CMD NicEnable "$NIC_NAME"
fi

echo "--- 接続アカウント ($ACCOUNT_NAME) の設定 ---"
# 既存設定がある場合は上書き（削除→作成）
echo "アカウント設定を更新します..."
"$VPNCMD" localhost /CLIENT /CMD AccountDelete "$ACCOUNT_NAME" > /dev/null 2>&1 || true

# 機密情報(ユーザー名、パスワード)を含むため、標準入力経由で渡す
exec_vpncmd_stdin <<EOF
AccountCreate $ACCOUNT_NAME /SERVER:$VPN_SERVER_HOST:$VPN_SERVER_PORT /HUB:$VPN_HUB_NAME /USERNAME:$VPN_USER /NICNAME:$NIC_NAME
AccountPasswordSet $ACCOUNT_NAME /PASSWORD:$VPN_PASSWORD /TYPE:standard
exit
EOF

echo "--- 接続開始 ---"
"$VPNCMD" localhost /CLIENT /CMD AccountConnect "$ACCOUNT_NAME"

echo "=== 接続状態の確認 ==="
sleep 3
"$VPNCMD" localhost /CLIENT /CMD AccountList

# ==========================================
# 4. IPアドレスの設定 (固定IP or DHCP)
# ==========================================

INTERFACE_NAME="vpn_$NIC_NAME"
echo "=== IPアドレスの設定 ==="
echo "対象インターフェース: $INTERFACE_NAME"

# インターフェースが上がるのを少し待つ
sleep 1
ip link set dev "$INTERFACE_NAME" up

if [ "$USE_STATIC_IP" = "true" ]; then
    echo "--- 固定IPアドレスを設定します ($VPN_STATIC_IP) ---"
    
    # 既存のIPがあれば削除（重複防止）
    ip addr flush dev "$INTERFACE_NAME"
    
    # IPアドレスの追加
    if ip addr add "$VPN_STATIC_IP" dev "$INTERFACE_NAME"; then
        echo "IPアドレスを設定しました。"
    else
        echo "エラー: IPアドレスの設定に失敗しました。"
        exit 1
    fi

    # ゲートウェイ設定（任意）
    if [ -n "$VPN_GATEWAY" ]; then
        echo "--- ゲートウェイを設定します ($VPN_GATEWAY) ---"
        # 既存のデフォルトルートへの影響を考慮し、ここでは明示的にルートを追加する例とする
        # 必要に応じて default ルートを書き換える等の処理に変更してください
        if ip route add default via "$VPN_GATEWAY" dev "$INTERFACE_NAME"; then
             echo "デフォルトゲートウェイを追加しました。"
        else
             echo "警告: ゲートウェイの追加に失敗しました（既に存在するか、設定が競合しています）。"
        fi
    fi

else
    echo "--- DHCPを使用してIPアドレスを取得します ---"
    if command -v dhclient &> /dev/null; then
        dhclient -v "$INTERFACE_NAME"
    elif command -v dhcpcd &> /dev/null; then
        dhcpcd "$INTERFACE_NAME"
    else
        echo "警告: dhclient または dhcpcd が見つかりません。openSUSEの場合は 'zypper install dhcp-client' を試してください。"
    fi
fi

echo ""
echo "=== 現在のIPアドレス情報 ==="
ip addr show "$INTERFACE_NAME"

echo ""
echo "=== セットアップ完了 ==="
echo "切断するには: sudo $VPNCMD localhost /CLIENT /CMD AccountDisconnect $ACCOUNT_NAME"
