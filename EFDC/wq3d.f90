SUBROUTINE WQ3D(ISTL_,IS2TL_)  

  !  CONTROL SUBROUTINE FOR WATER QUALITY MODEL  
  !  ORGINALLY CODED BY K.-Y. PARK  
  !  OPTIMIZED AND MODIFIED BY J. M. HAMRICK  

  !----------------------------------------------------------------------C  
  ! CHANGE RECORD  
  ! DATE MODIFIED     BY               DESCRIPTION
  !----------------------------------------------------------------------!
  ! 2011-03           Paul M. Craig      Rewritten to F90 
  ! 2008                                 Merged SNL and DS-INTL

  USE GLOBAL  
  USE WQ_RPEM_MODULE
  USE RESTART_MODULE
  USE CALCSERMOD,ONLY: CALCSER

   IMPLICIT NONE

  REAL(RKD), STATIC :: DAYNEXT
  REAL(RKD), STATIC :: SUNDAY1, SUNDAY2
  REAL  , STATIC :: SUNSOL1, SUNSOL2
  REAL  , STATIC :: SUNFRC1, SUNFRC2, WQTSDTINC
  
  REAL       :: TIMTMP,RATIO,SOLARAVG,WTEMP,WQTT,TT20
  INTEGER :: ISTL_,IS2TL_
  INTEGER    :: IWQTAGR,IWQTSTL,ISMTICI
  INTEGER    :: M1,M2,L,K,NMALG,NW
  INTEGER, STATIC :: M
  REAL(RKD), EXTERNAL :: DSTIME 
  REAL(RKD)           :: TTDS       ! MODEL TIMING TEMPORARY VARIABLE

  DATA IWQTAGR,IWQTSTL,ISMTICI/3*0/  
  
  IF( N == 1 )THEN
    WQTSDTINC = 0.
  ENDIF
   
  ! *** SET THE HYDRODYNAMIC TIMESTEP
  IF( ISDYNSTP == 0 )THEN  
    DELT=DT  
  ELSE  
    DELT=DTDYN  
  ENDIF  

  ! *** INCREMENT THE WATER QUALITY TIMESTEP
  WQKCNT=WQKCNT+DELT/86400.
  
  ! *** SET THE INITIAL DAYNEXT VALUE
  IF( ITNWQ == 0 )THEN
    DAYNEXT=DBLE(INT(TIMEDAY))+1.
  ENDIF

  ! *** PMC - NEW IMPLEMENTATION TO USE DAILY (FROM HOURLY) SOLAR RADIATION FOR ALGAL GROWTH
  IF( ITNWQ == 0 .AND. IWQSUN > 1 .AND. NASER > 0 )THEN
    ! *** BUILD THE DAILY AVERAGE SOLAR RADIATION FROM THE ASER DATA
    SUNDAY1 = DAYNEXT-1.
    SUNDAY2 = DAYNEXT

    ! *** FIND 1ST POINT
    M = 1
    DO WHILE (TSATM(1).TIM(M) < SUNDAY1)
      M = M+1
    END DO
    
    ! *** BUILD THE AVERAGE DAILY SOLAR RADIATION        
    M1 = 0
    M2 = 0
    SUNSOL1 = 0.0
    DO WHILE (TSATM(1).TIM(M) < SUNDAY1)
      M1 = M1+1
      IF( TSATM(1).VAL(M,6) > 0. )THEN
        M2 = M2+1
        SUNSOL1=SUNSOL1+TSATM(1).VAL(M,6)
      ENDIF
      M = M+1
    END DO
    IF( M1 > 0 )THEN
      SUNFRC1=FLOAT(M2)/FLOAT(M1)
      SUNSOL1=SUNSOL1/FLOAT(M1)
    ELSE
      SUNFRC1=1.0
    ENDIF
    
    ! *** BUILD THE AVERAGE DAILY SOLAR RADIATION        
    M1 = 0
    M2 = 0
    SUNSOL2 = 0.
    DO WHILE (TSATM(1).TIM(M) < SUNDAY2)
      M1 = M1+1
      IF( TSATM(1).VAL(M,6) > 0. )THEN
        M2 = M2+1
        SUNSOL2=SUNSOL2+TSATM(1).VAL(M,6)
      ENDIF
      M = M+1
    END DO
    IF( M1 > 0 )THEN
      SUNFRC2=FLOAT(M2)/FLOAT(M1)
      SUNSOL2=SUNSOL2/FLOAT(M1)
    ELSE
      SUNFRC2=1.
    ENDIF
  ENDIF

  ! *** READ INITIAL CONDITIONS
  IF( ITNWQ == 0 )THEN  
    IF( IWQICI == 1 ) CALL WQICI 
    IF( IWQICI == 2 ) CALL WQWCRST_IN 

    ! *** READ TIME/SPACE VARYING ALGAE PARAMETERS  
    !IF(IWQAGR == 1  .AND.  ITNWQ == IWQTAGR) CALL WQAGR(IWQTAGR)  
    IF( IWQAGR == 1 ) CALL WQAGR(IWQTAGR)   ! HARDWIRE FOR TEMPORALLY CONSTANT

    ! *** READ TIME/SPACE VARYING SETTLING VELOCITIES  
    !IF(IWQSTL == 1  .AND.  ITNWQ == IWQTSTL) CALL RWQSTL(IWQTSTL)  
    IF( IWQSTL == 1 ) CALL RWQSTL(IWQTSTL)   ! HARDWIRE FOR TEMPORALLY CONSTANT 
  ENDIF

  ! *** READ BENTHIC FLUX IF REQUIRED  
  ! *** CALL SPATIALLY AND TIME VARYING BENTHIC FLUX HERE.  ONLY CALL WQBENTHIC  
  ! *** IF SIMULATION TIME IS >= THE NEXT TIME IN THE BENTHIC FILE.  
  IF( IWQBEN  ==  2 )THEN  
    IF( ISDYNSTP == 0 )THEN  
      TIMTMP=(DT*FLOAT(N)+TCON*TBEGIN)/86400.  
    ELSE  
      TIMTMP=TIMEDAY
    ENDIF  
    IF( TIMTMP  >=  BENDAY )THEN  
      CALL WQBENTHIC(TIMTMP)  
    ENDIF  
  ENDIF  

  ! *** UPDATE POINT SOURCE LOADINGS  
  IF( IWQPSL == 1 )THEN
    ! *** MASS LOADING BC'S
    CALL RWQPSL  
  ELSEIF( IWQPSL == 2 )THEN
    ! *** CONCENTRATION BASED BC'S
    CALL CALCSER(ISTL_)
  ENDIF

  CALL WQWET  

  ! *** READ SEDIMENT MODEL INITIAL CONDITION  
  IF( IWQBEN == 1 )THEN  
    IF( ISMICI == 1  .AND.  ITNWQ == ISMTICI) CALL RSMICI(ISMTICI)  
  ENDIF  

  ! *** UPDATE OLD CONCENTRATIONS  

  ! *** CALCULATE PHYSICAL TRANSPORT  
  ! *** WQV(L,K,NW) SENT TO PHYSICAL TRANSPORT AND TRANSPORTED  
  ! *** VALUE RETURNED IN WQV(L,K,NW)  
  CALL CALWQC(ISTL_,IS2TL_) !transports (advects/disperses) WQV

  ! *** UPDATE WATER COLUMN KINETICS AND SEDIMENT MODEL  
  ! *** OVER LONGER TIME INTERVALS THAN PHYSICAL TRANSPORT  
  IF( ITNWQ == 0 .OR. WQKCNT >= WQKINUPT )THEN  
    DTWQ   = WQKCNT
    DTWQO2 = DTWQ*0.5  
    WQKCNT = 0.
    
    ! **  UPDATE SOLAR RADIATION INTENSITY  
    !   WQI1 = SOLAR RADIATION ON PREVIOUS DAY  
    !   WQI2 = SOLAR RADIATION TWO DAYS AGO  
    !   WQI3 = SOLAR RADIATION THREE DAYS AGO  
    ! ***  UPDATE OCCURS ONLY WHEN THE SIMULATION DAY CHANGES.  
    IF( TIMEDAY > DAYNEXT )THEN  ! *** DS-INTL: FORCE A SOLAR DAY UPDATE
      WQI3 = WQI2  
      WQI2 = WQI1  
      WQI1 = WQI0OPT  
      IF( IWQSUN > 0 )WQI0OPT = 0.0  
      DAYNEXT=DAYNEXT+1.
    ENDIF

    IF( IWQSUN > 1 .AND. NASER > 0 )THEN  
      IF( TIMEDAY > SUNDAY2 )THEN
        ! *** BUILD THE DAILY AVERAGE SOLAR RADIATION FROM THE ASER DATA
        SUNDAY1 = SUNDAY2
        SUNSOL1 = SUNSOL2
        SUNFRC1 = SUNFRC2
        
        ! *** BUILD THE AVERAGE DAILY SOLAR RADIATION        
        M1 = 0
        M2 = 0
        SUNSOL2 = 0.
        SUNDAY2 = SUNDAY2+1.
        DO WHILE (TSATM(1).TIM(M) < SUNDAY2)
          M1 = M1+1
          IF( TSATM(1).VAL(M,6) > 0. )THEN
            M2 = M2+1
            SUNSOL2=SUNSOL2+TSATM(1).VAL(M,6)
          ENDIF
          M = M+1
          IF( M > TSATM(1).NREC )THEN
            M = TSATM(1).NREC
            EXIT
          ENDIF
        END DO
        IF( M1 > 0 )THEN
          SUNFRC2=FLOAT(M2)/FLOAT(M1)
          SUNSOL2=SUNSOL2/FLOAT(M1)
        ELSE
          SUNFRC2=1.
        ENDIF
      ENDIF
    ENDIF  

    ! **  READ SOLAR RADIATION INTENSITY AND DAYLIGHT LENGTH  
    ! NOTE: IWQSUN=1 CALLS SUBROUTINE WQSUN WHICH READS THE DAILY  
    !                SOLAR RADIATION DATA FROM FILE SUNDAY.INP WHICH  
    !                ARE IN UNITS OF LANGLEYS/DAY.  
    !       IWQSUN=2 USES THE HOURLY SOLAR RADIATION DATA FROM ASER.INP  
    !                COUPLED WITH THE COMPUTED OPTIMAL DAILY LIGHT TO
    !                LIMIT ALGAL GROWTH.
    !       IWQSUN=3 USES THE DAILY AVERAGE SOLAR RADIATION DATA COMPUTED 
    !                FROM THE HOURLY ASER.INP AND THE COMPUTED OPTIMAL DAILY
    !                LIGHT TO LIMIT ALGAL GROWTH.
    !       IWQSUN>1 USES THE DAILY AVERAGE SOLAR RADIATION DATA COMPUTED 
    !                FROM THE HOURLY ASER.INP DATA.  CONVERTS WATTS/M**2 TO
    !                LANGLEYS/DAY USING 2.065.  COMPUTES THE FRACTION OF
    !                DAYLIGHT AND ADJUSTS FOR PHOTOSYNTHETIC ACTIVE RADIATION BY 
    !                PARADJ (~0.43) 
    !  
    IF( IWQSUN == 0 )THEN
      WQI0OPT = WQI0
    ELSEIF( IWQSUN == 1 )THEN  
      CALL WQSUN  
      WQI0=SOLSRDT  
      WQFD=SOLFRDT  
      ! *** OPTIMAL SOLAR RADIATION IS ALWAYS UPDATED BASED ON DAY AVERAGED
      WQI0OPT = MAX(WQI0OPT, WQI0)
      
    ELSEIF( IWQSUN > 1 .AND. NASER > 0 )THEN
      ! *** SOLAR RADIAION COMES FROM ASER FILE.  IWQSUN: 2-USE TIMING FROM ASER, 3-DAILY AVERAGE COMPUTED FROM ASER
      RATIO = (TIMEDAY-SUNDAY1)
      SOLARAVG = RATIO*(SUNSOL2-SUNSOL1)+SUNSOL1
      WQFD = RATIO*(SUNFRC2-SUNFRC1)+SUNFRC1

      ! *** SOLAR RADIATION IN LANGLEYS/DAY
      WQI0 = PARADJ*2.065*SOLARAVG  

      IF( IWQSUN == 2 )THEN
        ! *** OPTIMAL SOLAR RADIATION IS ALWAYS UPDATED BASED ON DAY AVERAGED.  USE 10 LANGLEYS/DAY TO PREVENT DIVISION BY ZERO LATER.
        WQI0OPT = MAX(WQI0OPT, WQI0, .1)

        IF( LDAYLIGHT .AND. (NASER > 1 .OR. USESHADE) )THEN  
          SOLARAVG = 0.  
          DO L=2,LA  
            SOLARAVG = SOLARAVG + SOLSWRT(L) 
          ENDDO  
          SOLARAVG = SOLARAVG/FLOAT(LA-1)
        ELSE
          ! *** Spatially Constant Atmospheric Parameters
          SOLARAVG = SOLSWRT(2)
        ENDIF  
        ! *** SOLAR RADIATION IN LANGLEYS/DAY
        WQI0 = PARADJ*2.065*SOLARAVG  
        WQFD=1.  
      ELSE
        ! *** OPTIMAL SOLAR RADIATION IS ALWAYS UPDATED BASED ON DAY AVERAGED
        WQI0OPT = MAX(WQI0OPT, WQI0)  
      ENDIF
    ENDIF 
    
    ! *** LOAD WQV INTO WQVO FOR REACTION CALCULATION  
    NMALG=0  
    IF( IDNOTRVA > 0 ) NMALG=1  
    DO NW=1,NWQV+NMALG  
      IF( ISTRWQ(NW) > 0 .OR. (NMALG == 1 .AND. NW == NWQV+NMALG) )THEN  
        DO K=1,KC  
          DO L=2,LA  
            WQVO(L,K,NW) = WQV(L,K,NW)
          ENDDO  
        ENDDO
      ENDIF  
    ENDDO  

    ! *** SET UP LOOK-UP TABLE FOR BACTERIA (FCB) TEMPERATURE DEPENDENCY OVER -10 degC TO 50 degC  
    IF( ISTRWQ(21) > 0 )THEN
      WTEMP = WQTDMIN
      DO M1=1,NWQTD  
        TT20 = WTEMP - 20.0  
        WQTT = WQKFCB * WQTFCB**TT20 * DTWQO2  
        WQTD1FCB(M1) = 1.0 - WQTT  
        WQTD2FCB(M1) = 1.0 / (1.0 + WQTT)  
        WTEMP = WTEMP + WQTDINC
      ENDDO  
    ENDIF
    
    ! ***   CALCULATE KINETIC SOURCES AND SINKS  
    TTDS=DSTIME(0) 

    IF( ISWQLVL == 0 ) CALL WQSKE0  
    IF( ISWQLVL == 1 ) CALL WQSKE1
    IF( ISWQLVL == 2 ) CALL WQSKE2  
    IF( ISWQLVL == 3 ) CALL WQSKE3  
    IF( ISWQLVL == 4 ) CALL WQSKE4  
    TWQKIN=TWQKIN+(DSTIME(0)-TTDS) 

    ! ***   DIAGNOSE NEGATIVE CONCENTRATIONS  
    IF( IWQNC > 0 )CALL WWQNC  

    ! ***   CALL SEDIMENT DIAGENSIS MODEL  
    IF( IWQBEN == 1 )THEN  
      TTDS=DSTIME(0) 
      CALL SMMBE  
      TWQSED=TWQSED+(DSTIME(0)-TTDS) 
    ENDIF  

    ! *** RPEM
    IF( ISRPEM > 0 )THEN
      CALL CAL_RPEM
    ENDIF

  ENDIF    ! *** ENDIF ON KINETIC AND SEDIMENT UPDATE  

  ! *** UPDATE WATER QUALITY TIMESTEP
  ITNWQ = ITNWQ + 1

  RETURN  
  
END  
