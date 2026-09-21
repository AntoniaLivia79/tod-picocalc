'=====================================================================
' TUNNELS OF DOOM - PicoMite / PicoCalc port (320x320 LCD)
' Simplified re-imagining of Kevin Kenney's 1982 TI-99/4A classic.
' Needs PARTY.DAT (made by PARTY.BAS) and an adventure module (*.ADV)
'=====================================================================
CLEAR                     ' drop any variables left by a previous run
OPTION EXPLICIT
OPTION DEFAULT INTEGER

CONST MAXF=10, MAXI=48, MAXM=24, MAXQ=8
CONST KUP=128, KDN=129, KLF=130, KRT=131, KEN=13, KESC=27
' Bit fields packed into cell(): exits,type,feature,monster,count,seen,quest,item,gold,map
CONST BMK=0, BTY=4, BFE=6, BMO=10, BMC=15, BSE=18, BQS=19, BIM=23, BGD=31, BMP=41
' Room features
CONST FCH=1, FVA=2, FFO=3, FST=4, FDN=6, FUP=7, FSH=8
' Layout
CONST TS=24, OX=10, OY=24, PANX=236
CONST BLK=0, WHT=&HFFFFFF, YEL=&HFFFF00, CYN=&H00FFFF, GRY=&H909090, GRN=&H58D878

' ---------- module data ----------
' cell() is resized in LoadModule to exactly FLOORS x GRID of the module
DIM cell(1,1,1)
DIM modf$, ttl$, win$, fail$
DIM intro$(5) LENGTH 160
DIM kit$(24) LENGTH 30
DIM nfl, gw, gh, nrm, wander, needmap, st1, st2, seed, nitm, nmon, nq, nintro, nkit
DIM sgold(3), sidx(20)
DIM itk$(MAXI) LENGTH 1
DIM itn$(MAXI) LENGTH 20
DIM igen$(MAXI) LENGTH 14
DIM icl$(MAXI) LENGTH 4
DIM iv1(MAXI), iv2(MAXI), icost(MAXI), ident(MAXI)
DIM mn$(MAXM) LENGTH 16
DIM mgl$(MAXM) LENGTH 1
DIM msd$(MAXM) LENGTH 24
DIM mcol(MAXM), mhp(MAXM), matk(MAXM), mdf(MAXM), mdm(MAXM), msp(MAXM), mxp(MAXM)
DIM mlo(MAXM), mhi(MAXM), mmx(MAXM), mrg(MAXM), mng(MAXM)
DIM qn$(MAXQ) LENGTH 24
DIM qf(MAXQ), qt(MAXQ), qs(MAXQ)
DIM fmn(MAXF)
' ---------- party ----------
DIM np, pcl(4), pco(4), php(4), pwd(4), pxp(4), plv(4), pbn(4), pcw(4), par(4), psh(4), phl(4)
DIM pw(4,1), pam(4,1), pmi(4,9), co(4)
DIM pn$(4) LENGTH 12
DIM cln$(4) LENGTH 8
' ---------- game state ----------
DIM fl, px, py, pd, inrm, ent, steps, gold, rat, dif, over, won, ry
DIM mapf(MAXF), upx(MAXF), upy(MAXF), dnx(MAXF), dny(MAXF)
DIM lg$(4) LENGTH 40
DIM vh$(8) LENGTH 32
DIM fls$(9) LENGTH 20
' ---------- combat ----------
DIM nmc, cmt, cmx(8), cmy(8), chp(8), cpx(4), cpy(4), ay0, ay1, negok, cfe, hallc, cdx, cdy
DIM DX(3), DY(3), ins(5)

DX(1)=1: DX(3)=-1: DY(0)=-1: DY(2)=1
ins(1)=46: ins(2)=82: ins(3)=106: ins(4)=121: ins(5)=130
co(1)=&H2040FF: co(2)=&HE000E0: co(3)=&H00B000: co(4)=&HE00000
cln$(1)="Fighter": cln$(2)="Wizard": cln$(3)="Rogue": cln$(4)="Hero"
FONT 1
RANDOMIZE TIMER
DO
  TitleScr
  PlayGame
LOOP
END

'===================== graphics wrappers ============================
SUB Clr c
  CLS c
END SUB
SUB TxL x,y,s$,c,b
  TEXT x,y,s$,"LT",1,1,c,b
END SUB
SUB TxA x,y,s$,a$,sc,c,b
  TEXT x,y,s$,a$,1,sc,c,b
END SUB
SUB Bx x,y,w,h,c,f
  BOX x,y,w,h,1,c,f
END SUB
SUB Bo x,y,w,h,c
  BOX x,y,w,h,2,c
END SUB
SUB Ln x1,y1,x2,y2,c
  LINE x1,y1,x2,y2,1,c
END SUB
SUB Ci x,y,r,c,f
  CIRCLE x,y,r,1,1,c,f
END SUB
SUB Tr x1,y1,x2,y2,x3,y3,c
  TRIANGLE x1,y1,x2,y2,x3,y3,c,c
END SUB
FUNCTION GetK()
  LOCAL k$
  DO: k$=INKEY$: LOOP UNTIL k$<>""
  GetK=ASC(UCASE$(k$))
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
SUB Sfx e$
  SELECT CASE e$
    CASE "step": SndSeq "70/8"
    CASE "wall": SndSeq "90/50"
    CASE "door": SndSeq "392/25,523/35"
    CASE "wander": SndSeq "220/70,208/70,196/140"
    CASE "guard": SndSeq "147/90,139/150"
    CASE "hit": SndSeq "900/15,330/30"
    CASE "miss": SndSeq "700/25,500/25"
    CASE "kill": SndSeq "523/40,784/70"
    CASE "mhit": SndSeq "110/50,300/25"
    CASE "mmiss": SndSeq "300/25"
    CASE "down": SndSeq "440/80,330/80,220/80,110/160"
    CASE "fire": SndSeq "2500/10,1200/20"
    CASE "magic": SndSeq "400/15,600/15,800/15,1000/15,1300/30"
    CASE "bad": SndSeq "300/60,200/100"
    CASE "good": SndSeq "523/60,784/100"
    CASE "cool": SndSeq "880/40"
    CASE "victory": SndSeq "523/70,659/70,784/120"
    CASE "gold": SndSeq "1319/40,1760/70"
    CASE "item": SndSeq "660/50,880/70"
    CASE "map": SndSeq "523/60,659/60,784/100"
    CASE "quest": SndSeq "523/100,659/100,784/100,1047/250"
    CASE "trap": SndSeq "180/25,120/25,200/25,100/25,150/50"
    CASE "open": SndSeq "784/60,988/60,1175/150"
    CASE "wrong": SndSeq "220/60,165/100"
    CASE "statue": SndSeq "98/250"
    CASE "crush": SndSeq "90/40,70/40,110/40,60/80"
    CASE "buy": SndSeq "1047/30,1319/50"
    CASE "no": SndSeq "220/60"
    CASE "level": SndSeq "392/70,523/70,659/70,784/150"
    CASE "lost": SndSeq "330/200,311/200,294/200,277/400"
    CASE "stdown": SndSeq "523/50,440/50,392/50,330/80"
    CASE "stup": SndSeq "330/50,392/50,440/50,523/80"
    CASE "save": SndSeq "880/30,1175/50"
    CASE "title": SndSeq "262/90,330/90,392/90,523/220"
    CASE "win": SndSeq "523/120,523/60,523/60,784/300,659/120,784/400"
    CASE "dead": SndSeq "392/200,370/200,349/200,330/500"
  END SELECT
END SUB

'===================== text helpers =================================
FUNCTION FS$(a$,n)
  LOCAL s$
  s$=FIELD$(a$,n,",")
  DO WHILE LEFT$(s$,1)=" ": s$=MID$(s$,2): LOOP
  DO WHILE RIGHT$(s$,1)=" ": s$=LEFT$(s$,LEN(s$)-1): LOOP
  FS$=s$
END FUNCTION
FUNCTION NF(a$,n)
  NF=VAL(FS$(a$,n))
END FUNCTION
FUNCTION Rest$(a$)
  Rest$=MID$(a$,INSTR(a$,",")+1)
END FUNCTION
SUB Msg s$
  LOCAL i
  FOR i=0 TO 3: lg$(i)=lg$(i+1): NEXT
  lg$(4)=LEFT$(s$,40)
  DrawLog
END SUB
SUB DrawLog
  LOCAL i, c
  Bx 0,258,320,62,0,0
  FOR i=0 TO 4
    IF i=4 THEN c=YEL ELSE c=WHT
    TxL 0,259+i*12,lg$(i),c,0
  NEXT
END SUB
SUB Prompt s$
  Bx 0,245,320,12,0,0
  TxL 0,245,LEFT$(s$,40),CYN,0
END SUB
SUB TopBar s$,c,b
  Bx 0,0,320,18,b,b
  TxL 2,3,LEFT$(s$,40),c,b
END SUB
SUB RL s$,c
  TxL 8,ry,LEFT$(s$,39),c,0: ry=ry+13
END SUB
SUB WrapTx s$,c
  LOCAL t$, w$, i
  t$=s$
  DO WHILE LEN(t$)>38
    i=39
    DO WHILE i>1 AND MID$(t$,i,1)<>" ": i=i-1: LOOP
    IF i<=1 THEN i=38
    RL LEFT$(t$,i),c: t$=MID$(t$,i+1)
  LOOP
  IF t$<>"" THEN RL t$,c
END SUB
FUNCTION KDir(k)
  KDir=VAL(MID$("0231",k-127,1))
END FUNCTION

'===================== cell access ==================================
FUNCTION CG(x,y,sh,nb)
  CG=(cell(fl,x,y)>>sh) AND ((1<<nb)-1)
END FUNCTION
SUB CS x,y,sh,nb,v
  LOCAL m
  m=((1<<nb)-1)<<sh
  cell(fl,x,y)=(cell(fl,x,y) AND INV m) OR ((v<<sh) AND m)
END SUB
FUNCTION IsUp(x,y)
  IsUp=(x=upx(fl) AND y=upy(fl))
END FUNCTION

'===================== module loading ===============================
SUB LoadModule f$
  LOCAL a$, k$, n, i
  nitm=0: nmon=0: nq=0: nintro=0: nkit=0: nfl=3: gw=12: gh=9: nrm=14
  wander=5: needmap=1: st1=4: st2=8: seed=0: sgold(1)=150: sgold(2)=120: sgold(3)=100
  ttl$="Adventure": win$="Victory!": fail$="Your quest has failed."
  FOR i=0 TO MAXF: fmn(i)=0: NEXT
  FOR i=0 TO MAXI: itk$(i)="": itn$(i)="": iv1(i)=0: iv2(i)=0: ident(i)=0: NEXT
  n=-1
  OPEN f$ FOR INPUT AS #1
  DO WHILE NOT EOF(#1)
    LINE INPUT #1, a$
    k$=UCASE$(FS$(a$,1))
    SELECT CASE k$
      CASE "TITLE": ttl$=Rest$(a$)
      CASE "INTRO": IF nintro<5 THEN intro$(nintro)=LEFT$(Rest$(a$),160): nintro=nintro+1
      CASE "WIN": win$=Rest$(a$)
      CASE "FAIL": fail$=Rest$(a$)
      CASE "FLOORS": nfl=MIN(MAXF,MAX(1,NF(a$,2)))
      CASE "GRID": gw=MIN(14,MAX(3,NF(a$,2))): gh=MIN(10,MAX(3,NF(a$,3)))
      CASE "ROOMS": nrm=MIN(40,MAX(3,NF(a$,2)))
      CASE "GOLD": sgold(1)=NF(a$,2): sgold(2)=NF(a$,3): sgold(3)=NF(a$,4)
      CASE "WANDER": wander=NF(a$,2)
      CASE "NEEDMAP": needmap=NF(a$,2)
      CASE "STORE": st1=NF(a$,2): st2=NF(a$,3)
      CASE "SEED": seed=NF(a$,2)
      CASE "KIT": IF nkit<24 THEN kit$(nkit)=LEFT$(Rest$(a$),30): nkit=nkit+1
      CASE "ITEM"
        IF nitm<MAXI THEN
          nitm=nitm+1: itk$(nitm)=LEFT$(UCASE$(FS$(a$,2)),1): itn$(nitm)=LEFT$(FS$(a$,3),20)
          iv1(nitm)=NF(a$,4): iv2(nitm)=NF(a$,5): icost(nitm)=NF(a$,6)
          icl$(nitm)=LEFT$(UCASE$(FS$(a$,7)),4): IF icl$(nitm)="" THEN icl$(nitm)="FWRH"
          igen$(nitm)=LEFT$(FS$(a$,8),14): IF igen$(nitm)="" THEN igen$(nitm)=LEFT$(itn$(nitm),14)
          ident(nitm)=(itk$(nitm)<>"M")
        ENDIF
      CASE "MON"
        IF nmon<MAXM THEN
          nmon=nmon+1: mn$(nmon)=LEFT$(FS$(a$,2),16): mgl$(nmon)=LEFT$(FS$(a$,3)+"?",1): mcol(nmon)=NF(a$,4)
          mhp(nmon)=MAX(1,NF(a$,5)): matk(nmon)=NF(a$,6): mdf(nmon)=NF(a$,7)
          mdm(nmon)=MAX(1,NF(a$,8)): msp(nmon)=MAX(1,NF(a$,9)): mxp(nmon)=NF(a$,10)
          mlo(nmon)=NF(a$,11): mhi(nmon)=NF(a$,12): mmx(nmon)=MIN(7,MAX(1,NF(a$,13)))
          mrg(nmon)=NF(a$,14): mng(nmon)=NF(a$,15): msd$(nmon)=LEFT$(FS$(a$,16),24)
        ENDIF
      CASE "QUEST"
        IF nq<MAXQ THEN nq=nq+1: qn$(nq)=LEFT$(FS$(a$,2),24): qf(nq)=MAX(1,NF(a$,3)): qt(nq)=NF(a$,4)
      CASE "FLOOR": n=NF(a$,2)
      CASE "MAP"
        IF n>=1 AND n<=MAXF THEN
          IF fmn(n)<19 THEN fmn(n)=fmn(n)+1
        ENDIF
    END SELECT
  LOOP
  CLOSE #1
  modf$=f$
  ERASE cell
  DIM cell(nfl,gw-1,gh-1)
END SUB

FUNCTION FindItem(n$)
  LOCAL i
  FOR i=1 TO nitm
    IF UCASE$(itn$(i))=UCASE$(n$) THEN FindItem=i: EXIT FUNCTION
  NEXT
END FUNCTION

FUNCTION LoadParty()
  LOCAL a$, i
  IF DIR$("PARTY.DAT",FILE)="" THEN EXIT FUNCTION
  OPEN "PARTY.DAT" FOR INPUT AS #1
  LINE INPUT #1,a$
  IF LEFT$(a$,8)<>"TODPARTY" THEN CLOSE #1: EXIT FUNCTION
  LINE INPUT #1,a$: np=MIN(4,MAX(1,VAL(a$)))
  FOR i=1 TO np
    LINE INPUT #1,a$
    pn$(i)=LEFT$(FS$(a$,1),12): pcl(i)=MIN(4,MAX(1,NF(a$,2))): pco(i)=MIN(4,MAX(1,NF(a$,3)))
    php(i)=MAX(1,NF(a$,4)): pbn(i)=NF(a$,5)
    pwd(i)=0: pxp(i)=0: plv(i)=1: pcw(i)=0: par(i)=0: psh(i)=0: phl(i)=0
  NEXT
  CLOSE #1
  LoadParty=1
END FUNCTION

SUB ApplyKits
  LOCAL i, j, it, r
  FOR i=1 TO np
    FOR j=0 TO nkit-1
      IF INSTR(UCASE$(FS$(kit$(j),1)),MID$("FWRH",pcl(i),1)) THEN
        it=FindItem(FS$(kit$(j),2))
        IF it>0 THEN r=GiveItem(i,it,1): ident(it)=1
      ENDIF
    NEXT
  NEXT
END SUB

'===================== dungeon construction ========================
SUB BuildDungeon
  LOCAL f, q
  IF seed THEN RANDOMIZE seed
  FOR f=1 TO nfl
    GenFloor f: Populate f: PlaceSpecial f,0
    mapf(f)=0
  NEXT
  FOR q=1 TO nq
    qs(q)=0: PlaceSpecial MIN(qf(q),nfl),q
  NEXT
  IF seed THEN RANDOMIZE TIMER
END SUB

SUB GenFloor f
  LOCAL i, j, x, y, n, t, bd, bj, d
  LOCAL rx(40), ry2(40)
  fl=f
  FOR y=0 TO gh-1: FOR x=0 TO gw-1: cell(f,x,y)=0: NEXT: NEXT
  IF fmn(f)>0 THEN
    ParseMap f
  ELSE
    n=0: t=0
    DO WHILE n<nrm AND t<3000
      x=INT(RND*gw): y=INT(RND*gh): t=t+1
      IF CG(x,y,BTY,2)=0 THEN CS x,y,BTY,2,2: rx(n)=x: ry2(n)=y: n=n+1
    LOOP
    FOR i=1 TO n-1
      bd=999: bj=0
      FOR j=0 TO i-1
        d=ABS(rx(i)-rx(j))+ABS(ry2(i)-ry2(j))
        IF d<bd THEN bd=d: bj=j
      NEXT
      Carve rx(i),ry2(i),rx(bj),ry2(bj)
    NEXT
    FOR i=1 TO 3
      j=INT(RND*n): t=INT(RND*n)
      IF j<>t THEN Carve rx(j),ry2(j),rx(t),ry2(t)
    NEXT
    CS rx(0),ry2(0),BFE,4,FUP
    IF f<nfl THEN CS rx(n-1),ry2(n-1),BFE,4,FDN
    IF (f=st1 OR f=st2) AND n>2 THEN CS rx(1),ry2(1),BFE,4,FSH
  ENDIF
  ' locate stairs (fall back to first/last room)
  upx(f)=-1: dnx(f)=-1: bj=-1
  FOR y=0 TO gh-1: FOR x=0 TO gw-1
    IF CG(x,y,BTY,2)=2 THEN
      IF upx(f)<0 AND CG(x,y,BFE,4)=FUP THEN upx(f)=x: upy(f)=y
      IF CG(x,y,BFE,4)=FDN THEN dnx(f)=x: dny(f)=y
      IF bj<0 THEN bj=y*16+x
      bd=y*16+x
    ENDIF
  NEXT: NEXT
  IF upx(f)<0 THEN upx(f)=bj MOD 16: upy(f)=bj\16: CS upx(f),upy(f),BFE,4,FUP
  IF f<nfl AND dnx(f)<0 THEN dnx(f)=bd MOD 16: dny(f)=bd\16: CS dnx(f),dny(f),BFE,4,FDN
  IF f=nfl AND dnx(f)>=0 THEN CS dnx(f),dny(f),BFE,4,0: dnx(f)=-1
END SUB

SUB Carve x0,y0,x1,y1
  LOCAL x, y, d, h
  x=x0: y=y0: h=(RND<.5)
  DO WHILE x<>x1 OR y<>y1
    IF (h=1 AND x<>x1) OR y=y1 THEN
      IF x1>x THEN d=1 ELSE d=3
    ELSE
      IF y1>y THEN d=2 ELSE d=0
    ENDIF
    Link x,y,d
    x=x+DX(d): y=y+DY(d)
  LOOP
END SUB

SUB Link x,y,d
  LOCAL nx, ny
  nx=x+DX(d): ny=y+DY(d)
  IF nx<0 OR ny<0 OR nx>=gw OR ny>=gh THEN EXIT SUB
  CS x,y,BMK,4,CG(x,y,BMK,4) OR (1<<d)
  CS nx,ny,BMK,4,CG(nx,ny,BMK,4) OR (1<<((d+2) MOD 4))
  IF CG(x,y,BTY,2)=0 THEN CS x,y,BTY,2,1
  IF CG(nx,ny,BTY,2)=0 THEN CS nx,ny,BTY,2,1
END SUB

' Hand-drawn floor: even rows = cells (even cols) and "-" links, odd rows = "|" links
' The MAP rows are not kept in memory: LoadModule only counts them
' (fmn), and they are read back from the module file here.
SUB ParseMap f
  LOCAL r, c, i, x, y, n, nr, ch$, a$, k$
  LOCAL mr$(18) LENGTH 29
  n=-1
  OPEN modf$ FOR INPUT AS #3
  DO WHILE NOT EOF(#3)
    LINE INPUT #3, a$
    k$=UCASE$(FS$(a$,1))
    IF k$="FLOOR" THEN n=NF(a$,2)
    IF k$="MAP" AND n=f AND nr<19 THEN mr$(nr)=MID$(a$,5,29): nr=nr+1
  LOOP
  CLOSE #3
  FOR r=0 TO nr-1
    FOR c=1 TO LEN(mr$(r))
      ch$=UCASE$(MID$(mr$(r),c,1)): x=(c-1)\2: y=r\2
      IF x<gw AND y<gh THEN
        IF (r MOD 2)=0 AND (c MOD 2)=1 THEN
          IF ch$="+" THEN CS x,y,BTY,2,1
          i=INSTR("RUDSFVCT",ch$)
          IF i>0 THEN CS x,y,BTY,2,2: CS x,y,BFE,4,VAL(MID$("07683214",i,1))
        ELSEIF (r MOD 2)=0 AND ch$="-" THEN
          Link x,y,1
        ELSEIF (c MOD 2)=1 AND ch$="|" THEN
          Link x,y,2
        ENDIF
      ENDIF
    NEXT
  NEXT
END SUB

SUB Populate f
  LOCAL x, y, fe, mt
  fl=f
  FOR y=0 TO gh-1: FOR x=0 TO gw-1
    IF CG(x,y,BTY,2)=2 AND IsUp(x,y)=0 THEN
      fe=CG(x,y,BFE,4)
      IF fe=0 AND fmn(f)=0 THEN
        SELECT CASE INT(RND*100)
          CASE 0 TO 13: fe=FCH
          CASE 14 TO 20: fe=FVA
          CASE 21 TO 28: fe=FFO
          CASE 29 TO 33: fe=FST
        END SELECT
        CS x,y,BFE,4,fe
      ENDIF
      IF fe<FDN THEN
        IF nmon>0 AND RND<.45 THEN mt=PickMon(f): CS x,y,BMO,5,mt: CS x,y,BMC,3,MonCount(mt)
        IF RND<.5 OR fe=FCH OR fe=FVA THEN CS x,y,BGD,10,MIN(1023,(5+INT(RND*(10+f*8)))*(1+(fe=FVA)))
        IF nitm>0 AND (RND<.3 OR fe=FCH OR fe=FVA) THEN CS x,y,BIM,8,PickItem()
      ENDIF
    ENDIF
  NEXT: NEXT
END SUB

' q=0 places this floor's map, q>0 places quest object q (with a guard)
SUB PlaceSpecial f,q
  LOCAL t, x, y
  fl=f
  FOR t=1 TO 800
    x=INT(RND*gw): y=INT(RND*gh)
    IF t>600 THEN x=(t MOD gw): y=((t\gw) MOD gh)
    IF CG(x,y,BTY,2)=2 AND IsUp(x,y)=0 AND CG(x,y,BFE,4)<FDN THEN
      IF q=0 AND CG(x,y,BMP,1)=0 THEN CS x,y,BMP,1,1: EXIT SUB
      IF q>0 AND CG(x,y,BQS,4)=0 THEN
        CS x,y,BQS,4,q
        IF nmon>0 AND CG(x,y,BMO,5)=0 THEN t=PickMon(f+1): CS x,y,BMO,5,t: CS x,y,BMC,3,MonCount(t)
        EXIT SUB
      ENDIF
    ENDIF
  NEXT
  ' no suitable room: put it in the arrival room
  IF q=0 THEN CS upx(f),upy(f),BMP,1,1 ELSE CS upx(f),upy(f),BQS,4,q
END SUB

FUNCTION PickMon(f)
  LOCAL i, t
  FOR t=1 TO 60
    i=1+INT(RND*nmon)
    IF f>=mlo(i) AND f<=mhi(i) THEN PickMon=i: EXIT FUNCTION
  NEXT
  PickMon=1+INT(RND*nmon)
END FUNCTION
FUNCTION MonCount(mt)
  MonCount=MIN(7,1+INT(RND*mmx(mt))+(dif-1)*(RND<.5))
END FUNCTION
FUNCTION PickItem()
  LOCAL i, t
  FOR t=1 TO 60
    i=1+INT(RND*nitm)
    IF INSTR("WRASMX",itk$(i))>0 THEN PickItem=i: EXIT FUNCTION
  NEXT
END FUNCTION

'===================== items =======================================
FUNCTION IName$(it)
  IF itk$(it)="M" AND ident(it)=0 THEN IName$=igen$(it) ELSE IName$=itn$(it)
END FUNCTION
FUNCTION Info$(it)
  SELECT CASE itk$(it)
    CASE "W","R": Info$="Dmg "+STR$(iv1(it))
    CASE "A","S": Info$="Pro "+STR$(iv1(it))
    CASE "X","P","H": Info$="x "+STR$(iv1(it))
    CASE ELSE: Info$="Magic"
  END SELECT
END FUNCTION

FUNCTION GiveItem(p,it,quiet)
  LOCAL kd$, s, j
  kd$=itk$(it)
  IF INSTR("WRAS",kd$)>0 AND INSTR(icl$(it),MID$("FWRH",pcl(p),1))=0 THEN
    IF quiet=0 THEN Msg pn$(p)+" cannot use "+itn$(it)
    EXIT FUNCTION
  ENDIF
  SELECT CASE kd$
    CASE "W","R"
      s=-1
      IF pw(p,1)=0 THEN s=1
      IF pw(p,0)=0 THEN s=0
      IF s<0 THEN
        IF quiet THEN EXIT FUNCTION
        Prompt pn$(p)+": replace weapon 1/2? ESC=no"
        s=GetK()-49
        IF s<0 OR s>1 THEN EXIT FUNCTION
      ENDIF
      pw(p,s)=it: pam(p,s)=0
    CASE "X"
      s=-1
      FOR j=0 TO 1
        IF itk$(pw(p,j))="R" AND iv2(pw(p,j))=iv2(it) THEN s=j
      NEXT
      IF s<0 THEN
        IF quiet=0 THEN Msg pn$(p)+" has no weapon for those."
        EXIT FUNCTION
      ENDIF
      IF pam(p,s)>=60 THEN
        IF quiet=0 THEN Msg "Sorry, no more are allowed."
        EXIT FUNCTION
      ENDIF
      pam(p,s)=MIN(60,pam(p,s)+iv1(it))
    CASE "A": par(p)=it
    CASE "S": psh(p)=it
    CASE "M"
      s=-1
      FOR j=9 TO 0 STEP -1
        IF pmi(p,j)=0 THEN s=j
      NEXT
      IF s<0 THEN
        IF quiet=0 THEN Msg pn$(p)+" can carry no more."
        EXIT FUNCTION
      ENDIF
      pmi(p,s)=it
    CASE "P": rat=rat+iv1(it)
    CASE "H": phl(p)=phl(p)+iv1(it)
    CASE ELSE: EXIT FUNCTION
  END SELECT
  GiveItem=1
END FUNCTION

' list magic items of player p, return slot 0-9 or -1
FUNCTION PickMI(p)
  LOCAL i, k
  Clr 0: TopBar pn$(p)+"'s MAGIC ITEMS",BLK,YEL
  ry=26
  FOR i=0 TO 9
    IF pmi(p,i) THEN RL STR$(i)+"  "+IName$(pmi(p,i)),WHT ELSE RL STR$(i)+"  -",GRY
  NEXT
  DrawLog
  Prompt "Choose 0-9  (ESC=cancel)"
  k=GetK()-48
  IF k<0 OR k>9 THEN PickMI=-1: EXIT FUNCTION
  IF pmi(p,k)=0 THEN PickMI=-1: EXIT FUNCTION
  PickMI=k
END FUNCTION

' use a magic item; u=0 asks who. Returns 1 if something was used
FUNCTION UseMagic(u,cmb)
  LOCAL s, it, e, pw2, t, j
  IF u=0 THEN u=AskP("User?",1)
  IF u=0 THEN EXIT FUNCTION
  s=PickMI(u)
  IF s<0 THEN EXIT FUNCTION
  it=pmi(u,s)
  IF INSTR(icl$(it),MID$("FWRH",pcl(u),1))=0 THEN Msg pn$(u)+" cannot use that.": EXIT FUNCTION
  pmi(u,s)=0: ident(it)=1: e=iv1(it): pw2=MAX(1,iv2(it))
  IF cmb THEN DrawCombat u ELSE Redraw
  Msg pn$(u)+" uses "+itn$(it)
  IF e=2 THEN Sfx "bad" ELSE Sfx "magic"
  SELECT CASE e
    CASE 1
      t=AskP("Heal whom?",0)
      IF t=0 THEN t=u
      pwd(t)=MAX(0,pwd(t)-pw2): Msg pn$(t)+" is healed."
    CASE 2: Msg "It was cursed!": Wound u,pw2
    CASE 3
      IF cmb THEN
        FOR j=1 TO nmc
          IF chp(j)>0 THEN DmgMon j,1+INT(RND*pw2),u
        NEXT
      ELSE
        Msg "Flames flicker and die."
      ENDIF
    CASE 4
      t=0
      IF cmb THEN t=Target(u)
      IF t THEN DmgMon t,pw2+INT(RND*pw2),u ELSE Msg "The magic fizzles."
    CASE 5: mapf(fl)=1: Msg "The floor map is revealed!"
    CASE 6: php(u)=php(u)+pw2: Msg pn$(u)+" feels stronger!"
    CASE 7: pbn(u)=pbn(u)+pw2: Msg pn$(u)+" feels lucky!"
    CASE ELSE: Msg "Nothing happens."
  END SELECT
  UseMagic=1
END FUNCTION

'===================== party helpers ===============================
FUNCTION Alive(i)
  Alive=(pwd(i)<php(i))
END FUNCTION
FUNCTION PartyAlive()
  LOCAL i, n
  FOR i=1 TO np: n=n+Alive(i): NEXT
  PartyAlive=n
END FUNCTION
FUNCTION AllFound()
  LOCAL q
  AllFound=1
  FOR q=1 TO nq
    IF qs(q)<>1 THEN AllFound=0
  NEXT
END FUNCTION
SUB Wound t,dmg
  IF pwd(t)>=php(t) THEN EXIT SUB
  pwd(t)=MIN(php(t),pwd(t)+dmg)
  IF pwd(t)>=php(t) THEN Msg pn$(t)+" is disabled!": Sfx "down"
END SUB
FUNCTION Prot(i)
  Prot=iv1(par(i))+iv1(psh(i))
END FUNCTION
FUNCTION AskP(q$,needA)
  LOCAL k
  DO
    Prompt q$+" (1-"+STR$(np)+",ESC)"
    k=GetK()
    IF k=KESC OR k=KEN THEN EXIT FUNCTION
    k=k-48
    IF k>=1 AND k<=np THEN
      IF needA=0 OR Alive(k) THEN AskP=k: EXIT FUNCTION
      Msg pn$(k)+" is disabled."
    ENDIF
  LOOP
END FUNCTION
SUB GainXP i,x
  pxp(i)=pxp(i)+x
  DO WHILE pxp(i)>=plv(i)*plv(i)*15
    plv(i)=plv(i)+1: php(i)=php(i)+2+INT(RND*4)
    Msg pn$(i)+" reaches level "+STR$(plv(i))+"!": Sfx "level"
  LOOP
END SUB
SUB Sw a,b
  LOCAL t
  t=a: a=b: b=t
END SUB
SUB SwapP a,b
  LOCAL t$, j
  t$=pn$(a): pn$(a)=pn$(b): pn$(b)=t$
  Sw pcl(a),pcl(b): Sw pco(a),pco(b): Sw php(a),php(b): Sw pwd(a),pwd(b)
  Sw pxp(a),pxp(b): Sw plv(a),plv(b): Sw pbn(a),pbn(b): Sw pcw(a),pcw(b)
  Sw par(a),par(b): Sw psh(a),psh(b): Sw phl(a),phl(b)
  FOR j=0 TO 1: Sw pw(a,j),pw(b,j): Sw pam(a,j),pam(b,j): NEXT
  FOR j=0 TO 9: Sw pmi(a,j),pmi(b,j): NEXT
END SUB

'===================== drawing =====================================
SUB DrawFig x,y,c
  Ci x+12,y+5,4,c,c
  Bx x+9,y+9,7,8,c,c
  Ln x+10,y+17,x+8,y+22,c: Ln x+14,y+17,x+16,y+22,c
  Ln x+17,y+12,x+21,y+3,c
END SUB
SUB DrawMon c,r,mt
  LOCAL x, y
  x=OX+c*TS: y=OY+r*TS
  Bx x+3,y+3,18,18,0,mcol(mt)
  TxL x+8,y+7,mgl$(mt),0,mcol(mt)
END SUB

' What lies through side d of cell x,y: 0 wall, 1 hallway, 2 room.
' The neighbour is only read when an exit exists, so the grid edge
' is never looked past.
FUNCTION ExitKind(x,y,d)
  IF ((CG(x,y,BMK,4)>>d) AND 1)=0 THEN EXIT FUNCTION
  IF CG(x+DX(d),y+DY(d),BTY,2)=2 THEN ExitKind=2 ELSE ExitKind=1
END FUNCTION
' Door on a side wall segment running from the near edge (x0,t0..b0)
' to the far edge (x1,t1..b1). It fills the middle half of the
' segment and 70% of the wall height, so it shrinks with distance.
SUB SideDoor x0,t0,b0,x1,t1,b1
  LOCAL xa, ta, ba, xb, tb, bb, da, db, ma, mb, kr
  xa=x0+(x1-x0)\4: ta=t0+(t1-t0)\4: ba=b0+(b1-b0)\4
  xb=x0+(x1-x0)*3\4: tb=t0+(t1-t0)*3\4: bb=b0+(b1-b0)*3\4
  da=ba-(ba-ta)*7\10: db=bb-(bb-tb)*7\10
  Tr xa,da,xb,db,xb,bb,&H8B4513: Tr xa,da,xb,bb,xa,ba,&H8B4513
  Ln xa,da,xb,db,&H402010: Ln xb,db,xb,bb,&H402010
  Ln xa,da,xa,ba,&H402010: Ln xa,ba,xb,bb,&H402010
  ma=(da+ba)\2: mb=(db+bb)\2
  Ln xa,ma,xb,mb,&HA0602A
  kr=MAX(1,ABS(xb-xa)\10)
  Ci xa+(xb-xa)*3\4,(ma+mb)\2+(ba-da)\12,kr,YEL,YEL
END SUB
' Door facing the party on the end wall between L..R, T..B
SUB FrontDoor L,T,R,B
  LOCAL dw, dh, x0, y0
  dw=MAX(6,(R-L)*2\5): dh=MAX(8,(B-T)*3\4)
  x0=(L+R)\2-dw\2: y0=B-dh
  Bx x0-1,y0-1,dw+2,dh+1,&H402010,&H402010
  Bx x0,y0,dw,dh,&H602010,&H8B4513
  IF dw>=14 THEN
    Bx x0+dw\5,y0+dh\10,dw*3\5,dh*7\20,&HA0602A,-1
    Bx x0+dw\5,y0+dh\2,dw*3\5,dh*7\20,&HA0602A,-1
  ENDIF
  Ci x0+dw*4\5,y0+dh*11\20,MAX(1,dw\16),YEL,YEL
END SUB
SUB DrawHall
  LOCAL k, x, y, nx, ny, d, l, r, m, L0, R0, T0, B0, L1, R1, T1, B1, dw, dh
  Clr GRN
  Bx 10,22,300,110,&H40E0F0,&H40E0F0
  Bx 10,132,300,110,WHT,WHT
  x=px: y=py: d=pd: l=(d+3) MOD 4: r=(d+1) MOD 4
  FOR k=0 TO 4
    L0=10+ins(k): R0=309-ins(k): T0=22+ins(k)*11\15: B0=241-ins(k)*11\15
    L1=10+ins(k+1): R1=309-ins(k+1): T1=22+ins(k+1)*11\15: B1=241-ins(k+1)*11\15
    m=CG(x,y,BMK,4)
    ' side walls: an exit into a hallway is an opening, an exit into
    ' a room is a door set in the wall, drawn in perspective
    IF ExitKind(x,y,l)=1 THEN
      Bx L0,T1,L1-L0+1,B1-T1+1,&HB09060,&HD0B070
    ELSE
      Tr L0,T0,L1,T1,L1,B1,&HE8C888: Tr L0,T0,L1,B1,L0,B0,&HE8C888
      Ln L0,T0,L1,T1,&HA08050: Ln L0,B0,L1,B1,&HA08050
      IF ExitKind(x,y,l)=2 THEN SideDoor L0,T0,B0,L1,T1,B1
    ENDIF
    IF ExitKind(x,y,r)=1 THEN
      Bx R1,T1,R0-R1+1,B1-T1+1,&HB09060,&HD0B070
    ELSE
      Tr R0,T0,R1,T1,R1,B1,&HE8C888: Tr R0,T0,R1,B1,R0,B0,&HE8C888
      Ln R0,T0,R1,T1,&HA08050: Ln R0,B0,R1,B1,&HA08050
      IF ExitKind(x,y,r)=2 THEN SideDoor R0,T0,B0,R1,T1,B1
    ENDIF
    IF ((m>>d) AND 1)=0 THEN Bx L1,T1,R1-L1+1,B1-T1+1,&HA06050,&HFF8070: EXIT FOR
    nx=x+DX(d): ny=y+DY(d)
    IF CG(nx,ny,BTY,2)=2 THEN
      Bx L1,T1,R1-L1+1,B1-T1+1,&HA06050,&HFF8070
      FrontDoor L1,T1,R1,B1
      EXIT FOR
    ENDIF
    x=nx: y=ny
    IF k=4 THEN Bx L1,T1,R1-L1+1,B1-T1+1,0,0
  NEXT
  TopBar "FLOOR "+STR$(fl)+"  FACING "+MID$("NORTHEAST SOUTHWEST",pd*5+1,5)+"  GOLD "+STR$(gold),0,GRN
  DrawLog
END SUB

' room / combat arena. hall=1 draws a 3-row corridor strip
SUB DrawArena hall
  LOCAL m, x, y, fe, fc
  Clr 0: fc=&HC8C8C8
  IF hall THEN
    Bx OX-4,OY+3*TS-4,9*TS+8,3*TS+8,&H303030,&H303030
    Bx OX,OY+3*TS,9*TS,3*TS,fc,fc
    EXIT SUB
  ENDIF
  Bx OX-4,OY-4,9*TS+8,9*TS+8,&H505050,&H505050
  Bx OX,OY,9*TS,9*TS,fc,fc
  m=CG(px,py,BMK,4)
  IF m AND 1 THEN Bx OX+4*TS,OY-4,TS,4,fc,fc
  IF m AND 2 THEN Bx OX+9*TS,OY+4*TS,4,TS,fc,fc
  IF m AND 4 THEN Bx OX+4*TS,OY+9*TS,TS,4,fc,fc
  IF m AND 8 THEN Bx OX-4,OY+4*TS,4,TS,fc,fc
  x=OX+4*TS+12: y=OY+4*TS+12: fe=CG(px,py,BFE,4)
  SELECT CASE fe
    CASE FCH: Bx x-10,y-7,20,14,0,&H905020: Ln x-10,y-2,x+9,y-2,0
    CASE FVA: Bx x-11,y-11,22,22,0,&H606070: Ci x,y,6,YEL,&H606070
    CASE FFO: Ci x,y,10,&H0000C0,&H40A0FF
    CASE FST: Ci x,y-6,4,GRY,GRY: Bx x-4,y-2,9,12,GRY,GRY
    CASE FDN,FUP
      Bx x-11,y-11,22,22,0,WHT
      FOR m=0 TO 3: Ln x-11,y-11+m*6,x+10,y-11+m*6,0: NEXT
      IF fe=FDN THEN TxL x-4,y-6,"v",0,WHT ELSE TxL x-4,y-6,"^",0,WHT
    CASE FSH: TxA x,y-12,"$","CT",2,&H00A000,fc
  END SELECT
  IF fe=FCH OR fe=FVA THEN EXIT SUB
  IF CG(px,py,BGD,10) THEN Ci OX+2*TS+12,OY+6*TS+12,7,0,YEL
  IF CG(px,py,BIM,8) THEN Tr OX+6*TS+12,OY+2*TS+3,OX+6*TS+3,OY+2*TS+21,OX+6*TS+21,OY+2*TS+21,&HE000E0
  IF CG(px,py,BQS,4) THEN TxA OX+2*TS+12,OY+2*TS+4,"*","CT",2,&HFF8000,fc
  IF CG(px,py,BMP,1) THEN Bx OX+6*TS+4,OY+6*TS+6,16,12,0,&HF0E0A0
END SUB

SUB Panel cur,cmb
  LOCAL i, y, c
  FOR i=1 TO np
    y=OY+(i-1)*55: c=co(pco(i))
    IF cur=i THEN TxL PANX,y,STR$(i)+" "+LEFT$(pn$(i),8),0,c ELSE TxL PANX,y,STR$(i)+" "+LEFT$(pn$(i),8),c,0
    IF Alive(i) THEN DrawFig PANX,y+12,c ELSE TxL PANX+4,y+20,"--",GRY,0
    TxL PANX+26,y+14,"HP "+STR$(php(i)),WHT,0
    TxL PANX+26,y+26,"WD "+STR$(pwd(i)),WHT,0
    IF cmb AND Alive(i) THEN TxL PANX+26,y+38,Ind$(i),YEL,0
  NEXT
END SUB

SUB DrawRoomScr
  LOCAL i, mt, n
  DrawArena 0
  mt=CG(px,py,BMO,5): n=CG(px,py,BMC,3)
  IF mt>0 THEN
    FOR i=1 TO n: DrawMon i,1,mt: NEXT
  ENDIF
  SetSlots 0
  FOR i=1 TO np
    IF Alive(i) THEN DrawFig OX+cpx(i)*TS,OY+cpy(i)*TS,co(pco(i))
  NEXT
  Panel 0,0
  TopBar "FLOOR "+STR$(fl)+"  ROOM  GOLD "+STR$(gold),WHT,&H303030
  DrawLog
END SUB

SUB Redraw
  IF inrm THEN DrawRoomScr ELSE DrawHall
  Prompt "Select movement option  (?=help)"
END SUB

SUB ShowMapScr
  LOCAL x, y, csz, x0, y0, c, m, sx, sy, s, h, fe
  csz=MIN(300\gw,220\gh): h=csz\2
  x0=160-(gw*csz)\2: y0=20+(220-gh*csz)\2
  Clr GRN: Bx 8,16,304,228,&HC8C8C8,&HC8C8C8
  FOR y=0 TO gh-1: FOR x=0 TO gw-1
    s=CG(x,y,BSE,1)
    IF CG(x,y,BTY,2)>0 AND (s OR mapf(fl)) THEN
      IF s THEN c=0 ELSE c=&H3050FF
      sx=x0+x*csz+h: sy=y0+y*csz+h: m=CG(x,y,BMK,4)
      IF m AND 1 THEN Ln sx,sy,sx,sy-h,c: Ln sx+1,sy,sx+1,sy-h,c
      IF m AND 2 THEN Ln sx,sy,sx+h,sy,c: Ln sx,sy+1,sx+h,sy+1,c
      IF m AND 4 THEN Ln sx,sy,sx,sy+h,c: Ln sx+1,sy,sx+1,sy+h,c
      IF m AND 8 THEN Ln sx,sy,sx-h,sy,c: Ln sx,sy+1,sx-h,sy+1,c
      IF CG(x,y,BTY,2)=2 THEN
        fe=CG(x,y,BFE,4)
        Bx sx-4,sy-4,10,10,c,&HC8C8C8
        IF fe=FUP THEN Bx sx-2,sy-2,6,6,c,WHT
        IF fe=FDN THEN Bx sx-2,sy-2,6,6,c,c
        IF fe=FSH THEN Bx sx-2,sy-2,6,6,c,YEL
      ENDIF
    ENDIF
  NEXT: NEXT
  Bo x0+px*csz+h-7,y0+py*csz+h-7,16,16,&HFF0000
  TxA 160,250,"FLOOR: "+STR$(fl),"CT",1,0,GRN
  IF mapf(fl)=0 THEN TxA 160,266,"(map of this floor not found)","CT",1,0,GRN
  TxA 160,296,"PRESS ANY KEY WHEN FINISHED","CT",1,0,GRN
  m=GetK()
END SUB

'===================== reports & screens ===========================
FUNCTION Ind$(i)
  LOCAL d
  d=PHit(i)-MHit(i)
  IF d>=30 THEN
    Ind$="++"
  ELSEIF d>=10 THEN
    Ind$="+"
  ELSEIF d>-10 THEN
    Ind$="0"
  ELSEIF d>-30 THEN
    Ind$="-"
  ELSE
    Ind$="--"
  ENDIF
END FUNCTION
FUNCTION WName$(i,j)
  LOCAL w
  w=pw(i,j)
  IF w=0 THEN WName$="Hands": EXIT FUNCTION
  WName$=itn$(w)
  IF itk$(w)="R" THEN WName$=WName$+" ("+STR$(pam(i,j))+")"
END FUNCTION

SUB PlayerRpt
  LOCAL i, j, k, n
  i=1
  DO
    Clr 0: TopBar "PLAYER REPORT  "+STR$(i)+"/"+STR$(np),0,YEL
    ry=24
    RL pn$(i)+" the "+cln$(pcl(i)),co(pco(i))
    RL "Level "+STR$(plv(i))+"   Experience "+STR$(pxp(i)),WHT
    RL "Hit points "+STR$(php(i))+"   Wounds "+STR$(pwd(i)),WHT
    RL "Bonus "+STR$(pbn(i))+"   Protection "+STR$(Prot(i)),WHT
    FOR j=0 TO 1
      IF pcw(i)=j THEN n=YEL ELSE n=WHT
      RL "Weapon "+STR$(j+1)+": "+WName$(i,j)+"  Dmg "+STR$(WDmg(i,j,0)),n
    NEXT
    IF par(i) THEN RL "Armor: "+itn$(par(i)),WHT ELSE RL "Armor: none",WHT
    IF psh(i) THEN RL "Shield: "+itn$(psh(i)),WHT ELSE RL "Shield: none",WHT
    RL "Healing left: "+STR$(phl(i)),WHT
    RL "Magic items:",YEL
    FOR j=0 TO 9
      IF pmi(i,j) THEN RL "  "+IName$(pmi(i,j)),WHT
    NEXT
    Prompt "UP/DOWN=other player  any key=back"
    k=GetK()
    IF k=KUP THEN
      i=i+1: IF i>np THEN i=1
    ELSEIF k=KDN THEN
      i=i-1: IF i<1 THEN i=np
    ELSE
      EXIT SUB
    ENDIF
  LOOP
END SUB

SUB PartyRpt
  LOCAL i, q, k, s$
  Clr 0: TopBar "PARTY REPORT",0,YEL
  ry=24
  RL "Gold: "+STR$(gold)+"    Rations: "+STR$(rat),WHT
  RL "Steps taken: "+STR$(steps),WHT
  ry=ry+6: RL "QUEST OBJECTS",YEL
  FOR q=1 TO nq
    IF qs(q)=1 THEN
      s$="FOUND"
    ELSEIF qs(q)=2 THEN
      s$="DESTROYED"
    ELSEIF qt(q)>0 THEN
      s$=STR$(qt(q))
    ELSE
      s$="-"
    ENDIF
    RL LEFT$(qn$(q)+SPACE$(24),24)+s$,WHT
  NEXT
  ry=ry+6: RL "SUMMARY            HP   WD  LVL",YEL
  FOR i=1 TO np
    RL LEFT$(pn$(i)+SPACE$(18),18)+RIGHT$("   "+STR$(php(i)),4)+RIGHT$("    "+STR$(pwd(i)),5)+RIGHT$("    "+STR$(plv(i)),5),co(pco(i))
  NEXT
  Prompt "Press any key"
  k=GetK()
END SUB

SUB MonRpt
  LOCAL k
  Clr 0: TopBar "MONSTER REPORT",0,YEL
  ry=24
  RL mn$(cmt),mcol(cmt)
  RL "Maximum hit points "+STR$(mhp(cmt)),WHT
  RL "Experience "+STR$(mxp(cmt)),WHT
  RL "Attack "+STR$(matk(cmt))+"   Max damage "+STR$(mdm(cmt)),WHT
  RL "Defense "+STR$(mdf(cmt))+"   Speed "+STR$(msp(cmt)),WHT
  IF mrg(cmt) THEN RL "Attacks at range",WHT ELSE RL "Melee only",WHT
  RL "Negotiation chance "+STR$(mng(cmt))+"%",WHT
  Prompt "Press any key"
  k=GetK()
END SUB

SUB HelpScr
  LOCAL k
  Clr 0: TopBar "COMMAND SUMMARY",0,YEL
  ry=24
  RL "ARROWS  move / turn / attack",WHT
  RL "> <     go down / up stairs (. ,)",WHT
  RL "M map   1 players  2 party  3 monsters",WHT
  RL "U use magic item   T trade item",WHT
  RL "O change formation L listen at door",WHT
  RL "K save game        Q quit quest",WHT
  ry=ry+8: RL "COMBAT",YEL
  RL "Arrow: step, or attack adjacent foe",WHT
  RL "F fire ranged weapon (SPACE fires)",WHT
  RL "W switch weapon  N negotiate",WHT
  RL "U magic item     ENTER end turn",WHT
  ry=ry+8: RL "In hallways UP walks forward,",GRY
  RL "LEFT/RIGHT turn, DOWN turns around.",GRY
  Prompt "Press any key"
  k=GetK()
END SUB

'===================== store ======================================
SUB Store
  LOCAL n, i, b, k, it
  n=0
  FOR i=1 TO nitm
    IF icost(i)>0 AND n<17 THEN n=n+1: sidx(n)=i
  NEXT
  IF n=0 THEN Msg "There is no store here.": EXIT SUB
  DO
    Clr 0: TopBar "GENERAL STORE        GOLD "+STR$(gold),0,YEL
    FOR i=1 TO n
      it=sidx(i)
      TxL 4,10+i*12,CHR$(64+i)+" "+LEFT$(itn$(it)+SPACE$(20),20)+LEFT$(Info$(it)+SPACE$(7),7)+RIGHT$("    "+STR$(icost(it)),5),WHT,0
    NEXT
    FOR i=1 TO np: TxL (i-1)*80,232,STR$(i)+" "+LEFT$(pn$(i),7),co(pco(i)),0: NEXT
    DrawLog
    Prompt "Buyer? (1-"+STR$(np)+", ESC=leave store)"
    b=GetK()
    IF b=KESC THEN EXIT SUB
    b=b-48
    IF b>=1 AND b<=np THEN
      Prompt "Buy which (A-"+CHR$(64+n)+") for "+pn$(b)+"?"
      k=GetK()-64
      IF k>=1 AND k<=n THEN
        it=sidx(k)
        IF gold<icost(it) THEN
          Msg "Not enough gold.": Sfx "no"
        ELSEIF GiveItem(b,it,0) THEN
          gold=gold-icost(it): ident(it)=1: Msg pn$(b)+" buys "+itn$(it): Sfx "buy"
        ENDIF
      ENDIF
    ENDIF
  LOOP
END SUB

'===================== exploration =================================
SUB PlayGame
  LOCAL k
  DO WHILE over=0
    Redraw
    k=GetK()
    SELECT CASE k
      CASE KUP,KDN,KLF,KRT: Walk k
      CASE 77: ShowMapScr
      CASE 49: PlayerRpt
      CASE 50: PartyRpt
      CASE 51: Msg "There are no monsters here."
      CASE 85: IF UseMagic(0,0) THEN TakeStep 0
      CASE 84: Trade
      CASE 79: Formation
      CASE 76: Listen
      CASE 75: SaveGame
      CASE 62,46: Stairs 1
      CASE 60,44: Stairs -1
      CASE 63,72: HelpScr
      CASE 81
        Prompt "Abandon this quest? (Y/N)"
        IF GetK()=89 THEN over=3
    END SELECT
  LOOP
  EndScr
END SUB

SUB Walk k
  LOCAL d, m
  m=CG(px,py,BMK,4)
  IF inrm THEN
    d=KDir(k)
    IF ((m>>d) AND 1)=0 THEN Sfx "wall": Msg "There is no exit that way.": EXIT SUB
    pd=d: MoveTo d
  ELSE
    SELECT CASE k
      CASE KLF: pd=(pd+3) MOD 4
      CASE KRT: pd=(pd+1) MOD 4
      CASE KDN: pd=(pd+2) MOD 4
      CASE KUP
        IF ((m>>pd) AND 1)=0 THEN Sfx "wall": Msg "A wall blocks the way.": EXIT SUB
        MoveTo pd
    END SELECT
  ENDIF
END SUB

SUB MoveTo d
  px=px+DX(d): py=py+DY(d)
  CS px,py,BSE,1,1
  IF CG(px,py,BTY,2)=2 THEN
    inrm=1: ent=(d+2) MOD 4: TakeStep 0
    IF over=0 THEN RoomEvents
  ELSE
    inrm=0: TakeStep 1
  ENDIF
END SUB

SUB TakeStep hall
  LOCAL i, mt, r
  steps=steps+1
  IF hall THEN Sfx "step"
  FOR i=1 TO np
    IF phl(i)>0 AND pwd(i)>0 THEN pwd(i)=pwd(i)-1: phl(i)=phl(i)-1
  NEXT
  IF steps MOD 10=0 THEN TimeStep
  IF over THEN EXIT SUB
  IF hall AND nmon>0 AND RND*100<wander THEN
    mt=PickMon(fl): DrawHall: Msg "A wandering "+mn$(mt)+" appears!": Sfx "wander": PAUSE 500
    r=Combat(1,mt,MonCount(mt))
  ENDIF
END SUB

SUB TimeStep
  LOCAL q, i
  FOR q=1 TO nq
    IF qs(q)=0 AND qt(q)>0 THEN
      qt(q)=qt(q)-1
      IF qt(q)=0 THEN qs(q)=2: Msg qn$(q)+" is destroyed!": Sfx "lost": over=2
    ENDIF
  NEXT
  IF rat>0 THEN
    rat=rat-1
    FOR i=1 TO np
      IF pwd(i)>0 THEN pwd(i)=pwd(i)-1
    NEXT
  ELSE
    Msg "The party is hungry."
  ENDIF
END SUB

SUB Stairs d
  LOCAL fe
  fe=CG(px,py,BFE,4)
  IF inrm=0 THEN Msg "There are no stairs here.": EXIT SUB
  IF d>0 THEN
    IF fe<>FDN THEN Msg "There are no stairs down here.": EXIT SUB
    IF needmap AND mapf(fl)=0 THEN Msg "You need the map of this floor!": EXIT SUB
    fl=fl+1: px=upx(fl): py=upy(fl)
  ELSE
    IF fe<>FUP THEN Msg "There are no stairs up here.": EXIT SUB
    IF fl=1 THEN
      IF AllFound() THEN won=1: over=4: EXIT SUB
      Msg "You climb to the surface.": Store: EXIT SUB
    ENDIF
    fl=fl-1: px=dnx(fl): py=dny(fl)
  ENDIF
  inrm=1: ent=2: CS px,py,BSE,1,1
  IF d>0 THEN Sfx "stdown" ELSE Sfx "stup"
  Msg "You are now on floor "+STR$(fl)+"."
END SUB

SUB Listen
  LOCAL nx, ny, mt
  IF inrm THEN Msg "Listen at doors from the hallway.": EXIT SUB
  nx=px+DX(pd): ny=py+DY(pd)
  IF ((CG(px,py,BMK,4)>>pd) AND 1)=0 THEN Msg "You hear only rock.": EXIT SUB
  IF CG(nx,ny,BTY,2)<>2 THEN Msg "There is no door ahead.": EXIT SUB
  TakeStep 0
  mt=CG(nx,ny,BMO,5)
  IF mt>0 AND RND<.7 THEN Msg "You hear "+msd$(mt)+"." ELSE Msg "You hear nothing."
END SUB

SUB Trade
  LOCAL a, b, s, j, t
  a=AskP("Trade from?",0): IF a=0 THEN EXIT SUB
  s=PickMI(a): IF s<0 THEN EXIT SUB
  Redraw
  b=AskP("Give to? (ESC=drop it)",0)
  IF b=0 THEN pmi(a,s)=0: Msg "Item dropped.": TakeStep 0: EXIT SUB
  t=-1
  FOR j=9 TO 0 STEP -1
    IF pmi(b,j)=0 THEN t=j
  NEXT
  IF t<0 THEN Msg pn$(b)+" can carry no more.": EXIT SUB
  pmi(b,t)=pmi(a,s): pmi(a,s)=0: Msg "Traded to "+pn$(b)+"."
  TakeStep 0
END SUB

SUB Formation
  LOCAL a
  a=AskP("Move whom to the front?",0)
  IF a>1 THEN SwapP 1,a: Msg pn$(1)+" now leads the party."
END SUB

'===================== rooms =======================================
SUB RoomEvents
  LOCAL mt, r
  mt=CG(px,py,BMO,5)
  DrawRoomScr
  IF mt=0 THEN Sfx "door"
  IF mt>0 THEN
    Msg STR$(CG(px,py,BMC,3))+" "+mn$(mt)+" guard this room!": Sfx "guard": PAUSE 500
    r=Combat(0,mt,CG(px,py,BMC,3))
    IF r<0 THEN EXIT SUB
    IF r=2 THEN
      CS px,py,BMC,3,MAX(1,MonLeft()): Msg "The monsters keep their treasure."
      EXIT SUB
    ENDIF
    CS px,py,BMO,5,0: CS px,py,BMC,3,0
    DrawRoomScr
  ENDIF
  Treasure
END SUB

SUB Treasure
  LOCAL fe, p
  fe=CG(px,py,BFE,4)
  SELECT CASE fe
    CASE FCH
      p=AskP("Who will open the chest?",1)
      IF p=0 THEN EXIT SUB
      IF RND*100<35-25*(pcl(p)>=3) THEN Msg "A trap! "+pn$(p)+" is hurt.": Sfx "trap": Wound p,1+INT(RND*(4+fl))
      CS px,py,BFE,4,0: DrawRoomScr: Reveal
    CASE FVA
      IF Vault()=0 THEN DrawRoomScr: EXIT SUB
      CS px,py,BFE,4,0: DrawRoomScr: Reveal
    CASE FFO: Reveal: Fountain
    CASE FST: Reveal: Statue
    CASE FSH
      Prompt "Visit the store? (Y/N)"
      IF GetK()=89 THEN Store
    CASE FDN: Reveal: Msg "Stairs lead down. Press > to descend."
    CASE FUP: Msg "Stairs lead up. Press < to climb."
    CASE ELSE: Reveal
  END SELECT
END SUB

SUB Reveal
  LOCAL g, it, q, p
  g=CG(px,py,BGD,10)*10
  IF g>0 THEN gold=gold+g: CS px,py,BGD,10,0: Msg "Found "+STR$(g)+" gold pieces!": Sfx "gold"
  q=CG(px,py,BQS,4)
  IF q>0 THEN
    IF qs(q)=0 THEN qs(q)=1
    CS px,py,BQS,4,0: Msg "You have found "+qn$(q)+"!": Sfx "quest": PAUSE 400
    IF AllFound() THEN Msg "Quest complete! Return to the surface."
  ENDIF
  IF CG(px,py,BMP,1) THEN mapf(fl)=1: CS px,py,BMP,1,0: Msg "You found the map of floor "+STR$(fl)+"!": Sfx "map"
  it=CG(px,py,BIM,8)
  IF it>0 THEN
    Msg "Found "+IName$(it)+"!": Sfx "item"
    DO
      p=AskP("Give to?",0)
      IF p=0 THEN Msg "You leave it behind.": EXIT SUB
      IF GiveItem(p,it,0) THEN CS px,py,BIM,8,0: Msg pn$(p)+" takes it.": EXIT SUB
    LOOP
  ENDIF
END SUB

FUNCTION Vault()
  LOCAL c$, g$, p, hi, i, k, cor, nh
  hi=MIN(9,3+fl\2): c$=""
  FOR i=1 TO 3: c$=c$+STR$(1+INT(RND*hi)): NEXT
  p=AskP("Who will open the vault?",1)
  DO
    IF p=0 THEN Msg "The combination scrambles.": EXIT FUNCTION
    Clr 0: TopBar "VAULT",0,YEL
    ry=24
    RL "Combination: 3 digits, each 1 to "+STR$(hi),WHT
    RL pn$(p)+"   HP "+STR$(php(p))+"  WD "+STR$(pwd(p)),co(pco(p))
    ry=ry+6
    FOR i=1 TO nh: RL "  "+vh$(i),WHT: NEXT
    DrawLog
    g$=""
    DO WHILE LEN(g$)<3
      Prompt "Guess: "+g$+"_   (ESC=give up)"
      k=GetK()
      IF k=KESC THEN p=0: EXIT DO
      IF k>=49 AND k<=48+hi THEN g$=g$+CHR$(k)
    LOOP
    IF p>0 THEN
      IF g$=c$ THEN Msg "You have found the combination!": Sfx "open": Vault=1: EXIT FUNCTION
      Sfx "wrong": cor=0
      FOR i=1 TO 3
        IF MID$(g$,i,1)=MID$(c$,i,1) THEN cor=cor+1
      NEXT
      IF nh=8 THEN
        FOR i=1 TO 7: vh$(i)=vh$(i+1): NEXT
      ELSE
        nh=nh+1
      ENDIF
      IF VAL(g$)<VAL(c$) THEN vh$(nh)=g$+"   "+STR$(cor)+" right   HIGHER" ELSE vh$(nh)=g$+"   "+STR$(cor)+" right   LOWER"
      IF RND<.3 THEN
        Msg "The vault's magic burns "+pn$(p)+"!": Sfx "trap": Wound p,1+INT(RND*3)
        IF Alive(p)=0 THEN p=AskP("Who will continue?",1)
      ENDIF
    ENDIF
  LOOP
END FUNCTION

SUB Fountain
  LOCAL p, r, used(4)
  DO
    DrawRoomScr
    p=AskP("Who drinks from the fountain?",0)
    IF p=0 THEN EXIT SUB
    IF used(p) THEN
      Msg pn$(p)+" has already drunk."
    ELSE
      used(p)=1
      SELECT CASE INT(RND*6)
        CASE 0: pwd(p)=0: Msg pn$(p)+" is fully healed!": Sfx "good"
        CASE 1: r=1+INT(RND*3): php(p)=php(p)+r: Msg pn$(p)+" gains "+STR$(r)+" hit points!": Sfx "good"
        CASE 2: pbn(p)=pbn(p)+1: Msg pn$(p)+" feels lucky!": Sfx "good"
        CASE 3: Msg pn$(p)+" is poisoned!": Sfx "bad": Wound p,1+INT(RND*4)
        CASE 4: pbn(p)=MAX(0,pbn(p)-1): Msg pn$(p)+" feels unlucky.": Sfx "bad"
        CASE ELSE: Msg "The water is cool and refreshing.": Sfx "cool"
      END SELECT
    ENDIF
  LOOP
END SUB

SUB Statue
  LOCAL p, s, it, amt
  p=AskP("Living statue user?",0): IF p=0 THEN EXIT SUB
  s=PickMI(p)
  DrawRoomScr
  IF s<0 THEN EXIT SUB
  it=pmi(p,s)
  Prompt "Offer gold: 1-9 x10  (ESC=none)"
  amt=(GetK()-48)*10
  IF amt<10 OR amt>90 THEN EXIT SUB
  IF amt>gold THEN Msg "You do not have that much gold.": EXIT SUB
  gold=gold-amt
  IF amt>=10+INT(RND*50) THEN
    ident(it)=1: Sfx "statue": Msg "The statue says: it is "+itn$(it)
  ELSEIF RND<.3 THEN
    pmi(p,s)=0: Msg "The statue crushes the item!": Sfx "crush"
  ELSE
    Msg "The statue is silent."
  ENDIF
END SUB

'===================== combat ======================================
FUNCTION MonLeft()
  LOCAL j, n
  FOR j=1 TO nmc
    IF chp(j)>0 THEN n=n+1
  NEXT
  MonLeft=n
END FUNCTION
FUNCTION PHit(i)
  PHit=MIN(95,MAX(5,55+5*(plv(i)+pbn(i))-6*mdf(cmt)))
END FUNCTION
FUNCTION MHit(i)
  MHit=MIN(95,MAX(5,45+6*matk(cmt)-5*Prot(i)))
END FUNCTION
FUNCTION WDmg(i,j,melee)
  LOCAL w
  w=pw(i,j)
  IF w=0 THEN WDmg=2: EXIT FUNCTION
  IF melee AND itk$(w)="R" THEN WDmg=2 ELSE WDmg=MAX(1,iv1(w))
END FUNCTION

SUB SetSlots hall
  LOCAL i, ix, iy, a, b
  cdx=4+4*DX(ent): cdy=4+4*DY(ent): ix=-DX(ent): iy=-DY(ent)
  FOR i=1 TO np
    IF hall THEN
      cpx(i)=VAL(MID$("1100",i,1)): cpy(i)=VAL(MID$("4345",i,1))
    ELSE
      a=VAL(MID$("1100",i,1)): b=VAL(MID$("0101",i,1))
      cpx(i)=cdx+ix*a-iy*b: cpy(i)=cdy+iy*a+ix*b
    ENDIF
  NEXT
END SUB

FUNCTION Occ(x,y)
  LOCAL i
  IF x<0 OR x>8 OR y<ay0 OR y>ay1 THEN Occ=99: EXIT FUNCTION
  IF cfe>0 AND x=4 AND y=4 THEN Occ=99: EXIT FUNCTION
  FOR i=1 TO nmc
    IF chp(i)>0 AND cmx(i)=x AND cmy(i)=y THEN Occ=i: EXIT FUNCTION
  NEXT
  FOR i=1 TO np
    IF Alive(i) AND cpx(i)=x AND cpy(i)=y THEN Occ=-i: EXIT FUNCTION
  NEXT
END FUNCTION

SUB PlaceMon i
  LOCAL t, x, y
  FOR t=1 TO 300
    x=INT(RND*9): y=ay0+INT(RND*(ay1-ay0+1))
    IF Occ(x,y)=0 THEN
      IF (hallc AND x>=5) OR (hallc=0 AND ABS(x-cdx)+ABS(y-cdy)>=5) THEN cmx(i)=x: cmy(i)=y: EXIT SUB
    ENDIF
  NEXT
  FOR y=ay0 TO ay1: FOR x=0 TO 8
    IF Occ(x,y)=0 THEN cmx(i)=x: cmy(i)=y: EXIT SUB
  NEXT: NEXT
END SUB

' returns 1 won, 2 paid off, -1 party destroyed
FUNCTION Combat(hall,mt,n)
  LOCAL i, j, r
  cmt=mt: nmc=MIN(8,MAX(1,n)): hallc=hall: negok=1
  IF hall THEN
    ay0=3: ay1=5: cfe=0
  ELSE
    ay0=0: ay1=8: cfe=CG(px,py,BFE,4)
  ENDIF
  FOR j=1 TO 8: chp(j)=0: NEXT
  SetSlots hall
  FOR j=1 TO nmc: PlaceMon j: chp(j)=mhp(mt): NEXT
  DO
    FOR i=1 TO np
      IF Alive(i) AND MonLeft()>0 THEN
        r=PTurn(i)
        IF r=2 THEN Combat=2: EXIT FUNCTION
        IF r=3 THEN EXIT FOR
      ENDIF
    NEXT
    IF MonLeft()=0 THEN
      DrawCombat 0: Msg "The "+mn$(mt)+" are defeated!": Sfx "victory": PAUSE 500
      Combat=1: EXIT FUNCTION
    ENDIF
    FOR j=1 TO nmc
      IF chp(j)>0 AND PartyAlive()>0 THEN MTurn j
    NEXT
    IF PartyAlive()=0 THEN
      DrawCombat 0: Msg "The party has been destroyed!": PAUSE 1200
      over=1: Combat=-1: EXIT FUNCTION
    ENDIF
  LOOP
END FUNCTION

SUB DrawCombat cur
  LOCAL i, j
  DrawArena hallc
  FOR j=1 TO nmc
    IF chp(j)>0 THEN DrawMon cmx(j),cmy(j),cmt
  NEXT
  FOR i=1 TO np
    IF Alive(i) THEN DrawFig OX+cpx(i)*TS,OY+cpy(i)*TS,co(pco(i))
  NEXT
  Panel cur,1
  TopBar STR$(MonLeft())+" "+UCASE$(mn$(cmt))+"   SPEED "+STR$(msp(cmt)),WHT,&H303030
  DrawLog
END SUB

' returns 0 normal, 2 paid off, 3 negotiation failed (round ends)
FUNCTION PTurn(i)
  LOCAL k, acts, d, gx, gy, o, t, r
  acts=2
  DO
    DrawCombat i
    Prompt pn$(i)+": "+WName$(i,pcw(i))
    k=GetK()
    SELECT CASE k
      CASE KUP,KDN,KLF,KRT
        d=KDir(k): gx=cpx(i)+DX(d): gy=cpy(i)+DY(d): o=Occ(gx,gy)
        IF o>0 AND o<99 THEN Attack i,o,1: EXIT FUNCTION
        IF o=0 AND acts=2 THEN cpx(i)=gx: cpy(i)=gy: acts=1
      CASE 70
        IF itk$(pw(i,pcw(i)))<>"R" THEN
          Msg "No ranged weapon ready (W switches)."
        ELSEIF pam(i,pcw(i))<=0 THEN
          Msg "Out of ammunition!"
        ELSE
          t=Target(i)
          IF t>0 THEN pam(i,pcw(i))=pam(i,pcw(i))-1: Sfx "fire": Attack i,t,0: EXIT FUNCTION
        ENDIF
      CASE 87
        pcw(i)=1-pcw(i): acts=acts-1: Msg pn$(i)+" readies "+WName$(i,pcw(i))
        IF acts=0 THEN EXIT FUNCTION
      CASE 85: IF UseMagic(i,1) THEN EXIT FUNCTION
      CASE 78
        IF negok THEN
          r=Negot()
          IF r>0 THEN PTurn=r: EXIT FUNCTION
        ELSE
          Msg "They will not negotiate."
        ENDIF
      CASE 49: PlayerRpt
      CASE 50: PartyRpt
      CASE 51: MonRpt
      CASE KEN,32: EXIT FUNCTION
    END SELECT
    IF MonLeft()=0 THEN EXIT FUNCTION
  LOOP
END FUNCTION

SUB Attack i,m,melee
  LOCAL dmg
  IF RND*100<PHit(i) THEN
    dmg=1+INT(RND*WDmg(i,pcw(i),melee))+plv(i)\3
    DmgMon m,dmg,i
  ELSE
    Msg pn$(i)+" misses.": Sfx "miss"
  ENDIF
END SUB

SUB DmgMon m,dmg,i
  chp(m)=chp(m)-dmg
  Msg pn$(i)+" hits "+mn$(cmt)+" for "+STR$(dmg)
  IF chp(m)<=0 THEN
    chp(m)=0: Msg "The "+mn$(cmt)+" is eliminated!": Sfx "kill": GainXP i,mxp(cmt)
  ELSE
    Sfx "hit"
  ENDIF
END SUB

FUNCTION Target(i)
  LOCAL gx, gy, k, j, d
  gx=cpx(i): gy=cpy(i)
  FOR j=nmc TO 1 STEP -1
    IF chp(j)>0 THEN gx=cmx(j): gy=cmy(j)
  NEXT
  DO
    DrawCombat i
    Bo OX+gx*TS,OY+gy*TS,TS,TS,YEL
    Prompt "Aim with arrows, SPACE=fire, ESC=cancel"
    k=GetK()
    IF k>=KUP AND k<=KRT THEN
      d=KDir(k)
      IF gx+DX(d)>=0 AND gx+DX(d)<=8 AND gy+DY(d)>=ay0 AND gy+DY(d)<=ay1 THEN gx=gx+DX(d): gy=gy+DY(d)
    ELSEIF k=32 OR k=KEN THEN
      j=Occ(gx,gy)
      IF j>0 AND j<99 THEN Target=j: EXIT FUNCTION
      Msg "There is no monster there."
    ELSEIF k=KESC THEN
      EXIT FUNCTION
    ENDIF
  LOOP
END FUNCTION

SUB MTurn j
  LOCAL s, t, i, dd, bd, sx, sy
  FOR s=1 TO msp(cmt)
    FOR i=1 TO np
      IF Alive(i) AND ABS(cpx(i)-cmx(j))+ABS(cpy(i)-cmy(j))=1 THEN MAttack i: EXIT SUB
    NEXT
    IF mrg(cmt) AND RND<.5 THEN MAttack RndAlive(): EXIT SUB
    t=0: bd=99
    FOR i=1 TO np
      IF Alive(i) THEN
        dd=ABS(cpx(i)-cmx(j))+ABS(cpy(i)-cmy(j))
        IF dd<bd THEN bd=dd: t=i
      ENDIF
    NEXT
    IF t=0 THEN EXIT SUB
    sx=SGN(cpx(t)-cmx(j)): sy=SGN(cpy(t)-cmy(j))
    IF sx<>0 AND Occ(cmx(j)+sx,cmy(j))=0 THEN
      cmx(j)=cmx(j)+sx
    ELSEIF sy<>0 AND Occ(cmx(j),cmy(j)+sy)=0 THEN
      cmy(j)=cmy(j)+sy
    ENDIF
  NEXT
END SUB

FUNCTION RndAlive()
  LOCAL t, i
  FOR t=1 TO 30
    i=1+INT(RND*np)
    IF Alive(i) THEN RndAlive=i: EXIT FUNCTION
  NEXT
END FUNCTION

SUB MAttack t
  LOCAL dmg
  IF t=0 THEN EXIT SUB
  IF RND*100<MHit(t) THEN
    dmg=1+INT(RND*mdm(cmt))
    Msg mn$(cmt)+" hits "+pn$(t)+" for "+STR$(dmg)
    IF pwd(t)+dmg<php(t) THEN Sfx "mhit"
    Wound t,dmg
  ELSE
    Msg mn$(cmt)+" misses "+pn$(t)+".": Sfx "mmiss"
  ENDIF
END SUB

FUNCTION Negot()
  LOCAL price, k
  price=mxp(cmt)*MonLeft()*4+10
  DO
    IF RND*100>=mng(cmt) THEN Msg "Negotiations fail! They attack!": Sfx "guard": negok=0: Negot=3: EXIT FUNCTION
    Msg "They demand "+STR$(price)+" gold."
    Prompt "Y=pay  N=haggle  R=refuse"
    k=GetK()
    IF k=89 THEN
      IF gold>=price THEN gold=gold-price: Msg "You pay and leave in peace.": Sfx "gold": Negot=2: EXIT FUNCTION
      Msg "You do not have enough gold."
    ELSEIF k=78 THEN
      price=price\2
    ELSE
      Msg "You refuse their price.": negok=0: EXIT FUNCTION
    ENDIF
  LOOP
END FUNCTION

'===================== save / load =================================
SUB AddN a$,v
  a$=a$+STR$(v)+","
END SUB

SUB SaveGame
  LOCAL i, j, x, y, f, a$
  OPEN "TODSAVE.DAT" FOR OUTPUT AS #2
  PRINT #2,"TODSAVE1,"+modf$
  a$="": AddN a$,fl: AddN a$,px: AddN a$,py: AddN a$,pd: AddN a$,inrm: AddN a$,ent
  AddN a$,steps: AddN a$,gold: AddN a$,rat: AddN a$,dif: AddN a$,np
  PRINT #2,a$
  FOR i=1 TO np
    a$=pn$(i)+","
    AddN a$,pcl(i): AddN a$,pco(i): AddN a$,php(i): AddN a$,pwd(i): AddN a$,pxp(i): AddN a$,plv(i)
    AddN a$,pbn(i): AddN a$,pcw(i): AddN a$,par(i): AddN a$,psh(i): AddN a$,phl(i)
    FOR j=0 TO 1: AddN a$,pw(i,j): AddN a$,pam(i,j): NEXT
    FOR j=0 TO 9: AddN a$,pmi(i,j): NEXT
    PRINT #2,a$
  NEXT
  a$="": FOR i=1 TO MAXQ: AddN a$,qt(i): AddN a$,qs(i): NEXT: PRINT #2,a$
  a$="": FOR i=1 TO MAXI: AddN a$,ident(i): NEXT: PRINT #2,a$
  FOR f=1 TO nfl
    a$="": AddN a$,mapf(f): AddN a$,upx(f): AddN a$,upy(f): AddN a$,dnx(f): AddN a$,dny(f)
    PRINT #2,a$
    FOR y=0 TO gh-1
      a$="": FOR x=0 TO gw-1: AddN a$,cell(f,x,y): NEXT: PRINT #2,a$
    NEXT
  NEXT
  CLOSE #2
  Msg "Game saved to TODSAVE.DAT": Sfx "save"
END SUB

FUNCTION LoadGame()
  LOCAL a$, m$, i, j, x, y, f
  IF DIR$("TODSAVE.DAT",FILE)="" THEN EXIT FUNCTION
  OPEN "TODSAVE.DAT" FOR INPUT AS #2
  LINE INPUT #2,a$
  CLOSE #2
  IF LEFT$(a$,8)<>"TODSAVE1" THEN EXIT FUNCTION
  m$=FS$(a$,2)
  IF DIR$(m$,FILE)="" THEN EXIT FUNCTION
  LoadModule m$
  OPEN "TODSAVE.DAT" FOR INPUT AS #2
  LINE INPUT #2,a$: LINE INPUT #2,a$
  fl=NF(a$,1): px=NF(a$,2): py=NF(a$,3): pd=NF(a$,4): inrm=NF(a$,5): ent=NF(a$,6)
  steps=NF(a$,7): gold=NF(a$,8): rat=NF(a$,9): dif=NF(a$,10): np=NF(a$,11)
  FOR i=1 TO np
    LINE INPUT #2,a$
    pn$(i)=FS$(a$,1): pcl(i)=NF(a$,2): pco(i)=NF(a$,3): php(i)=NF(a$,4): pwd(i)=NF(a$,5)
    pxp(i)=NF(a$,6): plv(i)=NF(a$,7): pbn(i)=NF(a$,8): pcw(i)=NF(a$,9): par(i)=NF(a$,10)
    psh(i)=NF(a$,11): phl(i)=NF(a$,12)
    FOR j=0 TO 1: pw(i,j)=NF(a$,13+j*2): pam(i,j)=NF(a$,14+j*2): NEXT
    FOR j=0 TO 9: pmi(i,j)=NF(a$,17+j): NEXT
  NEXT
  LINE INPUT #2,a$
  FOR i=1 TO MAXQ: qt(i)=NF(a$,i*2-1): qs(i)=NF(a$,i*2): NEXT
  LINE INPUT #2,a$
  FOR i=1 TO MAXI: ident(i)=NF(a$,i): NEXT
  FOR f=1 TO nfl
    LINE INPUT #2,a$
    mapf(f)=NF(a$,1): upx(f)=NF(a$,2): upy(f)=NF(a$,3): dnx(f)=NF(a$,4): dny(f)=NF(a$,5)
    FOR y=0 TO gh-1
      LINE INPUT #2,a$
      FOR x=0 TO gw-1: cell(f,x,y)=NF(a$,x+1): NEXT
    NEXT
  NEXT
  CLOSE #2
  over=0: won=0: LoadGame=1
END FUNCTION

'===================== title / setup / end =========================
SUB TitleScr
  LOCAL k, i, tune
  DO
    Clr 0
    Bo 10,40,300,200,&H2040FF: Bo 56,70,208,139,&H2040FF
    Ln 10,40,56,70,&H2040FF: Ln 309,40,263,70,&H2040FF
    Ln 10,239,56,208,&H2040FF: Ln 309,239,263,208,&H2040FF
    TxA 160,108,"TUNNELS","CT",3,YEL,0
    TxA 160,146,"OF DOOM","CT",3,YEL,0
    TxA 160,8,"A PicoMite adventure","CT",1,GRY,0
    TxA 160,262,"N - New quest    C - Continue saved","CT",1,WHT,0
    TxA 160,280,"Q - Quit","CT",1,WHT,0
    IF tune=0 THEN Sfx "title": tune=1
    k=GetK()
    IF k=78 THEN
      IF NewGame() THEN EXIT SUB
    ELSEIF k=67 THEN
      IF LoadGame() THEN
        FOR i=0 TO 4: lg$(i)="": NEXT
        Msg "Welcome back to "+ttl$: EXIT SUB
      ENDIF
      TxA 160,300,"No usable saved game found","CT",1,&HFF4040,0: PAUSE 1500
    ELSEIF k=81 THEN
      Clr 0: END
    ENDIF
  LOOP
END SUB

FUNCTION NewGame()
  LOCAL f$, n, k, i, j
  Clr 0: TopBar "SELECT ADVENTURE MODULE",0,YEL
  ry=30: n=0: f$=DIR$("*.ADV",FILE)
  DO WHILE f$<>"" AND n<9
    n=n+1: fls$(n)=f$: RL STR$(n)+"  "+f$,WHT: f$=DIR$()
  LOOP
  IF n=0 THEN RL "No .ADV module files found!",&HFF4040: k=GetK(): EXIT FUNCTION
  IF LoadParty()=0 THEN RL "No PARTY.DAT - run PARTY.BAS first!",&HFF4040: k=GetK(): EXIT FUNCTION
  Prompt "Choose module 1-"+STR$(n)+" (ESC=back)"
  k=GetK()-48
  IF k<1 OR k>n THEN EXIT FUNCTION
  LoadModule fls$(k)
  i=LoadParty()
  Clr 0: TopBar UCASE$(ttl$),0,YEL
  ry=30
  FOR i=0 TO nintro-1: WrapTx intro$(i),WHT: NEXT
  ry=ry+10: RL "Difficulty? 1=Easy 2=Medium 3=Hard",CYN
  DO: dif=GetK()-48: LOOP UNTIL dif>=1 AND dif<=3
  RL "Constructing the dungeon...",YEL
  over=0: won=0: steps=0: rat=0
  FOR i=1 TO np
    FOR j=0 TO 1: pw(i,j)=0: pam(i,j)=0: NEXT
    FOR j=0 TO 9: pmi(i,j)=0: NEXT
  NEXT
  BuildDungeon
  ApplyKits
  gold=sgold(dif)*np
  FOR i=0 TO 4: lg$(i)="": NEXT
  fl=1: px=upx(1): py=upy(1): pd=0: inrm=1: ent=2: CS px,py,BSE,1,1
  Msg "Welcome, adventurers!"
  Store
  Msg "You descend into the Tunnels of Doom."
  NewGame=1
END FUNCTION

SUB EndScr
  LOCAL k, i
  Clr 0
  ry=40
  IF won THEN
    TopBar "VICTORY!",0,YEL: WrapTx win$,YEL: Sfx "win"
  ELSEIF over=3 THEN
    TopBar "QUEST ABANDONED",WHT,&H800000
  ELSEIF over=2 THEN
    TopBar "QUEST FAILED",WHT,&H800000: WrapTx fail$,WHT: Sfx "dead"
  ELSE
    TopBar "THE PARTY HAS BEEN DESTROYED",WHT,&H800000: WrapTx fail$,WHT: Sfx "dead"
  ENDIF
  ry=ry+10
  RL "Gold: "+STR$(gold)+"    Steps: "+STR$(steps),WHT
  FOR i=1 TO np
    RL pn$(i)+"  level "+STR$(plv(i))+"  xp "+STR$(pxp(i)),co(pco(i))
  NEXT
  Prompt "Press any key"
  k=GetK()
  PLAY STOP
END SUB
