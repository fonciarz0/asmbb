
iglobal

  if used cVersion
    cVersion  db   '<b>AsmBB v3.0</b> (check-in: <a href="http://asm32.info/fossil/asmbb/info/'
              file "../manifest.uuid":0,16
              db   '">'
              file "../manifest.uuid":0,16
              db   "</a>)"
              dd 0
  end if

endg