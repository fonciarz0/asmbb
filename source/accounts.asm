

proc ShowLoginPage, .pSpecial
begin
        mov     eax, [.pSpecial]
        stdcall StrCat, [eax+TSpecialParams.page_title], "Login dialog"

        stdcall StrNew
        stdcall StrCatTemplate, eax, "login_form", 0, [.pSpecial]
        return
endp





sqlGetUserInfo   text "select id, salt, passHash, status from Users where lower(nick) = lower(?)"
sqlInsertSession text "insert into sessions (userID, sid, last_seen) values ( ?, ?, strftime('%s','now') )"
sqlCheckSession  text "select sid from sessions where userID = ?"


proc UserLogin, .pSpecial
.stmt  dd ?

.user     dd ?
.password dd ?

.userID   dd ?
.session  dd ?
.status   dd ?

begin
        pushad

        xor     eax, eax
        mov     [.session], eax
        mov     [.user], eax
        mov     [.password], eax

        stdcall StrNew
        mov     edi, eax

; check the information

        mov     esi, [.pSpecial]
        mov     ebx, [esi+TSpecialParams.post]

        stdcall GetQueryItem, ebx, "username=", 0
        mov     [.user], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .redirect_back_short

        stdcall GetQueryItem, ebx, "password=", 0
        mov     [.password], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .redirect_back_short

; hash the password

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlGetUserInfo, -1, eax, 0

        stdcall StrPtr, [.user]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        je      .user_ok


.bad_user:
        cinvoke sqliteFinalize, [.stmt]
        jmp     .redirect_back_bad_password


.user_ok:

        cinvoke sqliteColumnText, [.stmt], 1    ; the salt
        stdcall StrDupMem, eax
        push    eax

        stdcall StrCat, eax, [.password]
        stdcall StrMD5, eax
        stdcall StrDel ; from the stack
        stdcall StrDel, [.password]

        mov     [.password], eax

        cinvoke sqliteColumnText, [.stmt], 2    ; the password hash.

        stdcall StrCompCase, [.password], eax
        jnc     .bad_user


; here the password matches this from the database.

        cinvoke sqliteColumnInt, [.stmt], 0
        mov     [.userID], eax

        cinvoke sqliteColumnInt, [.stmt], 3
        mov     [.status], eax

        cinvoke sqliteFinalize, [.stmt]

; check the status of the user

        test    [.status], permLogin
        jz      .redirect_back_bad_permissions


; Check for existing session

        lea     eax, [.stmt]
        cinvoke sqlitePrepare, [hMainDatabase], sqlCheckSession, -1, eax, 0

        cinvoke sqliteBindInt, [.stmt], 1, [.userID]

        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .new_session

        cinvoke sqliteColumnText, [.stmt], 0
        stdcall StrDupMem, eax
        mov     [.session], eax

        jmp     .set_the_cookie


.new_session:

        cinvoke sqliteFinalize, [.stmt]

        stdcall GetRandomString, 32
        mov     [.session], eax


; Insert new session record.

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlInsertSession, -1, eax, 0

        cinvoke sqliteBindInt, [.stmt], 1, [.userID]

        stdcall StrPtr, [.session]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]

; check for error here!


; now, set some cookies

.set_the_cookie:

        cinvoke sqliteFinalize, [.stmt]

        stdcall StrCat, edi, "Set-Cookie: sid="
        stdcall StrCat, edi, [.session]
        stdcall StrCat, edi, <"; HttpOnly; Path=/", 13, 10>

        stdcall GetQueryItem, ebx, "backlink=", 0
        test    eax, eax
        jnz     .go_back

        stdcall StrMakeRedirect2, edi, "/list", [esi+TSpecialParams.query]
        jmp     .finish

.go_back:
        stdcall StrMakeRedirect2, edi, eax, 0  ; go back from where came.
        stdcall StrDel, eax
        jmp     .finish

.redirect_back_short:

        stdcall StrMakeRedirect2, edi, "/message/login_missing_data/", [esi+TSpecialParams.query]  ; go backward.
        jmp     .finish

.redirect_back_bad_permissions:

        stdcall StrMakeRedirect2, edi, "/message/login_bad_permissions/", [esi+TSpecialParams.query] ; go backward.
        jmp     .finish


.redirect_back_bad_password:

        stdcall StrMakeRedirect2, edi, "/message/login_bad_password/", [esi+TSpecialParams.query]

.finish:
        stdcall StrDel, [.user]
        stdcall StrDel, [.password]
        stdcall StrDel, [.session]

        mov     [esp+4*regEAX], edi
        popad
        return

endp




sqlLogout text "delete from Sessions where userID = ?"

proc UserLogout, .pspecial
.stmt dd ?
begin
        pushad

        stdcall StrNew
        mov     edi, eax

        mov     esi, [.pspecial]

        cmp     [esi+TSpecialParams.session], 0
        je      .finish

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlLogout, -1, eax, 0
        cinvoke sqliteBindInt, [.stmt], 1, [esi+TSpecialParams.userID]
        cinvoke sqliteStep, [.stmt]
        cinvoke sqliteFinalize, [.stmt]

; delete the cookie.

        stdcall StrCat, edi, <"Set-Cookie: sid=; HttpOnly; Path=/; Max-Age=0", 13, 10>

.finish:
        stdcall StrNew
        stdcall StrCatTemplate, eax, "logout", 0, [.pspecial]

        stdcall StrMakeRedirect2, edi, eax, 0
        stdcall StrDel, eax

        mov     [esp+4*regEAX], edi
        popad
        return
endp






proc ShowRegisterPage
begin
        stdcall StrNew
        stdcall StrCatTemplate, eax, "register_form", 0, 0
        return
endp



;sqlCheckMinInterval text "select (strftime('%s','now') - time_reg) as delta from WaitingActivation where (ip_from = ?) and ( delta>30 ) order by time_reg desc limit 1"
sqlRegisterUser    text "insert into WaitingActivation (nick, passHash, salt, email, ip_from, time_reg, time_email, a_secret) values (?, ?, ?, ?, ?, strftime('%s','now'), NULL, ?)"
sqlCheckUserExists text "select 1 from Users where lower(nick) = lower(?) or email = ? limit 1"

proc RegisterNewUser, .pSpecial

.stmt      dd ?

.user      dd ?
.password  dd ?
.password2 dd ?
.email     dd ?
.secret    dd ?
.ip_from   dd ?

.email_text dd ?

begin
        pushad

        xor     eax, eax
        mov     [.user], eax
        mov     [.password], eax
        mov     [.password2], eax
        mov     [.email], eax
        mov     [.secret], eax
        mov     [.ip_from], eax

; check the information

        mov     esi, [.pSpecial]
        mov     ebx, [esi+TSpecialParams.post]

        stdcall GetQueryItem, ebx, "username=", 0
        mov     [.user], eax

        stdcall StrLen, eax
        cmp     eax, 3
        jbe     .error_short_name

        cmp     eax, 256
        ja      .error_trick

        stdcall GetQueryItem, ebx, "email=", 0
        mov     [.email], eax

        stdcall CheckEmail, eax
        jc      .error_bad_email

        stdcall GetQueryItem, ebx, "password=", 0
        mov     [.password], eax

        stdcall GetQueryItem, ebx, "password2=", 0
        mov     [.password2], eax

        stdcall StrCompCase, [.password], [.password2]
        jnc     .error_different

        stdcall StrLen, [.password]

        cmp     eax, 5
        jbe     .error_short_pass

        cmp     eax, 1024
        ja      .error_trick

        mov     eax, [.pSpecial]
        stdcall ValueByName, [eax+TSpecialParams.params], "REMOTE_ADDR"
        stdcall StrIP2Num, eax
        jc      .error_technical_problem

        mov     [.ip_from], eax

; hash the password

        stdcall HashPassword, [.password]
        jc      .error_technical_problem

        stdcall StrDel, [.password]
        stdcall StrDel, [.password2]
        mov     [.password], eax
        mov     [.password2], edx       ; the salt!

        stdcall GetRandomString, 32
        jc      .error_technical_problem

        mov     [.secret], eax

; check whether the user exists

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlCheckUserExists, -1, eax, 0

        stdcall StrPtr, [.user]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.email]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]
        mov     ebx, eax

        cinvoke sqliteFinalize, [.stmt]

        cmp     ebx, SQLITE_ROW
        je      .error_exists

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlRegisterUser, -1, eax, 0

        stdcall StrPtr, [.user]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.password]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.password2]
        cinvoke sqliteBindText, [.stmt], 3, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.email]
        cinvoke sqliteBindText, [.stmt], 4, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteBindInt, [.stmt], 5, [.ip_from]

        stdcall StrPtr, [.secret]
        cinvoke sqliteBindText, [.stmt], 6, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]
        mov     ebx, eax

        cinvoke sqliteFinalize, [.stmt]

        cmp     ebx, SQLITE_DONE
        jne     .error_exists

; now send the activation email for all registered user, where the email was not sent.

        stdcall ProcessActivationEmails
        jc      .error_technical_problem

; the user has been created and now is waiting for email activation.

        stdcall StrMakeRedirect2, 0, "/message/user_created/", [esi+TSpecialParams.query]                    ; go forward.
        jmp     .finish


.error_technical_problem:

        stdcall StrMakeRedirect2, 0, "/message/register_technical/", [esi+TSpecialParams.query]              ; go backward.
        jmp     .finish


.error_short_name:

        stdcall StrMakeRedirect2, 0, "/message/register_short_name/", [esi+TSpecialParams.query]             ; go backward.
        jmp     .finish

.error_trick:

        stdcall StrMakeRedirect2, 0, "/message/register_bot/", [esi+TSpecialParams.query]

        jmp     .finish


.error_bad_email:
        stdcall StrMakeRedirect2, 0, "/message/register_bad_email/", [esi+TSpecialParams.query]              ; go backward.
        jmp     .finish


.error_short_pass:
        stdcall StrMakeRedirect2, 0, "/message/register_short_pass/", [esi+TSpecialParams.query]             ; go backward.
        jmp     .finish


.error_different:

        stdcall StrMakeRedirect2, 0, "/message/register_passwords_different/", [esi+TSpecialParams.query]    ; go backward.
        jmp     .finish


.error_exists:

        stdcall StrMakeRedirect2, 0, "/message/register_user_exists/", [esi+TSpecialParams.query]            ; go backward.

.finish:
        stdcall StrDel, [.user]
        stdcall StrDel, [.password]
        stdcall StrDel, [.password2]
        stdcall StrDel, [.email]
        stdcall StrDel, [.secret]

        mov     [esp+4*regEAX], eax
        popad
        return
endp






sqlBegin      text  "begin transaction;"
sqlActivate   text  "insert into Users ( nick, passHash, salt, status, email ) select nick, passHash, salt, ?, email from WaitingActivation where a_secret = ?"
sqlDeleteWait text  "delete from WaitingActivation where a_secret = ?"
sqlCheckCount text  "select count(1), salt from WaitingActivation where a_secret = ?"
sqlCommit     text  "commit transaction"
sqlRollback   text  "rollback"

sqlUpdateUserEmail text "update users set email = (select email from WaitingActivation where a_secret = ?1) where nick = (select nick from WaitingActivation where a_secret = ?1)"

proc ActivateAccount, .hSecret
.stmt dd ?
.type dd ?
begin
        pushad

; begin transaction

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlBegin, sqlBegin.length, eax, 0
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .rollback

        cinvoke sqliteFinalize, [.stmt]

; check again whether all is successful.

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlCheckCount, sqlCheckCount.length, eax, 0

        stdcall StrPtr, [.hSecret]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .rollback

        cinvoke sqliteColumnInt, [.stmt], 0
        cmp     eax, 1
        jne     .rollback

        cinvoke sqliteColumnType, [.stmt], 1    ; the salt if exists
        mov     [.type], eax

        cinvoke sqliteFinalize, [.stmt]

        cmp     [.type], SQLITE_NULL
        jne     .insert_new_user

; update user email

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlUpdateUserEmail, sqlUpdateUserEmail.length, eax, 0

        stdcall StrPtr, [.hSecret]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .rollback

        jmp     .finalize_delete_from_waiting


; insert new user

.insert_new_user:

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlActivate, sqlActivate.length, eax, 0

        stdcall GetParam, "user_perm", gpInteger
        jc      .rollback

        cinvoke sqliteBindInt, [.stmt], 1, eax

        stdcall StrPtr, [.hSecret]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]

        cmp     eax, SQLITE_DONE
        jne     .rollback


.finalize_delete_from_waiting:

        cinvoke sqliteFinalize, [.stmt]

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlDeleteWait, sqlDeleteWait.length, eax, 0

        stdcall StrPtr, [.hSecret]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .rollback

        cinvoke sqliteFinalize, [.stmt]

; commit transaction

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlCommit, sqlCommit.length, eax, 0
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .rollback

        cinvoke sqliteFinalize, [.stmt]

        cmp     [.type], SQLITE_NULL
        jne     .msg_new_account

        stdcall StrMakeRedirect2, 0, "/message/email_changed", 0
        jmp     .finish


.msg_new_account:
        stdcall StrMakeRedirect2, 0, "/message/congratulations", 0


.finish:
        mov     [esp+4*regEAX], eax
        popad
        return


.rollback:

        cinvoke sqliteFinalize, [.stmt]         ; finalize the bad statement.

; rollback transaction

        cinvoke sqliteExec, [hMainDatabase], sqlRollback, 0, 0, 0

        stdcall StrMakeRedirect2, 0, "/message/bad_secret", 0
        jmp     .finish

endp



sqlGetUserPass   text "select nick, salt, passHash from Users where id = ?"
sqlUpdateUserPass text "update users set passHash = ?, salt = ? where id = ?"


proc ChangePassword, .pSpecial

.stmt     dd ?

.oldpass  dd ?
.newpass  dd ?
.newpass2 dd ?
begin
        pushad

        xor     eax, eax
        mov     [.oldpass], eax
        mov     [.newpass], eax
        mov     [.newpass2], eax

        mov     esi, [.pSpecial]
        mov     ebx, [esi+TSpecialParams.post]

        stdcall GetQueryItem, ebx, "oldpass=", 0
        test    eax, eax
        jz      .bad_parameter

        mov     [.oldpass], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .bad_parameter


        stdcall GetQueryItem, ebx, "newpass=", 0
        test    eax, eax
        jz      .bad_parameter

        mov     [.newpass], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .bad_parameter

        cmp     eax, 5
        jbe     .error_short_pass

        stdcall GetQueryItem, ebx, "newpass2=", 0
        test    eax, eax
        jz      .bad_parameter

        mov     [.newpass2], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .bad_parameter

        stdcall StrCompCase, [.newpass], [.newpass2]
        jnc     .error_different


        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlGetUserPass, sqlGetUserPass.length, eax, 0
        cinvoke sqliteBindInt, [.stmt], 1, [esi+TSpecialParams.userID]
        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .bad_user

        cinvoke sqliteColumnText, [.stmt], 1    ; salt
        stdcall StrDupMem, eax
        push    eax

        stdcall StrCat, eax, [.oldpass]
        stdcall StrMD5, eax
        stdcall StrDel ; from the stack
        stdcall StrDel, [.oldpass]
        mov     [.oldpass], eax

        cinvoke sqliteColumnText, [.stmt], 2    ; the password hash.
        stdcall StrCompCase, [.oldpass], eax
        jnc     .bad_password

        cinvoke sqliteFinalize, [.stmt]


        stdcall HashPassword, [.newpass]
        stdcall StrDel, [.newpass]
        stdcall StrDel, [.newpass2]

        mov     [.newpass], eax         ; hash
        mov     [.newpass2], edx        ; salt

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlUpdateUserPass, sqlUpdateUserPass.length, eax, 0

        cinvoke sqliteBindInt, [.stmt], 3, [esi+TSpecialParams.userID]

        stdcall StrPtr, [.newpass]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC

        stdcall StrPtr, [.newpass2]
        cinvoke sqliteBindText, [.stmt], 2, eax, [eax+string.len], SQLITE_STATIC

        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .error_update

        cinvoke sqliteFinalize, [.stmt]

        stdcall UserLogout, [.pSpecial]
        stdcall StrDel, eax

        stdcall StrMakeRedirect2, 0, "/message/password_changed", [esi+TSpecialParams.query]

.finish:

        stdcall StrDel, [.oldpass]
        stdcall StrDel, [.newpass]
        stdcall StrDel, [.newpass2]

        mov     [esp+4*regEAX], eax
        popad
        return


.bad_user:

        cinvoke sqliteFinalize, [.stmt]
        stdcall StrMakeRedirect2, 0, "/message/register_bot", [esi+TSpecialParams.query]
        jmp     .finish


.bad_password:

        cinvoke sqliteFinalize, [.stmt]
        stdcall StrMakeRedirect2, 0, "/message/change_password", [esi+TSpecialParams.query]
        jmp     .finish


.bad_parameter:

        stdcall StrMakeRedirect2, 0, "/message/login_missing_data", [esi+TSpecialParams.query]
        jmp     .finish


.error_different:

        stdcall StrMakeRedirect2, 0, "/message/change_different", [esi+TSpecialParams.query]
        jmp     .finish


.error_update:

        stdcall StrMakeRedirect2, 0, "/message/error_cant_write", [esi+TSpecialParams.query]
        jmp     .finish


.error_short_pass:
        stdcall StrMakeRedirect2, 0, "/message/register_short_pass/", [esi+TSpecialParams.query]
        jmp     .finish

endp





proc ChangeEmail, .pSpecial

.stmt     dd ?

.nick     dd ?
.password dd ?
.email    dd ?
.secret   dd ?

begin
        pushad

        xor     eax, eax
        mov     [.nick], eax
        mov     [.password], eax
        mov     [.email], eax
        mov     [.secret], eax

        mov     esi, [.pSpecial]
        mov     ebx, [esi+TSpecialParams.post]

        stdcall GetQueryItem, ebx, "password=", 0
        test    eax, eax
        jz      .bad_parameter

        mov     [.password], eax

        stdcall StrLen, eax
        test    eax, eax
        jz      .bad_parameter


        stdcall GetQueryItem, ebx, "email=", 0
        test    eax, eax
        jz      .bad_parameter

        mov     [.email], eax

        stdcall CheckEmail, eax
        jc      .bad_email

        stdcall GetRandomString, 32
        jc      .error_technical_problem

        mov     [.secret], eax

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlGetUserPass, sqlGetUserPass.length, eax, 0

        cinvoke sqliteBindInt, [.stmt], 1, [esi+TSpecialParams.userID]

        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_ROW
        jne     .bad_user

        cinvoke sqliteColumnText, [.stmt], 1    ; salt
        stdcall StrDupMem, eax
        push    eax

        stdcall StrCat, eax, [.password]
        stdcall StrMD5, eax
        stdcall StrDel ; from the stack
        stdcall StrDel, [.password]
        mov     [.password], eax

        cinvoke sqliteColumnText, [.stmt], 2    ; the password hash.
        stdcall StrCompCase, [.password], eax
        jnc     .bad_password

        cinvoke sqliteColumnText, [.stmt], 0    ; the user nick
        stdcall StrDupMem, eax
        mov     [.nick], eax

        cinvoke sqliteFinalize, [.stmt]

        lea     eax, [.stmt]
        cinvoke sqlitePrepare_v2, [hMainDatabase], sqlRegisterUser, sqlRegisterUser.length, eax, 0

        stdcall StrPtr, [.nick]
        cinvoke sqliteBindText, [.stmt], 1, eax, [eax+string.len], SQLITE_STATIC        ; user nickname

        stdcall StrPtr, [.email]
        cinvoke sqliteBindText, [.stmt], 4, eax, [eax+string.len], SQLITE_STATIC        ; new email

        stdcall StrPtr, [.secret]
        cinvoke sqliteBindText, [.stmt], 6, eax, [eax+string.len], SQLITE_STATIC        ; the secret

        cinvoke sqliteStep, [.stmt]
        cmp     eax, SQLITE_DONE
        jne     .error_update

        cinvoke sqliteFinalize, [.stmt]

        stdcall ProcessActivationEmails
        jc      .error_technical_problem

        stdcall StrMakeRedirect2, 0, "/message/email_activation_sent", [esi+TSpecialParams.query]

.finish:

        stdcall StrDel, [.nick]
        stdcall StrDel, [.password]
        stdcall StrDel, [.email]
        stdcall StrDel, [.secret]

        mov     [esp+4*regEAX], eax
        popad
        return


.bad_user:

        cinvoke sqliteFinalize, [.stmt]
        stdcall StrMakeRedirect2, 0, "/message/register_bot", [esi+TSpecialParams.query]
        jmp     .finish


.bad_password:

        cinvoke sqliteFinalize, [.stmt]
        stdcall StrMakeRedirect2, 0, "/message/change_password", [esi+TSpecialParams.query]
        jmp     .finish


.bad_parameter:

        stdcall StrMakeRedirect2, 0, "/message/login_missing_data", [esi+TSpecialParams.query]
        jmp     .finish


.error_update:

        stdcall StrMakeRedirect2, 0, "/message/error_cant_write", [esi+TSpecialParams.query]
        jmp     .finish


.bad_email:
        stdcall StrMakeRedirect2, 0, "/message/register_bad_email", [esi+TSpecialParams.query]
        jmp     .finish


.error_technical_problem:

        stdcall StrMakeRedirect2, 0, "/message/register_technical", [esi+TSpecialParams.query]
        jmp     .finish

endp
