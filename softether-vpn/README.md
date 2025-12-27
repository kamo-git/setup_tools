# SoftEther VPN Client Setup Script

SoftEther VPN Client (Linux) のインストールから接続設定までを自動化するBashスクリプトです。

## 機能

*   必要なパッケージ（ビルドツール等）の自動インストール (openSUSE, Ubuntu/Debian, CentOS/RHEL対応)
*   ソースコードのダウンロードとビルド
*   `vpncmd` を使用した初期設定（仮想NIC作成、アカウント作成）
*   接続の確立とIPアドレスの取得（DHCP または 固定IP）

## 使い方

1.  ディレクトリに移動します。

    ```bash
    cd softether-vpn
    ```

2.  設定ファイルを準備します。

    ```bash
    cp .env.sample .env
    nano .env
    ```

    `.env` ファイル内で、接続先のサーバー情報、ユーザー名、パスワード、固定IP設定などを記述してください。

3.  スクリプトを実行します。

    ```bash
    chmod +x setup.sh
    sudo ./setup.sh
    ```


## 動作確認環境

*   openSUSE
*   Ubuntu / Debian
*   CentOS / RHEL

## 備考

*   実行には `root` 権限 (`sudo`) が必要です。
*   既存のインストールがある場合は、ビルドをスキップして接続設定のみ行います。
