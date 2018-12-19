sqlCheckEmpty text 'select count() from sqlite_master'


;-------------------------------------------------------------------
; If the file in [.ptrFileName] exists, the function opens it.
; if the file does not exists, new database is created and the
; initialization script from [.ptrInitScript] is executed on it.
;
; Returns:
;    CF: 0 - database was open successfully
;      eax = 0 - Existing database was open successfuly.
;      eax = 1 - New database was created and init script was executed successfully.
;      eax = 2 - New database was created but init script exits with error.
;    CF: 1 - the database could not be open. (error)
;-------------------------------------------------------------------
proc OpenOrCreate, .ptrFileName, .ptrDatabase, .ptrInitScript
   .hSQL dd ?
begin
        push    edi esi ebx

        mov     esi, [.ptrDatabase]
        cinvoke sqliteOpen_v2, [.ptrFileName], esi, SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE or SQLITE_OPEN_FULLMUTEX, 0
        test    eax, eax
        jz      .openok

.error:
        stc
        pop     ebx esi edi
        return

.openok:
        xor     ebx, ebx
        lea     eax, [.hSQL]
        cinvoke sqlitePrepare_v2, [esi], sqlCheckEmpty, sqlCheckEmpty.length, eax, 0

        cinvoke sqliteStep, [.hSQL]
        cinvoke sqliteColumnInt, [.hSQL], 0
        push    eax
        cinvoke sqliteFinalize, [.hSQL]
        pop     eax
        test    eax, eax
        jnz     .finish

        inc     ebx
        cinvoke sqliteExec, [esi], [.ptrInitScript], NULL, NULL, NULL
        test    eax, eax
        jz      .finish

        inc     ebx

.finish:
        mov     eax, ebx
        clc
        pop     ebx esi edi
        return
endp


proc SQliteRegisterFunctions, .ptrDatabase
begin
        cinvoke sqliteCreateFunction_v2, [.ptrDatabase], txt "url_encode", 1, SQLITE_UTF8, 0, sqliteURLEncode, 0, 0, 0
        cinvoke sqliteCreateFunction_v2, [.ptrDatabase], txt "html_encode", 1, SQLITE_UTF8, 0, sqliteHTMLEncode, 0, 0, 0
        cinvoke sqliteCreateFunction_v2, [.ptrDatabase], txt "slugify", 1, SQLITE_UTF8, 0, sqliteSlugify, 0, 0, 0
        cinvoke sqliteCreateFunction_v2, [.ptrDatabase], txt "tagify", 1, SQLITE_UTF8, 0, sqliteTagify, 0, 0, 0
        return
endp



proc sqliteURLEncode, .context, .num, .pValue
begin
        mov     eax, [.pValue]
        cinvoke sqliteValueText, [eax]
        test    eax, eax
        jz      .null

        stdcall StrURLEncode, eax
        push    eax
        stdcall StrPtr, eax

.result:
        cinvoke sqliteResultText, [.context], eax, [eax+string.len], SQLITE_TRANSIENT
        stdcall StrDel ; from the stack
        cret

.null:
        cinvoke sqliteResultNULL, [.context]
        cret
endp



proc sqliteHTMLEncode, .context, .num, .pValue
begin
        mov     eax, [.pValue]
        cinvoke sqliteValueText, [eax]
        test    eax, eax
        jz      .null

        stdcall StrEncodeHTML, eax
        push    eax
        stdcall StrPtr, eax

.result:
        cinvoke sqliteResultText, [.context], eax, [eax+string.len], SQLITE_TRANSIENT
        stdcall StrDel ; from the stack
        cret

.null:
        cinvoke sqliteResultNULL, [.context]
        cret
endp


proc sqliteSlugify, .context, .num, .pValue
begin
        mov     eax, [.pValue]
        cinvoke sqliteValueText, [eax]
        test    eax, eax
        jz      .null

        stdcall StrSlugify, eax
        push    eax
        stdcall StrPtr, eax

.result:
        cinvoke sqliteResultText, [.context], eax, [eax+string.len], SQLITE_TRANSIENT
        stdcall StrDel ; from the stack
        cret

.null:
        cinvoke sqliteResultNULL, [.context]
        cret
endp


proc sqliteTagify, .context, .num, .pValue
begin
        mov     eax, [.pValue]
        cinvoke sqliteValueText, [eax]
        test    eax, eax
        jz      .null

        stdcall StrDupMem, eax
        stdcall StrTagify, eax
        push    eax
        stdcall StrPtr, eax

        cinvoke sqliteResultText, [.context], eax, [eax+string.len], SQLITE_TRANSIENT
        stdcall StrDel ; from the stack
        cret

.null:
        cinvoke sqliteResultNULL, [.context]
        cret
endp



proc sqliteConvertPHPBBText, .context, .num, .pValue
begin
        push    edi

        stdcall TextCreate, sizeof.TText
        mov     edi, eax

        mov     eax, [.pValue]
        cinvoke sqliteValueText, [eax]
        test    eax, eax
        jz      .null

        stdcall TextAddString, edi, 0, eax
        stdcall ConvertPhpBBText, edx
        stdcall TextCompact, edx
        push    edx

        cinvoke sqliteResultText, [.context], edx, [edx+TText.GapBegin], SQLITE_TRANSIENT
        stdcall TextFree ; from the stack
        cret

.null:
        cinvoke sqliteResultNULL, [.context]
        cret
endp



proc ConvertPhpBB, .pText
begin

        return
endp