MODULE XYIJCONV
!Author: Dang Huu Chung

USE GLOBAL  
USE INFOMOD

IMPLICIT NONE

CONTAINS

SUBROUTINE XY2IJ(CEL) 
  TYPE(CELL),INTENT(INOUT) :: CEL
  INTEGER :: N,NPMAX
  
  NPMAX = SIZE(CEL%XCEL)
  IF(  .NOT. ALLOCATED(XCOR) ) CALL AREA_CENTRD
  DO N=1,NPMAX 
    CALL CONTAINERIJ(N,CEL%XCEL(N),CEL%YCEL(N),CEL%ICEL(N),CEL%JCEL(N))
  ENDDO
  
END SUBROUTINE

SUBROUTINE CONTAINERIJ(NCEL,XCLL,YCLL,ICLL,JCLL)   

  INTEGER,INTENT(IN ) :: NCEL
  REAL(8),   INTENT(IN ) :: XCLL,YCLL
  INTEGER,INTENT(OUT) :: ICLL,JCLL
  INTEGER :: LMILOC(1),L,I,J,ILN,JLN
  INTEGER :: I1,I2,J1,J2
  REAL(8) :: RADLA(LA)
  
  ! *** FOR THE FIRST CALL                     
  RADLA(2:LA) = SQRT((XCLL-XCOR(2:LA,5))**2+(YCLL-YCOR(2:LA,5))**2) 
  LMILOC = MINLOC(RADLA(2:LA))
  ILN = IL(LMILOC(1)+1)    !I OF THE NEAREST CELL FOR DRIFTER
  JLN = JL(LMILOC(1)+1)    !J OF THE NEAREST CELL FOR DRIFTER     

  ! *** DETERMINE THE CELL CONTAINING THE DRIFTER WITHIN 9 CELLS: LLA(NCEL)
  I1 = MAX(1,ILN-1)
  I2 = MIN(ILN+1,ICM)
  J1 = MAX(1,JLN-1)
  J2 = MIN(JLN+1,JCM)
  LOOP:DO J=J1,J2
    DO I=I1,I2
      L = LIJ(I,J)
      IF( L<2) CYCLE
      IF( INSIDECELL(L,XCLL,YCLL) )THEN
        ICLL = I
        JCLL = J
        RETURN
      ENDIF
    ENDDO
  ENDDO LOOP
  PRINT*,'THIS CELL IS OUTSIDE THE DOMAIN:',NCEL
  STOP

END SUBROUTINE

 SUBROUTINE AREACAL(XC,YC,AREA)   
  ! *** AREA CALCULATION OF A POLYGON
  ! *** WITH GIVEN VEXTICES (XC,YC)
  REAL(8),INTENT(IN) :: XC(:),YC(:)
  REAL(8),INTENT(OUT) :: AREA
  REAL(8) :: XVEC(2),YVEC(2)
  INTEGER :: NPOL,K
  
  NPOL = SIZE(XC)
  AREA = 0
  XVEC(1)=XC(2)-XC(1)
  YVEC(1)=YC(2)-YC(1)
  DO K=3,NPOL
    XVEC(2) = XC(K)-XC(1)
    YVEC(2) = YC(K)-YC(1)
    AREA = AREA+0.5*ABS( XVEC(1)*YVEC(2)-XVEC(2)*YVEC(1))
    XVEC(1)=XVEC(2)
    YVEC(1)=YVEC(2)
  ENDDO
  
END SUBROUTINE

FUNCTION INSIDECELL(L,XM,YM) RESULT(INSIDE)   

  LOGICAL(4) :: INSIDE
  INTEGER,INTENT(IN) :: L
  REAL(8) ,INTENT(IN) :: XM,YM
  REAL(8) :: XC(6),YC(6),AREA2
  XC(1) = XM 
  YC(1) = YM 
  XC(2:5)=XCOR(L,1:4)
  YC(2:5)=YCOR(L,1:4)
  XC(6) = XC(2)
  YC(6) = YC(2)
  CALL AREACAL(XC,YC,AREA2)
  IF( ABS(AREA2-AREA(L)) <= 1D-6 )THEN
    INSIDE=.TRUE.
  ELSE 
    INSIDE=.FALSE.
  ENDIF

END FUNCTION

SUBROUTINE AREA_CENTRD
  ! *** DETERMINING CELLCENTROID OF ALL CELLS
  ! *** AND CALCULATING THE AREA OF EACH CELL
  INTEGER :: I,J,K
  REAL(8) :: XC(4),YC(4),AREA2
  
  PRINT *,'***   READING CORNERS.INP'
  OPEN(UCOR,FILE='corners.inp',ACTION='READ')
  CALL SKIPCOM(UCOR, '*')
  ALLOCATE(XCOR(LA,5),YCOR(LA,5),AREA(LA))
  XCOR = 0
  YCOR = 0
  AREA = 0
  DO WHILE(1)
     READ(UCOR,*,END=100,ERR=998) I,J,(XCOR(LIJ(I,J),K),YCOR(LIJ(I,J),K),K=1,4)
     XC(1:4) = XCOR(LIJ(I,J),1:4)
     YC(1:4) = YCOR(LIJ(I,J),1:4)
     CALL AREACAL(XC,YC,AREA2)
     AREA(LIJ(I,J)) = AREA2
     ! *** STORE THE CELL CENTROID IN INDEX=5
     XCOR(LIJ(I,J),5) = 0.25*SUM(XC)        
     YCOR(LIJ(I,J),5) = 0.25*SUM(YC)
  ENDDO
  100 CLOSE(UCOR)
  RETURN
  998 STOP 'CORNERS.INP READING ERROR!'
END SUBROUTINE

SUBROUTINE DIST2LINE(L,IP,X0,Y0,IPOINT,OFFSET,D,X3,Y3)
  ! *** COMPUTES THE DISTANCE FROM A POINT TO A LINE SEGMENT (X1,Y1),(X2,Y2) TO A POINT (X0,Y0) 
  ! *** RETURNS THE DISTANCE D AND THE INTERSECTION POINT ON THE LINE (X3,Y3)

  ! *** IP IS THE SIDE NUMBER, C1-C4 ARE THE POINT LOCATIONS AND ORDER
  ! *** 
  ! ***    C2    2   C3
  ! *** 
  ! ***    1          3
  ! *** 
  ! ***    C1   4    C4
  
  INTEGER(IK4),INTENT(IN)  :: L,IP,IPOINT
  REAL(RKD)   ,INTENT(IN)  :: X0,Y0,OFFSET
  REAL(RKD)   ,INTENT(OUT) :: D,X3,Y3
    
  INTEGER(IK4) :: I1,I2
  REAL(RKD)    :: H,XDEL,YDEL,ANG,EPSILON

  IF( IP == 4 )THEN
    I1 = 4
    I2 = 1
  ELSE
    I1 = IP
    I2 = IP+1
  ENDIF
  XDEL = XCOR(L,I2) - XCOR(L,I1)
  YDEL = YCOR(L,I2) - YCOR(L,I1)
    
  D = YDEL*X0 - XDEL*Y0 + XCOR(L,I2)*YCOR(L,I1) - YCOR(L,I2)*XCOR(L,I1)
  H = SQRT(XDEL*XDEL + YDEL*YDEL)
  IF( H < 1E-6 )THEN
    D = 0
    RETURN
  ENDIF
      
  ! *** SIGNED DISTANCE  <0 - LEFT OF LINE, >0 - RIGHT OF LINE
  D = D/H
  
  IF( IPOINT > 0 )THEN
    !IF( ABS(XDEL) < 1E-12 )THEN
    !  M = 1E32
    !ELSEIF( ABS(YDEL) > 1E-12 )THEN
    !  M = YDEL/XDEL
    !ELSE
    !  M = 1E-32
    !ENDIF
    ANG = ATAN2(YDEL,XDEL)
    ANG = ANG + 0.5*PI
    
    !DS = SIGN(1.,XDEL)
    X3 = X0 + COS(ANG)*D  !*DS
    Y3 = Y0 + SIN(ANG)*D  !*DS

    ! *** CHECK RANGES BUT ADD A SMALL BUFFER FOR ROUNDOFF (EPSILON)
    EPSILON = 1E-12*X3
    IF( (X3 + EPSILON) < MIN(XCOR(L,I1),XCOR(L,I2)) .OR. (X3 - EPSILON) > MAX(XCOR(L,I1),XCOR(L,I2)) )THEN
      ! *** ON THE LINE BUT NOT IN THE SEGMENT
      D = 1E32
      RETURN
    ELSEIF( (Y3 + EPSILON) < MIN(YCOR(L,I1),YCOR(L,I2)) .OR. (Y3 - EPSILON) > MAX(YCOR(L,I1),YCOR(L,I2)) )THEN
      ! *** ON THE LINE BUT NOT IN THE SEGMENT
      D = 1E32
      RETURN
    ENDIF
  
    ! *** RECOMPUTE X3,Y3 WITH OFFSET
    X3 = X0 + COS(ANG)*(D-OFFSET)  !*DS
    Y3 = Y0 + SIN(ANG)*(D-OFFSET)  !*DS

  ENDIF

  RETURN
    
END SUBROUTINE

END MODULE