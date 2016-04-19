MAX_AVATAR_SIZE = 50*1024
MAX_USER_DESC   = 10*1024



sqlGetFullUserInfo text "select ",                                                                      \
                          "id as userid, ",                                                             \
                          "nick as username, ",                                                         \
                          "av_time as AVer, ",                                                          \
                          "status, ",                                                                   \
                          "user_desc, ",                                                                \
                          "strftime('%d.%m.%Y %H:%M:%S', LastSeen, 'unixepoch') as LastSeen, ",         \
                          "(select count(1) from posts p where p.userid = u.id ) as totalposts, ",      \
                          "(select status & 1 <> 0) as canlogin, ",                                     \
                          "(select status & 4 <> 0) as canpost, ",                                      \
                          "(select status & 8 <> 0) as canstart, ",                                     \
                          "(select status & 16 <> 0) as caneditown, ",                                  \
                          "(select status & 32 <> 0) as caneditall, ",                                  \
                          "(select status & 64 <> 0) as candelown, ",                                   \
                          "(select status & 128 <> 0) as candelall, ",                                  \
                          "(select status & 0x80000000 <> 0) as isadmin ",                              \
                        "from users u ",                                                                \
                        "where nick = ?"

sqlUpdateUserDesc   text "update users set user_desc = ? where nick = ?"


proc ShowUserInfo, .UserName, .pSpecial
.stmt dd ?
begin
        pushad

        xor     edi, edi
        cmp     [.UserName], edi
        je      .exit

        stdcall StrNew
        mov     edi, eax
        mov     esi, [.pSpecial]

        cmp     [esi+TSpecialParams.post_array], 0
        jne     .save_user_info

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlGetFullUserInfo, sqlGetFullUserInfo.length, eax, 0

        stdcall StrPtr, [.UserName]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .missing_user


        stdcall StrCat, [esi+TSpecialParams.page_title], "Profile for: "
        cinvoke sqliteColumnText, [.stmt], 1
        stdcall StrCat, [esi+TSpecialParams.page_title], eax


        stdcall StrCat, edi, '<div class="user_profile">'

        stdcall StrCatTemplate, edi, "userinfo", [.stmt], esi

        test    [esi+TSpecialParams.userStatus], permAdmin
        jnz     .put_edit_form

        cinvoke sqliteColumnInt, [.stmt], 0
        cmp     eax, [esi+TSpecialParams.userID]
        jne     .edit_form_ok

.put_edit_form:

        stdcall StrCatTemplate, edi, "form_editinfo", [.stmt], esi

.edit_form_ok:

        stdcall StrCat, edi, '</div>'
        clc

.finish:

        pushf
        cinvoke sqliteFinalize, [.stmt]
        popf

.exit:
        mov     [esp+4*regEAX], edi
        popad
        return


.missing_user:
        stdcall AppendError, edi, "404 Not Found", [.pSpecial]
        stc
        jmp     .finish


.save_user_info:

locals
  .user_desc    dd ?
endl

        and     [.user_desc], 0

        test    [esi+TSpecialParams.userStatus], permAdmin
        jnz     .permissions_ok

        stdcall StrCompCase, [.UserName], [esi+TSpecialParams.userName]
        jnc     .permissions_fail

.permissions_ok:

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlUpdateUserDesc, sqlUpdateUserDesc.length, eax, 0

        stdcall GetPostString, [esi+TSpecialParams.post_array], txt "user_desc", 0
        mov     [.user_desc], eax
        test    eax, eax
        jz      .update_end

        stdcall StrByteUtf8, [.user_desc], MAX_USER_DESC
        stdcall StrTrim, [.user_desc], eax

        stdcall StrPtr, [.user_desc]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.UserName]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]

.update_end:

        stdcall StrDupMem, "/!userinfo/"
        stdcall StrCat, eax, [.UserName]
        push    eax

        stdcall StrMakeRedirect, edi, eax
        stdcall StrDel ; from the stack

        stdcall StrDel, [.user_desc]

        stc
        jmp     .finish

.permissions_fail:

        stdcall AppendError, edi, "403 Forbidden", [.pSpecial]
        stc
        jmp     .finish

endp






sqlGetUserAvatar    text "select avatar, av_time from Users where nick = ? and avatar is not null"

proc UserAvatar, .UserName, .pSpecial
.stmt      dd ?

.date      TDateTime

.timeRetLo dd ?
.timeRetHi dd ?

begin
        pushad

        xor     edi, edi
        mov     [.stmt], edi

        cmp     [.UserName], edi
        je      .exit

        stdcall StrNew
        mov     edi, eax
        mov     esi, [.pSpecial]

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlGetUserAvatar, sqlGetUserAvatar.length, eax, 0

        stdcall StrPtr, [.UserName]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .default_avatar

        cinvoke sqliteColumnInt64, [.stmt], 1
        mov     [.timeRetLo], eax
        mov     [.timeRetHi], edx

        stdcall ValueByName, [esi+TSpecialParams.params], "HTTP_IF_MODIFIED_SINCE"
        jc      .get_avatar

        lea     edx, [.date]
        stdcall DecodeHTTPDate, eax, edx
        jc      .get_avatar

        stdcall DateTimeToTime, edx

        cmp     edx, [.timeRetHi]
        jb      .get_avatar
        ja      .not_changed

        cmp     eax, [.timeRetLo]
        jb      .get_avatar

.not_changed:

        stdcall StrCat, edi, <"Status: 304 Not Modified", 13, 10, 13, 10>
        jmp     .finish

.default_avatar:
        stdcall StrMakeRedirect, edi, "/images/anon.png"
        jmp     .finish

.get_avatar:

        stdcall StrCat, edi, <"Status: 200 OK", 13, 10, "Cache-control: max-age=1000000">

        stdcall FormatHTTPTime, [.timeRetLo], [.timeRetHi]
        stdcall StrCat, edi, <13, 10, "Last-modified: ">
        stdcall StrCat, edi, eax
        stdcall StrDel, eax

        cinvoke sqliteColumnBytes, [.stmt], 0
        mov     ebx, eax

        stdcall StrCat, edi, <13, 10, "Content-type: image/png", 13, 10, "Content-length: ">
        stdcall NumToStr, ebx, ntsDec or ntsUnsigned
        stdcall StrCat, edi, eax
        stdcall StrCat, edi, <txt 13, 10, 13, 10>
        stdcall StrDel, eax

        cinvoke sqliteColumnBlob, [.stmt], 0
        stdcall StrCatMem, edi, eax, ebx

.finish:
        cinvoke sqliteFinalize, [.stmt]
        stc

.exit:
        mov     [esp+4*regEAX], edi
        popad
        return
endp





sqlUpdateUserAvatar text "update Users set avatar = ?, av_time = strftime('%s','now') where nick = ?"


proc UpdateUserAvatar, .UserName, .pSpecial
.stmt      dd ?
.img_ptr   dd ?    ; pointer to TByteStream

begin
        pushad

;        DebugMsg "Avatar upload!"

        xor     edi, edi
        mov     [.stmt], edi
        mov     [.img_ptr], edi
        mov     esi, [.pSpecial]

;        OutputValue "User name:", [.UserName], 16, 8
;        OutputValue "Post data:", [esi+TSpecialParams.post_array], 16, 8

        cmp     [.UserName], edi
        je      .exit

        cmp     [esi+TSpecialParams.post_array], edi
        je      .exit

;        DebugMsg "Post data OK!"

        stdcall StrNew
        mov     edi, eax

        test    [esi+TSpecialParams.userStatus], permAdmin
        jnz     .permissions_ok

        stdcall StrCompCase, [.UserName], [esi+TSpecialParams.userName]
        jnc     .permissions_fail

.permissions_ok:

;        DebugMsg "Permissions OK!"

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlUpdateUserAvatar, sqlUpdateUserAvatar.length, eax, 0

        stdcall ValueByName, [esi+TSpecialParams.post_array], txt "avatar"
        jc      .update_end

        test    eax, eax
        jz      .update_end

        cmp     eax, $c0000000
        jae     .update_end              ; because of some reason, the avatar is posted as a string.

        cmp     [eax+TArray.count], 1
        jne     .update_end              ; multiple images has been posted.

        lea     ebx, [eax+TArray.array]

        stdcall StrCompCase, [ebx+TPostFileItem.mime], "image/png"
        jnc     .update_end

;        DebugMsg "Now sanitize the PNG."

        stdcall SanitizeImagePng, [ebx+TPostFileItem.data], [ebx+TPostFileItem.size], 128, 128
        jc      .update_end

        mov     [.img_ptr], eax

        lea     ecx, [eax+TByteStream.data]
        cinvoke sqliteBindBlob, [.stmt], 1, ecx, [eax+TByteStream.size], SQLITE_STATIC

        stdcall StrPtr, [.UserName]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]


.update_end:
        stdcall StrDupMem, "/!userinfo/"
        stdcall StrCat, eax, [.UserName]
        push    eax

        stdcall StrMakeRedirect, edi, eax
        stdcall StrDel ; from the stack

        stdcall FreeMem, [.img_ptr]
        jmp     .finish


.permissions_fail:

        stdcall AppendError, edi, "403 Forbidden", [.pSpecial]

        jmp     .finish


.finish:
        cinvoke sqliteFinalize, [.stmt]
        stc

.exit:
        mov     [esp+4*regEAX], edi
        popad
        return


;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


endp
