SUBROUTINE SETOPENBC(D_LTD2,DE_TI,HUT,HVT)
 
  ! CHANGE RECORD
  ! ** SUBROUTINE SETOBC SETS OPEN BOUNDARY CONDITIONS FOR
  !    CALPUV2T & CALPUV2C   AND  CALPUV9 & CALPUV9C
  !
  ! *** MODIFIED BY PAUL M. CRAIG TO ADDRESS MOVING CALL IN CALPUV2#

  USE GLOBAL

  IMPLICIT NONE

  INTEGER :: L, LS,LN,M,LL
  REAL    :: C1,  D_LTD2, DE_TI, HDRY2,TM,TMPVAL,TC,TS,FP1G,CET,TMP,CWT,CNT,CST
  REAL    :: HUT(LCM),HVT(LCM)

  C1 = 0.5*G
  HDRY2 = 0.2*HDRY
  
  ! **  SET OPEN BOUNDARY SURFACE ELEVATIONS
  
  IF( ISDYNSTP == 0 )THEN
    TN=DT*FLOAT(N)+TCON*TBEGIN
  ELSE
    TN=TIMESEC
  ENDIF
  DO M=1,MTIDE
    TM=MOD(TN,TCP(M))
    TM=PI2*TM/TCP(M)
    CCCOS(M)=COS(TM)
    SSSIN(M)=SIN(TM)
  ENDDO

  ! *** WEST OPEN BOUNDARY
  DO LL=1,NPBW
    L=LPBW(LL)
    CC(L)=DELTI*DXYP(L)
    CS(L)=0.
    CW(L)=0.
    CE(L)=0.
    CN(L)=0.
    IF( LOPENBCDRY(L) )CYCLE

    FP(L)=PSERT(NPSERW(LL)) +0.5*PSERZDF(NPSERW(LL)) + PSERST(NPSERW(LL))+0.5*PSERZDS(NPSERW(LL))
    IF( NPFORT >= 1 .AND. NPSERW1(LL) > 0 )THEN
      TMPVAL=PSERT(NPSERW1(LL)) +0.5*PSERZDF(NPSERW1(LL)) + PSERST(NPSERW1(LL))+0.5*PSERZDS(NPSERW1(LL))
      FP(L)=FP(L)+TPCOORDW(LL)*(TMPVAL-FP(L))
    ENDIF
    DO M=1,MTIDE
      TC=CCCOS(M)
      TS=SSSIN(M)
      FP(L)=FP(L)+PCBW(LL,M)*TC+PSBW(LL,M)*TS
    ENDDO

    IF( ISPBW(LL) == 1 .OR. ISPBW(LL) == 2 )THEN
      ! *** RADIATION BC TYPES
      CET=0.5*D_LTD2*G*HRUO(LEC(L))*RCX(LEC(L))*HUT(LEC(L))
      TMP=D_LTD2*SQRT(G*HUT(LEC(L)))*DXIU(LEC(L))
      CC(L)=CET*(1.+TMP)/TMP
      CE(L)=-CET
      FP(L)=CET*(2.*FP(L) - SQRT(G*HUT(LEC(L)))*FUHDYE(LEC(L))*DYIU(LEC(L))/HUT(LEC(L)))/TMP
    ELSE
      ! *** INACTIVAVE BC'S WHEN ELEVATIONS DROP BELOW BOTTOM+HDRY
      FP1G=FP(L)/G-HDRY2
      IF( FP1G < BELV(L) .OR. FP1G < BELV(LEC(L)) )THEN
        FP(L)=(BELV(L)+HDRY2)*G
        CET=0.
        LOPENBCDRY(L)=.TRUE.
      ELSE
        CET=0.5*D_LTD2*G*HRUO(LEC(L))*RCX(LEC(L))*HUT(LEC(L))
      ENDIF
      FP(LEC(L))=FP(LEC(L))+CET*FP(L)
      FP(L)=DE_TI*DXYP(L)*FP(L)
    ENDIF
  ENDDO

  ! *** EAST OPEN BOUNDARY
  DO LL=1,NPBE
    L=LPBE(LL)
    CC(L)=DELTI*DXYP(L)
    CS(L)=0.
    CW(L)=0.
    CE(L)=0.
    CN(L)=0.
    IF( LOPENBCDRY(L) )CYCLE

    FP(L)=PSERT(NPSERE(LL)) +0.5*PSERZDF(NPSERE(LL)) + PSERST(NPSERE(LL))+0.5*PSERZDS(NPSERE(LL))
    IF( NPFORT >= 1 .AND. NPSERE1(LL) > 0 )THEN
      TMPVAL=PSERT(NPSERE1(LL)) +0.5*PSERZDF(NPSERE1(LL)) + PSERST(NPSERE1(LL))+0.5*PSERZDS(NPSERE1(LL))
      FP(L)=FP(L)+TPCOORDE(LL)*(TMPVAL-FP(L))
    ENDIF
    DO M=1,MTIDE
      TC=CCCOS(M)
      TS=SSSIN(M)
      FP(L)=FP(L)+PCBE(LL,M)*TC+PSBE(LL,M)*TS
    ENDDO

    IF( ISPBE(LL) == 1 .OR. ISPBE(LL) == 2 )THEN
      ! *** RADIATION BC TYPES
      CWT=0.5*D_LTD2*G*HRUO(L)*RCX(L)*HUT(L)
      TMP=D_LTD2*SQRT(G*HUT(L))*DXIU(L)
      CC(L)=CWT*(1.+TMP)/TMP
      CW(L)=-CWT
      FP(L)=CWT*(2.*FP(L) + SQRT(G*HUT(L))*FUHDYE(L)*DYIU(L)/HUT(L))/TMP
    ELSE
      ! *** INACTIVAVE BC'S WHEN ELEVATIONS DROP BELOW BOTTOM+HDRY
      FP1G=FP(L)/G-HDRY2
      IF( FP1G < BELV(L) .OR. FP1G < BELV(LWC(L)) )THEN
        FP(L)=(BELV(L)+HDRY2)*G
        CWT=0.
        LOPENBCDRY(L)=.TRUE.
      ELSE
        CWT=0.5*D_LTD2*G*HRUO(L)*RCX(L)*HUT(L)
      ENDIF
      FP(LWC(L))=FP(LWC(L))+CWT*FP(L)
      FP(L)=DE_TI*DXYP(L)*FP(L)
    ENDIF
  ENDDO

  ! *** SOUTH OPEN BOUNDARY
  DO LL=1,NPBS
    L=LPBS(LL)
    LN=LNC(L)
    CC(L)=DELTI*DXYP(L)
    CS(L)=0.
    CW(L)=0.
    CE(L)=0.
    CN(L)=0.
    IF( LOPENBCDRY(L) )CYCLE

    FP(L)=PSERT(NPSERS(LL)) +0.5*PSERZDF(NPSERS(LL)) + PSERST(NPSERS(LL))+0.5*PSERZDS(NPSERS(LL))
    IF( NPFORT >= 1 .AND. NPSERS1(LL) > 0 )THEN
      TMPVAL=PSERT(NPSERS1(LL)) +0.5*PSERZDF(NPSERS1(LL)) + PSERST(NPSERS1(LL))+0.5*PSERZDS(NPSERS1(LL))
      FP(L)=FP(L)+TPCOORDS(LL)*(TMPVAL-FP(L))
    ENDIF
    DO M=1,MTIDE
      TC=CCCOS(M)
      TS=SSSIN(M)
      FP(L)=FP(L)+PCBS(LL,M)*TC+PSBS(LL,M)*TS
    ENDDO
    
    IF( ISPBS(LL) == 1 .OR. ISPBS(LL) == 2 )THEN
      ! *** RADIATION BC TYPES
      CNT=0.5*D_LTD2*G*HRVO(LN)*RCY(LN)*HVT(LN)
      TMP=D_LTD2*SQRT(G*HVT(LN))*DYIV(LN)
      CC(L)=CNT*(1.+TMP)/TMP
      CN(L)=-CNT
      FP(L)=CNT*( 2.*FP(L) - SQRT(G*HVT(LN))*FVHDXE(LN)*DXIV(LN)/HVT(LN) )/TMP
    ELSE
      ! *** INACTIVAVE BC'S WHEN ELEVATIONS DROP BELOW BOTTOM+HDRY
      FP1G=FP(L)/G-HDRY2
      IF( FP1G < BELV(L) .OR. FP1G < BELV(LN) )THEN
        FP(L)=(BELV(L)+HDRY2)*G
        CNT=0.
        LOPENBCDRY(L)=.TRUE.
      ELSE
        CNT=0.5*D_LTD2*G*HRVO(LN)*RCY(LN)*HVT(LN)
      ENDIF
      FP(LN)=FP(LN)+CNT*FP(L)
      FP(L)=DE_TI*DXYP(L)*FP(L)
    ENDIF
  ENDDO

  ! *** NORTH OPEN BOUNDARY
  DO LL=1,NPBN
    L=LPBN(LL)
    LS=LSC(L)
    CC(L)=DELTI*DXYP(L)
    CS(L)=0.
    CW(L)=0.
    CE(L)=0.
    CN(L)=0.
    IF( LOPENBCDRY(L) )CYCLE
    
    FP(L)=PSERT(NPSERN(LL)) +0.5*PSERZDF(NPSERN(LL)) + PSERST(NPSERN(LL))+0.5*PSERZDS(NPSERN(LL))
    IF( NPFORT >= 1 .AND. NPSERN1(LL) > 0 )THEN
      TMPVAL=PSERT(NPSERN1(LL)) +0.5*PSERZDF(NPSERN1(LL)) + PSERST(NPSERN1(LL))+0.5*PSERZDS(NPSERN1(LL))
      FP(L)=FP(L)+TPCOORDN(LL)*(TMPVAL-FP(L))
    ENDIF
    DO M=1,MTIDE
      TC=CCCOS(M)
      TS=SSSIN(M)
      FP(L)=FP(L)+PCBN(LL,M)*TC+PSBN(LL,M)*TS
    ENDDO

    IF( ISPBN(LL) == 1 .OR. ISPBN(LL) == 2 )THEN
      ! *** RADIATION BC TYPES
      CST=0.5*D_LTD2*G*HRVO(L)*RCY(L)*HVT(L)
      TMP=D_LTD2*SQRT(G*HVT(L))*DYIV(L)
      CC(L)=CST*(1.+TMP)/TMP
      CS(L)=-CST
      FP(L)=CST*(2.*FP(L) + SQRT(G*HVT(L))*FVHDXE(L)*DXIV(L)/HVT(L))/TMP
    ELSE
      ! *** INACTIVAVE BC'S WHEN ELEVATIONS DROP BELOW BOTTOM+HDRY
      FP1G=FP(L)/G-HDRY2
      IF( FP1G < BELV(L) .OR. FP1G < BELV(LS) )THEN
        FP(L)=(BELV(L)+HDRY2)*G
        CST=0.
        LOPENBCDRY(L)=.TRUE.
      ELSE
        CST=0.5*D_LTD2*G*HRVO(L)*RCY(L)*HVT(L)
      ENDIF
      FP(LS)=FP(LS)+CST*FP(L)
      FP(L)=DE_TI*DXYP(L)*FP(L)
    ENDIF
  ENDDO

  RETURN
END
