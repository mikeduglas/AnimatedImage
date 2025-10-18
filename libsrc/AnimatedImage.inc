!* Animated images
!* mike duglas 2025

  INCLUDE('winapi.inc'), ONCE
  INCLUDE('gdiplus.inc'), ONCE

TAnimatedImage                CLASS(TGdiPlusImage), TYPE, MODULE('AnimatedImage.clw'), LINK('AnimatedImage.clw')
hThread                         HANDLE, PRIVATE
hPause                          HANDLE, PRIVATE
hExitEvent                      HANDLE, PRIVATE
w                               &WINDOW, PRIVATE
hWnd                            HWND, PRIVATE
nFrameCount                     LONG, PRIVATE
nFramePosition                  LONG, PRIVATE
bIsInitialized                  BOOL, PRIVATE
bPause                          BOOL, PRIVATE
propItem                        &TGdiPlusPropertyItem, PRIVATE
rgnFeq                          SIGNED, PRIVATE
rc                              &TRect, PRIVATE
bVisible                        BOOL, PRIVATE

Construct                       PROCEDURE()
Destruct                        PROCEDURE(), DERIVED
Load                            PROCEDURE(STRING pFileName), BOOL, PROC
InitAnimation                   PROCEDURE(WINDOW pW, SIGNED pRgnFeq)   !- Prepare animated GIF. Call it from Event:OpenWindow.
KillAnimation                   PROCEDURE()
Visible                         PROCEDURE(<BOOL pVisible>), BOOL, PROC
ResetPosition                   PROCEDURE()
Trace                           PROCEDURE(STRING pMsg)
IsAnimatedGIF                   PROCEDURE(), BOOL
SetPause                        PROCEDURE(BOOL pPause)
IsPaused                        PROCEDURE(), BOOL
TestForAnimatedGIF              PROCEDURE(), BOOL, PROC, PROTECTED    !- Check GIF/Image for avialability of animation
Initialize                      PROCEDURE(), PROTECTED
DrawFrameGIF                    PROCEDURE(), BOOL, PROTECTED
Draw                            PROCEDURE(), BOOL, PROC, PROTECTED
ThreadAnimation                 PROCEDURE(), PRIVATE                  !- Helper function
ClearRect                       PROCEDURE(), PRIVATE
OnPosChanged                    PROCEDURE(LONG lParam)
                              END
