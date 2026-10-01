#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName PASCOPI
;@Ahk2Exe-SetDescription PASCOPI

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
; （タスクトレイのメニューから解除可能）
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
    document := WinActive("ahk_group Desktop")
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

    InsertionSort(groups, (a, b) => StrCmpLogical(a.parent, b.parent))

    for group in groups
        InsertionSort(group.entries, CompareEntries)

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
; 並び替え（挿入ソート）
;
; フォルダ
; ↓
; ファイル
;
; file1
; file2
; file10
; ============================================================

InsertionSort(items, compare) {
    loop items.Length - 1 {
        current := items[A_Index + 1]
        i := A_Index

        while i >= 1 && compare(items[i], current) > 0 {
            items[i + 1] := items[i]
            i--
        }

        items[i + 1] := current
    }
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
    A_Clipboard := ""
    A_Clipboard := text

    if !ClipWait(1)
        throw Error("クリップボードへのコピーに失敗しました。")
}

; ============================================================
; コピー完了の表示（1秒で消える）
; ============================================================

ShowCopied(count) {
    ToolTip("📋 コピーしました" (count > 1 ? "（" count "件）" : ""))
    SetTimer(() => ToolTip(), -1000)
}

; ============================================================
; タスクトレイのメニュー / 自動起動
;
; 初期設定は自動起動ON
; 起動するたびにスタートアップフォルダのショートカットを
; 現在の場所へ作成（移動した場合も追従）
;
; 「Windows起動時に自動起動」でON / OFFを切り替え
; OFFにした場合は設定ファイルに保存し、再登録しない
; ============================================================

SetupTrayMenu() {
    static STARTUP_MENU := "Windows起動時に自動起動"

    A_IconTip := "PASCOPI（Ctrl + Alt + C）"
    A_TrayMenu.Insert("1&", STARTUP_MENU, ToggleStartup)
    A_TrayMenu.Insert("2&")

    if !IsAutoStartEnabled()
        return

    try {
        CreateStartupShortcut()
        A_TrayMenu.Check(STARTUP_MENU)
    }
    catch as err {
        ShowError("自動起動の登録に失敗しました。`n`n" err.Message)
    }
}

ToggleStartup(itemName, *) {
    try {
        if IsAutoStartEnabled() {
            if FileExist(StartupShortcutPath())
                FileDelete(StartupShortcutPath())
            SetAutoStartEnabled(false)
            A_TrayMenu.Uncheck(itemName)
        }
        else {
            CreateStartupShortcut()
            SetAutoStartEnabled(true)
            A_TrayMenu.Check(itemName)
        }
    }
    catch as err {
        ShowError("自動起動の設定に失敗しました。`n`n" err.Message)
    }
}

; 設定は %AppData%\PASCOPI\settings.ini に保存
SettingsPath() {
    return A_AppData "\PASCOPI\settings.ini"
}

IsAutoStartEnabled() {
    return IniRead(SettingsPath(), "Settings", "AutoStart", "1") = "1"
}

SetAutoStartEnabled(enabled) {
    DirCreate(A_AppData "\PASCOPI")
    IniWrite(enabled ? "1" : "0", SettingsPath(), "Settings", "AutoStart")
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
