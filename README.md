# PASCOPI

Explorerやデスクトップで選択したファイル・フォルダのパスを、`Ctrl + Alt + C` で整形してコピーするWindows用ツール

## コピーされる形式

### 1つ選択

```text
C:\Users\ユーザー名\Documents\sample.txt
C:\Users\ユーザー名\Documents\SampleFolder\
```

フルパスをコピー（フォルダは末尾に `\` を付加）

### 複数選択

```text
C:\Users\ユーザー名\Documents\
Folder1\
Folder2\
file1.txt
file2.txt
file10.txt
```

親フォルダの下に、フォルダ → ファイルの順、名前順（`file2` → `file10`）で並べる

デスクトップや検索結果などで親フォルダが異なる場合は、親フォルダごとにまとめて空行で区切る

```text
C:\Users\ユーザー名\Desktop\
Folder1\
memo.txt

C:\Users\Public\Desktop\
Google Chrome.lnk
Microsoft Edge.lnk
```

## インストール

動作環境：Windows 10 / 11

1. `PASCOPI.exe` を[ダウンロード](https://github.com/ogura-ryoya/PASCOPI/releases/latest/download/PASCOPI.exe)
2. 好きな場所に置いて実行

起動すると、Windows起動時に自動で起動するよう登録される

### 初回起動時の警告について

* 「WindowsによってPCが保護されました」と表示された場合は、「詳細情報」→「実行」をクリック
* AutoHotkeyで作成したexeは、ウイルス対策ソフトに誤って検出されることがある。その場合は `.ahk` 版（下記）を使用

<details>
<summary>.ahk 版（AutoHotkey v2 をインストール済みの場合）</summary>

`PASCOPI.ahk` を[ダウンロード](https://github.com/ogura-ryoya/PASCOPI/releases/latest/download/PASCOPI.ahk)して実行

</details>

## タスクトレイのメニュー

タスクトレイの PASCOPI アイコン（`H`）を右クリック

| メニュー | 動作 |
| --- | --- |
| vX.X.X | バージョン表示 |
| 有効 | `Ctrl + Alt + C` のON / OFFを切り替え（アイコンのダブルクリックでも可） |
| 終了 | 自動起動を解除して終了 |

## アンインストール

タスクトレイのメニューから「終了」を選び、`PASCOPI.exe` を削除

## リリース手順（開発者向け）

1. `PASCOPI.ahk` 先頭のバージョン（`;@Ahk2Exe-SetVersion` と `VERSION :=` の2か所）を更新してコミット
2. `v1.2.0` のような形式のタグでGitHubのリリースを公開

GitHub Actionsがタグのバージョンを埋め込んだ `PASCOPI.exe` をビルドし、`PASCOPI.ahk` と一緒にリリースへ添付する
