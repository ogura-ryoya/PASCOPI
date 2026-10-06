#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName PASCOPI
;@Ahk2Exe-SetDescription PASCOPI
;@Ahk2Exe-SetVersion 1.2.0

; リリース時に GitHub Actions がタグのバージョンで上書きする
VERSION := "1.2.0"

; ============================================================
; PASCOPI
;
; Explorer / デスクトップで Ctrl + Alt + C
;
; 1個選択
;   ファイル  → フルパス
;   フォルダ  → フルパス + \
;
; 複数選択
;   親フォルダー + \
;   フォルダを上
;   ファイルを下
;   同じ種類は名前順
;   ※ 親フォルダーが異なる場合（デスクトップ・検索結果など）は
;     親フォルダーごとにまとめ、空行で区切る（1件だけならフルパス）
;
; \\?\ / \\?\UNC\ は通常のWindowsパスへ変換
; Windows 11 Explorerのタブに対応
;
; 起動するとWindows起動時の自動起動を登録
; タスクトレイのメニュー
;   有効 … ON / OFF の切り替え
;   終了 … 自動起動を解除して終了
; ============================================================

GroupAdd("Explorer", "ahk_class CabinetWClass")
GroupAdd("Explorer", "ahk_class ExploreWClass")

GroupAdd("Desktop", "ahk_class Progman")
GroupAdd("Desktop", "ahk_class WorkerW")

SetupTrayMenu()

; Explorer / デスクトップ以外では Ctrl + Alt + C を横取りしない
#HotIf WinActive("ahk_group Explorer") || WinActive("ahk_group Desktop")
^!c:: CopyExplorerSelection()
#HotIf

CopyExplorerSelection() {
    try {
        entries := GetSelectedEntries(WinExist("A"))

        ; 選択なし → 何もしない
        if entries.Length = 0
            return

        CopyToClipboard(FormatEntries(entries))
        ShowCopied(entries.Length)
    }
    catch as err {
        ShowError(err.Message)
    }
}

; ============================================================
; 選択項目を取得
;
; [{path, isFolder}, ...]
; ============================================================

GetSelectedEntries(hwnd) {
    document := WinExist("ahk_group Desktop ahk_id " hwnd)
        ? GetDesktopDocument()
        : GetExplorerDocument(hwnd)

    items := document.SelectedItems
    entries := []

    for item in items {
        path := NormalizePath(item.Path)

        ; ごみ箱などの仮想項目（::{GUID}）はパスを持たないため除外
        if path != "" && SubStr(path, 1, 2) != "::"
            entries.Push({ path: path, isFolder: IsFolderItem(item, path) })
    }

    if items.Count > 0 && entries.Length = 0
        throw Error("選択項目はパスを持たない項目です（ごみ箱など）。")

    return entries
}

; ============================================================
; コピーする文字列を作成
;
; 親フォルダーごとにまとめる（デスクトップ・検索結果など）
;   2件以上 → 親フォルダー + 項目名
;   1件のみ → フルパス（続けて並べる）
;   グループ間は空行で区切る
; ============================================================

FormatEntries(entries) {
    if entries.Length = 1
        return DisplayPath(entries[1])

    blocks := []

    for group in GroupByParent(entries) {
        if group.entries.Length = 1 {
            line := DisplayPath(group.entries[1])

            if blocks.Length && blocks[-1].isSingle
                blocks[-1].text .= "`r`n" line
            else
                blocks.Push({ text: line, isSingle: true })

            continue
        }

        lines := [AddFolderBackslash(group.parent)]

        for entry in group.entries {
            SplitPath(entry.path, &name)
            lines.Push(entry.isFolder ? AddFolderBackslash(name) : name)
        }

        blocks.Push({ text: JoinLines(lines), isSingle: false })
    }

    texts := []
    for block in blocks
        texts.Push(block.text)

    return JoinLines(texts, "`r`n`r`n")
}

DisplayPath(entry) {
    return entry.isFolder ? AddFolderBackslash(entry.path) : entry.path
}

; [{parent, entries}, ...]（親フォルダー順、各グループ内は並び替え済み）
GroupByParent(entries) {
    groups := []
    index := Map()
    index.CaseSense := "Off"

    for entry in entries {
        SplitPath(entry.path, , &parent)

        if !index.Has(parent) {
            index[parent] := { parent: parent, entries: [] }
            groups.Push(index[parent])
        }

        index[parent].entries.Push(entry)
    }

    groups := MergeSort(groups, (a, b) => StrCmpLogical(a.parent, b.parent))

    for group in groups
        group.entries := MergeSort(group.entries, CompareEntries)

    return groups
}

JoinLines(lines, separator := "`r`n") {
    result := ""

    for line in lines
        result .= (A_Index = 1 ? "" : separator) line

    return result
}

; ============================================================
; Explorerの現在のタブのDocumentを取得
; ============================================================

GetExplorerDocument(hwnd) {
    static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"

    ; Win11 Explorerのタブ（タブ非対応のExplorerでは 0）
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", "ahk_id " hwnd)
    catch
        activeTab := 0

    for window in ComObject("Shell.Application").Windows {
        try {
            if window.HWND != hwnd
                continue

            if !activeTab
                return window.Document

            ; IOleWindow::GetWindow でタブのHWNDを取得し、現在のタブと比較
            shellBrowser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
            tabHwnd := 0
            ComCall(3, shellBrowser, "Ptr*", &tabHwnd)

            if tabHwnd = activeTab
                return window.Document
        }
    }

    throw Error("現在のExplorerタブを取得できませんでした。")
}

; ============================================================
; デスクトップのDocumentを取得
; ============================================================

GetDesktopDocument() {
    static SWC_DESKTOP := 8, SWFO_NEEDDISPATCH := 1

    hwnd := Buffer(4, 0)

    try {
        desktop := ComObject("Shell.Application").Windows.FindWindowSW(
            0, "", SWC_DESKTOP, ComValue(0x4003, hwnd.Ptr), SWFO_NEEDDISPATCH
        )
        return desktop.Document
    }

    throw Error("デスクトップを取得できませんでした。")
}

; ============================================================
; フォルダ判定
; ============================================================

IsFolderItem(item, path) {
    ; ファイルシステム上の項目は属性で判定
    ; （Shellの IsFolder は .zip も true を返すため）
    if attributes := FileExist(path)
        return InStr(attributes, "D") != 0

    ; ファイルシステム外の項目は Shell の判定に従う
    try return item.IsFolder
    return false
}

; ============================================================
; 並び替え（マージソート）
;
; フォルダ
; ↓
; ファイル
;
; file1
; file2
; file10
; ============================================================

; 並び替えた新しい配列を返す（大量に選択しても高速）
MergeSort(items, compare) {
    return MergeSortRange(items, compare, 1, items.Length)
}

MergeSortRange(items, compare, first, last) {
    if first > last
        return []

    if first = last
        return [items[first]]

    middle := (first + last) // 2
    left := MergeSortRange(items, compare, first, middle)
    right := MergeSortRange(items, compare, middle + 1, last)

    ; 並び替え済みの左右を、先頭から小さい順に取り出してつなぐ
    result := []
    i := 1, j := 1

    while i <= left.Length && j <= right.Length
        result.Push(compare(left[i], right[j]) <= 0 ? left[i++] : right[j++])

    while i <= left.Length
        result.Push(left[i++])

    while j <= right.Length
        result.Push(right[j++])

    return result
}

CompareEntries(a, b) {
    if a.isFolder != b.isFolder
        return a.isFolder ? -1 : 1

    return StrCmpLogical(a.path, b.path)
}

; Explorerと同じ自然順（file2 < file10）
StrCmpLogical(a, b) {
    return DllCall("Shlwapi\StrCmpLogicalW", "Str", a, "Str", b, "Int")
}

; ============================================================
; \\?\ を通常形式へ
; ============================================================

NormalizePath(path) {
    if SubStr(path, 1, 8) = "\\?\UNC\"
        return "\\" SubStr(path, 9)

    if SubStr(path, 1, 4) = "\\?\"
        return SubStr(path, 5)

    return path
}

; ============================================================
; フォルダ末尾に \
; ============================================================

AddFolderBackslash(path) {
    return RTrim(path, "\") "\"
}

; ============================================================
; クリップボードへコピー
; ============================================================

CopyToClipboard(text) {
    saved := ClipboardAll()

    try {
        A_Clipboard := ""
        A_Clipboard := text

        if ClipWait(1)
            return
    }

    ; 失敗したら元の中身に戻す
    try A_Clipboard := saved
    throw Error("クリップボードへのコピーに失敗しました。")
}

; ============================================================
; コピー完了の表示（1秒で消える）
; ============================================================

ShowCopied(count) {
    ToolTip("📋 コピーしました" (count > 1 ? "（" count "件）" : ""))

    ; 同じ関数を指定するとタイマーがリセットされ、最後のコピーから1秒表示される
    SetTimer(HideToolTip, -1000)
}

HideToolTip() {
    ToolTip()
}

; ============================================================
; タスクトレイのメニュー / 自動起動
;
; 有効  … チェックでON / OFF（OFF中は Ctrl + Alt + C を無効化）
; 終了  … 自動起動を解除して終了
;
; 起動するたびにスタートアップフォルダのショートカットを
; 現在の場所へ作成（移動した場合も追従）
; ============================================================

SetupTrayMenu() {
    static ENABLE_MENU := "有効", EXIT_MENU := "終了"
    versionMenu := "PASCOPI " VersionText()

    ; 標準の項目（Reload / Exit など）は使わない
    A_TrayMenu.Delete()
    A_TrayMenu.Add(versionMenu, (*) => 0)
    A_TrayMenu.Disable(versionMenu)
    A_TrayMenu.Add()
    A_TrayMenu.Add(ENABLE_MENU, ToggleEnabled)
    A_TrayMenu.Add()
    A_TrayMenu.Add(EXIT_MENU, ExitPascopi)

    A_TrayMenu.Check(ENABLE_MENU)
    A_TrayMenu.Default := ENABLE_MENU  ; アイコンのダブルクリックでも切り替え
    UpdateIconTip()

    try CreateStartupShortcut()
    catch as err
        ShowError("自動起動の登録に失敗しました。`n`n" err.Message)
}

ToggleEnabled(itemName, *) {
    Suspend(-1)
    A_TrayMenu.ToggleCheck(itemName)
    UpdateIconTip()
}

UpdateIconTip() {
    A_IconTip := "PASCOPI " VersionText() (A_IsSuspended ? "（無効）" : "")
}

VersionText() {
    return "v" VERSION
}

ExitPascopi(*) {
    try FileDelete(StartupShortcutPath())
    ExitApp()
}

StartupShortcutPath() {
    return A_Startup "\PASCOPI.lnk"
}

CreateStartupShortcut() {
    if A_IsCompiled
        FileCreateShortcut(A_ScriptFullPath, StartupShortcutPath(), A_ScriptDir)
    else
        FileCreateShortcut(A_AhkPath, StartupShortcutPath(), A_ScriptDir, '"' A_ScriptFullPath '"')
}

; ============================================================
; エラー表示
; ============================================================

ShowError(message) {
    MsgBox("❌ PASCOPI エラー`n`n" message, "PASCOPI")
}
