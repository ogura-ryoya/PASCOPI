#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; PASCOPI
;
; Explorerで Ctrl + Alt + C
;
; 1個選択
;   ファイル  → フルパス
;   フォルダ  → フルパス + \
;
; 複数選択
;   現在のフォルダー + \
;   フォルダを上
;   ファイルを下
;   同じ種類は名前順
;
; \\?\ / \\?\UNC\ は通常のWindowsパスへ変換
; Windows 11 Explorerのタブに対応
; ============================================================

^!c:: CopyExplorerSelection()

CopyExplorerSelection() {
    hwnd := WinExist("A")

    if !hwnd {
        ShowError("現在のウィンドウを取得できませんでした。")
        return
    }

    class := WinGetClass("ahk_id " hwnd)

    if class != "CabinetWClass" && class != "ExploreWClass" {
        ShowError("現在のウィンドウはExplorerではありません。`n`nClass: " class)
        return
    }

    ; --------------------------------------------------------
    ; Shell.Application
    ; --------------------------------------------------------

    try shell := ComObject("Shell.Application")
    catch as err {
        ShowError("Shell.Application の取得に失敗しました。`n`n" err.Message)
        return
    }

    ; --------------------------------------------------------
    ; 現在のExplorerタブ
    ; --------------------------------------------------------

    document := GetExplorerDocument(shell, hwnd)

    if !IsObject(document) {
        ShowError("現在のExplorerタブを取得できませんでした。")
        return
    }

    ; --------------------------------------------------------
    ; 選択項目
    ; --------------------------------------------------------

    try {
        items := document.SelectedItems
        selectedCount := items.Count
    }
    catch as err {
        ShowError("選択項目の取得に失敗しました。`n`n" err.Message)
        return
    }

    ; 選択なし → 何もしない
    if selectedCount = 0
        return

    ; ========================================================
    ; 1個選択
    ; ========================================================

    if selectedCount = 1 {
        try {
            item := items.Item(0)
            path := NormalizePath(item.Path)
        }
        catch as err {
            ShowError("選択項目の取得に失敗しました。`n`n" err.Message)
            return
        }

        if path = "" {
            ShowError("選択項目のPathが空でした。")
            return
        }

        if IsFolderItem(item, path)
            path := AddFolderBackslash(path)

        CopyToClipboard(path)
        return
    }

    ; ========================================================
    ; 複数選択
    ; ========================================================

    try folderPath := NormalizePath(document.Folder.Self.Path)
    catch as err {
        ShowError("現在のフォルダーのPath取得に失敗しました。`n`n" err.Message)
        return
    }

    if folderPath = "" {
        ShowError("現在のフォルダーPathが空です。")
        return
    }

    entries := []

    try {
        for item in items {
            try {
                path := NormalizePath(item.Path)

                if path = ""
                    continue

                SplitPath(path, &name)

                entries.Push({
                    name: name,
                    isFolder: IsFolderItem(item, path)
                })
            }
        }
    }
    catch as err {
        ShowError("選択項目の取得中にエラーが発生しました。`n`n" err.Message)
        return
    }

    if entries.Length = 0 {
        ShowError("選択項目を取得できませんでした。")
        return
    }

    ; 名前順ソート
    SortEntries(entries)

    ; 現在のフォルダー
    result := AddFolderBackslash(folderPath)

    ; 選択項目
    for entry in entries {
        name := entry.name

        if entry.isFolder
            name := AddFolderBackslash(name)

        result .= "`r`n" name
    }

    CopyToClipboard(result)
}

; ============================================================
; Explorerの現在のタブのDocumentを取得
; ============================================================

GetExplorerDocument(shell, hwnd) {
    static IID_IShellBrowser :=
        "{000214E2-0000-0000-C000-000000000046}"

    ; Win11 Explorerのタブ
    try activeTab := ControlGetHwnd(
        "ShellTabWindowClass1",
        "ahk_id " hwnd
    )
    catch
        activeTab := 0

    for window in shell.Windows {
        try {
            if window.HWND != hwnd
                continue

            ; タブが存在しない場合
            if !activeTab
                return window.Document

            ; 現在のタブを特定
            shellBrowser := ComObjQuery(
                window,
                IID_IShellBrowser,
                IID_IShellBrowser
            )

            if !shellBrowser
                continue

            currentTab := 0

            ; IShellBrowser::GetControlWindow
            ComCall(
                3,
                shellBrowser,
                "Int*",
                &currentTab
            )

            if currentTab = activeTab
                return window.Document
        }
        catch {
            continue
        }
    }

    return ""
}

; ============================================================
; フォルダ判定
; ============================================================

IsFolderItem(item, path) {
    ; Shellによる判定を優先
    try {
        if item.IsFolder
            return true
    }
    catch {
    }

    ; 通常のファイルシステム
    return InStr(FileExist(path), "D") != 0
}

; ============================================================
; 名前順ソート
;
; フォルダ
; ↓
; ファイル
;
; file1
; file2
; file10
; ============================================================

SortEntries(entries) {
    entryCount := entries.Length

    loop entryCount - 1 {
        swapped := false

        loop entryCount - A_Index {
            i := A_Index

            a := entries[i]
            b := entries[i + 1]

            ; フォルダを上へ
            if !a.isFolder && b.isFolder {
                entries[i] := b
                entries[i + 1] := a
                swapped := true
                continue
            }

            ; 同じ種類 → 名前順
            if a.isFolder = b.isFolder {
                compare := DllCall(
                    "Shlwapi\StrCmpLogicalW",
                    "Str", a.name,
                    "Str", b.name,
                    "Int"
                )

                if compare > 0 {
                    entries[i] := b
                    entries[i + 1] := a
                    swapped := true
                }
            }
        }

        if !swapped
            break
    }
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
    try {
        A_Clipboard := ""
        A_Clipboard := text

        if !ClipWait(1) {
            ShowError("クリップボードへのコピーに失敗しました。")
            return false
        }

        return true
    }
    catch as err {
        ShowError(
            "クリップボードへのコピー中にエラーが発生しました。`n`n"
            err.Message
        )
        return false
    }
}

; ============================================================
; エラー表示
; ============================================================

ShowError(message) {
    MsgBox(
        "❌ PASCOPI エラー`n`n" message,
        "PASCOPI"
    )
}
