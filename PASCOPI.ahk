#Requires AutoHotkey v2.0
#SingleInstance Force


; ============================================================
; Explorerで Ctrl + Alt + C
;
; 1個選択
;   ファイル → フルパス
;   フォルダ → フルパス + \
;
; 複数選択
;   現在のフォルダー + \
;   フォルダを上
;   ファイルを下
;   同じ種類は自然順
;
; パスの \\?\ / \\?\UNC\ は通常形式に変換
;
; Windows 11 Explorerのタブにも対応
; ============================================================

^!c::
{
    CopyExplorerSelection()
}


CopyExplorerSelection()
{
    ; ========================================================
    ; 現在のExplorer
    ; ========================================================

    hwnd := WinExist("A")

    if !hwnd
    {
        ShowError("現在のウィンドウを取得できませんでした。")
        return
    }


    class := WinGetClass("ahk_id " hwnd)

    if !(class = "CabinetWClass" || class = "ExploreWClass")
    {
        ShowError(
            "現在のウィンドウはExplorerではありません。`n`n"
            . "Class: " class
        )
        return
    }


    ; ========================================================
    ; Shell.Application
    ; ========================================================

    try
    {
        shell := ComObject("Shell.Application")
    }
    catch as err
    {
        ShowError(
            "Shell.Application の取得に失敗しました。`n`n"
            . err.Message
        )
        return
    }


    ; ========================================================
    ; アクティブなExplorerのDocument取得
    ; ========================================================

    document := GetExplorerDocument(shell, hwnd)

    if !IsObject(document)
    {
        ShowError(
            "現在のExplorerのDocumentを取得できませんでした。"
        )
        return
    }


    ; ========================================================
    ; 選択項目取得
    ; ========================================================

    items := ""
    count := -1
    lastError := ""


    Loop 10
    {
        try
        {
            items := document.SelectedItems
            count := items.Count

            if count > 0
                break

            Sleep 50
        }
        catch as err
        {
            lastError := err.Message
            Sleep 50
        }
    }


    ; ========================================================
    ; 選択項目取得失敗
    ; ========================================================

    if count < 0
    {
        ShowError(
            "選択項目の取得に失敗しました。`n`n"
            . lastError
        )
        return
    }


    ; ========================================================
    ; 選択なし
    ; ========================================================

    if count = 0
    {
        ShowError(
            "Explorerは取得できましたが、選択項目が0個です。"
        )
        return
    }


    ; ========================================================
    ; 1個だけ選択
    ;
    ; ファイル → フルパス
    ; フォルダ → フルパス + \
    ; ========================================================

    if count = 1
    {
        try
        {
            item := items.Item(0)
            path := NormalizePath(item.Path)
        }
        catch as err
        {
            ShowError(
                "選択項目のPath取得に失敗しました。`n`n"
                . err.Message
            )
            return
        }


        if path = ""
        {
            ShowError(
                "選択項目のPathが空でした。"
            )
            return
        }


        ; フォルダ判定
        isFolder := IsFolderItem(item, path)


        ; フォルダなら末尾に \
        if isFolder
            path := AddFolderBackslash(path)


        ; クリップボードへ
        CopyToClipboard(path)

        return
    }


    ; ========================================================
    ; 現在のフォルダー
    ; ========================================================

    try
    {
        folderPath := NormalizePath(
            document.Folder.Self.Path
        )
    }
    catch as err
    {
        ShowError(
            "現在のフォルダーのPath取得に失敗しました。`n`n"
            . err.Message
        )
        return
    }


    if folderPath = ""
    {
        ShowError(
            "現在のフォルダーPathが空です。"
        )
        return
    }


    ; ========================================================
    ; 選択項目を取得
    ; ========================================================

    entries := []


    try
    {
        for item in items
        {
            try
            {
                path := NormalizePath(item.Path)

                if path = ""
                    continue


                SplitPath(path, &name)


                ; フォルダ判定
                isFolder := IsFolderItem(item, path)


                entries.Push({
                    name: name,
                    path: path,
                    isFolder: isFolder
                })
            }
            catch
            {
                ; 個別項目で取得できない場合はスキップ
                continue
            }
        }
    }
    catch as err
    {
        ShowError(
            "選択項目の列挙中にエラーが発生しました。`n`n"
            . err.Message
        )
        return
    }


    if entries.Length = 0
    {
        ShowError(
            "選択項目を取得できませんでした。"
        )
        return
    }


    ; ========================================================
    ; ソート
    ;
    ; 1. フォルダ
    ; 2. ファイル
    ;
    ; 同じ種類なら自然順
    ;
    ; file1
    ; file2
    ; file10
    ; ========================================================

    count := entries.Length


    Loop count
    {
        swapped := false


        Loop count - 1
        {
            i := A_Index

            current := entries[i]
            next := entries[i + 1]


            ; --------------------------------------------
            ; フォルダをファイルより上へ
            ; --------------------------------------------

            if !current.isFolder && next.isFolder
            {
                temp := entries[i]

                entries[i] := entries[i + 1]
                entries[i + 1] := temp

                swapped := true

                continue
            }


            ; --------------------------------------------
            ; 同じ種類なら自然順
            ; --------------------------------------------

            if current.isFolder = next.isFolder
            {
                try
                {
                    compareResult := DllCall(
                        "Shlwapi\StrCmpLogicalW",
                        "Str", current.name,
                        "Str", next.name,
                        "Int"
                    )
                }
                catch
                {
                    compareResult := (
                        current.name > next.name
                            ? 1
                            : current.name < next.name
                                ? -1
                                : 0
                    )
                }


                if compareResult > 0
                {
                    temp := entries[i]

                    entries[i] := entries[i + 1]
                    entries[i + 1] := temp

                    swapped := true
                }
            }
        }


        if !swapped
            break
    }


    ; ========================================================
    ; 結果作成
    ;
    ; 現在のフォルダーもフォルダーなので \
    ; ========================================================

    result := AddFolderBackslash(folderPath) . "`r`n"


    for entry in entries
    {
        name := entry.name


        ; --------------------------------------------
        ; フォルダなら末尾に \
        ; --------------------------------------------

        if entry.isFolder
            name := AddFolderBackslash(name)


        result .= name . "`r`n"
    }


    ; 最後の改行を削除
    result := RTrim(result, "`r`n")


    ; ========================================================
    ; クリップボードへ
    ; ========================================================

    CopyToClipboard(result)
}


; ============================================================
; パスを通常のWindows形式に変換
;
; \\?\UNC\server\share\...
;       ↓
; \\server\share\...
;
; \\?\C:\...
;       ↓
; C:\...
; ============================================================

NormalizePath(path)
{
    ; \\?\UNC\ → \\server\share\
    if SubStr(path, 1, 8) = "\\?\UNC\"
        return "\\" . SubStr(path, 9)


    ; \\?\C:\ → C:\
    if SubStr(path, 1, 4) = "\\?\"
        return SubStr(path, 5)


    return path
}


; ============================================================
; フォルダ判定
; ============================================================

IsFolderItem(item, path)
{
    attributes := FileExist(path)


    ; 実在するフォルダ
    if InStr(attributes, "D")
        return true


    ; 特殊なExplorer項目などへのフォールバック
    try
    {
        itemType := item.Type

        if InStr(itemType, "フォルダー")
            || InStr(itemType, "Folder")
        {
            return true
        }
    }
    catch
    {
    }


    return false
}


; ============================================================
; フォルダ末尾に \ を追加
; ============================================================

AddFolderBackslash(path)
{
    return RTrim(path, "\") . "\"
}


; ============================================================
; ExplorerのDocument取得
;
; Windows 11 Explorerのタブに対応
; ============================================================

GetExplorerDocument(shell, hwnd)
{
    static IID_IShellBrowser :=
        "{000214E2-0000-0000-C000-000000000046}"


    ; --------------------------------------------------------
    ; アクティブなExplorerタブ
    ; --------------------------------------------------------

    activeTab := 0


    try
    {
        activeTab := ControlGetHwnd(
            "ShellTabWindowClass1",
            "ahk_id " hwnd
        )
    }
    catch
    {
        activeTab := 0
    }


    ; --------------------------------------------------------
    ; Shell.ApplicationのExplorer一覧
    ; --------------------------------------------------------

    try
    {
        for window in shell.Windows
        {
            try
            {
                ; 別Explorerは無視
                if window.HWND != hwnd
                    continue


                ; ------------------------------------------------
                ; Windows 11のタブを確認
                ; ------------------------------------------------

                if activeTab
                {
                    try
                    {
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


                        if currentTab != activeTab
                            continue
                    }
                    catch
                    {
                        ; タブ判定に失敗した場合は
                        ; 通常のDocumentを使用
                    }
                }


                document := window.Document


                if IsObject(document)
                    return document
            }
            catch
            {
                continue
            }
        }
    }
    catch
    {
        return ""
    }


    return ""
}


; ============================================================
; クリップボードへコピー
; ============================================================

CopyToClipboard(text)
{
    try
    {
        ; 古い内容をクリア
        A_Clipboard := ""


        ; 新しい内容をセット
        A_Clipboard := text


        ; 反映確認
        if !ClipWait(1)
        {
            ShowError(
                "クリップボードへのコピーに失敗しました。"
            )

            return false
        }


        return true
    }
    catch as err
    {
        ShowError(
            "クリップボードへのコピー中にエラーが発生しました。`n`n"
            . err.Message
        )

        return false
    }
}


; ============================================================
; エラー表示
; ============================================================

ShowError(message)
{
    MsgBox(
        "❌ Explorer Copy エラー`n`n"
        . message,
        "Explorer Copy"
    )
}