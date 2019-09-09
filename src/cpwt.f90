!===============================================================
!
!================================================================

   
      MODULE conf

      IMPLICIT NONE

      REAL, PARAMETER :: pi = 3.141592653589793
      INTEGER, PARAMETER :: na = 23

      REAL :: k0

      END MODULE conf



      MODULE cpwt

      CONTAINS

      SUBROUTINE wlet_transform(grid, nx, ny, nnx, nny, dx, dy, kf, ns, &
        wt_grid)     

      USE conf

      IMPLICIT NONE

      INTEGER :: nx, ny, nnx, nny, ns, nn(2)
      REAL    :: dx, dy
      REAL    :: grid(nx,ny), grid_pad(nnx,nny), kf(ns)
      COMPLEX :: wt_grid(nx,ny,na,ns)
      REAL    :: kx(nnx), ky(nny)
      COMPLEX :: ft_grid(nnx,nny), ft2_grid(nnx,nny), daughter(nnx,nny) 

      INTEGER :: is, ia
      REAL    :: da, scales, angle, lam, kk
      CHARACTER(LEN=1) :: trail
      CHARACTER(LEN=30) :: progress
!
! Python bindings
!
!f2py REAL, intent(in) :: grid
!f2py INTEGER, intent(hide),depend(grid) :: nx=shape(grid,0), ny=shape(grid,1)
!f2py INTEGER, intent(in) :: nnx, nny
!f2py REAL, intent(in) :: dx, dy
!f2py REAL, intent(in) :: kf
!f2py INTEGER, intent(hide),depend(kf) :: ns=shape(kf,0)
!f2py COMPLEX, intent(out) :: wt_grid

        CALL taper_data(grid,nx,ny,10)
        grid_pad = 0.
!
! Remove mean value
!
        grid_pad(1:nx,1:ny) = grid - sum(grid)/nx/ny
!
! Complex form
!
        ft_grid = CMPLX(grid_pad)
!
! Fourier transform
!
        nn(1) = nnx
        nn(2) = nny
        CALL fourn(ft_grid,nn,2,1)
!
! Define wavenumbers
!
        CALL defk(nnx,nny,dx,dy,kx,ky)
!
! Define angle parameters
!
        da = REAL(pi/na)
!_______________________________________________
!     
!     MAIN WAVELET TANSFORM LOOP
!_______________________________________________
!
!
! Loop through scales
!
        trail = '-'
        progress = ''
        WRITE(*, fmt="(1x,a,i2,a)", advance="no")'#loops = ',ns,':'
        DO is = 1,ns
!
! Define wavenumbers and scales
!
          trail = '_'
          kk = kf(is)*1.e3
          lam = 2.*pi/kk
          scales = k0/kk
          ! WRITE(*, fmt="(1x,a)", advance="no")TRIM(progress)//trail
          WRITE(*, fmt="(1x,i2)", advance="no")is
          progress = TRIM(progress)//trail
!
! Loop through angles
!
          DO ia = 1,na
!
! Define angle increments
! 
            angle = REAL(ia-1)*da-pi/2.e0
!
! Calculate daughter wavelet
!
            CALL wave_function(nnx,nny,kx,ky,k0,scales,angle,daughter)
!
! Compute wavelet transform in Fourier space
!
            daughter = daughter*CONJG(ft_grid)
!
! Back to physical space
!
            CALL fourn(daughter,nn,2,-1)
!
! Normalization
!
            ft2_grid = (daughter)/FLOAT(nnx*nny)
!
! Quadrant swap
!
            CALL cfftswap(ft2_grid,nnx,nny)
!
! Store array
!
            wt_grid(:,:,ia,is) = ft2_grid(1:nx,1:ny)

          END DO
        END DO
        WRITE(*,*)

      END SUBROUTINE wlet_transform

!===============================================================
!
!================================================================

      SUBROUTINE wlet_scalogram(wl_trans, nx, ny, ns, wl_sg, ewl_sg)

      USE conf

      IMPLICIT NONE

      INTEGER :: nx, ny, ns
      COMPLEX :: wl_trans(nx,ny,na,ns)
      REAL    :: wl_sg(nx,ny,ns), ewl_sg(nx,ny,ns)
      REAL    :: sg(nx,ny,na,ns)

      INTEGER :: is, ia
!
! Python bindings
!
!f2py COMPLEX, intent(in) :: wl_trans
!f2py INTEGER, intent(hide),depend(wl_trans) :: nx=shape(wl_trans,0)
!f2py INTEGER, intent(hide),depend(wl_trans) :: ny=shape(wl_trans,1)
!f2py INTEGER, intent(hide),depend(wl_trans) :: ns=shape(wl_trans,3)
!f2py REAL, intent(out) :: wl_sg, ewl_sg

        wl_sg = 0.e0
        DO is = 1,ns
          DO ia = 1,na
            sg(:,:,ia,is) = CABS(wl_trans(:,:,ia,is)*CONJG(wl_trans(:,:,ia,is)))
!
! Azimuthal average
!
            wl_sg(:,:,is) = wl_sg(:,:,is) + sg(:,:,ia,is)
          END DO
        END DO
!
! Normalization
!
        wl_sg = wl_sg/FLOAT(na)
!
! Jackknife estimation
!
        CALL jackknife_1d_sgram(sg,nx,ny,na,ns,ewl_sg)

        RETURN
      END SUBROUTINE wlet_scalogram

!===============================================================
!
!================================================================

      SUBROUTINE wlet_xscalogram(wl_trans1, wl_trans2, nx, ny, ns, wl_xsg, ewl_xsg)

      USE conf

      IMPLICIT NONE

      INTEGER :: nx, ny, ns
      COMPLEX :: wl_trans1(nx,ny,na,ns), wl_trans2(nx,ny,na,ns)
      COMPLEX :: wl_xsg(nx,ny,ns), xsg(nx,ny,na,ns)
      REAL :: ewl_xsg(nx,ny,ns), ewl_xsg_real(nx,ny,ns), ewl_xsg_imag(nx,ny,ns)

      INTEGER :: is, ia
!
! Python bindings
!
!f2py COMPLEX, intent(in) :: wl_trans1, wl_trans2
!f2py INTEGER, intent(hide),depend(wl_trans1) :: nx=shape(wl_trans1,0)
!f2py INTEGER, intent(hide),depend(wl_trans1) :: ny=shape(wl_trans1,1)
!f2py INTEGER, intent(hide),depend(wl_trans1) :: ns=shape(wl_trans1,3)
!f2py REAL, intent(out) :: wl_xsg, ewl_xsg

        wl_xsg = CMPLX(0.e0,0.e0)
        DO is = 1,ns
          DO ia = 1, na
            xsg(:,:,ia,is) = wl_trans1(:,:,ia,is)*CONJG(wl_trans2(:,:,ia,is))
!
! Azimuthal average
!
            wl_xsg(:,:,is) = wl_xsg(:,:,is) + xsg(:,:,ia,is)
          END DO
        END DO
!
! Normalization
!
        wl_xsg = wl_xsg/FLOAT(na)
!
! Jackknife estimation
!
        CALL jackknife_1d_sgram(REAL(xsg),nx,ny,na,ns,ewl_xsg_real)
        CALL jackknife_1d_sgram(IMAG(xsg),nx,ny,na,ns,ewl_xsg_imag)
        ewl_xsg = SQRT(ewl_xsg_real**2 + ewl_xsg_imag**2)

        RETURN
      END SUBROUTINE wlet_xscalogram

!===============================================================
!
!================================================================

      SUBROUTINE wlet_admit_coh(wl_trans1, wl_trans2, nx, ny, ns, &
        wl_admit, ewl_admit, wl_coh, ewl_coh)

      USE conf

      IMPLICIT NONE

      INTEGER :: nx, ny, ns
      COMPLEX :: wl_trans1(nx,ny,na,ns), wl_trans2(nx,ny,na,ns)
      REAL    :: wl_admit(nx,ny,ns), wl_coh(nx,ny,ns)
      REAL    :: ewl_admit(nx,ny,ns), ewl_coh(nx,ny,ns)

      REAL    :: sg1(nx,ny,na,ns), sg2(nx,ny,na,ns)
      COMPLEX :: xsg(nx,ny,na,ns)

      REAL    :: wl_sg1(nx,ny,ns), wl_sg2(nx,ny,ns)
      COMPLEX :: wl_xsg(nx,ny,ns)
      INTEGER :: is, ia
!
! Python bindings
!
!f2py COMPLEX, intent(in) :: wl_trans1, wl_trans2
!f2py INTEGER, intent(hide),depend(wl_trans1) :: nx=shape(wl_trans1,0)
!f2py INTEGER, intent(hide),depend(wl_trans1) :: ny=shape(wl_trans1,1)
!f2py INTEGER, intent(hide),depend(wl_trans1) :: ns=shape(wl_trans1,3)
!f2py REAL, intent(out) :: wl_admit, ewl_admit, wl_coh, ewl_coh

        DO is = 1,ns
          DO ia = 1, na

            sg1(:,:,ia,is) = CABS(wl_trans1(:,:,ia,is)*CONJG(wl_trans1(:,:,ia,is)))
            sg2(:,:,ia,is) = CABS(wl_trans2(:,:,ia,is)*CONJG(wl_trans2(:,:,ia,is)))
            xsg(:,:,ia,is) = wl_trans1(:,:,ia,is)*CONJG(wl_trans2(:,:,ia,is))
!
! Azimuthal average
!
            wl_sg1(:,:,is) = wl_sg1(:,:,is) + sg1(:,:,ia,is)
            wl_sg2(:,:,is) = wl_sg2(:,:,is) + sg2(:,:,ia,is)
            wl_xsg(:,:,is) = wl_xsg(:,:,is) + xsg(:,:,ia,is)

          END DO
        END DO
!
! Normalization
!
        wl_sg1 = wl_sg1/FLOAT(na)
        wl_sg2 = wl_sg2/FLOAT(na)
        wl_xsg = wl_xsg/FLOAT(na)
!
! Admittance and coherence
!
        wl_admit = REAL(wl_xsg)/wl_sg1
        wl_coh = CABS(wl_xsg*CONJG(wl_xsg))/(wl_sg1*wl_sg2)
!
! Jackknife estimation
!
        PRINT*,'Calculation jackknife error on admittance and coherence'
        CALL jackknife_admit_coh(xsg,sg1,sg2,nx,ny,na,ns,ewl_admit,ewl_coh)

        RETURN
      END SUBROUTINE wlet_admit_coh

      END MODULE cpwt