'=====================================================================
' TUNNELS OF DOOM - Adventure Editor for PicoMite / PicoCalc
' Loads an .ADV module, edits it section by section, and saves it
' back or under a new name. The file is kept as text lines, so
' comments, blank lines and line order all survive editing.
'=====================================================================
CLEAR                     ' drop any variables left by a previous run
OPTION EXPLICIT
OPTION DEFAULT INTEGER

CONST MAXL=220, LLEN=200, NSEC=8, LROWS=19
CONST WHT=&HFFFFFF, YEL=&HFFFF00, CYN=&H00FFFF, GRY=&H909090
CONST RED=&HFF4040, GRN=&H40FF40, BLU=&H203090, BLK=0
CONST KUP=128, KDN=129, KLF=130, KRT=131, KHOM=134, KEND=135
CONST KPGU=136, KPGD=137, KENT=13, KESC=27, KBS=8, KDEL=127

DIM ln$(MAXL) LENGTH LLEN
DIM ix(MAXL)
DIM nl, nix, dirty, edcan, trunc, nv
DIM fname$ LENGTH 40
DIM sec$(NSEC) LENGTH 60
DIM secn$(NSEC) LENGTH 20
DIM vm$(60) LENGTH 40
DIM fl$(40) LENGTH 40

FONT 1
EdInitSec
EdStart
CLS
END

'===================== screen helpers ================================
' 40 columns x 26 rows of 8x12 text. All drawing goes through here.
SUB EdCls
  CLS BLK
END SUB
SUB EdRow r,s$,c,b
  BOX 0,r*12,320,12,1,b,b
  IF s$<>"" THEN TEXT 0,r*12,LEFT$(s$,40),"LT",1,1,c,b
END SUB
SUB EdCur col,r,ch$
  TEXT col*8,r*12,ch$,"LT",1,1,BLK,WHT
END SUB
SUB EdBar s$
  EdRow 0,s$,BLK,YEL
END SUB
SUB EdStat s$,c
  EdRow 22,s$,c,BLK
END SUB
SUB EdHelp a$,b$
  EdRow 24,a$,CYN,BLK
  EdRow 25,b$,CYN,BLK
END SUB
SUB EdWrap s$,r
  LOCAL i
  FOR i=0 TO 4
    IF i*40<LEN(s$) THEN EdRow r+i,MID$(s$,i*40+1,40),WHT,BLK
  NEXT
END SUB
FUNCTION EdKey()
  LOCAL k$
  DO: k$=INKEY$: LOOP UNTIL k$<>""
  EdKey=ASC(k$)
END FUNCTION
FUNCTION EdKeyU()
  LOCAL k
  k=EdKey()
  IF k>=97 AND k<=122 THEN k=k-32
  EdKeyU=k
END FUNCTION
FUNCTION EdYes(q$)
  EdStat q$+" (Y/N)",YEL
  EdYes=(EdKeyU()=89)
END FUNCTION

'===================== text helpers ==================================
FUNCTION EdNS$(n)
  EdNS$=EdTrim$(STR$(n))
END FUNCTION
FUNCTION EdTrim$(s$)
  LOCAL a, b
  a=1: b=LEN(s$)
  DO WHILE a<=b
    IF MID$(s$,a,1)<>" " THEN EXIT DO
    a=a+1
  LOOP
  DO WHILE b>=a
    IF MID$(s$,b,1)<>" " THEN EXIT DO
    b=b-1
  LOOP
  EdTrim$=MID$(s$,a,b-a+1)
END FUNCTION
' keyword of a line ("" for blank lines and # comments)
FUNCTION EdKw$(s$)
  LOCAL t$
  t$=EdTrim$(s$)
  IF t$="" OR LEFT$(t$,1)="#" THEN EdKw$="": EXIT FUNCTION
  EdKw$=UCASE$(EdTrim$(FIELD$(t$,1,",")))
END FUNCTION
FUNCTION EdNFld(s$)
  LOCAL i, n
  n=1
  FOR i=1 TO LEN(s$)
    IF MID$(s$,i,1)="," THEN n=n+1
  NEXT
  EdNFld=n
END FUNCTION
FUNCTION EdFld$(s$,n)
  EdFld$=FIELD$(s$,n,",")
END FUNCTION
FUNCTION EdSetFld$(s$,n,v$)
  LOCAL i, m, r$
  m=MAX(EdNFld(s$),n)
  FOR i=1 TO m
    IF i>1 THEN r$=r$+","
    IF i=n THEN r$=r$+v$ ELSE r$=r$+EdFld$(s$,i)
  NEXT
  EdSetFld$=r$
END FUNCTION
FUNCTION EdIsNum(v$)
  LOCAL t$, i, st
  t$=UCASE$(EdTrim$(v$))
  IF t$="" THEN EXIT FUNCTION
  IF LEFT$(t$,2)="&H" THEN
    IF LEN(t$)=2 THEN EXIT FUNCTION
    FOR i=3 TO LEN(t$)
      IF INSTR("0123456789ABCDEF",MID$(t$,i,1))=0 THEN EXIT FUNCTION
    NEXT
    EdIsNum=1: EXIT FUNCTION
  ENDIF
  st=1
  IF LEFT$(t$,1)="-" THEN st=2
  IF st>LEN(t$) THEN EXIT FUNCTION
  FOR i=st TO LEN(t$)
    IF INSTR("0123456789",MID$(t$,i,1))=0 THEN EXIT FUNCTION
  NEXT
  EdIsNum=1
END FUNCTION

'===================== module format =================================
SUB EdInitSec
  secn$(1)="Story text":    sec$(1)=" TITLE INTRO WIN FAIL "
  secn$(2)="Settings":      sec$(2)=" FLOORS GRID ROOMS GOLD WANDER NEEDMAP STORE SEED "
  secn$(3)="Items":         sec$(3)=" ITEM "
  secn$(4)="Starting kits": sec$(4)=" KIT "
  secn$(5)="Monsters":      sec$(5)=" MON "
  secn$(6)="Quest objects": sec$(6)=" QUEST "
  secn$(7)="Floor maps":    sec$(7)=" FLOOR MAP "
  secn$(8)="All lines":     sec$(8)=""
END SUB
' Field labels and types (N number, T text) for each keyword.
' A leading * means the whole rest of the line is one text field.
FUNCTION EdSpec$(k$)
  SELECT CASE k$
    CASE "TITLE": EdSpec$="*Title"
    CASE "INTRO": EdSpec$="*Intro text"
    CASE "WIN": EdSpec$="*Victory message"
    CASE "FAIL": EdSpec$="*Failure message"
    CASE "MAP": EdSpec$="*Map row (29 max)"
    CASE "FLOORS": EdSpec$="Floors 1-10:N"
    CASE "GRID": EdSpec$="Width 3-14:N|Height 3-10:N"
    CASE "ROOMS": EdSpec$="Rooms 3-40:N"
    CASE "GOLD": EdSpec$="Gold easy:N|Gold medium:N|Gold hard:N"
    CASE "WANDER": EdSpec$="Wander % a step:N"
    CASE "NEEDMAP": EdSpec$="Need map 0/1:N"
    CASE "STORE": EdSpec$="Store floor A:N|Store floor B:N"
    CASE "SEED": EdSpec$="Seed 0=random:N"
    CASE "FLOOR": EdSpec$="Floor number:N"
    CASE "KIT": EdSpec$="Classes FWRH:T|Item name:T"
    CASE "QUEST": EdSpec$="Name:T|Floor:N|Countdown 0=ofs:N"
    CASE "ITEM"
      EdSpec$="Kind WRXASPHM:T|Name:T|Value 1:N|Value 2:N|Cost 0=not sold:N|Classes FWRH:T|Unknown name:T"
    CASE "MON"
      EdSpec$="Name:T|Glyph:T|Colour &HRRGGBB:N|Hit points:N|Attack:N|Defense:N|Damage:N|Speed:N|XP:N|Min floor:N|Max floor:N|Max group 1-7:N|Ranged 0/1:N|Negotiate %:N|Sound:T"
    CASE ELSE: EdSpec$=""
  END SELECT
END FUNCTION
' fewest fields (including the keyword) TOD.BAS needs on a line
FUNCTION EdMinF(k$)
  SELECT CASE k$
    CASE "ITEM": EdMinF=6
    CASE "MON": EdMinF=15
    CASE "QUEST", "KIT", "GRID", "STORE": EdMinF=3
    CASE "GOLD": EdMinF=4
    CASE ELSE: EdMinF=2
  END SELECT
END FUNCTION
FUNCTION EdTmpl$(k$)
  SELECT CASE k$
    CASE "TITLE": EdTmpl$="TITLE,New Adventure"
    CASE "INTRO": EdTmpl$="INTRO,Describe the quest here."
    CASE "WIN": EdTmpl$="WIN,You have won!"
    CASE "FAIL": EdTmpl$="FAIL,Your quest has failed."
    CASE "FLOORS": EdTmpl$="FLOORS,3"
    CASE "GRID": EdTmpl$="GRID,12,9"
    CASE "ROOMS": EdTmpl$="ROOMS,14"
    CASE "GOLD": EdTmpl$="GOLD,150,120,100"
    CASE "WANDER": EdTmpl$="WANDER,5"
    CASE "NEEDMAP": EdTmpl$="NEEDMAP,1"
    CASE "STORE": EdTmpl$="STORE,2,0"
    CASE "SEED": EdTmpl$="SEED,0"
    CASE "ITEM": EdTmpl$="ITEM,W,New Weapon,5,0,20,FRH,"
    CASE "KIT": EdTmpl$="KIT,FRH,Dagger"
    CASE "MON": EdTmpl$="MON,New Monster,m,&H808080,4,2,1,3,1,5,1,3,3,0,0,growling"
    CASE "QUEST": EdTmpl$="QUEST,New Treasure,1,0"
    CASE "FLOOR": EdTmpl$="FLOOR,1"
    CASE "MAP": EdTmpl$="MAP,U-+-R"
    CASE ELSE: EdTmpl$="# "
  END SELECT
END FUNCTION

'===================== line storage ==================================
FUNCTION EdInSec(i,s)
  LOCAL k$
  IF s=NSEC THEN EdInSec=1: EXIT FUNCTION
  k$=EdKw$(ln$(i))
  IF k$="" THEN EXIT FUNCTION
  EdInSec=(INSTR(sec$(s)," "+k$+" ")>0)
END FUNCTION
SUB EdBuildIx s
  LOCAL i
  nix=0
  FOR i=1 TO nl
    IF EdInSec(i,s) THEN nix=nix+1: ix(nix)=i
  NEXT
END SUB
' insert s$ so it becomes line p; returns 1 if there was room
FUNCTION EdInsLine(p,s$)
  LOCAL i
  IF nl>=MAXL THEN EdStat "File is full ("+EdNS$(MAXL)+" lines)",RED: PAUSE 1500: EXIT FUNCTION
  FOR i=nl TO p STEP -1
    ln$(i+1)=ln$(i)
  NEXT
  ln$(p)=s$: nl=nl+1: dirty=1: EdInsLine=1
END FUNCTION
SUB EdDelLine p
  LOCAL i
  FOR i=p TO nl-1
    ln$(i)=ln$(i+1)
  NEXT
  ln$(nl)="": nl=nl-1: dirty=1
END SUB

'===================== line editor ===================================
' Edits s$ on row 23 with a scrolling window. ESC sets edcan=1.
FUNCTION EdInput$(p$,init$,mx)
  LOCAL s$, k, cp, ofs
  s$=LEFT$(init$,mx): cp=LEN(s$)+1: edcan=0
  EdRow 21,p$,YEL,BLK
  EdRow 22,"",WHT,BLK
  EdHelp "ENTER accept  ESC cancel  arrows move","BS/DEL erase  HOME/END  max "+STR$(mx)
  DO
    IF cp<ofs+1 THEN ofs=cp-1
    IF cp>ofs+39 THEN ofs=cp-39
    EdRow 23,MID$(s$,ofs+1,39),WHT,BLU
    EdCur cp-ofs-1,23,MID$(s$+" ",cp,1)
    k=EdKey()
    SELECT CASE k
      CASE KENT: EdInput$=s$: EXIT FUNCTION
      CASE KESC: edcan=1: EdInput$=init$: EXIT FUNCTION
      CASE KLF: IF cp>1 THEN cp=cp-1
      CASE KRT: IF cp<=LEN(s$) THEN cp=cp+1
      CASE KHOM: cp=1
      CASE KEND: cp=LEN(s$)+1
      CASE KBS
        IF cp>1 THEN s$=LEFT$(s$,cp-2)+MID$(s$,cp): cp=cp-1
      CASE KDEL
        IF cp<=LEN(s$) THEN s$=LEFT$(s$,cp-1)+MID$(s$,cp+1)
      CASE 32 TO 126
        IF LEN(s$)<mx THEN s$=LEFT$(s$,cp-1)+CHR$(k)+MID$(s$,cp): cp=cp+1
    END SELECT
  LOOP
END FUNCTION

'===================== entry editor ==================================
SUB EdEntry i
  LOCAL k$, sp$, nf, n, f, sel, kc, v$, cur$, mx, t$, lab$, typ$, p
  k$=EdKw$(ln$(i)): sp$=EdSpec$(k$)
  IF sp$="" THEN
    EdCls
    EdBar "EDIT LINE "+EdNS$(i): EdWrap ln$(i),2
    v$=EdInput$("Line text",ln$(i),LLEN)
    IF edcan=0 THEN ln$(i)=v$: dirty=1
    EXIT SUB
  ENDIF
  IF LEFT$(sp$,1)="*" THEN
    p=INSTR(ln$(i),",")
    IF p=0 THEN ln$(i)=ln$(i)+",": p=LEN(ln$(i))
    mx=LLEN-p
    IF k$="MAP" THEN mx=29
    IF k$="INTRO" THEN mx=MIN(mx,160)
    EdCls
    EdBar "EDIT "+k$+"  (line "+EdNS$(i)+")": EdWrap MID$(ln$(i),p+1),2
    v$=EdInput$(MID$(sp$,2),MID$(ln$(i),p+1),mx)
    IF edcan=0 THEN ln$(i)=LEFT$(ln$(i),p)+v$: dirty=1
    EXIT SUB
  ENDIF
  nf=1
  FOR f=1 TO LEN(sp$)
    IF MID$(sp$,f,1)="|" THEN nf=nf+1
  NEXT
  n=EdNFld(ln$(i))-1
  IF n>nf THEN nf=n
  sel=1
  DO
    EdCls
    EdBar "EDIT "+k$+"  (line "+EdNS$(i)+")"
    FOR f=1 TO nf
      lab$=FIELD$(FIELD$(sp$,f,"|"),1,":")
      IF lab$="" THEN lab$="Extra field"
      t$=LEFT$(lab$+SPACE$(17),17)+" "+EdFld$(ln$(i),f+1)
      IF f=sel THEN EdRow f+1,t$,BLK,CYN ELSE EdRow f+1,t$,WHT,BLK
    NEXT
    EdRow 18,LEFT$(ln$(i),40),GRY,BLK
    EdRow 19,MID$(ln$(i),41,40),GRY,BLK
    EdHelp "UP/DOWN choose  ENTER edit field","ESC finished"
    kc=EdKeyU()
    SELECT CASE kc
      CASE KUP: IF sel>1 THEN sel=sel-1
      CASE KDN: IF sel<nf THEN sel=sel+1
      CASE KESC: EXIT SUB
      CASE KENT
        t$=FIELD$(sp$,sel,"|"): lab$=FIELD$(t$,1,":"): typ$=FIELD$(t$,2,":")
        IF lab$="" THEN lab$="Extra field"
        cur$=EdFld$(ln$(i),sel+1)
        mx=LLEN-(LEN(ln$(i))-LEN(cur$))
        IF mx>60 THEN mx=60
        v$=EdInput$(lab$,cur$,mx)
        IF edcan=0 THEN
          IF INSTR(v$,",") THEN
            EdStat "Commas are not allowed here",RED: PAUSE 1200
          ELSEIF typ$="N" AND EdIsNum(v$)=0 THEN
            EdStat "Please enter a number",RED: PAUSE 1200
          ELSE
            ln$(i)=EdSetFld$(ln$(i),sel+1,EdTrim$(v$)): dirty=1
          ENDIF
        ENDIF
    END SELECT
  LOOP
END SUB

'===================== section list ==================================
' choose the keyword for a new line; returns "" if cancelled
FUNCTION EdPickKw$(s)
  LOCAL n, i, k
  LOCAL w$(10) LENGTH 10
  IF s=NSEC THEN EdPickKw$="#": EXIT FUNCTION
  n=0
  FOR i=1 TO 10
    w$(i)=FIELD$(EdTrim$(sec$(s)),i," ")
    IF w$(i)<>"" THEN n=i
  NEXT
  IF n=1 THEN EdPickKw$=w$(1): EXIT FUNCTION
  EdCls
  EdBar "INSERT WHICH KIND OF LINE?"
  FOR i=1 TO n
    EdRow i+1,EdNS$(i)+"  "+w$(i),WHT,BLK
  NEXT
  EdHelp "Press a number","ESC cancel"
  DO
    k=EdKey()
    IF k=KESC THEN EdPickKw$="": EXIT FUNCTION
    IF k>=49 AND k<=48+n THEN EdPickKw$=w$(k-48): EXIT FUNCTION
  LOOP
END FUNCTION
FUNCTION EdIns(s,sel)
  LOCAL k$, p
  k$=EdPickKw$(s)
  IF k$="" THEN EXIT FUNCTION
  IF nix>0 THEN p=ix(sel)+1 ELSE p=nl+1
  IF EdInsLine(p,EdTmpl$(k$)) THEN EdIns=p
END FUNCTION
SUB EdList s
  LOCAL sel, top, kc, r, j, p, t$
  sel=1: top=1
  DO
    EdBuildIx s
    IF sel>nix THEN sel=nix
    IF sel<1 THEN sel=1
    IF sel<top THEN top=sel
    IF sel>top+LROWS-1 THEN top=sel-LROWS+1
    EdCls
    EdBar UCASE$(secn$(s))+"  ("+EdNS$(nix)+")  "+fname$
    IF nix=0 THEN EdRow 2,"(none yet - press I to insert)",GRY,BLK
    FOR r=0 TO LROWS-1
      j=top+r
      IF j>nix THEN EXIT FOR
      t$=RIGHT$("   "+EdNS$(ix(j)),3)+" "+ln$(ix(j))
      IF j=sel THEN EdRow r+2,t$,BLK,CYN ELSE EdRow r+2,t$,WHT,BLK
    NEXT
    EdHelp "ENTER edit I insert C copy X delete","U/M move up/down  ESC back"
    kc=EdKeyU()
    SELECT CASE kc
      CASE KUP: sel=sel-1
      CASE KDN: sel=sel+1
      CASE KPGU: sel=sel-LROWS
      CASE KPGD: sel=sel+LROWS
      CASE KHOM: sel=1
      CASE KEND: sel=nix
      CASE KENT
        IF nix>0 THEN EdEntry ix(sel)
      CASE 73
        p=EdIns(s,sel)
        IF p>0 THEN
          EdEntry p
          EdBuildIx s
          FOR j=1 TO nix
            IF ix(j)=p THEN sel=j
          NEXT
        ENDIF
      CASE 67
        IF nix>0 THEN
          p=ix(sel)
          IF EdInsLine(p+1,ln$(p)) THEN sel=sel+1
        ENDIF
      CASE 88
        IF nix>0 THEN
          IF EdYes("Delete line "+EdNS$(ix(sel))+"?") THEN EdDelLine ix(sel)
        ENDIF
      CASE 85
        IF sel>1 THEN
          t$=ln$(ix(sel)): ln$(ix(sel))=ln$(ix(sel-1)): ln$(ix(sel-1))=t$
          sel=sel-1: dirty=1
        ENDIF
      CASE 77
        IF sel<nix THEN
          t$=ln$(ix(sel)): ln$(ix(sel))=ln$(ix(sel+1)): ln$(ix(sel+1))=t$
          sel=sel+1: dirty=1
        ENDIF
      CASE KESC: EXIT SUB
    END SELECT
  LOOP
END SUB

'===================== validation ====================================
SUB EdAddV s$
  IF nv<60 THEN nv=nv+1: vm$(nv)=LEFT$(s$,40)
END SUB
SUB EdCheck
  LOCAL i, j, f, k$, sp$, t$, typ$, fls, cur, g, ok, nit, nmn, nqs, nkt, nin, gw
  LOCAL hu(10), hd(10), hm(10)
  LOCAL seen$ LENGTH 120
  nv=0: fls=3: gw=12
  FOR i=1 TO nl
    k$=EdKw$(ln$(i))
    IF k$="FLOORS" THEN fls=VAL(EdFld$(ln$(i),2))
    IF k$="GRID" THEN gw=VAL(EdFld$(ln$(i),2))
  NEXT
  FOR i=1 TO nl
    k$=EdKw$(ln$(i))
    IF k$<>"" THEN
      sp$=EdSpec$(k$)
      IF sp$="" THEN EdAddV "L"+EdNS$(i)+": unknown keyword "+k$
      IF INSTR(" TITLE WIN FAIL FLOORS GRID ROOMS GOLD WANDER NEEDMAP STORE SEED "," "+k$+" ") THEN
        IF INSTR(seen$," "+k$+" ") THEN
          EdAddV "L"+EdNS$(i)+": 2nd "+k$+" (last one wins)"
        ELSE
          seen$=seen$+" "+k$+" "
        ENDIF
      ENDIF
      IF sp$<>"" AND LEFT$(sp$,1)<>"*" THEN
        IF EdNFld(ln$(i))<EdMinF(k$) THEN EdAddV "L"+EdNS$(i)+": "+k$+" has too few fields"
        f=1
        DO
          t$=FIELD$(sp$,f,"|")
          IF t$="" THEN EXIT DO
          typ$=FIELD$(t$,2,":")
          IF typ$="N" AND f+1<=EdNFld(ln$(i)) THEN
            IF EdIsNum(EdFld$(ln$(i),f+1))=0 THEN EdAddV "L"+EdNS$(i)+": "+LEFT$(FIELD$(t$,1,":"),14)+" not a number"
          ENDIF
          f=f+1
        LOOP
      ENDIF
      SELECT CASE k$
        CASE "INTRO": nin=nin+1
        CASE "FLOORS"
          IF fls<1 OR fls>10 THEN EdAddV "L"+EdNS$(i)+": FLOORS must be 1-10"
        CASE "GRID"
          g=VAL(EdFld$(ln$(i),3))
          IF gw<3 OR gw>14 OR g<3 OR g>10 THEN EdAddV "L"+EdNS$(i)+": GRID must be 3-14 by 3-10"
        CASE "ITEM"
          nit=nit+1
          IF INSTR("WRXASPHM",UCASE$(LEFT$(EdFld$(ln$(i),2)+"?",1)))=0 THEN EdAddV "L"+EdNS$(i)+": item kind must be W R X A S P H M"
          IF UCASE$(EdFld$(ln$(i),2))="R" THEN
            ok=0
            FOR j=1 TO nl
              IF EdKw$(ln$(j))="ITEM" AND UCASE$(EdFld$(ln$(j),2))="X" AND VAL(EdFld$(ln$(j),5))=VAL(EdFld$(ln$(i),5)) THEN ok=1
            NEXT
            IF ok=0 THEN EdAddV "L"+EdNS$(i)+": no ammo (X) in group "+EdFld$(ln$(i),5)
          ENDIF
        CASE "MON"
          nmn=nmn+1
          g=VAL(EdFld$(ln$(i),13))
          IF g<1 OR g>7 THEN EdAddV "L"+EdNS$(i)+": max group must be 1-7"
          IF VAL(EdFld$(ln$(i),11))>VAL(EdFld$(ln$(i),12)) THEN EdAddV "L"+EdNS$(i)+": min floor > max floor"
          IF VAL(EdFld$(ln$(i),11))>fls+1 THEN EdAddV "L"+EdNS$(i)+": monster can never appear"
        CASE "QUEST"
          nqs=nqs+1
          g=VAL(EdFld$(ln$(i),3))
          IF g<1 OR g>fls THEN EdAddV "L"+EdNS$(i)+": quest floor must be 1-"+EdNS$(fls)
        CASE "KIT"
          nkt=nkt+1: ok=0
          FOR j=1 TO nl
            IF EdKw$(ln$(j))="ITEM" AND UCASE$(EdFld$(ln$(j),3))=UCASE$(EdFld$(ln$(i),3)) THEN ok=1
          NEXT
          IF ok=0 THEN EdAddV "L"+EdNS$(i)+": no ITEM named "+EdFld$(ln$(i),3)
        CASE "FLOOR"
          cur=VAL(EdFld$(ln$(i),2))
          IF cur<1 OR cur>fls OR cur>10 THEN EdAddV "L"+EdNS$(i)+": FLOOR must be 1-"+EdNS$(fls): cur=0
        CASE "MAP"
          t$=MID$(ln$(i),INSTR(ln$(i),",")+1)
          IF cur=0 THEN
            EdAddV "L"+EdNS$(i)+": MAP row outside a FLOOR"
          ELSE
            hm(cur)=1
            IF INSTR(UCASE$(t$),"U") THEN hu(cur)=1
            IF INSTR(UCASE$(t$),"D") THEN hd(cur)=1
            IF LEN(t$)>29 THEN EdAddV "L"+EdNS$(i)+": row longer than 29"
            IF (LEN(t$)+1)\2>gw THEN EdAddV "L"+EdNS$(i)+": row wider than GRID"
          ENDIF
      END SELECT
    ENDIF
  NEXT
  IF INSTR(seen$," TITLE ")=0 THEN EdAddV "No TITLE line"
  IF nin>5 THEN EdAddV "More than 5 INTRO lines"
  IF nit>48 THEN EdAddV "More than 48 ITEM lines"
  IF nmn>24 THEN EdAddV "More than 24 MON lines"
  IF nqs>8 THEN EdAddV "More than 8 QUEST lines"
  IF nkt>24 THEN EdAddV "More than 24 KIT lines"
  IF nqs=0 THEN EdAddV "No QUEST lines - nothing to find"
  FOR f=1 TO 10
    IF hm(f) AND hu(f)=0 THEN EdAddV "Floor "+EdNS$(f)+" map has no U stairs"
    IF hm(f) AND hd(f)=0 AND f<fls THEN EdAddV "Floor "+EdNS$(f)+" map has no D stairs"
  NEXT
  IF nv=0 THEN EdAddV "No problems found."
  EdShowV
END SUB
SUB EdShowV
  LOCAL top, r, kc
  top=1
  DO
    EdCls
    EdBar "VALIDATION  ("+EdNS$(nv)+")"
    FOR r=0 TO LROWS-1
      IF top+r<=nv THEN EdRow r+2,vm$(top+r),WHT,BLK
    NEXT
    EdHelp "UP/DOWN scroll","ESC back"
    kc=EdKey()
    IF kc=KUP AND top>1 THEN top=top-1
    IF kc=KDN AND top+LROWS<=nv THEN top=top+1
    IF kc=KESC THEN EXIT SUB
  LOOP
END SUB

'===================== files =========================================
SUB EdLoad f$
  LOCAL a$
  nl=0: trunc=0
  OPEN f$ FOR INPUT AS #1
  DO WHILE NOT EOF(#1)
    LINE INPUT #1,a$
    IF nl<MAXL THEN
      nl=nl+1
      IF LEN(a$)>LLEN THEN trunc=1
      ln$(nl)=LEFT$(a$,LLEN)
    ELSE
      trunc=2
    ENDIF
  LOOP
  CLOSE #1
  fname$=f$: dirty=0
END SUB
SUB EdNew
  LOCAL a$
  nl=0: trunc=0
  RESTORE EdTemplate
  DO
    READ a$
    IF a$="END" THEN EXIT DO
    nl=nl+1: ln$(nl)=a$
  LOOP
  fname$="NEW.ADV": dirty=1
END SUB
SUB EdSave f$
  LOCAL i
  OPEN f$ FOR OUTPUT AS #1
  FOR i=1 TO nl
    PRINT #1,ln$(i)
  NEXT
  CLOSE #1
  fname$=f$: dirty=0
  EdStat "Saved "+f$,GRN: PAUSE 800
END SUB
SUB EdSaveAs
  LOCAL n$
  EdCls
  EdBar "SAVE AS"
  EdRow 2,"Current file: "+fname$,WHT,BLK
  n$=UCASE$(EdTrim$(EdInput$("New file name",fname$,30)))
  IF edcan OR n$="" THEN EXIT SUB
  IF INSTR(n$,".")=0 THEN n$=n$+".ADV"
  IF DIR$(n$,FILE)<>"" THEN
    IF EdYes("Replace "+n$+"?")=0 THEN EXIT SUB
  ENDIF
  EdSave n$
END SUB
' pick an .ADV file; returns 1 when something was loaded
FUNCTION EdPick()
  LOCAL n, sel, kc, r, f$
  n=0: f$=DIR$("*.ADV",FILE)
  DO WHILE f$<>"" AND n<40
    n=n+1: fl$(n)=f$: f$=DIR$()
  LOOP
  sel=1
  DO
    EdCls
    EdBar "OPEN ADVENTURE FILE"
    IF n=0 THEN EdRow 2,"No .ADV files found.",GRY,BLK
    FOR r=1 TO MIN(n,LROWS)
      IF r=sel THEN EdRow r+1,fl$(r),BLK,CYN ELSE EdRow r+1,fl$(r),WHT,BLK
    NEXT
    EdHelp "ENTER open  N new from template","ESC cancel"
    kc=EdKeyU()
    SELECT CASE kc
      CASE KUP: IF sel>1 THEN sel=sel-1
      CASE KDN: IF sel<MIN(n,LROWS) THEN sel=sel+1
      CASE KENT
        IF n>0 THEN EdLoad fl$(sel): EdPick=1: EXIT FUNCTION
      CASE 78: EdNew: EdPick=1: EXIT FUNCTION
      CASE KESC: EXIT FUNCTION
    END SELECT
  LOOP
END FUNCTION

'===================== main menu =====================================
SUB EdStart
  LOCAL kc, s, r
  IF EdPick()=0 THEN EXIT SUB
  DO
    EdCls
    EdBar "ADVENTURE EDITOR"
    IF dirty THEN EdRow 2,fname$+"  (modified)",YEL,BLK ELSE EdRow 2,fname$,WHT,BLK
    EdRow 3,EdNS$(nl)+" of "+EdNS$(MAXL)+" lines",GRY,BLK
    FOR s=1 TO NSEC
      EdBuildIx s
      EdRow s+4,EdNS$(s)+"  "+LEFT$(secn$(s)+SPACE$(16),16)+RIGHT$("   "+EdNS$(nix),4),WHT,BLK
    NEXT
    r=NSEC+6
    EdRow r,"V  Validate",WHT,BLK
    EdRow r+1,"S  Save",WHT,BLK
    EdRow r+2,"A  Save as a new file",WHT,BLK
    EdRow r+3,"L  Load another file",WHT,BLK
    EdRow r+4,"Q  Quit",WHT,BLK
    IF trunc=1 THEN EdStat "Some long lines were cut to "+EdNS$(LLEN),RED
    IF trunc=2 THEN EdStat "File too long! Lines after "+EdNS$(MAXL)+" lost",RED
    EdHelp "Press a number or letter",""
    kc=EdKeyU()
    SELECT CASE kc
      CASE 49 TO 48+NSEC: EdList kc-48
      CASE 86: EdCheck
      CASE 83: EdSave fname$
      CASE 65: EdSaveAs
      CASE 76
        IF dirty THEN
          IF EdYes("Discard unsaved changes?") THEN r=EdPick()
        ELSE
          r=EdPick()
        ENDIF
      CASE 81
        IF dirty=0 THEN EXIT SUB
        IF EdYes("Quit without saving?") THEN EXIT SUB
    END SELECT
  LOOP
END SUB

'===================== new-module template ===========================
EdTemplate:
DATA "# Adventure module for TUNNELS OF DOOM (made with ADVEDIT.BAS)"
DATA "# See README.md for every keyword and field."
DATA "TITLE,New Adventure"
DATA "INTRO,Describe your quest here."
DATA "WIN,You have won!"
DATA "FAIL,Your quest has failed."
DATA "FLOORS,2"
DATA "GRID,10,8"
DATA "ROOMS,10"
DATA "GOLD,150,120,100"
DATA "WANDER,5"
DATA "NEEDMAP,1"
DATA "STORE,2,0"
DATA "SEED,0"
DATA "ITEM,W,Dagger,4,0,6,FRH,"
DATA "ITEM,W,Sword,8,0,40,FH,"
DATA "ITEM,A,Leather Armor,1,0,15,FRH,"
DATA "ITEM,P,Rations,10,0,20,,"
DATA "ITEM,H,Healing,15,0,30,,"
DATA "ITEM,M,Healing Potion,1,6,0,,Potion"
DATA "KIT,FRH,Dagger"
DATA "KIT,FWRH,Rations"
DATA "MON,Giant Rat,r,&H906030,3,1,0,3,2,3,1,2,5,0,10,squeaking"
DATA "MON,Skeleton,s,&HE0E0E0,6,3,2,5,1,8,1,2,4,0,0,rattling bones"
DATA "QUEST,Golden Idol,2,0"
DATA "END"
