#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetWorkingDir A_ScriptDir

; Load environment variables from .env file
LoadEnvFile()

DEEPL_ENDPOINT := "https://api-free.deepl.com/v2/translate"
GROQ_ENDPOINT := "https://api.groq.com/openai/v1/chat/completions"

FLOOD_DELAY_MS := 1200
lastTranslateTick := 0
debugMonitorGui := 0
debugControls := Map()
translationMode := 4 ; Default: DeepL + Groq Slang
currentHotkey := "PgDn" ; Default Hotkey

; Setup Initial Hotkey
Hotkey(currentHotkey, TranslateCallback)

TranslateCallback(*)
{
    TranslateClipboard("TR", "EN")
}

; Tray Menu Setup
A_TrayMenu.Delete() ; Clear standard menu
A_TrayMenu.Add("RPShift Menu", (*) => ToggleDebugMonitor())
A_TrayMenu.Add("Reload Script", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "RPShift Menu"
A_TrayMenu.ClickCount := 1 ; Single click to open default

; Auto-Start Debug Monitor
CreateDebugMonitor()

`::Send "{t}"

; PgDn is now dynamic
; PgDn:: TranslateClipboard("TR", "EN")
^!c:: TranslateClipboard("EN", "TR")
^!d:: ToggleDebugMonitor()

TranslateClipboard(source, target)
{
    global lastTranslateTick, FLOOD_DELAY_MS, debugMonitorGui

    if (A_TickCount - lastTranslateTick < FLOOD_DELAY_MS)
        return
    lastTranslateTick := A_TickCount

    clipBackup := ClipboardAll()
    A_Clipboard := ""
    Send "^c"

    if !ClipWait(0.6)
    {
        A_Clipboard := clipBackup
        return
    }

    text := Trim(A_Clipboard)
    if (text = "")
    {
        A_Clipboard := clipBackup
        return
    }

    isFormal := false
    command := ""
    content := text

    if SubStr(text, 1, 1) = "/"
    {
        isFormal := true
        parts := StrSplit(text, " ", , 2)
        command := parts[1]
        content := parts.Length > 1 ? parts[2] : ""
    }

    originalText := content
    deeplResult := DeepL_Translate(content, source, target)
    finalResult := deeplResult
    deepseekResult := ""
    deepseekRawResponse := ""

    if (translationMode = 1 || translationMode = 2)
    {
        ; Groq Direct Modes
        deeplResult := "(Skipped)"
        isSlang := (translationMode = 2)
        
        finalResult := Groq_DirectTranslate(content, source, target, isSlang, &deepseekRawResponse)
        deepseekResult := finalResult ; For debug display
    }
    else 
    {
        ; DeepL Based Modes (3 and 4)
        deeplResult := DeepL_Translate(content, source, target)
        finalResult := deeplResult
        
        if (deeplResult != "" && translationMode = 4 && target = "EN" && !isFormal)
        {
            deepseekResult := Groq_Slangify(originalText, deeplResult, &deepseekRawResponse)
            if (deepseekResult != "" && deepseekResult != deeplResult)
                finalResult := deepseekResult
        }
    }

    if (finalResult != "")
    {
        ; Update debug monitor if it exists
        if (debugMonitorGui)
        {
            UpdateDebugMonitor(originalText, deeplResult, deepseekResult, finalResult, deepseekRawResponse, source, target)
        }

        A_Clipboard := command ? command " " finalResult : finalResult
        Send "^v"
        Sleep 120
    }

    A_Clipboard := clipBackup
}

LoadEnvFile()
{
    envPath := A_ScriptDir . "\.env"
    if !FileExist(envPath)
        return
    
    envFile := FileOpen(envPath, "r")
    if !envFile
        return
    
    while !envFile.AtEOF
    {
        line := Trim(envFile.ReadLine())
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        
        if RegExMatch(line, "^([^=]+)=(.*)$", &match)
        {
            key := Trim(match[1])
            value := Trim(match[2])
            ; Remove quotes if present
            if (SubStr(value, 1, 1) = '"' && SubStr(value, -1) = '"')
                value := SubStr(value, 2, -1)
            EnvSet(key, value)
        }
    }
    envFile.Close()
}

Groq_Slangify(originalText, translatedText, rawResponseRef := "")
{
    global GROQ_ENDPOINT
    
    apiKey := EnvGet("GROQ_API_KEY")
    if (apiKey = "")
        return translatedText
    
    if (translatedText = "")
        return translatedText
    
    ; More specific prompt with original text for error correction
    prompt := "I have an original text and its English translation. Please:" . "`n" 
        . "MOST IMPORTANT: Preserve the EXACT meaning and intent of the original text. The meaning must remain identical - slang is secondary to meaning preservation." . "`n"
        . "1. FIRST, check the translation against the original text. If the translation is wrong or misses the meaning, FIX IT. The final meaning must be accurate to the original." . "`n"
        . "2. Convert the text to casual, natural, spoken American English. Use common contractions (gonna, wanna, I'm) but don't overdo it. It should sound like a real person talking, not a caricature." . "`n"
        . "3. CRITICAL: If converting to slang would change the fundamental meaning or tone (e.g. if the original is serious/sad), prioritize the MEANING. Do not force slang where it doesn't fit the emotion." . "`n"
        . "4. Translate ALL words directly, including sensitive terms. The Turkish word 'zenci' should be translated to 'nigga' only in a casual/street context, otherwise 'black'. Context matters." . "`n"
        . "Original text: " . originalText . "`n"
        . "Translation: " . translatedText . "`n"
        . "Return ONLY the final text. No explanations."
    
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    
    escapedContent := EscapeJson(prompt)
    ; Groq API uses OpenAI-compatible format - using llama-3.1-8b-instant (fast and free)
    jsonBody := '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' . escapedContent . '"}],"temperature":0.8,"max_tokens":500}'
    
    url := GROQ_ENDPOINT
    
    try
    {
        http.Open("POST", url, false)
        http.SetRequestHeader("Content-Type", "application/json; charset=UTF-8")
        http.SetRequestHeader("Authorization", "Bearer " . apiKey)
        http.Send(jsonBody)
        
        statusCode := http.Status
        ; Ensure response is treated as UTF-8
        response := http.ResponseText
        ; AutoHotkey v2 handles UTF-8 automatically, but ensure proper decoding
        
        ; Store raw response for debugging
        if (rawResponseRef != "")
        {
            errorInfo := ""
            if (statusCode != 200)
                errorInfo := "ERROR - Status Code: " . statusCode . "`n"
            if (InStr(response, '"error"'))
            {
                ; Try to extract error message
                if RegExMatch(response, '"message"\s*:\s*"([^"]+)"', &errorMatch)
                    errorInfo .= "API Error: " . errorMatch[1] . "`n"
                else
                    errorInfo .= "API Error detected in response`n"
            }
            ; Check for rate limit
            if (statusCode = 429 || InStr(response, "rateLimitExceeded") || InStr(response, "RESOURCE_EXHAUSTED"))
                errorInfo .= "RATE LIMIT EXCEEDED - Please wait and try again`n"
            rawResponseRef := errorInfo . "Status: " . statusCode . "`n`nResponse (first 3000 chars):`n" . SubStr(response, 1, 3000)
        }
        
        ; Check for rate limit (429)
        if (statusCode = 429)
        {
            ; Show a brief notification
            TrayTip("Rate Limit", "Groq API rate limit exceeded. Please wait a moment.", 3)
            return translatedText
        }
        
        ; Check for errors first
        if (statusCode != 200)
        {
            ; Show error notification
            if (statusCode = 401)
                TrayTip("API Error", "Invalid Groq API key. Check your .env file.", 5)
            else if (statusCode = 403)
                TrayTip("API Error", "Groq API access forbidden. Check API permissions.", 5)
            else
                TrayTip("API Error", "Groq API error: Status " . statusCode, 5)
            return translatedText
        }
        
        ; Check for API errors in response
        if (InStr(response, '"error"'))
        {
            ; Try to extract error message
            if RegExMatch(response, '"message"\s*:\s*"([^"]+)"', &errorMatch)
                TrayTip("API Error", "Groq: " . errorMatch[1], 5)
            return translatedText
        }
        
        ; Groq API returns OpenAI-compatible format: {"choices":[{"message":{"content":"..."}}]}
        ; Extract content from nested structure
        
        ; Method 1: Find content field in message
        pos := InStr(response, '"content"')
        if (pos > 0)
        {
            ; Find colon after "text"
            colonPos := InStr(response, ":", false, pos)
            if (colonPos > 0)
            {
                ; Find opening quote
                quoteStart := InStr(response, '"', false, colonPos)
                if (quoteStart > 0)
                {
                    ; Now find closing quote, handling escaped quotes properly
                    quoteEnd := quoteStart + 1
                    while (quoteEnd <= StrLen(response) && quoteEnd - quoteStart < 5000)
                    {
                        char := SubStr(response, quoteEnd, 1)
                        if (char = '"')
                        {
                            ; Check if it's escaped - look backwards for backslashes
                            escapeCount := 0
                            checkPos := quoteEnd - 1
                            while (checkPos >= quoteStart && SubStr(response, checkPos, 1) = "\")
                            {
                                escapeCount++
                                checkPos--
                            }
                            ; If even number of backslashes (or zero), quote is not escaped
                            if (Mod(escapeCount, 2) = 0)
                            {
                                ; Found unescaped closing quote
                                result := SubStr(response, quoteStart + 1, quoteEnd - quoteStart - 1)
                                result := UnescapeJson(result)
                                result := Trim(result)
                                ; Clean up any remaining \r \n that weren't properly escaped
                                result := StrReplace(result, "\r", "")
                                result := StrReplace(result, "\n", " ")
                                result := StrReplace(result, "  ", " ")
                                result := Trim(result)
                                ; Post-process to reduce excessive apostrophes and commas
                                result := CleanExcessivePunctuation(result)
                                if (result != "" && result != translatedText)
                                    return result
                                break
                            }
                        }
                        quoteEnd++
                    }
                }
            }
        }
        
        ; Method 2: Fallback - simple regex for content
        if RegExMatch(response, '"content"\s*:\s*"([^"]{1,500})"', &match)
        {
            result := UnescapeJson(match[1])
            result := Trim(result)
            result := StrReplace(result, "\r", "")
            result := StrReplace(result, "\n", " ")
            result := StrReplace(result, "  ", " ")
            result := Trim(result)
            ; Post-process to reduce excessive apostrophes and commas
            result := CleanExcessivePunctuation(result)
            if (result != "" && result != translatedText)
                return result
        }
    }
    catch as err
    {
        return translatedText
    }
    
    return translatedText
}

EscapeJson(str)
{
    ; Order matters: escape backslash first, then other characters
    ; Handle UTF-8 characters properly
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`t", "\t")
    
    ; Ensure UTF-8 encoding - AutoHotkey strings are already UTF-16/UTF-8 compatible
    ; But we need to make sure special characters are preserved
    return str
}

UnescapeJson(str)
{
    ; Order matters: handle double backslashes first, then escaped characters
    ; Replace \\ with a temporary marker, then restore after other replacements
    str := StrReplace(str, "\\\\", "\x01TEMP_BACKSLASH\x01")
    str := StrReplace(str, "\\n", "`n")
    str := StrReplace(str, "\\r", "`r")
    str := StrReplace(str, "\\t", "`t")
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, "\x01TEMP_BACKSLASH\x01", "\")
    return str
}

ToggleDebugMonitor()
{
    global debugMonitorGui, debugControls
    
    if (debugMonitorGui)
    {
        try
        {
            debugMonitorGui.Destroy()
            debugMonitorGui := 0
            debugControls.Clear()
        }
    }
    else
    {
        CreateDebugMonitor()
    }
}

CreateDebugMonitor()
{
    global debugMonitorGui, debugControls
    
    debugMonitorGui := Gui("+AlwaysOnTop -Caption +Border +OwnDialogs", "Translation Debug Monitor")
    debugMonitorGui.BackColor := "1E1E1E"
    debugMonitorGui.SetFont("s10 cWhite", "Segoe UI")
    
    ; Title Bar (Custom)
    debugMonitorGui.SetFont("s11 cWhite bold", "Segoe UI")
    debugMonitorGui.AddText("x20 y10 w400 h30 BackgroundTrans", "RPSHIFT translation macro, only turkish to english")
    
    ; Logo - Removed from top


    ; Window Controls (Minimize / Close)
    debugMonitorGui.SetFont("s12 cGray bold", "Segoe UI")
    minBtn := debugMonitorGui.AddText("x540 y5 w40 h30 Center BackgroundTrans", "_")
    minBtn.OnEvent("Click", (*) => debugMonitorGui.Minimize())

    closeBtn := debugMonitorGui.AddText("x590 y5 w40 h30 Center BackgroundTrans", "X")
    closeBtn.OnEvent("Click", (*) => ToggleDebugMonitor())
    
    ; Drag support for custom title bar
    debugMonitorGui.AddText("x0 y0 w640 h40 BackgroundTrans").OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, , debugMonitorGui.Hwnd))
    
    yPos := 50

    ; Original Text Section
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y" . yPos . " w600", "ORIGINAL TEXT (" . A_Now . "):")
    debugMonitorGui.SetFont("s11 cWhite", "Segoe UI")
    originalTextCtrl := debugMonitorGui.AddEdit("x20 y+5 w600 h70 ReadOnly Background2D2D2D -E0x200", "") 
    SetDarkMode(originalTextCtrl)
    
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+10 w600", "DEEPL TRANSLATION:")
    debugMonitorGui.SetFont("s11 cWhite", "Segoe UI")
    deeplTextCtrl := debugMonitorGui.AddEdit("x20 y+5 w600 h70 ReadOnly Background2D2D2D -E0x200", "")
    SetDarkMode(deeplTextCtrl)
    
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+10 w600", "GROQ SLANGIFY:")
    debugMonitorGui.SetFont("s11 cWhite", "Segoe UI")
    deepseekTextCtrl := debugMonitorGui.AddEdit("x20 y+5 w600 h70 ReadOnly Background2D2D2D -E0x200", "")
    SetDarkMode(deepseekTextCtrl)
    
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+10 w600", "FINAL RESULT:")
    debugMonitorGui.SetFont("s11 c00FF00 bold", "Segoe UI") ; Green + Bold for visibility
    finalTextCtrl := debugMonitorGui.AddEdit("x20 y+5 w600 h70 ReadOnly Background2D2D2D -E0x200", "")
    SetDarkMode(finalTextCtrl)
    
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+10 w600", "GROQ RAW RESPONSE (for debugging):")
    debugMonitorGui.SetFont("s9 cGray", "Consolas")
    rawResponseCtrl := debugMonitorGui.AddEdit("x20 y+5 w600 h50 ReadOnly Background2D2D2D -E0x200", "")
    SetDarkMode(rawResponseCtrl)
    
    ; Custom "Clear" Button
    debugMonitorGui.SetFont("s10 bold cWhite", "Segoe UI")
    clearBtn := debugMonitorGui.AddText("x20 y+15 w600 h35 Center Background3E3E3E 0x200", "CLEAR OUTPUT") ; 0x200 = Vertical Center
    clearBtn.OnEvent("Click", (*) => ClearDebugMonitor())
    
    modes := ["1. Groq Only (Direct Translate)", "2. Groq Only (Translate + Slang) (Önerilen)", "3. DeepL Only (Önerilen)", "4. DeepL + Groq Slang"]
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+15 w600", "TRANSLATION MODE:")
    debugMonitorGui.SetFont("s10 cBlack", "Segoe UI")
    debugMonitorGui.AddDropDownList("x20 y+5 w600 Choose" . translationMode, modes).OnEvent("Change", (ctrl, *) => SetTranslationMode(ctrl.Value))

    ; Custom Hotkey Display (Read-Only) & Change Button
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI Semibold")
    debugMonitorGui.AddText("x20 y+10 w600", "TRIGGER HOTKEY:")
    debugMonitorGui.SetFont("s10 cWhite", "Segoe UI")
    hkDisplayCtrl := debugMonitorGui.AddEdit("x20 y+5 w480 h30 ReadOnly Background2D2D2D -E0x200", currentHotkey)
    SetDarkMode(hkDisplayCtrl)
    
    changeBtn := debugMonitorGui.AddButton("x+10 yp w110 h30", "Change")
    changeBtn.OnEvent("Click", (*) => OpenHotkeyDialog(hkDisplayCtrl))

    ; Logo at Bottom (Absolute Positioning)
    ; Window h900. Content ends around y600.
    ; Place logo at y620. Link at bottom.
    logoPath := A_ScriptDir . "\logo.png"
    if FileExist(logoPath)
    {
        try {
            ; Centered w400. x120. y620 fixed.
            debugMonitorGui.AddPicture("x120 y620 w400 h-1 BackgroundTrans", logoPath)
        }
    }
    
    ; Footer - "Developed by diceandink" (Absolute Positioning)
    ; y860 fixed.
    debugMonitorGui.SetFont("s9 cGray", "Segoe UI")
    debugMonitorGui.AddText("x240 y860 w85 h20 Right BackgroundTrans", "Developed by")
    
    debugMonitorGui.SetFont("s9 cWhite bold underline", "Segoe UI")
    devLink := debugMonitorGui.AddText("x+5 yp w80 h20 Left BackgroundTrans cWhite", "diceandink")
    devLink.OnEvent("Click", (*) => Run("https://github.com/diceandink"))

    ; Store control references in Map
    debugControls["original"] := originalTextCtrl
    debugControls["deepl"] := deeplTextCtrl
    debugControls["deepseek"] := deepseekTextCtrl
    debugControls["final"] := finalTextCtrl
    debugControls["raw"] := rawResponseCtrl
    
    ; Auto-size height slightly reduced due to compaction, but keeping fixed for safety
    debugMonitorGui.Show("w640 h900")
}

OpenHotkeyDialog(displayCtrl)
{
    global currentHotkey, debugMonitorGui
    
    hkGui := Gui("+Owner" . debugMonitorGui.Hwnd . " +AlwaysOnTop +ToolWindow", "Change Hotkey")
    hkGui.BackColor := "1E1E1E"
    hkGui.SetFont("s10 cWhite", "Segoe UI")
    
    hkGui.AddText("x20 y20 w200", "Press new hotkey combination:")
    hkCtrl := hkGui.AddHotkey("x20 y+10 w200 vNewHotkey", currentHotkey)
    
    saveBtn := hkGui.AddButton("x20 y+20 w90 h30", "Save")
    saveBtn.OnEvent("Click", (*) => SaveHotkey(hkGui, hkCtrl, displayCtrl))
    
    cancelBtn := hkGui.AddButton("x+20 yp w90 h30", "Cancel")
    cancelBtn.OnEvent("Click", (*) => hkGui.Destroy())
    
    hkGui.Show()
}

SaveHotkey(guiObj, hkCtrl, displayCtrl)
{
    global currentHotkey
    
    newHk := hkCtrl.Value
    if (newHk = "")
    {
        MsgBox("Please press a key combination first.", "Error", "Icon!")
        return
    }
    
    try
    {
        if (currentHotkey != "")
            Hotkey(currentHotkey, "Off")
            
        currentHotkey := newHk
        Hotkey(currentHotkey, TranslateCallback, "On")
        
        displayCtrl.Value := currentHotkey
        guiObj.Destroy()
    }
    catch as err
    {
        MsgBox("Invalid Hotkey: " . err.Message, "Error", "Icon!")
    }
}

SetDarkMode(ctrl)
{
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0)
    {
        try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Str", 0)
    }
}

UpdateDebugMonitor(original, deepl, deepseek, final, rawResponse, source, target)
{
    global debugMonitorGui, debugControls
    
    if (!debugMonitorGui || !debugControls.Has("original"))
        return
    
    try
    {
        debugControls["original"].Value := original . " [" . source . "]"
        debugControls["deepl"].Value := deepl . " [" . target . "]"
        
        if (deepseek != "" && deepseek != deepl)
        {
            debugControls["deepseek"].Value := deepseek
            debugControls["final"].Value := final
        }
        else
        {
            debugControls["deepseek"].Value := "(No slangify applied - Groq returned: " . (deepseek = "" ? "empty" : "same as DeepL") . ")"
            debugControls["final"].Value := final
        }
        
        if (rawResponse != "")
            debugControls["raw"].Value := rawResponse
    }
}

ClearDebugMonitor()
{
    global debugMonitorGui, debugControls
    
    if (!debugMonitorGui || !debugControls.Has("original"))
        return
    
    try
    {
        debugControls["original"].Value := ""
        debugControls["deepl"].Value := ""
        debugControls["deepseek"].Value := ""
        debugControls["final"].Value := ""
        if (debugControls.Has("raw"))
            debugControls["raw"].Value := ""
    }
}

SetTranslationMode(modeIndex)
{
    global translationMode
    translationMode := modeIndex
}





Groq_DirectTranslate(text, source, target, useSlang, rawResponseRef := "")
{
    global GROQ_ENDPOINT
    
    apiKey := EnvGet("GROQ_API_KEY")
    if (apiKey = "")
        return "Error: Missing GROQ_API_KEY"
        
    systemPrompt := "You are a professional translator. Translate the following text from " . source . " to " . target . "."
    if (useSlang && target = "EN")
        systemPrompt .= " The target text must be in casual, natural American English slang. Preserve the original meaning but make it sound like a real person speaking."
    else
        systemPrompt .= " Provide a strictly accurate, meaning-preserving translation."
        
    systemPrompt .= " IMPORTANT: Return ONLY the final translated text. Do NOT provide multiple options (no 'or'). Do NOT use quotes around the output. Do NOT add notes."
        
    prompt := systemPrompt . "`n`nOriginal Text: " . text . "`n`nTranslation:"

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    escapedContent := EscapeJson(prompt)
    ; Lower temperature to 0.3 for more deterministic/single answers
    jsonBody := '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' . escapedContent . '"}],"temperature":0.3,"max_tokens":1000}'
    
    try
    {
        http.Open("POST", GROQ_ENDPOINT, false)
        http.SetRequestHeader("Content-Type", "application/json; charset=UTF-8")
        http.SetRequestHeader("Authorization", "Bearer " . apiKey)
        http.Send(jsonBody)
        
        response := http.ResponseText
        
        ; Store raw response for debugging
        if (rawResponseRef != "")
            rawResponseRef := "Status: " . http.Status . "`n`nResponse (first 1000 chars):`n" . SubStr(response, 1, 1000)

        ; Robust Parsing Logic (Ported from Groq_Slangify)
        pos := InStr(response, '"content"')
        if (pos > 0)
        {
             colonPos := InStr(response, ":", false, pos)
             if (colonPos > 0)
             {
                 quoteStart := InStr(response, '"', false, colonPos)
                 if (quoteStart > 0)
                 {
                     quoteEnd := quoteStart + 1
                     while (quoteEnd <= StrLen(response) && quoteEnd - quoteStart < 10000)
                     {
                         char := SubStr(response, quoteEnd, 1)
                         if (char = '"')
                         {
                             escapeCount := 0
                             checkPos := quoteEnd - 1
                             while (checkPos >= quoteStart && SubStr(response, checkPos, 1) = "\")
                             {
                                 escapeCount++
                                 checkPos--
                             }
                             if (Mod(escapeCount, 2) = 0)
                             {
                                 result := SubStr(response, quoteStart + 1, quoteEnd - quoteStart - 1)
                                 result := UnescapeJson(result)
                                 return Trim(result)
                             }
                         }
                         quoteEnd++
                     }
                 }
             }
        }
        
        ; Fallback regex
        if RegExMatch(response, '"content"\s*:\s*"([^"]+)"', &match)
        {
            result := UnescapeJson(match[1])
            result := Trim(result)
            
            ; 1. Clean Quotes
            if (SubStr(result, 1, 1) = '"' && SubStr(result, -1) = '"')
                result := SubStr(result, 2, -1)
                
            ; 2. Strict Single Output: If there are multiple lines or " or ", take the first one
            if InStr(result, "`n")
            {
                lines := StrSplit(result, "`n")
                loop lines.Length
                {
                    line := Trim(lines[A_Index])
                    if (line != "" && line != "or")
                    {
                        result := line
                        break
                    }
                }
            }
            
            ; 3. Aggressive " or " check
            if InStr(result, " or ")
            {
                parts := StrSplit(result, " or ")
                result := Trim(parts[1])
            }
            
            ; Final cleanup of quotes just in case
            result := StrReplace(result, '"', "")
            
            return result
        }
        
        return "Error: Parse failed (Response might be empty or malformed)"
    }
    catch as err
    {
        return "Error: " . err.Message
    }
    return ""
}

DeepL_Translate(text, source := "TR", target := "EN")
{
    global DEEPL_ENDPOINT
    
    apiKey := EnvGet("DEEPL_API_KEY")
    if (apiKey = "")
        return ""

    http := ComObject("WinHttp.WinHttpRequest.5.1")

    data :=
        "auth_key=" . apiKey
        . "&text=" . text
        . "&source_lang=" . source
        . "&target_lang=" . target
        . "&split_sentences=1"
        . "&preserve_formatting=1"

    http.Open("POST", DEEPL_ENDPOINT, false)
    http.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
    http.Send(data)

    response := http.ResponseText
    
    ; DeepL API returns: {"translations":[{"text":"..."}]}
    ; Need to handle escaped quotes properly
    pos := InStr(response, '"text"')
    if (pos > 0)
    {
        ; Find colon after "text"
        colonPos := InStr(response, ":", false, pos)
        if (colonPos > 0)
        {
            ; Find opening quote
            quoteStart := InStr(response, '"', false, colonPos)
            if (quoteStart > 0)
            {
                ; Now find closing quote, handling escaped quotes properly
                quoteEnd := quoteStart + 1
                while (quoteEnd <= StrLen(response) && quoteEnd - quoteStart < 10000)
                {
                    char := SubStr(response, quoteEnd, 1)
                    if (char = '"')
                    {
                        ; Check if it's escaped - look backwards for backslashes
                        escapeCount := 0
                        checkPos := quoteEnd - 1
                        while (checkPos >= quoteStart && SubStr(response, checkPos, 1) = "\")
                        {
                            escapeCount++
                            checkPos--
                        }
                        ; If even number of backslashes (or zero), quote is not escaped
                        if (Mod(escapeCount, 2) = 0)
                        {
                            ; Found unescaped closing quote
                            result := SubStr(response, quoteStart + 1, quoteEnd - quoteStart - 1)
                            ; Unescape JSON characters
                            result := StrReplace(result, '\\"', '"')
                            result := StrReplace(result, "\\\\", "\")
                            result := StrReplace(result, "\\r", "")
                            result := StrReplace(result, "\\n", " ")
                            result := StrReplace(result, "\r", "")
                            result := StrReplace(result, "\n", " ")
                            result := StrReplace(result, "  ", " ")
                            result := Trim(result)
                            return result
                        }
                    }
                    quoteEnd++
                }
            }
        }
    }
    
    ; Fallback to simple regex if above method fails
    if RegExMatch(response, '"text"\s*:\s*"([^"]*)"', &m)
    {
        result := m[1]
        ; Clean up escaped newlines and carriage returns
        result := StrReplace(result, "\\r", "")
        result := StrReplace(result, "\\n", " ")
        result := StrReplace(result, "\r", "")
        result := StrReplace(result, "\n", " ")
        result := StrReplace(result, "  ", " ")
        result := Trim(result)
        return result
    }

    return ""
}

CleanExcessivePunctuation(text)
{
    ; Reduce excessive apostrophes and commas
    ; Fix patterns like "growin', growin', and growin'" -> "growin' and growin'"
    ; Fix patterns like "talkin' 'bout" -> "talkin' bout"
    
    ; Remove apostrophes before words that don't need them (like 'bout, 'em when not needed)
    text := RegExReplace(text, "(\w+)'\s+'(\w+)", "$1 $2")  ; Remove apostrophe between words like "talkin' 'bout"
    
    ; Fix excessive repetition with commas (e.g., "growin', growin', and growin'" -> "growin' and growin'")
    text := RegExReplace(text, "(\w+[',]?)\s*,\s*\1\s*,\s*and\s+\1", "$1 and $1")
    text := RegExReplace(text, "(\w+[',]?)\s*,\s*\1\s*,\s*\1", "$1 and $1")
    
    ; Reduce multiple consecutive commas
    text := RegExReplace(text, ",\s*,+", ",")
    
    ; Fix patterns like "talkin' 'bout" -> "talkin' bout" (already done above, but keep for safety)
    text := RegExReplace(text, "(\w+)'\s+'(\w+)", "$1 $2")
    
    ; Clean up multiple spaces
    text := RegExReplace(text, "\s+", " ")
    text := Trim(text)
    
    return text
}

UrlEncode(str)
{
    ; URL encode using AutoHotkey v2's built-in encoding
    encoded := ""
    utf8Buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, utf8Buf, "UTF-8")
    size := utf8Buf.Size
    
    Loop size
    {
        byte := NumGet(utf8Buf, A_Index - 1, "UChar")
        ; Keep alphanumeric and safe characters as-is
        if ((byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte = 45 || byte = 95 || byte = 46 || byte = 126)
        {
            encoded .= Chr(byte)
        }
        else if (byte = 32)
        {
            encoded .= "+"
        }
        else
        {
            encoded .= "%" . Format("{:02X}", byte)
        }
    }
    return encoded
}