select
-- Thread fields

  ?3 as threadID,
  ?4 as Caption,
  ?5 as Tags,
  ?6 as Invited,
  ?7 as Pinned,

-- Post fields

  P.id,
  ?8 as Source,
  ?9 as Format,

-- User fields

  U.nick as UserName,

-- Common flags and data

  ?1 = (select id from Posts where threadid = P.threadid order by rowid limit 1) as EditThread,
  ?2 as Ticket

from
  Posts P

left join
  Users U on U.id = P.userID

where
  P.id = ?1
