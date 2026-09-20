'=====================================================================
' TUNNELS OF DOOM - Party Creator for PicoMite / PicoCalc
' Builds a party of 1-4 adventurers and writes PARTY.DAT for TOD.BAS
'=====================================================================
CLEAR                     ' drop any variables left by a previous run
OPTION EXPLICIT
OPTION DEFAULT INTEGER
CONST WHT=&HFFFFFF, YEL=&HFFFF00, CYN=&H00FFFF, GRY=&H909090

DIM np, i, k, ry, used(4)
DIM pcl(4), pco(4), php(4), pbn(4), co(4)
DIM pn$(4) LENGTH 12
DIM cln$(4) LENGTH 8
DIM coln$(4) LENGTH 8
co(1)=&H2040FF: co(2)=&HE000E0: co(3)=&H00B000: co(4)=&HE00000
cln$(1)="Fighter": cln$(2)="Wizard": cln$(3)="Rogue": cln$(4)="Hero"
coln$(1)="Blue": coln$(2)="Magenta": coln$(3)="Green": coln$(4)="Red"
FONT 1
RANDOMIZE TIMER
SndSeq "262/90,330/90,392/90,523/220"

DO
  Header "CREATE YOUR PARTY"
  RL "Fighter - all weapons and armor,",WHT
  RL "          cannot read scrolls.",WHT
  RL "Wizard  - few weapons, no armor,",WHT
  RL "          reads scrolls, starts with one.",WHT
  RL "Rogue   - all weapons, light armor,",WHT
  RL "          good at avoiding traps.",WHT
  RL "Hero    - does it all, but only in a",WHT
  RL "          one-player party.",WHT
  ry=ry+10
  RL "Number of players? (1-4)",CYN
  DO: np=GetK()-48: LOOP UNTIL np>=1 AND np<=4
  FOR i=1 TO 4: used(i)=0: NEXT
  FOR i=1 TO np
    MakePlayer i
  NEXT
  DO
    ShowParty
    k=GetK()
    IF k=82 THEN
      FOR i=1 TO np: Roll i: NEXT
    ENDIF
  LOOP UNTIL k=13 OR k=27
  IF k=13 THEN EXIT DO
LOOP

OPEN "PARTY.DAT" FOR OUTPUT AS #1
PRINT #1,"TODPARTY1"
PRINT #1,STR$(np)
FOR i=1 TO np
  PRINT #1,pn$(i)+","+STR$(pcl(i))+","+STR$(pco(i))+","+STR$(php(i))+","+STR$(pbn(i))
NEXT
CLOSE #1
Header "PARTY SAVED"
SndSeq "523/100,659/100,784/100,1047/250"
RL "PARTY.DAT has been written.",WHT
ry=ry+10
RL "Press ENTER to start TOD.BAS,",CYN
RL "any other key to exit.",CYN
IF GetK()=13 THEN PLAY STOP: RUN "TOD.BAS"
CLS
END

SUB MakePlayer n
  LOCAL k, mx, c
  Header "PLAYER"+STR$(n)+" OF"+STR$(np)
  RL "Name?",CYN
  pn$(n)=LineIn$(8,ry,10)
  ry=ry+20
  IF np=1 THEN
    RL "Class: 1 Fighter 2 Wizard 3 Rogue 4 Hero",CYN: mx=4
  ELSE
    RL "Class: 1 Fighter 2 Wizard 3 Rogue",CYN: mx=3
  ENDIF
  DO: k=GetK()-48: LOOP UNTIL k>=1 AND k<=mx
  pcl(n)=k: RL "  "+cln$(k),WHT
  ry=ry+6
  RL "Colour:",CYN
  FOR c=1 TO 4
    IF used(c)=0 THEN RL "  "+STR$(c)+" "+coln$(c),co(c)
  NEXT
  DO: k=GetK()-48: LOOP UNTIL k>=1 AND k<=4
  DO WHILE used(k)
    k=GetK()-48
    IF k<1 OR k>4 THEN k=1
  LOOP
  used(k)=1: pco(n)=k
  Roll n
END SUB

SUB Roll n
  SndSeq "800/15,500/15,900/15,600/25"
  SELECT CASE pcl(n)
    CASE 1: php(n)=10+Dice(6): pbn(n)=2
    CASE 2: php(n)=6+Dice(4): pbn(n)=0
    CASE 3: php(n)=8+Dice(6): pbn(n)=1
    CASE 4: php(n)=12+Dice(6): pbn(n)=2
  END SELECT
  pbn(n)=pbn(n)+Dice(2)-1
END SUB

FUNCTION Dice(s)
  Dice=1+INT(RND*s)
END FUNCTION

SUB ShowParty
  LOCAL n, y
  Header "YOUR PARTY"
  FOR n=1 TO np
    y=ry
    DrawFig 10,y,co(pco(n))
    TEXT 44,y,STR$(n)+". "+pn$(n),"LT",1,1,co(pco(n)),0
    TEXT 44,y+13,cln$(pcl(n))+"  HP"+STR$(php(n))+"  Bonus"+STR$(pbn(n)),"LT",1,1,WHT,0
    ry=ry+36
  NEXT
  ry=ry+10
  RL "R      re-roll hit points and bonus",CYN
  RL "ENTER  save this party",CYN
  RL "ESC    start over",CYN
END SUB

SUB DrawFig x,y,c
  CIRCLE x+12,y+5,4,1,1,c,c
  BOX x+9,y+9,7,8,1,c,c
  LINE x+10,y+17,x+8,y+22,1,c: LINE x+14,y+17,x+16,y+22,1,c
  LINE x+17,y+12,x+21,y+3,1,c
END SUB

SUB Header s$
  CLS 0
  BOX 0,0,320,18,1,YEL,YEL
  TEXT 160,3,s$,"CT",1,1,0,YEL
  ry=30
END SUB

SUB RL s$,c
  TEXT 8,ry,s$,"LT",1,1,c,0: ry=ry+13
END SUB

FUNCTION GetK()
  LOCAL k$
  DO: k$=INKEY$: LOOP UNTIL k$<>""
  SndT 1200,6
  GetK=ASC(UCASE$(k$))
END FUNCTION

FUNCTION LineIn$(x,y,mx)
  LOCAL s$, k$
  DO
    TEXT x,y,s$+"_ ","LT",1,1,WHT,0
    DO: k$=INKEY$: LOOP UNTIL k$<>""
    SndT 1200,6
    IF k$=CHR$(13) AND s$<>"" THEN EXIT DO
    IF k$=CHR$(8) AND LEN(s$)>0 THEN s$=LEFT$(s$,LEN(s$)-1)
    IF k$>=" " AND k$<="z" AND k$<>"," AND LEN(s$)<mx THEN s$=s$+UCASE$(k$)
  LOOP
  LineIn$=s$
END FUNCTION

'===================== sound (PicoMite PLAY TONE) ==================
' Effects are strings of notes "freq/ms,..." played on both
' channels; freq 0 is a rest. Each PAUSE lets the tone finish
' before the next PLAY TONE replaces it.
SUB SndT f,ms
  IF f>0 THEN PLAY TONE f,f,ms
  PAUSE ms
END SUB
SUB SndSeq s$
  LOCAL i, n$
  i=1
  DO
    n$=FIELD$(s$,i,",")
    IF n$="" THEN EXIT DO
    SndT VAL(n$),VAL(FIELD$(n$,2,"/"))
    i=i+1
  LOOP
END SUB
