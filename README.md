# PASCOPI

Windows Explorerのファイル・フォルダのパスを整形してコピーするAutoHotkey v2スクリプト

## できること

### ファイルを1つ選択

```text
C:\Users\ユーザー名\Documents\sample.txt
```

ファイルのフルパスをコピー

### フォルダを1つ選択

```text
C:\Users\ユーザー名\Documents\SampleFolder\
```

フォルダのフルパスをコピー、末尾に `\` を付加

### 複数選択

```text
C:\Users\ユーザー名\Documents\
Folder1\
Folder2\
file1.txt
file2.txt
file10.txt
```

* 現在のフォルダを先頭に追加
* フォルダを上に配置
* ファイルを下に配置
* 同じ種類は名前順でソート

### 共通

`\\?\` / `\\?\UNC\` 形式のパスを通常形式に変換

## 使い方

### 起動

1. AutoHotkey v2のセットアップファイルを[ダウンロード](https://www.autohotkey.com/download/ahk-v2.exe)
2. セットアップファイルを実行し、AutoHotkey v2をインストール
3. `PASCOPI.ahk` を[ダウンロード](https://github.com/ogura-ryoya/PASCOPI/releases/download/v1.0.1/PASCOPI.ahk)
4. `PASCOPI.ahk` を実行し、PASCOPIを起動

タスクバーにある`^（隠れているインジケーターを表示します）`をクリックし、`H (PASCOPI.ahk)` のアイコンが表示されていれば起動成功

### 実行

Windows Explorer上でファイルやフォルダを選択し、`Ctrl + Alt + C` で実行

### Windows起動時に自動起動
PASCOPIは、Windowsを起動すると自動的に起動されるわけではない

そのため、毎回手動でPASCOPIを起動するのが面倒な場合は、スタートアップに登録をする

1. `Win + R` を押す
2. `shell:startup` と入力してOK
3. `PASCOPI.ahk` のショートカットをスタートアップフォルダに追加
