# PASCOPI

Windows Explorerのファイル・フォルダのパスを整形してコピーするAutoHotkey v2スクリプト

## できること

Explorerでファイルやフォルダを選択し、`Ctrl + Alt + C` を押すとパスをクリップボードにコピー

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

* 親フォルダを先頭に追加
* フォルダを上に配置
* ファイルを下に配置
* 同じ種類はExplorerと同じ名前順（`file2` → `file10`）でソート

デスクトップや検索結果などで親フォルダが異なる項目を複数選択した場合は、親フォルダごとにまとめて空行で区切る

```text
C:\Users\ユーザー名\Desktop\
Folder1\
memo.txt

C:\Users\Public\Desktop\
Google Chrome.lnk
Microsoft Edge.lnk
```

親フォルダに1件しかない項目は、フルパスで続けて並べる

```text
C:\Users\ユーザー名\Documents\report.docx
C:\Users\ユーザー名\Downloads\image.png
```

### 共通

* `\\?\` / `\\?\UNC\` 形式のパスを通常形式に変換
* Windows 11 Explorerのタブに対応（表示中のタブの選択項目をコピー）
* デスクトップ上の選択にも対応
* コピーするとマウスの近くに「📋 コピーしました」と1秒表示
* `.zip` はファイルとして扱う（末尾に `\` を付けない）
* Explorer・デスクトップ以外のウィンドウでは `Ctrl + Alt + C` を横取りしない

## 使い方

### 起動

1. `PASCOPI.exe` を[ダウンロード](https://github.com/ogura-ryoya/PASCOPI/releases/latest/download/PASCOPI.exe)
2. `PASCOPI.exe` を好きな場所に置いて実行

AutoHotkeyのインストールは不要

タスクバーにある`^（隠れているインジケーターを表示します）`をクリックし、`H` のアイコン（PASCOPI）が表示されていれば起動成功

<details>
<summary>AutoHotkey v2 をインストール済みの場合（.ahk 版）</summary>

1. `PASCOPI.ahk` を[ダウンロード](https://github.com/ogura-ryoya/PASCOPI/releases/latest/download/PASCOPI.ahk)
2. `PASCOPI.ahk` を実行

</details>

### 実行

Explorerやデスクトップでファイルやフォルダを選択し、`Ctrl + Alt + C` で実行

### Windows起動時に自動起動

PASCOPIを一度起動すると、Windows起動時に自動で起動するよう登録される（設定は不要）

* 解除したい場合は、タスクトレイの PASCOPI アイコンを右クリックし、「Windows起動時に自動起動」のチェックを外す
* もう一度クリックすると再登録
* PASCOPIを別の場所へ移動した場合も、移動先で一度起動すれば登録先が自動で更新される

## 開発者向け：リリース手順

GitHubでリリースを公開すると、GitHub Actions（`.github/workflows/release.yml`）が `PASCOPI.exe` をビルドし、`PASCOPI.ahk` と一緒にリリースへ自動で添付する

## 補足：Windows標準の「パスのコピー」との違い

Windows 11には標準で `Ctrl + Shift + C`（右クリック →「パスのコピー」）がある

| | Windows標準 | PASCOPI |
| --- | --- | --- |
| 1個選択 | `"C:\...\sample.txt"`（ダブルクォート付き） | `C:\...\sample.txt` |
| フォルダ | 末尾 `\` なし | 末尾 `\` あり |
| 複数選択 | 全項目をフルパスで列挙 | 親フォルダ + 項目名、フォルダ優先の名前順 |
