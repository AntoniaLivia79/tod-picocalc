CLEAR                     ' drop any variables left by a previous run
'=====================================================================
' ADVENTURE CREATOR for Tunnels of Doom (PicoMite / PicoCalc 320x320)
' Creates and edits *.ADV adventure modules for TOD.BAS, including
' random generation of monsters, items, quests, story text, settings,
' hand-drawn floor maps, or a complete adventure.
'=====================================================================
OPTION EXPLICIT
OPTION DEFAULT INTEGER

CONST MXF=10, MXI=48, MXM=24, MXQ=8, MXK=24, MXX=40, MXG=60
CONST KUP=128, KDN=129, KLF=130, KRT=131, KESC=27, KENT=13, KBS=8
CONST WHT=&HFFFFFF, YEL=&HFFFF00, CYN=&H00FFFF, GRY=&H808080
CONST RED=&HFF5050, GRN=&H40E040, BARC=&H203080, BLK=0
CONST SYM$=" +RUDSCVFT"

' ---- adventure data ----
DIM ttl$ LENGTH 40, winm$ LENGTH 160, failm$ LENGTH 160
DIM intro$(5) LENGTH 160
DIM cln$(4) LENGTH 8        ' class slot names (CLASSES line)
DIM sv(12)                 ' settings, see AeLab$ mode 2
DIM itm$(MXI) LENGTH 100   ' fields after "ITEM,"
DIM mon$(MXM) LENGTH 120   ' fields after "MON,"
DIM kit$(MXK) LENGTH 40    ' fields after "KIT,"
DIM qst$(MXQ) LENGTH 40    ' fields after "QUEST,"
DIM xtra$(MXX) LENGTH 100  ' unrecognised lines, kept on save
DIM nit, nmo, nki, nqs, nxt
DIM mp(MXF,13,9)           ' map cell: bits 0-3 type, 16 east link, 32 south
DIM hasmap(MXF), rowc(MXF)
DIM fname$ LENGTH 40, dirty
' ---- work areas ----
DIM ddx(3), ddy(3), bq(140), bv(13,9)
DIM msg$(MXG) LENGTH 40, nmsg, nerr
DIM cur, lastk
ddx(1)=1: ddx(3)=-1: ddy(0)=-1: ddy(2)=1

FONT 1
RANDOMIZE TIMER
AeNew
AeMain
CLS
END

'===================== screen & keyboard ===========================
SUB AeRow r,s$,c
  ' one full 40-column text row (rows 0-25)
  TEXT 0,r*12,LEFT$(s$+SPACE$(40),40),"LT",1,1,c,BLK
END SUB
SUB AeBar s$
  BOX 0,0,320,13,1,BARC,BARC
  TEXT 2,1,LEFT$(s$,39),"LT",1,1,YEL,BARC
END SUB
SUB AeHelp a$,b$
  AeRow 23,a$,GRY: AeRow 24,b$,GRY
END SUB
SUB AeStat s$,c
  AeRow 25,s$,c
END SUB
FUNCTION AeKey()
  LOCAL k$
  DO: k$=INKEY$: LOOP UNTIL k$<>""
  AeKey=ASC(UCASE$(k$)): lastk=ASC(k$)
END FUNCTION
FUNCTION AeYes(p$)
  AeStat p$+" (Y/N)",YEL
  AeYes=(AeKey()=89)
  AeStat "",WHT
END FUNCTION
SUB AeWait s$
  AeStat s$+" - press a key",YEL
  lastk=AeKey()
  AeStat "",WHT
END SUB
' Line input on row 25. Commas are refused (they separate fields).
' Returns the old text if ESC is pressed.
FUNCTION AeIn$(p$,old$,mx)
  LOCAL b$, k$, w
  b$=old$
  DO
    w=38-LEN(p$)
    AeRow 25,p$+RIGHT$(b$,w)+"_",CYN
    DO: k$=INKEY$: LOOP UNTIL k$<>""
    SELECT CASE ASC(k$)
      CASE KENT: AeIn$=b$: AeStat "",WHT: EXIT FUNCTION
      CASE KESC: AeIn$=old$: AeStat "",WHT: EXIT FUNCTION
      CASE KBS,127: IF LEN(b$)>0 THEN b$=LEFT$(b$,LEN(b$)-1)
      CASE 32 TO 126
        IF k$<>"," AND LEN(b$)<mx THEN b$=b$+k$
    END SELECT
  LOOP
END FUNCTION
' keep only the digits of a typed number (at most 5), so values
' like 14E198 can never overflow an integer here or in TOD.BAS
FUNCTION AeDig$(v$)
  LOCAL i, o$
  FOR i=1 TO LEN(v$)
    IF INSTR("0123456789",MID$(v$,i,1)) AND LEN(o$)<5 THEN o$=o$+MID$(v$,i,1)
  NEXT
  IF o$="" THEN o$="0"
  AeDig$=STR$(VAL(o$))
END FUNCTION
' a colour as &HRRGGBB (plain numbers are accepted too)
FUNCTION AeHexCol$(v$)
  LOCAL i, o$, u$
  u$=UCASE$(v$)
  IF LEFT$(u$,2)="&H" THEN
    FOR i=3 TO LEN(u$)
      IF INSTR("0123456789ABCDEF",MID$(u$,i,1)) AND LEN(o$)<6 THEN o$=o$+MID$(u$,i,1)
    NEXT
    IF o$="" THEN o$="0"
    AeHexCol$="&H"+RIGHT$("000000"+o$,6)
  ELSE
    AeHexCol$="&H"+HEX$(VAL(AeDig$(v$)) AND &HFFFFFF,6)
  ENDIF
END FUNCTION
FUNCTION AeN$(v)
  AeN$=STR$(v)
END FUNCTION
FUNCTION AeR(n)
  ' random whole number 0..n-1
  AeR=INT(RND*n)
END FUNCTION
FUNCTION AeCnt(s$)
  LOCAL i, n
  n=1
  FOR i=1 TO LEN(s$)
    IF MID$(s$,i,1)="|" THEN n=n+1
  NEXT
  AeCnt=n
END FUNCTION
FUNCTION AePick$(s$)
  AePick$=FIELD$(s$,1+AeR(AeCnt(s$)),"|")
END FUNCTION
FUNCTION AeTrim$(s$)
  LOCAL t$
  t$=s$
  DO WHILE LEFT$(t$,1)=" ": t$=MID$(t$,2): LOOP
  DO WHILE RIGHT$(t$,1)=" ": t$=LEFT$(t$,LEN(t$)-1): LOOP
  AeTrim$=t$
END FUNCTION
FUNCTION AeF$(r$,n)
  AeF$=AeTrim$(FIELD$(r$,n,","))
END FUNCTION
' replace field n of a comma record that has nf fields
FUNCTION AeSetF$(r$,n,nf,v$)
  LOCAL i, o$
  FOR i=1 TO nf
    IF i=n THEN o$=o$+v$ ELSE o$=o$+AeF$(r$,i)
    IF i<nf THEN o$=o$+","
  NEXT
  AeSetF$=o$
END FUNCTION

'===================== new / main menu =============================
SUB AeNew
  LOCAL f, x, y
  ttl$="New Adventure": winm$="Victory is yours!": failm$="Your quest has failed."
  FOR f=0 TO 5: intro$(f)="": NEXT
  cln$(1)="Fighter": cln$(2)="Wizard": cln$(3)="Rogue": cln$(4)="Hero"
  sv(1)=3: sv(2)=12: sv(3)=9: sv(4)=14: sv(5)=150: sv(6)=120: sv(7)=100
  sv(8)=5: sv(9)=1: sv(10)=2: sv(11)=0: sv(12)=0
  nit=0: nmo=0: nki=0: nqs=0: nxt=0
  FOR f=0 TO MXF
    hasmap(f)=0: rowc(f)=0
    FOR y=0 TO 9: FOR x=0 TO 13: mp(f,x,y)=0: NEXT: NEXT
  NEXT
  fname$="": dirty=0
END SUB

SUB AeMain
  LOCAL k, f$
  DO
    CLS
    f$=fname$: IF f$="" THEN f$="(not saved)"
    AeBar "ADVENTURE CREATOR   "+f$
    AeRow 2,"  "+LEFT$(ttl$,36),YEL
    AeRow 4,"  1  Story text",WHT
    AeRow 5,"  2  Settings  ("+AeN$(sv(1))+" floors, "+AeN$(sv(2))+"x"+AeN$(sv(3))+" grid)",WHT
    AeRow 6,"  3  Items           ("+AeN$(nit)+")",WHT
    AeRow 7,"  4  Starting kits   ("+AeN$(nki)+")",WHT
    AeRow 8,"  5  Monsters        ("+AeN$(nmo)+")",WHT
    AeRow 9,"  6  Quest objects   ("+AeN$(nqs)+")",WHT
    AeRow 10,"  7  Floor maps      ("+AeN$(AeMapCount())+" drawn)",WHT
    AeRow 11,"  8  Check adventure",WHT
    AeRow 12,"  9  Generate a random adventure",WHT
    AeRow 14,"  N  New         L  Load",CYN
    AeRow 15,"  S  Save        A  Save as",CYN
    AeRow 16,"  Q  Quit",CYN
    IF dirty THEN AeRow 18,"  There are unsaved changes.",RED
    AeRow 21,"  R in any editor adds random content.",GRY
    k=AeKey()
    SELECT CASE k
      CASE 49: AeFields 1
      CASE 50: AeFields 2
      CASE 51 TO 54: AeList k-50
      CASE 55: AeFloors
      CASE 56: AeCheck: AeShowMsg "ADVENTURE CHECK"
      CASE 57
        IF AeYes("Replace everything with a random adventure?") THEN AeRndAll
      CASE 78
        IF AeSafe() THEN AeNew
      CASE 76
        IF AeSafe() THEN AeLoadMenu
      CASE 83: AeSaveMenu 0
      CASE 65: AeSaveMenu 1
      CASE 81
        IF AeSafe() THEN EXIT SUB
    END SELECT
  LOOP
END SUB
FUNCTION AeSafe()
  AeSafe=1
  IF dirty THEN AeSafe=AeYes("Discard unsaved changes?")
END FUNCTION

'===================== field editors ===============================
' mode 1 story, 2 settings, 3 item, 4 kit, 5 monster, 6 quest (record cur)
FUNCTION AeNF(md)
  AeNF=VAL(MID$("1212070215030",md*2-1,2))
END FUNCTION
FUNCTION AeLab$(md,i)
  LOCAL s$
  SELECT CASE md
    CASE 1: s$="Title|Intro 1|Intro 2|Intro 3|Intro 4|Intro 5|Win text|Fail text|Fighter slot|Wizard slot|Rogue slot|Hero slot"
    CASE 2: s$="Floors|Grid width|Grid height|Rooms/floor|Gold easy|Gold medium|Gold hard|Wander %|Need map|Store floor|Store floor 2|Seed"
    CASE 3: s$="Kind|Name|"+AeV1$(AeF$(itm$(cur),1))+"|"+AeV2$(AeF$(itm$(cur),1))+"|Cost|Classes|Unknown name"
    CASE 4: s$="Classes|Item"
    CASE 5: s$="Name|Glyph|Colour|Hit points|Attack|Defense|Damage|Speed|XP each|First floor|Last floor|Max group|Ranged|Negotiate %|Sound"
    CASE 6: s$="Name|Floor|Countdown"
  END SELECT
  AeLab$=FIELD$(s$,i,"|")
END FUNCTION
FUNCTION AeV1$(k$)
  IF INSTR("WRXASPHM",k$)>0 THEN AeV1$=FIELD$("Damage|Damage|Count|Protection|Protection|Count|Heals|Effect 1-7",INSTR("WRXASPHM",k$),"|") ELSE AeV1$="Value 1"
END FUNCTION
FUNCTION AeV2$(k$)
  IF k$="R" OR k$="X" THEN
    AeV2$="Ammo group"
  ELSEIF k$="M" THEN
    AeV2$="Power"
  ELSE
    AeV2$="(unused)"
  ENDIF
END FUNCTION
FUNCTION AeHint$(md,i)
  LOCAL k$
  SELECT CASE md
    CASE 1
      IF i>=2 AND i<=6 THEN AeHint$="Intro paragraph, up to 160 chars" ELSE AeHint$="Up to 40 chars (160 for win/fail)"
      IF i>=9 THEN AeHint$="What this adventure calls the class"
    CASE 2
      IF i>=5 AND i<=7 THEN
        AeHint$="Starting gold per player"
      ELSE
        AeHint$=FIELD$("1-10|3-14|3-10|Rooms on random floors 3-40||||Wandering monster chance 0-30|1 = map needed to go down|0 = none|0 = none|0 = new dungeon each game",i,"|")
      ENDIF
    CASE 3
      k$=AeF$(itm$(cur),1)
      SELECT CASE i
        CASE 1: AeHint$="W R X A S P H M  (LEFT/RIGHT)"
        CASE 3
          IF k$="M" THEN AeHint$="1 heal 2 curse 3 fire 4 bolt 5 map 6 HP 7 luck" ELSE AeHint$="Number"
        CASE 4
          IF k$="R" THEN
            AeHint$="Shares a number with its ammo; 0 = none"
          ELSEIF k$="X" THEN
            AeHint$="Weapon and its ammo share a number"
          ELSE
            AeHint$="Number"
          ENDIF
        CASE 5: AeHint$="0 = not sold in stores"
        CASE 6: AeHint$="F W R H letters, blank = everyone"
        CASE 7: AeHint$="Name before it is identified"
        CASE ELSE: AeHint$="Up to 20 chars"
      END SELECT
    CASE 4
      IF i=1 THEN AeHint$="F W R H letters" ELSE AeHint$="LEFT/RIGHT picks an item"
    CASE 5
      IF i<=8 THEN
        AeHint$=FIELD$("Up to 16 chars|One character on the map|&HRRGGBB|1-99|Chance to hit|Harder to hit|Max damage per hit|Moves per turn 1-2",i,"|")
      ELSE
        AeHint$=FIELD$("Experience per kill|Appears from floor|Appears to floor|1-7 in a group|1 = shoots (LEFT/RIGHT)|0-100 chance to bargain|Heard when listening",i-8,"|")
      ENDIF
    CASE 6
      AeHint$=FIELD$("Up to 24 chars|Floor it is hidden on|Ticks (10 steps) 0 = no limit",i,"|")
  END SELECT
END FUNCTION
FUNCTION AeMaxL(md,i)
  AeMaxL=24
  SELECT CASE md
    CASE 1
      AeMaxL=160
      IF i=1 THEN AeMaxL=40
      IF i>=9 THEN AeMaxL=8
    CASE 2: AeMaxL=6
    CASE 3: AeMaxL=VAL(FIELD$("1|20|4|4|5|4|14",i,"|"))
    CASE 4: IF i=1 THEN AeMaxL=4 ELSE AeMaxL=20
    CASE 5: AeMaxL=VAL(FIELD$("16|1|9|3|3|3|3|1|4|2|2|1|1|3|24",i,"|"))
    CASE 6: IF i=1 THEN AeMaxL=24 ELSE AeMaxL=4
  END SELECT
END FUNCTION
' LEFT/RIGHT choices ("" = free text)
FUNCTION AeChoice$(md,i)
  LOCAL j, s$
  AeChoice$=""
  IF md=3 AND i=1 THEN AeChoice$="W|R|X|A|S|P|H|M"
  IF md=5 AND i=13 THEN AeChoice$="0|1"
  IF md=5 AND i=8 THEN AeChoice$="1|2"
  IF md=2 AND i=9 THEN AeChoice$="0|1"
END FUNCTION
FUNCTION AeGetV$(md,i)
  SELECT CASE md
    CASE 1
      IF i=1 THEN
        AeGetV$=ttl$
      ELSEIF i<=6 THEN
        AeGetV$=intro$(i-1)
      ELSEIF i=7 THEN
        AeGetV$=winm$
      ELSEIF i=8 THEN
        AeGetV$=failm$
      ELSE
        AeGetV$=cln$(i-8)
      ENDIF
    CASE 2: AeGetV$=AeN$(sv(i))
    CASE 3: AeGetV$=AeF$(itm$(cur),i)
    CASE 4: AeGetV$=AeF$(kit$(cur),i)
    CASE 5: AeGetV$=AeF$(mon$(cur),i)
    CASE 6: AeGetV$=AeF$(qst$(cur),i)
  END SELECT
END FUNCTION
SUB AeSetV md,i,v$
  dirty=1
  SELECT CASE md
    CASE 1
      IF i=1 THEN
        ttl$=LEFT$(v$,40)
      ELSEIF i<=6 THEN
        intro$(i-1)=v$
      ELSEIF i=7 THEN
        winm$=v$
      ELSEIF i=8 THEN
        failm$=v$
      ELSE
        IF AeTrim$(v$)<>"" THEN cln$(i-8)=LEFT$(AeTrim$(v$),8)
      ENDIF
    CASE 2: sv(i)=VAL(AeDig$(v$)): AeClampSet
    CASE 3
      IF i>=3 AND i<=5 THEN v$=AeDig$(v$)
      itm$(cur)=AeSetF$(itm$(cur),i,7,v$)
    CASE 4: kit$(cur)=AeSetF$(kit$(cur),i,2,v$)
    CASE 5
      IF i=3 THEN v$=AeHexCol$(v$)
      IF i>=4 AND i<=14 THEN v$=AeDig$(v$)
      mon$(cur)=AeSetF$(mon$(cur),i,15,v$)
    CASE 6
      IF i>=2 THEN v$=AeDig$(v$)
      qst$(cur)=AeSetF$(qst$(cur),i,3,v$)
  END SELECT
END SUB
SUB AeClampSet
  LOCAL f, x, y
  sv(1)=MIN(MXF,MAX(1,sv(1))): sv(2)=MIN(14,MAX(3,sv(2))): sv(3)=MIN(10,MAX(3,sv(3)))
  sv(4)=MIN(40,MAX(3,sv(4))): sv(8)=MIN(30,MAX(0,sv(8))): sv(9)=(sv(9)<>0)
  sv(10)=MIN(MXF,MAX(0,sv(10))): sv(11)=MIN(MXF,MAX(0,sv(11)))
  FOR f=5 TO 7: sv(f)=MIN(9999,MAX(0,sv(f))): NEXT
  ' clip drawn maps to the grid size (INV, not NOT: NOT is logical in
  ' MMBasic, so AND (NOT 16) would wipe the whole cell)
  FOR f=1 TO MXF
    FOR y=0 TO 9: FOR x=0 TO 13
      IF x>=sv(2) OR y>=sv(3) THEN mp(f,x,y)=0
      IF x=sv(2)-1 THEN mp(f,x,y)=mp(f,x,y) AND (INV 16)
      IF y=sv(3)-1 THEN mp(f,x,y)=mp(f,x,y) AND (INV 32)
    NEXT: NEXT
  NEXT
END SUB

SUB AeFields md
  LOCAL n, i, sel, k, v$, t$, c$, j, y
  n=AeNF(md): sel=1
  SELECT CASE md
    CASE 1: t$="STORY TEXT"
    CASE 2: t$="SETTINGS"
    CASE 3: t$="ITEM "+STR$(cur)
    CASE 4: t$="STARTING KIT "+STR$(cur)
    CASE 5: t$="MONSTER "+STR$(cur)
    CASE 6: t$="QUEST OBJECT "+STR$(cur)
  END SELECT
  CLS
  DO
    AeBar t$
    FOR i=1 TO n
      y=i+1
      IF i=sel THEN c$=">" ELSE c$=" "
      AeRow y,c$+LEFT$(AeLab$(md,i)+SPACE$(13),13)+" "+LEFT$(AeGetV$(md,i),25),WHT
      IF i=sel THEN TEXT 0,y*12,c$+LEFT$(AeLab$(md,i)+SPACE$(13),13),"LT",1,1,BLK,CYN
    NEXT
    AeRow 21,AeHint$(md,sel),CYN
    IF md=3 AND sel=1 THEN AeRow 22,"W weapon R ranged X ammo A armor",GRY ELSE AeRow 22,"",GRY
    IF md=3 AND sel=1 THEN AeRow 23,"S shield P rations H heal M magic",GRY ELSE AeHelp "UP/DOWN field  ENTER edit  L/R choose","R randomise  ESC done"
    IF md=3 AND sel=1 THEN AeRow 24,"UP/DOWN  L/R choose  R random  ESC",GRY
    k=AeKey()
    SELECT CASE k
      CASE KUP: sel=sel-1: IF sel<1 THEN sel=n
      CASE KDN: sel=sel+1: IF sel>n THEN sel=1
      CASE KENT
        v$=AeIn$(AeLab$(md,sel)+": ",AeGetV$(md,sel),AeMaxL(md,sel))
        AeSetV md,sel,v$
        IF md=3 AND sel=1 THEN AeSetV md,1,LEFT$(UCASE$(v$),1)
        IF (md=3 AND sel=6) OR (md=4 AND sel=1) THEN AeSetV md,sel,UCASE$(v$)
      CASE KLF,KRT
        c$=AeChoice$(md,sel)
        IF md=4 AND sel=2 AND nit>0 THEN
          ' kit item: step through the item list itself
          j=0
          FOR i=1 TO nit
            IF UCASE$(AeF$(itm$(i),2))=UCASE$(AeGetV$(md,sel)) THEN j=i
          NEXT
          IF k=KRT THEN j=j+1 ELSE j=j-1
          IF j<1 THEN j=nit
          IF j>nit THEN j=1
          AeSetV md,sel,AeF$(itm$(j),2)
          CLS
        ELSEIF c$<>"" THEN
          j=0
          FOR i=1 TO AeCnt(c$)
            IF UCASE$(FIELD$(c$,i,"|"))=UCASE$(AeGetV$(md,sel)) THEN j=i
          NEXT
          IF k=KRT THEN j=j+1 ELSE j=j-1
          IF j<1 THEN j=AeCnt(c$)
          IF j>AeCnt(c$) THEN j=1
          AeSetV md,sel,FIELD$(c$,j,"|")
          CLS
        ENDIF
      CASE 82
        SELECT CASE md
          CASE 1: AeRndStory
          CASE 2: AeRndSettings
          CASE 3: itm$(cur)=AeRndItem$("")
          CASE 4: kit$(cur)=AeRndKit$()
          CASE 5: mon$(cur)=AeRndMon$(1+AeR(sv(1)))
          CASE 6: qst$(cur)=AeRndQuest$()
        END SELECT
        dirty=1: CLS
      CASE KESC: EXIT SUB
    END SELECT
  LOOP
END SUB

'===================== record lists ================================
' kind 1 items, 2 kits, 3 monsters, 4 quests (field mode = kind+2)
FUNCTION AeCount(kd)
  SELECT CASE kd
    CASE 1: AeCount=nit
    CASE 2: AeCount=nki
    CASE 3: AeCount=nmo
    CASE 4: AeCount=nqs
  END SELECT
END FUNCTION
FUNCTION AeLimit(kd)
  AeLimit=VAL(FIELD$("48|24|24|8",kd,"|"))
END FUNCTION
FUNCTION AeRec$(kd,i)
  SELECT CASE kd
    CASE 1: AeRec$=itm$(i)
    CASE 2: AeRec$=kit$(i)
    CASE 3: AeRec$=mon$(i)
    CASE 4: AeRec$=qst$(i)
  END SELECT
END FUNCTION
SUB AePut kd,i,r$
  SELECT CASE kd
    CASE 1: itm$(i)=r$
    CASE 2: kit$(i)=r$
    CASE 3: mon$(i)=r$
    CASE 4: qst$(i)=r$
  END SELECT
END SUB
SUB AeSetCount kd,n
  SELECT CASE kd
    CASE 1: nit=n
    CASE 2: nki=n
    CASE 3: nmo=n
    CASE 4: nqs=n
  END SELECT
END SUB
FUNCTION AeSum$(kd,i)
  LOCAL r$
  r$=AeRec$(kd,i)
  SELECT CASE kd
    CASE 1
      AeSum$=AeF$(r$,1)+" "+LEFT$(AeF$(r$,2)+SPACE$(18),18)+" "+AeF$(r$,3)+"/"+AeF$(r$,4)+" $"+AeF$(r$,5)
    CASE 2
      AeSum$=LEFT$(AeF$(r$,1)+"    ",5)+AeF$(r$,2)
    CASE 3
      AeSum$=AeF$(r$,2)+" "+LEFT$(AeF$(r$,1)+SPACE$(16),16)+" F"+AeF$(r$,10)+"-"+AeF$(r$,11)+" HP"+AeF$(r$,4)
    CASE 4
      AeSum$=LEFT$(AeF$(r$,1)+SPACE$(24),24)+" F"+AeF$(r$,2)+" T"+AeF$(r$,3)
  END SELECT
END FUNCTION
FUNCTION AeBlank$(kd)
  SELECT CASE kd
    CASE 1: AeBlank$="W,New Item,4,0,10,FWRH,"
    CASE 2: AeBlank$="FWRH,"+AeF$(itm$(1),2)
    CASE 3: AeBlank$="New Monster,m,&HC0C0C0,5,2,1,4,1,10,1,"+AeN$(sv(1))+",3,0,0,growling"
    CASE 4: AeBlank$="New Treasure,"+AeN$(sv(1))+",0"
  END SELECT
END FUNCTION
FUNCTION AeRndRec$(kd)
  SELECT CASE kd
    CASE 1: AeRndRec$=AeRndItem$("")
    CASE 2: AeRndRec$=AeRndKit$()
    CASE 3: AeRndRec$=AeRndMon$(1+AeR(sv(1)))
    CASE 4: AeRndRec$=AeRndQuest$()
  END SELECT
END FUNCTION

SUB AeList kd
  LOCAL sel, top, i, k, n, t$, r$, y, c
  sel=1: top=1
  t$=FIELD$("ITEMS|STARTING KITS|MONSTERS|QUEST OBJECTS",kd,"|")
  CLS
  DO
    n=AeCount(kd)
    IF sel>n THEN sel=n
    IF sel<1 THEN sel=1
    IF sel<top THEN top=sel
    IF sel>top+18 THEN top=sel-18
    AeBar t$+"  ("+AeN$(n)+" of "+STR$(AeLimit(kd))+")"
    FOR i=0 TO 18
      y=i+2
      IF top+i<=n THEN
        IF top+i=sel THEN c=YEL ELSE c=WHT
        AeRow y,RIGHT$(" "+AeN$(top+i),2)+" "+AeSum$(kd,top+i),c
        IF top+i=sel THEN TEXT 0,y*12,RIGHT$(" "+AeN$(top+i),2),"LT",1,1,BLK,YEL
      ELSE
        AeRow y,"",WHT
      ENDIF
    NEXT
    IF n=0 THEN AeRow 3,"  Empty - press A to add or R for random",GRY
    IF kd=1 THEN AeRow 21,"Store sells the first 17 items with a cost",GRY ELSE AeRow 21,"",GRY
    AeHelp "ENTER edit  A add  R add random  D delete","< > move up/down  C copy  ESC back"
    k=AeKey()
    SELECT CASE k
      CASE KUP: sel=sel-1
      CASE KDN: sel=sel+1
      CASE KENT
        IF n>0 THEN cur=sel: AeFields kd+2: CLS
      CASE 65,82,67
        IF n>=AeLimit(kd) THEN
          AeWait "The list is full"
        ELSEIF k=67 AND n=0 THEN
          AeWait "Nothing to copy"
        ELSE
          IF k=65 THEN r$=AeBlank$(kd)
          IF k=82 THEN r$=AeRndRec$(kd)
          IF k=82 AND kd=1 THEN r$=AeUniq$(r$)
          IF k=67 THEN r$=AeRec$(kd,sel)
          n=n+1: AeSetCount kd,n: AePut kd,n,r$: sel=n: dirty=1
          IF k=65 THEN cur=sel: AeFields kd+2: CLS
        ENDIF
      CASE 68
        IF n>0 THEN
          IF AeYes("Delete "+LEFT$(AeSum$(kd,sel),20)+"?") THEN
            FOR i=sel TO n-1: AePut kd,i,AeRec$(kd,i+1): NEXT
            AeSetCount kd,n-1: dirty=1
          ENDIF
        ENDIF
      CASE 44,60
        IF sel>1 THEN r$=AeRec$(kd,sel-1): AePut kd,sel-1,AeRec$(kd,sel): AePut kd,sel,r$: sel=sel-1: dirty=1
      CASE 46,62
        IF sel<n THEN r$=AeRec$(kd,sel+1): AePut kd,sel+1,AeRec$(kd,sel): AePut kd,sel,r$: sel=sel+1: dirty=1
      CASE KESC: EXIT SUB
    END SELECT
  LOOP
END SUB

'===================== floor maps ==================================
FUNCTION AeMapCount()
  LOCAL f, n
  FOR f=1 TO sv(1)
    IF hasmap(f) THEN n=n+1
  NEXT
  AeMapCount=n
END FUNCTION
SUB AeClearFloor f
  LOCAL x, y
  FOR y=0 TO 9: FOR x=0 TO 13: mp(f,x,y)=0: NEXT: NEXT
END SUB
SUB AeFloors
  LOCAL sel, k, f, s$
  sel=1
  CLS
  DO
    AeBar "FLOOR MAPS"
    FOR f=1 TO sv(1)
      IF hasmap(f) THEN s$="hand-drawn" ELSE s$="random each game"
      IF f=sel THEN
        AeRow f+1,">Floor "+STR$(f)+"  "+s$,YEL
      ELSE
        AeRow f+1," Floor "+STR$(f)+"  "+s$,WHT
      ENDIF
    NEXT
    AeRow 14,"Floors without a drawing are made by the",GRY
    AeRow 15,"game at random every time it is played.",GRY
    AeHelp "ENTER draw/edit  G random drawing","X remove drawing  ESC back"
    k=AeKey()
    SELECT CASE k
      CASE KUP: sel=sel-1: IF sel<1 THEN sel=sv(1)
      CASE KDN: sel=sel+1: IF sel>sv(1) THEN sel=1
      CASE KENT
        IF hasmap(sel)=0 THEN AeClearFloor sel
        AeMapEd sel: CLS
      CASE 71
        IF hasmap(sel)=0 OR AeYes("Replace this drawing?") THEN AeRndFloor sel: dirty=1: AeMapEd sel: CLS
      CASE 88
        IF hasmap(sel) THEN
          IF AeYes("Remove the drawing of floor "+STR$(sel)+"?") THEN hasmap(sel)=0: AeClearFloor sel: dirty=1: CLS
        ENDIF
      CASE KESC: EXIT SUB
    END SELECT
  LOOP
END SUB

' ---- links: d 0 N, 1 E, 2 S, 3 W ----
FUNCTION AeLinked(f,x,y,d)
  AeLinked=0
  SELECT CASE d
    CASE 0: IF y>0 THEN AeLinked=((mp(f,x,y-1) AND 32)<>0)
    CASE 1: AeLinked=((mp(f,x,y) AND 16)<>0)
    CASE 2: AeLinked=((mp(f,x,y) AND 32)<>0)
    CASE 3: IF x>0 THEN AeLinked=((mp(f,x-1,y) AND 16)<>0)
  END SELECT
END FUNCTION
SUB AeLink f,x,y,d,st
  LOCAL ax, ay, b
  ax=x: ay=y
  IF d=0 THEN ay=y-1
  IF d=3 THEN ax=x-1
  IF ax<0 OR ay<0 THEN EXIT SUB
  IF d=0 OR d=2 THEN b=32 ELSE b=16
  IF d=1 AND x>=sv(2)-1 THEN EXIT SUB
  IF d=2 AND y>=sv(3)-1 THEN EXIT SUB
  IF st THEN mp(f,ax,ay)=mp(f,ax,ay) OR b ELSE mp(f,ax,ay)=mp(f,ax,ay) AND (INV b)
END SUB
FUNCTION AeCode(f,x,y)
  AeCode=mp(f,x,y) AND 15
END FUNCTION
SUB AeSetCode f,x,y,c
  mp(f,x,y)=(mp(f,x,y) AND 48) OR c
END SUB
FUNCTION AeDeg(f,x,y)
  LOCAL d, n
  FOR d=0 TO 3: n=n+AeLinked(f,x,y,d): NEXT
  AeDeg=n
END FUNCTION
FUNCTION AeInGrid(x,y)
  AeInGrid=(x>=0 AND y>=0 AND x<sv(2) AND y<sv(3))
END FUNCTION

' ---- map drawing ----
FUNCTION AePitch()
  AePitch=MIN(22,MIN(318\sv(2),212\sv(3)))
END FUNCTION
FUNCTION AeCellCol(c)
  AeCellCol=VAL(FIELD$("0|&H909090|&HA06030|&H00C000|&HE02020|&HE0C000|&HE08000|&HA040E0|&H3070FF|&HE0E0E0",c+1,"|"))
END FUNCTION
SUB AeDrawCell f,x,y,cx,cy
  LOCAL p, ox, oy, px, py, c, m, lc
  p=AePitch(): ox=(320-sv(2)*p)\2: oy=16
  px=ox+x*p: py=oy+y*p: m=p\2
  BOX px,py,p,p,1,BLK,BLK
  c=AeCode(f,x,y): lc=&HC0C0C0
  IF AeLinked(f,x,y,0) THEN BOX px+m-1,py,3,m,1,lc,lc
  IF AeLinked(f,x,y,2) THEN BOX px+m-1,py+m,3,p-m,1,lc,lc
  IF AeLinked(f,x,y,3) THEN BOX px,py+m-1,m,3,1,lc,lc
  IF AeLinked(f,x,y,1) THEN BOX px+m,py+m-1,p-m,3,1,lc,lc
  IF c=0 THEN
    PIXEL px+m,py+m,&H404040
  ELSEIF c=1 THEN
    BOX px+m-3,py+m-3,7,7,1,AeCellCol(1),AeCellCol(1)
  ELSE
    BOX px+3,py+3,p-6,p-6,1,AeCellCol(c),AeCellCol(c)
    IF c>2 THEN TEXT px+m+1,py+m+1,MID$(SYM$,c+1,1),"CM",1,1,BLK,AeCellCol(c)
  ENDIF
  IF x=cx AND y=cy THEN BOX px,py,p,p,1,YEL
END SUB
SUB AeDrawMap f,cx,cy
  LOCAL x, y
  FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1: AeDrawCell f,x,y,cx,cy: NEXT: NEXT
END SUB
SUB AeRedrawAround f,x,y,cx,cy
  LOCAL d, nx, ny
  AeDrawCell f,x,y,cx,cy
  FOR d=0 TO 3
    nx=x+ddx(d): ny=y+ddy(d)
    IF AeInGrid(nx,ny) THEN AeDrawCell f,nx,ny,cx,cy
  NEXT
END SUB
FUNCTION AeCellName$(c)
  AeCellName$=FIELD$("empty|hallway|room|stairs up|stairs down|store|chest|vault|fountain|statue",c+1,"|")
END FUNCTION

SUB AeMapEd f
  LOCAL cx, cy, k, d, penon, ox, oy, nx, ny, c, i, px, py
  hasmap(f)=1: dirty=1
  CLS
  AeBar "FLOOR "+STR$(f)+" MAP  (? = help)"
  AeDrawMap f,0,0
  cx=0: cy=0: penon=0
  DO
    IF penon THEN AeRow 20,"PEN ON: moving draws hallway",GRN ELSE AeRow 20,"",WHT
    AeRow 21,"("+AeN$(cx+1)+","+AeN$(cy+1)+") "+AeCellName$(AeCode(f,cx,cy)),CYN
    AeHelp "+ R U D S C V F T place  SPACE erase","L+arrow link  J join  P pen  G random"
    AeStat "X clear  ESC done",GRY
    k=AeKey()
    d=-1
    IF k=KUP THEN d=0
    IF k=KRT THEN d=1
    IF k=KDN THEN d=2
    IF k=KLF THEN d=3
    IF d>=0 THEN
      nx=cx+ddx(d): ny=cy+ddy(d)
      IF AeInGrid(nx,ny) THEN
        IF penon THEN
          IF AeCode(f,cx,cy)=0 THEN AeSetCode f,cx,cy,1
          IF AeCode(f,nx,ny)=0 THEN AeSetCode f,nx,ny,1
          AeLink f,cx,cy,d,1
        ENDIF
        px=cx: py=cy: cx=nx: cy=ny
        AeRedrawAround f,px,py,cx,cy: AeDrawCell f,cx,cy,cx,cy
      ENDIF
    ELSE
      c=INSTR(SYM$,CHR$(k))-1
      IF k=32 OR k=46 THEN
        FOR i=0 TO 3: AeLink f,cx,cy,i,0: NEXT
        AeSetCode f,cx,cy,0: AeRedrawAround f,cx,cy,cx,cy
      ELSEIF c>0 THEN
        IF c=3 THEN AeReplaceSym f,3
        AeSetCode f,cx,cy,c: AeRedrawAround f,cx,cy,cx,cy
      ELSE
        SELECT CASE k
          CASE 76
            AeStat "Link which way? (arrow)",YEL
            i=AeKey(): d=-1
            IF i=KUP THEN d=0
            IF i=KRT THEN d=1
            IF i=KDN THEN d=2
            IF i=KLF THEN d=3
            IF d>=0 THEN
              nx=cx+ddx(d): ny=cy+ddy(d)
              IF AeInGrid(nx,ny) THEN
                AeLink f,cx,cy,d,1-AeLinked(f,cx,cy,d)
                IF AeCode(f,nx,ny)=0 AND AeLinked(f,cx,cy,d) THEN AeSetCode f,nx,ny,1
                AeRedrawAround f,cx,cy,cx,cy
              ENDIF
            ENDIF
          CASE 74
            FOR i=0 TO 3
              nx=cx+ddx(i): ny=cy+ddy(i)
              IF AeInGrid(nx,ny) THEN
                IF AeCode(f,nx,ny)>0 AND AeCode(f,cx,cy)>0 THEN AeLink f,cx,cy,i,1
              ENDIF
            NEXT
            AeRedrawAround f,cx,cy,cx,cy
          CASE 80: penon=1-penon
          CASE 71
            IF AeYes("Replace with a random floor?") THEN AeRndFloor f: CLS: AeBar "FLOOR "+STR$(f)+" MAP  (? = help)": AeDrawMap f,cx,cy
          CASE 88
            IF AeYes("Clear this floor?") THEN AeClearFloor f: AeDrawMap f,cx,cy
          CASE 63
            AeMapHelp
            CLS: AeBar "FLOOR "+STR$(f)+" MAP  (? = help)": AeDrawMap f,cx,cy
          CASE KESC: EXIT SUB
        END SELECT
      ENDIF
    ENDIF
  LOOP
END SUB
' only one stairs-up per floor
SUB AeReplaceSym f,c
  LOCAL x, y
  FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
    IF AeCode(f,x,y)=c THEN AeSetCode f,x,y,2: AeDrawCell f,x,y,-1,-1
  NEXT: NEXT
END SUB
SUB AeMapHelp
  CLS
  AeBar "MAP EDITOR HELP"
  AeRow 2,"Arrows   move the cursor",WHT
  AeRow 3,"+        hallway",WHT
  AeRow 4,"R        room (random contents)",WHT
  AeRow 5,"U / D    stairs up / stairs down",WHT
  AeRow 6,"S        store",WHT
  AeRow 7,"C V F T  chest, vault, fountain, statue",WHT
  AeRow 8,"SPACE    erase cell and its links",WHT
  AeRow 9,"L arrow  add or remove a link",WHT
  AeRow 10,"J        join to all used neighbours",WHT
  AeRow 11,"P        pen: moving lays hallway",WHT
  AeRow 12,"G        replace with a random floor",WHT
  AeRow 13,"X        clear the floor",WHT
  AeRow 15,"Every floor needs one U. Every floor",CYN
  AeRow 16,"except the last needs a D. All cells",CYN
  AeRow 17,"must be reachable from the U.",CYN
  AeRow 18,"Monsters, gold, items, the floor map",CYN
  AeRow 19,"and quest objects are added by the",CYN
  AeRow 20,"game when it builds the dungeon.",CYN
  AeWait ""
END SUB

' ---- BFS over links from (sx,sy); bv()=distance+1, returns count ----
FUNCTION AeBFS(f,sx,sy)
  LOCAL h, t, x, y, d, nx, ny, n
  FOR y=0 TO 9: FOR x=0 TO 13: bv(x,y)=0: NEXT: NEXT
  bq(0)=sx+sy*14: bv(sx,sy)=1: t=1: n=1
  DO WHILE h<t
    x=bq(h) MOD 14: y=bq(h)\14: h=h+1
    FOR d=0 TO 3
      nx=x+ddx(d): ny=y+ddy(d)
      IF AeInGrid(nx,ny) THEN
        IF AeLinked(f,x,y,d) AND bv(nx,ny)=0 AND AeCode(f,nx,ny)>0 THEN
          bv(nx,ny)=bv(x,y)+1: bq(t)=nx+ny*14: t=t+1: n=n+1
        ENDIF
      ENDIF
    NEXT
  LOOP
  AeBFS=n
END FUNCTION
' random cell with code c, returns x+y*14 or -1
FUNCTION AeFind(f,c)
  LOCAL t, x, y
  AeFind=-1
  FOR t=1 TO 300
    x=AeR(sv(2)): y=AeR(sv(3))
    IF AeCode(f,x,y)=c THEN AeFind=x+y*14: EXIT FUNCTION
  NEXT
  FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
    IF AeCode(f,x,y)=c THEN AeFind=x+y*14: EXIT FUNCTION
  NEXT: NEXT
END FUNCTION

SUB AeRndFloor f
  LOCAL x, y, d, nx, ny, n, target, tries, rooms, i, bx, by, best
  AeClearFloor f: hasmap(f)=1
  x=AeR(sv(2)): y=AeR(sv(3)): AeSetCode f,x,y,1: n=1
  target=sv(2)*sv(3)*(45+AeR(20))\100
  DO WHILE n<target AND tries<6000
    tries=tries+1
    x=AeR(sv(2)): y=AeR(sv(3))
    IF AeCode(f,x,y)>0 THEN
      d=AeR(4): nx=x+ddx(d): ny=y+ddy(d)
      IF AeInGrid(nx,ny) THEN
        IF AeCode(f,nx,ny)=0 THEN AeSetCode f,nx,ny,1: AeLink f,x,y,d,1: n=n+1
      ENDIF
    ENDIF
  LOOP
  ' a few loops so there is more than one way round
  FOR i=1 TO n\6
    x=AeR(sv(2)): y=AeR(sv(3)): d=AeR(4): nx=x+ddx(d): ny=y+ddy(d)
    IF AeInGrid(nx,ny) THEN
      IF AeCode(f,x,y)>0 AND AeCode(f,nx,ny)>0 THEN AeLink f,x,y,d,1
    ENDIF
  NEXT
  ' dead ends become rooms, then extra rooms at random
  FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
    IF AeCode(f,x,y)=1 AND AeDeg(f,x,y)=1 AND rooms<sv(4) THEN AeSetCode f,x,y,2: rooms=rooms+1
  NEXT: NEXT
  tries=0
  DO WHILE rooms<MIN(sv(4),n\2) AND tries<400
    tries=tries+1: i=AeFind(f,1)
    IF i<0 THEN EXIT DO
    AeSetCode f,i MOD 14,i\14,2: rooms=rooms+1
  LOOP
  ' stairs up in a room, stairs down in the farthest room
  i=AeFind(f,2): IF i<0 THEN i=AeFind(f,1)
  bx=i MOD 14: by=i\14: AeSetCode f,bx,by,3
  n=AeBFS(f,bx,by)
  IF f<sv(1) THEN
    best=-1
    FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
      IF AeCode(f,x,y)=2 AND bv(x,y)>best THEN best=bv(x,y): nx=x: ny=y
    NEXT: NEXT
    IF best<0 THEN
      FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
        IF AeCode(f,x,y)=1 AND bv(x,y)>best THEN best=bv(x,y): nx=x: ny=y
      NEXT: NEXT
    ENDIF
    IF best>0 THEN AeSetCode f,nx,ny,4
  ENDIF
  IF f=sv(10) OR f=sv(11) THEN
    i=AeFind(f,2): IF i>=0 THEN AeSetCode f,i MOD 14,i\14,5
  ENDIF
  FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
    IF AeCode(f,x,y)=2 THEN
      d=AeR(100)
      IF d<12 THEN AeSetCode f,x,y,6
      IF d>=12 AND d<18 THEN AeSetCode f,x,y,7
      IF d>=18 AND d<24 THEN AeSetCode f,x,y,8
      IF d>=24 AND d<28 THEN AeSetCode f,x,y,9
    ENDIF
  NEXT: NEXT
END SUB

'===================== random content ==============================
FUNCTION AeRndMon$(t)
  LOCAL nm$, b$, s$, hp, atk, df, dm, sp, xp, lo, hi, cnt, rg, ng, g$, c
  b$=AePick$("Rat|Bat|Spider|Goblin|Orc|Skeleton|Zombie|Wolf|Snake|Troll|Ogre|Wraith|Beetle|Imp|Slime|Golem|Ghoul|Harpy|Kobold|Lizard|Wight|Mummy")
  nm$=AePick$("Cave|Giant|Fire|Ice|Shadow|Bone|Swamp|Stone|Dire|Ghost|Rust|Plague|Storm|Blood|Iron|Venom|Grim|Mad")+" "+b$
  nm$=LEFT$(nm$,16)
  IF t<1 THEN t=1
  hp=2+t*3+AeR(t*2+2): atk=1+t+AeR(3): df=t\2+AeR(2): dm=2+t+AeR(t+1)
  sp=1+(RND<.2): xp=hp+atk*2+dm*2
  lo=MAX(1,t-1): hi=MIN(sv(1),t+1)
  cnt=MAX(1,MIN(7,6-t\2-AeR(3))): rg=(RND<.15): ng=AeR(5)*10
  g$=LCASE$(LEFT$(b$,1)): IF t*2>sv(1) THEN g$=UCASE$(g$)
  c=VAL(AePick$("&HFF6060|&H60FF60|&H6080FF|&HFFFF60|&HFF60FF|&H60FFFF|&HFFA040|&HC0C0C0|&HA0FF40|&HFF4090"))
  s$=nm$+","+g$+",&H"+HEX$(c,6)+","+AeN$(hp)+","+AeN$(atk)+","+AeN$(df)+","+AeN$(dm)+","+AeN$(sp)
  s$=s$+","+AeN$(xp)+","+AeN$(lo)+","+AeN$(hi)+","+AeN$(cnt)+","+AeN$(rg)+","+AeN$(ng)+","
  AeRndMon$=s$+AePick$("squeaking|flapping|hissing|growling|rattling bones|shuffling|howling|snarling|chittering|moaning|grunting|dripping|clanking|whispering|scratching")
END FUNCTION

' kind$="" picks a kind at random
FUNCTION AeRndItem$(kind$)
  LOCAL k$, ev$, e, pw, cost, gn$, nm$, cl$
  k$=kind$
  IF k$="" THEN k$=MID$("WWRXAASPHMMMM",1+AeR(13),1)
  SELECT CASE k$
    CASE "W"
      ev$=AePick$("Dagger:4:6:FWRH|Club:5:8:FWRH|Hand Axe:6:15:FRH|Mace:7:25:FRH|Spear:7:30:FRH|Sword:8:40:FRH|War Hammer:9:55:FH|Great Sword:10:80:FH")
      AeRndItem$="W,"+FIELD$(ev$,1,":")+","+FIELD$(ev$,2,":")+",0,"+FIELD$(ev$,3,":")+","+FIELD$(ev$,4,":")+","
    CASE "R"
      ' ammo group 0 = needs no ammunition (a sling never runs out)
      ev$=AePick$("Sling:4:10:0:FWRH|Short Bow:6:30:2:FRH|Long Bow:7:45:2:FRH|Crossbow:9:50:3:FRH")
      AeRndItem$="R,"+FIELD$(ev$,1,":")+","+FIELD$(ev$,2,":")+","+FIELD$(ev$,4,":")+","+FIELD$(ev$,3,":")+","+FIELD$(ev$,5,":")+","
    CASE "X"
      ev$=AePick$("Arrows:20:2:20:FRH|Quarrels:10:3:20:FRH")
      AeRndItem$="X,"+FIELD$(ev$,1,":")+","+FIELD$(ev$,2,":")+","+FIELD$(ev$,3,":")+","+FIELD$(ev$,4,":")+","+FIELD$(ev$,5,":")+","
    CASE "A"
      ev$=AePick$("Leather Armor:1:15:FRH|Ring Mail:2:35:FRH|Chain Mail:3:60:FH|Plate Armor:5:120:FH")
      AeRndItem$="A,"+FIELD$(ev$,1,":")+","+FIELD$(ev$,2,":")+",0,"+FIELD$(ev$,3,":")+","+FIELD$(ev$,4,":")+","
    CASE "S"
      ev$=AePick$("Buckler:1:12:FRH|Shield:1:20:FH|Tower Shield:2:45:FH")
      AeRndItem$="S,"+FIELD$(ev$,1,":")+","+FIELD$(ev$,2,":")+",0,"+FIELD$(ev$,3,":")+","+FIELD$(ev$,4,":")+","
    CASE "P": AeRndItem$="P,Rations,10,0,20,FWRH,"
    CASE "H": AeRndItem$="H,Healing,"+AeN$(10+AeR(3)*5)+",0,30,FWRH,"
    CASE ELSE
      e=1+AeR(7)
      SELECT CASE e
        CASE 1: ev$=AePick$("Healing Potion:Potion|Medicinal Ale:Ale|Elixir of Life:Flask|Troll Tonic:Flask"): pw=5+AeR(11)
        CASE 2: ev$=AePick$("Cursed Potion:Potion|Poison Ale:Ale|Witch Brew:Flask|Rotten Mead:Ale"): pw=2+AeR(6)
        CASE 3: ev$=AePick$("Fireball Scroll:Scroll|Wand of Frost:Wand|Storm Scroll:Scroll|Dragon Horn:Horn"): pw=5+AeR(8)
        CASE 4: ev$=AePick$("Lightning Scroll:Scroll|Wand of Bolts:Wand|Death Scroll:Scroll|Star Rod:Rod"): pw=8+AeR(10)
        CASE 5: ev$=AePick$("Seeing Scroll:Scroll|Crystal Ball:Orb|Map Scroll:Scroll|Eye of Ages:Gem"): pw=1
        CASE 6: ev$=AePick$("Giant Strength:Potion|Ring of Health:Ring|Oak Heart:Charm|Potion of Might:Potion"): pw=2+AeR(4)
        CASE 7: ev$=AePick$("Lucky Charm:Charm|Amulet of Luck:Amulet|Rabbit Foot:Charm|Four-Leaf Clover:Charm"): pw=1+AeR(2)
      END SELECT
      nm$=FIELD$(ev$,1,":"): gn$=FIELD$(ev$,2,":")
      cl$="FWRH": IF gn$="Scroll" THEN cl$="WH"
      cost=0: IF e<>2 AND RND<.3 THEN cost=40+AeR(12)*10
      AeRndItem$="M,"+nm$+","+AeN$(e)+","+AeN$(pw)+","+AeN$(cost)+","+cl$+","+gn$
  END SELECT
END FUNCTION
' try for an item whose name is not already used (same kind)
FUNCTION AeUniq$(r$)
  LOCAL t, o$
  o$=r$
  FOR t=1 TO 30
    IF AeHasItem(AeF$(o$,2))=0 THEN EXIT FOR
    o$=AeRndItem$(AeF$(r$,1))
  NEXT
  AeUniq$=o$
END FUNCTION
FUNCTION AeRndKit$()
  LOCAL i, j, c$
  AeRndKit$="FWRH,"
  IF nit=0 THEN EXIT FUNCTION
  FOR j=1 TO 30
    i=1+AeR(nit)
    IF INSTR("WRXASP",AeF$(itm$(i),1))>0 THEN EXIT FOR
  NEXT
  c$=AeF$(itm$(i),6): IF c$="" THEN c$="FWRH"
  AeRndKit$=MID$(c$,1+AeR(LEN(c$)),1)+","+AeF$(itm$(i),2)
END FUNCTION
FUNCTION AeRndQuest$()
  LOCAL fl, tm, n$
  fl=MAX(1,sv(1)-AeR(2)): tm=0
  IF RND<.5 THEN tm=60+AeR(11)*10
  n$=AePick$("Crown of Kings|Silver Chalice|Dragon Egg|Lost Prince|Book of Ages|Star Gem|Ancient Sword|Golden Harp|Emerald Idol|Moon Pearl|Staff of Power|Sun Stone|Queen Aurora|Rainbow Orb")
  AeRndQuest$=n$+","+AeN$(fl)+","+AeN$(tm)
END FUNCTION
SUB AeRndStory
  LOCAL pl$, q1$, q2$, i, lim, t$
  pl$=AePick$("Tomb|Caverns|Halls|Mines|Vaults|Catacombs|Fortress|Labyrinth|Pits|Crypt")+" of "+AePick$("Doom|Shadows|Despair|Zarak|Thunder|the Lich|Eternal Night|Mount Grim|the Serpent")
  ttl$=LEFT$("The "+pl$,40)
  q1$="a great treasure": q2$=""
  IF nqs>0 THEN q1$="the "+AeF$(qst$(1),1)
  IF nqs>1 THEN q2$="the "+AeF$(qst$(2),1)
  FOR i=1 TO nqs
    IF VAL(AeF$(qst$(i),3))>0 THEN lim=1
  NEXT
  FOR i=0 TO 5: intro$(i)="": NEXT
  intro$(0)=AePick$("Deep below|Far beneath|Under|Hidden beneath")+" "+AePick$("a ruined keep|the old mountain|a haunted village|the king's palace|a forgotten temple")+" lie the "+pl$+"."
  IF q2$="" THEN
    intro$(1)="Brave adventurers must recover "+q1$+" and return to the surface."
  ELSE
    intro$(1)="Brave adventurers must recover "+q1$+" and "+q2$+" then return to the surface."
  ENDIF
  intro$(2)=AePick$("Monsters guard every hall.|Evil stirs in the depths.|Few who entered came back.|Gold and danger wait below.")
  IF lim THEN intro$(3)="Hurry - some treasures will not wait forever!"
  winm$="You return to the surface in triumph. Your names will be sung for ages!"
  ' class names to suit the story
  t$=AePick$("Fighter:Wizard:Rogue:Hero|Knight:Mage:Thief:Paladin|Warrior:Sorcerer:Scout:Champion|Soldier:Magus:Burglar:Lord")
  FOR i=1 TO 4: cln$(i)=FIELD$(t$,i,":"): NEXT
  failm$="Darkness claims the "+pl$+" and all who entered."
  dirty=1
END SUB
SUB AeRndSettings
  sv(1)=3+AeR(5): sv(2)=10+AeR(5): sv(3)=8+AeR(3): sv(4)=10+AeR(10)
  sv(5)=130+AeR(5)*10: sv(6)=sv(5)-30: sv(7)=sv(6)-30
  sv(8)=3+AeR(6): sv(9)=1: sv(10)=1+sv(1)\2: sv(11)=0: sv(12)=0
  dirty=1: AeClampSet
END SUB

SUB AeRndAll
  LOCAL t, i, s$, nq, r$
  AeNew
  AeStat "Generating...",YEL
  AeRndSettings
  ' a standard shop plus some random magic
  s$="W:Dagger|W:Hand Axe|W:Mace|W:Sword|R:Sling|R:Short Bow|R:Crossbow|X:Arrows|X:Quarrels|A:Leather Armor|A:Chain Mail|S:Shield"
  FOR i=1 TO AeCnt(s$)
    AeStdItem FIELD$(FIELD$(s$,i,"|"),1,":"),FIELD$(FIELD$(s$,i,"|"),2,":")
  NEXT
  nit=nit+1: itm$(nit)="P,Rations,10,0,20,FWRH,"
  nit=nit+1: itm$(nit)="H,Healing,15,0,30,FWRH,"
  nit=nit+1: itm$(nit)="M,Fireball Scroll,3,8,0,WH,Scroll"
  FOR i=1 TO 5+AeR(5): r$=AeUniq$(AeRndItem$("M")): nit=nit+1: itm$(nit)=r$: NEXT
  s$="F,Sword|F,Shield|FR,Leather Armor|R,Hand Axe|R,Short Bow|R,Arrows|W,Dagger|W,Sling|W,Fireball Scroll|H,Sword|H,Fireball Scroll"
  FOR i=1 TO AeCnt(s$): nki=nki+1: kit$(nki)=FIELD$(s$,i,"|"): NEXT
  ' two monsters for each level of toughness
  FOR t=1 TO sv(1)
    FOR i=1 TO 2
      IF nmo<MXM THEN nmo=nmo+1: mon$(nmo)=AeRndMon$(t)
    NEXT
  NEXT
  nq=1+AeR(2)
  FOR i=1 TO nq
    nqs=nqs+1: qst$(nqs)=AeRndQuest$()
    IF i=nq THEN qst$(nqs)=AeSetF$(qst$(nqs),2,3,AeN$(sv(1)))
  NEXT
  AeRndStory
  IF AeYes("Draw random maps for every floor?") THEN
    FOR i=1 TO sv(1): AeRndFloor i: NEXT
  ENDIF
  dirty=1
END SUB
' copy one of the standard items (by kind and name)
SUB AeStdItem k$,n$
  LOCAL t, r$
  FOR t=1 TO 200
    r$=AeRndItem$(k$)
    IF AeF$(r$,2)=n$ THEN nit=nit+1: itm$(nit)=r$: EXIT SUB
  NEXT
END SUB

'===================== checking ====================================
SUB AeAdd s$,er
  IF nmsg<MXG THEN nmsg=nmsg+1: msg$(nmsg)=LEFT$(s$,40)
  IF er THEN nerr=nerr+1
END SUB
FUNCTION AeHasItem(n$)
  LOCAL i
  AeHasItem=0
  FOR i=1 TO nit
    IF UCASE$(AeF$(itm$(i),2))=UCASE$(n$) THEN AeHasItem=i
  NEXT
END FUNCTION
SUB AeCheck
  LOCAL i, j, f, x, y, k$, n, nu, nd, nr, cover, a, ok
  nmsg=0: nerr=0
  IF ttl$="" THEN AeAdd "WARN: no title",0
  IF intro$(0)="" THEN AeAdd "WARN: no introduction text",0
  IF sv(10)>sv(1) OR sv(11)>sv(1) THEN AeAdd "WARN: a store floor is past the last floor",0
  ' items
  FOR i=1 TO nit
    k$=AeF$(itm$(i),1)
    IF INSTR("WRXASPHM",k$)=0 OR k$="" THEN AeAdd "ERROR: item "+STR$(i)+" has no valid kind",1
    IF AeF$(itm$(i),2)="" THEN AeAdd "ERROR: item "+STR$(i)+" has no name",1
    IF k$="M" AND (VAL(AeF$(itm$(i),3))<1 OR VAL(AeF$(itm$(i),3))>7) THEN AeAdd "ERROR: "+AeF$(itm$(i),2)+" effect not 1-7",1
    IF k$="R" AND VAL(AeF$(itm$(i),4))>0 THEN
      ok=0
      FOR j=1 TO nit
        IF AeF$(itm$(j),1)="X" AND AeF$(itm$(j),4)=AeF$(itm$(i),4) THEN ok=1
      NEXT
      IF ok=0 THEN AeAdd "WARN: no ammo for "+AeF$(itm$(i),2),0
    ENDIF
    FOR j=1 TO i-1
      IF UCASE$(AeF$(itm$(j),2))=UCASE$(AeF$(itm$(i),2)) THEN AeAdd "WARN: two items named "+AeF$(itm$(i),2),0
    NEXT
  NEXT
  IF nit=0 THEN AeAdd "WARN: no items (nothing to buy)",0
  ' kits
  FOR i=1 TO nki
    IF AeHasItem(AeF$(kit$(i),2))=0 THEN AeAdd "ERROR: kit item "+AeF$(kit$(i),2)+"?",1
  NEXT
  ' monsters
  FOR i=1 TO nmo
    IF AeF$(mon$(i),1)="" THEN AeAdd "ERROR: monster "+STR$(i)+" has no name",1
    a=VAL(AeF$(mon$(i),12))
    IF a<1 OR a>7 THEN AeAdd "ERROR: "+AeF$(mon$(i),1)+" group not 1-7",1
    IF VAL(AeF$(mon$(i),10))>VAL(AeF$(mon$(i),11)) THEN AeAdd "ERROR: "+AeF$(mon$(i),1)+" floors reversed",1
    IF VAL(AeF$(mon$(i),4))<1 THEN AeAdd "ERROR: "+AeF$(mon$(i),1)+" has no hit points",1
    ' a monster may start one floor below the last: it then only guards
    ' the last floor's quest objects. Any deeper and it never appears.
    IF VAL(AeF$(mon$(i),10))>sv(1)+1 THEN AeAdd "WARN: "+AeF$(mon$(i),1)+" can never appear",0
  NEXT
  IF nmo>0 THEN
    FOR f=1 TO sv(1)
      cover=0
      FOR i=1 TO nmo
        IF f>=VAL(AeF$(mon$(i),10)) AND f<=VAL(AeF$(mon$(i),11)) THEN cover=1
      NEXT
      IF cover=0 THEN AeAdd "WARN: no monsters for floor "+STR$(f),0
    NEXT
  ENDIF
  ' quests
  IF nqs=0 THEN AeAdd "WARN: no quest objects - instant win",0
  FOR i=1 TO nqs
    a=VAL(AeF$(qst$(i),2))
    IF a<1 OR a>sv(1) THEN AeAdd "ERROR: "+AeF$(qst$(i),1)+" floor not 1-"+AeN$(sv(1)),1
  NEXT
  ' drawn maps
  FOR f=1 TO sv(1)
    IF hasmap(f) THEN
      nu=0: nd=0: nr=0: n=0
      FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
        a=AeCode(f,x,y)
        IF a=3 THEN nu=nu+1: i=x: j=y
        IF a=4 THEN nd=nd+1
        IF a>=5 OR a=2 THEN nr=nr+1
        IF a>0 THEN n=n+1
        IF a=0 AND AeDeg(f,x,y)>0 THEN AeAdd "ERROR: F"+AeN$(f)+" link to empty cell at "+AeN$(x+1)+","+AeN$(y+1),1
      NEXT: NEXT
      IF nu<>1 THEN AeAdd "ERROR: floor "+STR$(f)+" needs exactly one U",1
      IF nd=0 AND f<sv(1) THEN AeAdd "ERROR: floor "+STR$(f)+" has no D (stairs down)",1
      IF nd>0 AND f=sv(1) THEN AeAdd "WARN: last floor has stairs down",0
      IF nd>1 THEN AeAdd "WARN: floor "+STR$(f)+" has more than one D",0
      IF nr=0 THEN AeAdd "WARN: floor "+STR$(f)+" has no rooms for treasure",0
      IF nu=1 THEN
        IF AeBFS(f,i,j)<n THEN AeAdd "ERROR: floor "+STR$(f)+": some cells unreachable",1
      ENDIF
    ENDIF
  NEXT
  IF nxt>0 THEN AeAdd "WARN: "+AeN$(nxt)+" unrecognised line(s) kept as-is",0
  IF nmsg=0 THEN AeAdd "No problems found.",0
END SUB
SUB AeShowMsg t$
  LOCAL top, i, k
  top=1
  DO
    CLS
    AeBar t$+"  "+AeN$(nerr)+" error(s)"
    FOR i=0 TO 19
      IF top+i<=nmsg THEN
        IF LEFT$(msg$(top+i),5)="ERROR" THEN AeRow i+2,msg$(top+i),RED ELSE AeRow i+2,msg$(top+i),WHT
      ENDIF
    NEXT
    AeHelp "UP/DOWN scroll","ESC back"
    k=AeKey()
    IF k=KUP AND top>1 THEN top=top-1
    IF k=KDN AND top+19<nmsg THEN top=top+1
    IF k=KESC OR k=KENT THEN EXIT SUB
  LOOP
END SUB

'===================== load / save =================================
SUB AeLoadMenu
  LOCAL n, i, k, sel, f$
  LOCAL fl$(30) LENGTH 40
  CLS
  AeBar "LOAD ADVENTURE"
  f$=DIR$("*.ADV",FILE)
  DO WHILE f$<>"" AND n<30
    n=n+1: fl$(n)=f$: f$=DIR$()
  LOOP
  IF n=0 THEN AeWait "No .ADV files found": EXIT SUB
  sel=1
  DO
    FOR i=1 TO MIN(n,19)
      IF i=sel THEN AeRow i+1,">"+fl$(i),YEL ELSE AeRow i+1," "+fl$(i),WHT
    NEXT
    AeHelp "UP/DOWN choose  ENTER load","ESC cancel"
    k=AeKey()
    IF k=KUP AND sel>1 THEN sel=sel-1
    IF k=KDN AND sel<MIN(n,19) THEN sel=sel+1
    IF k=KESC THEN EXIT SUB
    IF k=KENT THEN AeLoad fl$(sel): EXIT SUB
  LOOP
END SUB

SUB AeLoad fn$
  LOCAL a$, k$, n, r, c, x, y, ch$
  AeNew
  AeStat "Loading "+fn$,YEL
  n=-1
  OPEN fn$ FOR INPUT AS #1
  DO WHILE NOT EOF(#1)
    LINE INPUT #1, a$
    k$=UCASE$(AeF$(a$,1))
    SELECT CASE k$
      CASE "TITLE": ttl$=LEFT$(MID$(a$,INSTR(a$,",")+1),40)
      CASE "INTRO"
        FOR r=0 TO 4
          IF intro$(r)="" THEN intro$(r)=LEFT$(MID$(a$,INSTR(a$,",")+1),160): EXIT FOR
        NEXT
      CASE "WIN": winm$=LEFT$(MID$(a$,INSTR(a$,",")+1),160)
      CASE "FAIL": failm$=LEFT$(MID$(a$,INSTR(a$,",")+1),160)
      CASE "CLASSES"
        FOR r=1 TO 4
          IF AeF$(a$,r+1)<>"" THEN cln$(r)=LEFT$(AeF$(a$,r+1),8)
        NEXT
      CASE "FLOORS": sv(1)=VAL(AeF$(a$,2))
      CASE "GRID": sv(2)=VAL(AeF$(a$,2)): sv(3)=VAL(AeF$(a$,3))
      CASE "ROOMS": sv(4)=VAL(AeF$(a$,2))
      CASE "GOLD": sv(5)=VAL(AeF$(a$,2)): sv(6)=VAL(AeF$(a$,3)): sv(7)=VAL(AeF$(a$,4))
      CASE "WANDER": sv(8)=VAL(AeF$(a$,2))
      CASE "NEEDMAP": sv(9)=VAL(AeF$(a$,2))
      CASE "STORE": sv(10)=VAL(AeF$(a$,2)): sv(11)=VAL(AeF$(a$,3))
      CASE "SEED": sv(12)=VAL(AeF$(a$,2))
      CASE "ITEM"
        IF nit<MXI THEN nit=nit+1: itm$(nit)=AeFix$(a$,7)
      CASE "KIT"
        IF nki<MXK THEN nki=nki+1: kit$(nki)=AeFix$(a$,2)
      CASE "MON"
        IF nmo<MXM THEN nmo=nmo+1: mon$(nmo)=AeFix$(a$,15)
      CASE "QUEST"
        IF nqs<MXQ THEN nqs=nqs+1: qst$(nqs)=AeFix$(a$,3)
      CASE "FLOOR"
        n=VAL(AeF$(a$,2))
        IF n>=1 AND n<=MXF THEN AeClearFloor n: hasmap(n)=1: rowc(n)=0
      CASE "MAP"
        IF n>=1 AND n<=MXF THEN
          r=rowc(n): a$=MID$(a$,5,29)
          FOR c=1 TO LEN(a$)
            ch$=UCASE$(MID$(a$,c,1)): x=(c-1)\2: y=r\2
            IF x<14 AND y<10 THEN
              IF (r MOD 2)=0 AND (c MOD 2)=1 THEN
                AeSetCode n,x,y,MAX(0,INSTR(SYM$,ch$)-1)
              ELSEIF (r MOD 2)=0 AND ch$="-" THEN
                mp(n,x,y)=mp(n,x,y) OR 16
              ELSEIF (c MOD 2)=1 AND ch$="|" THEN
                mp(n,x,y)=mp(n,x,y) OR 32
              ENDIF
            ENDIF
          NEXT
          rowc(n)=r+1
        ENDIF
      CASE ""
      CASE ELSE
        IF LEFT$(k$,1)<>"#" AND nxt<MXX THEN nxt=nxt+1: xtra$(nxt)=LEFT$(a$,100)
    END SELECT
  LOOP
  CLOSE #1
  AeClampSet
  fname$=fn$: dirty=0
END SUB
' fields after the keyword, trimmed, exactly nf of them
FUNCTION AeFix$(a$,nf)
  LOCAL i, o$
  FOR i=1 TO nf
    o$=o$+AeF$(a$,i+1)
    IF i<nf THEN o$=o$+","
  NEXT
  AeFix$=o$
END FUNCTION

SUB AeSaveMenu asnew
  LOCAL f$, e$
  f$=fname$
  IF asnew OR f$="" THEN
    f$=AeIn$("Save as: ",f$,24)
    IF UCASE$(RIGHT$(f$,4))=".ADV" THEN f$=LEFT$(f$,LEN(f$)-4)
    f$=AeSafeName$(f$)
    IF f$="" THEN EXIT SUB
    f$=f$+".ADV"
    e$=DIR$(f$,FILE)
    IF e$<>"" AND UCASE$(f$)<>UCASE$(fname$) THEN
      IF AeYes(f$+" exists. Replace it?")=0 THEN EXIT SUB
    ENDIF
  ENDIF
  AeCheck
  IF nerr>0 THEN
    IF AeYes(AeN$(nerr)+" error(s) found. Save anyway?")=0 THEN AeShowMsg "PROBLEMS": EXIT SUB
  ENDIF
  AeSave f$
  fname$=f$: dirty=0
  AeWait "Saved "+f$
END SUB

' keep letters, digits, - and _ only
FUNCTION AeSafeName$(a$)
  LOCAL i, c$, o$
  FOR i=1 TO LEN(a$)
    c$=MID$(a$,i,1)
    IF INSTR("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",UCASE$(c$))>0 THEN o$=o$+c$
  NEXT
  AeSafeName$=LEFT$(o$,20)
END FUNCTION
SUB AeSave fn$
  LOCAL i, f, r, x, y, s$, c, lr
  OPEN fn$ FOR OUTPUT AS #1
  PRINT #1, "# "+ttl$+" - made with ADVED.BAS (Adventure Creator)"
  PRINT #1, "# Load in TOD.BAS. README.md explains every line."
  PRINT #1, "TITLE,"+ttl$
  FOR i=0 TO 4
    IF intro$(i)<>"" THEN PRINT #1, "INTRO,"+intro$(i)
  NEXT
  PRINT #1, "WIN,"+winm$
  PRINT #1, "FAIL,"+failm$
  PRINT #1, "# class names, in slot order: fighter, wizard, rogue, hero"
  PRINT #1, "CLASSES,"+cln$(1)+","+cln$(2)+","+cln$(3)+","+cln$(4)
  PRINT #1, "FLOORS,"+AeN$(sv(1))
  PRINT #1, "GRID,"+AeN$(sv(2))+","+AeN$(sv(3))
  PRINT #1, "ROOMS,"+AeN$(sv(4))
  PRINT #1, "GOLD,"+AeN$(sv(5))+","+AeN$(sv(6))+","+AeN$(sv(7))
  PRINT #1, "WANDER,"+AeN$(sv(8))
  PRINT #1, "NEEDMAP,"+AeN$(sv(9))
  PRINT #1, "STORE,"+AeN$(sv(10))+","+AeN$(sv(11))
  PRINT #1, "SEED,"+AeN$(sv(12))
  PRINT #1, "# ITEM,kind,name,v1,v2,cost,classes,unknown-name"
  FOR i=1 TO nit: PRINT #1, "ITEM,"+itm$(i): NEXT
  PRINT #1, "# KIT,classes,item"
  FOR i=1 TO nki: PRINT #1, "KIT,"+kit$(i): NEXT
  PRINT #1, "# MON,name,glyph,colour,hp,attack,defense,damage,speed,xp,"
  PRINT #1, "#   minfloor,maxfloor,maxcount,ranged,negotiate%,sound"
  FOR i=1 TO nmo: PRINT #1, "MON,"+mon$(i): NEXT
  PRINT #1, "# QUEST,name,floor,countdown"
  FOR i=1 TO nqs: PRINT #1, "QUEST,"+qst$(i): NEXT
  FOR f=1 TO sv(1)
    IF hasmap(f) THEN
      PRINT #1, "FLOOR,"+AeN$(f)
      ' last row that has anything in it
      lr=0
      FOR y=0 TO sv(3)-1: FOR x=0 TO sv(2)-1
        IF mp(f,x,y)<>0 THEN lr=y*2
        IF mp(f,x,y) AND 32 THEN lr=y*2+1
      NEXT: NEXT
      FOR r=0 TO lr
        s$=""
        y=r\2
        FOR x=0 TO sv(2)-1
          c=AeCode(f,x,y)
          IF (r MOD 2)=0 THEN
            s$=s$+MID$(SYM$,c+1,1)
            IF x<sv(2)-1 THEN
              IF mp(f,x,y) AND 16 THEN s$=s$+"-" ELSE s$=s$+" "
            ENDIF
          ELSE
            IF mp(f,x,y) AND 32 THEN s$=s$+"|" ELSE s$=s$+" "
            IF x<sv(2)-1 THEN s$=s$+" "
          ENDIF
        NEXT
        DO WHILE RIGHT$(s$,1)=" ": s$=LEFT$(s$,LEN(s$)-1): LOOP
        PRINT #1, "MAP,"+s$
      NEXT
    ENDIF
  NEXT
  FOR i=1 TO nxt: PRINT #1, xtra$(i): NEXT
  CLOSE #1
END SUB
