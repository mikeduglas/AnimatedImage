!* Animated images
!* mike duglas 2025

!- from https://www.codeproject.com/KB/GDI-plus/imageexgdi.aspx

  MEMBER

  INCLUDE('AnimatedImage.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE

    MODULE('Win API')
      winapi::CreateThread(LONG lpSecurityAttributes, LONG pStacksize, LONG lpFunction, LONG lpParameter, LONG pCreationFlags, *ULONG pThreadID),HANDLE,PASCAL,NAME('CreateThread')
      winapi::ResumeThread(HANDLE hThread),ULONG,PROC,PASCAL,NAME('ResumeThread')
      winapi::WaitForSingleObject(HANDLE hHandle, LONG dwMilliSeconds),LONG,PROC,PASCAL,NAME('WaitForSingleObject')
   
      winapi::CreateEvent(LONG lpSecurityAttributes, BOOL bManualReset, BOOL bInitialState, *CSTRING lpName),RAW,HANDLE,PASCAL,NAME('CreateEventA')
      winapi::SetEvent(HANDLE hEvent),BOOL,PASCAL,PROC,NAME('SetEvent')
      winapi::ResetEvent(HANDLE hEvent),BOOL,PASCAL,PROC,NAME('ResetEvent')
      winapi::CloseHandle(HANDLE hFile),BOOL,PASCAL,PROC,NAME('CloseHandle')
    
      winapi::GetSysColor(LONG nIndex),UNSIGNED,PASCAL,PROC,NAME('GetSysColor')
    END
    MODULE('Clarion API')
      AttachThreadToClarion(BOOL pAllocate),PASCAL
    END

    _ThreadAnimationProc(LONG lpParameter),ULONG,PASCAL,PRIVATE


    LOWORD(LONG pLongVal), LONG, PRIVATE
    HIWORD(LONG pLongVal), LONG, PRIVATE
    GET_X_LPARAM(LONG pLongVal), SHORT, PRIVATE
    GET_Y_LPARAM(LONG pLongVal), SHORT, PRIVATE
    rgn::SubclassProc(HWND hWnd, ULONG wMsg, UNSIGNED wParam, LONG lParam, ULONG subclassId, UNSIGNED dwRefData), LONG, PASCAL, PRIVATE
  END

!- PropertyItem
PropertyTagFrameDelay         EQUATE(5100h)

!- CreateThread flag
CREATE_SUSPENDED              EQUATE(00000004h)

!https://learn.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nf-gdiplusheaders-image-selectactiveframe
!DEFINE_GUID(FrameDimensionTime, 0x6aedbd6d,0x3fb5,0x418a,0x83,0xa6,0x7f,0x45,0x22,0x9d,0xc8,0x72);
FrameDimensionTime            GROUP               !- for GIFs
Data1                           LONG(6aedbd6dh)
Data2                           SHORT(3fb5h)
Data3                           SHORT(418ah)
Data4                           STRING('<83h><0a6h><7fh><45h><22h><9dh><0c8h><72h>')
                              END
!DEFINE_GUID(FrameDimensionPage, 0x7462dc86,0x6180,0x4c7e,0x8e,0x3f,0xee,0x73,0x33,0xa7,0xa4,0x83);
FrameDimensionPage            GROUP               !- for TIFFs
Data1                           LONG(7462dc86h)
Data2                           SHORT(6180h)
Data3                           SHORT(4c7eh)
Data4                           STRING('<8eh><3fh><0eeh><73h><33h><0a7h><0a4h><83h>')
                              END

tagWINDOWPOS                  GROUP, TYPE
hwndInsertAfter                 HWND
hwnd                            HWND
x                               LONG
y                               LONG
cx                              LONG
cy                              LONG
flags                           UNSIGNED
                              END

COLOR:WINDOWGRAY              EQUATE(0F0F0F0H)    !- default background 


LOWORD                        PROCEDURE(LONG pLongVal)
  CODE
  RETURN BAND(pLongVal, 0FFFFh)

HIWORD                        PROCEDURE(LONG pLongVal)
  CODE
  RETURN BSHIFT(BAND(pLongVal, 0FFFF0000h), -16)

GET_X_LPARAM                  PROCEDURE(LONG pLongVal)
  CODE
  RETURN LOWORD(pLongVal)

GET_Y_LPARAM                  PROCEDURE(LONG pLongVal)
  CODE
  RETURN HIWORD(pLongVal)

rgn::SubclassProc             PROCEDURE(HWND hWnd, ULONG wMsg, UNSIGNED wParam, LONG lParam, ULONG subclassId, UNSIGNED dwRefData)
win                             TWnd
image                           &TAnimatedImage
  CODE
  win.SetHandle(hWnd)
  !- get TAnimatedImage instance
  image &= (dwRefData)
  IF image &= NULL
    !- not our window
    RETURN win.DefSubclassProc(wMsg, wParam, lParam)
  END

  CASE wMsg
  OF WM_WINDOWPOSCHANGED
    image.OnPosChanged(lParam)
    RETURN 0  !- don't send WM_MOVE and WN_SIZE
  END
  
  !- call original window proc
  RETURN win.DefSubclassProc(wMsg, wParam, lParam)

_ThreadAnimationProc          PROCEDURE(LONG lpParameter)
image                           &TAnimatedImage, AUTO
  CODE
  AttachThreadToClarion(TRUE)
  
  image &= (lpParameter)
  IF NOT image &= NULL
    image.ThreadAnimation()
  END
  RETURN 0

TAnimatedImage.Construct      PROCEDURE()
  CODE
  SELF.propItem &= NEW TGdiPlusPropertyItem
  SELF.rc &= NEW TRect
  SELF.bVisible = TRUE

TAnimatedImage.Destruct       PROCEDURE()
  CODE
  SELF.KillAnimation()
    
  DISPOSE(SELF.propItem)
  DISPOSE(SELF.rc)

TAnimatedImage.Trace          PROCEDURE(STRING pMsg)
  CODE
  printd('[TAnimatedImage] %s', pMsg)
  
TAnimatedImage.Load           PROCEDURE(STRING pFileName)
  CODE
  SELF.KillAnimation()
  IF SELF.FromFile(pFileName, FALSE) = GpStatus:Ok
    SELF.Initialize()
    SELF.bIsInitialized =TRUE
    
    SELF.TestForAnimatedGIF()
  END
  RETURN SELF.bIsInitialized
  
TAnimatedImage.IsAnimatedGIF  PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.nFrameCount > 1)

TAnimatedImage.SetPause       PROCEDURE(BOOL pPause)
  CODE
  IF SELF.IsAnimatedGIF()
    IF pPause AND NOT SELF.bPause
      winapi::ResetEvent(SELF.hPause)
    ELSIF SELF.bPause AND NOT pPause
      winapi::SetEvent(SELF.hPause)
    END
    SELF.bPause = pPause
  END
  
TAnimatedImage.IsPaused       PROCEDURE()
  CODE
  RETURN SELF.bPause

TAnimatedImage.InitAnimation  PROCEDURE(WINDOW pW, SIGNED pRgnFeq)
thisWin                         TCWnd
rgnWin                          TWnd
nTID                            ULONG, AUTO
  CODE
  IF NOT SELF.bIsInitialized
    SELF.Trace('GIF not initialized.')
    RETURN
  END
  
  SELF.w &= pW
  thisWin.Init(pW)
  rgnWin.Init(pRgnFeq)

  SELF.hWnd = thisWin.GetHandle()
  SELF.rgnFeq = pRgnFeq
  
  !- get image rect
  rgnWin.GetWindowRect(SELF.rc)
  thisWin.ScreenToClient(SELF.rc)
  
  !- overwrite region subclass proc
  rgnWin.SetWindowSubclass(ADDRESS(rgn::SubclassProc), 0, ADDRESS(SELF))

  IF SELF.IsAnimatedGIF()
    IF SELF.hThread = 0
      nTID = 0
      SELF.hThread =  winapi::CreateThread(0, 0, ADDRESS(_ThreadAnimationProc), ADDRESS(SELF), CREATE_SUSPENDED, nTID)
      IF NOT SELF.hThread
        SELF.Trace('Couldn''t start a GIF animation thread.')
      ELSE
        winapi::ResumeThread(SELF.hThread)
      END
    END
  ELSE
    SELF.Draw()
  END
  
TAnimatedImage.KillAnimation  PROCEDURE()
  CODE
  SELF.ClearRect()
  SELF.rc.Assign(0, 0, 0, 0)
  
  IF SELF.hThread
    SELF.SetPause(FALSE)
    winapi::SetEvent(SELF.hExitEvent)
    winapi::WaitForSingleObject(SELF.hThread, INFINITE)
  END
  
  winapi::CloseHandle(SELF.hThread)
  winapi::CloseHandle(SELF.hExitEvent)
  winapi::CloseHandle(SELF.hPause)
  
  SELF.propItem.Free()

TAnimatedImage.Visible        PROCEDURE(<BOOL pVisible>)
  CODE
  IF NOT OMITTED(pVisible)
    SELF.bVisible = pVisible

    IF SELF.bVisible
      IF NOT SELF.IsAnimatedGIF()
        SELF.Draw()
      END
      SELF.SetPause(FALSE)
    ELSE
      SELF.SetPause(TRUE)
      SELF.ClearRect()
    END
  END
  RETURN SELF.bVisible
  
TAnimatedImage.ResetPosition  PROCEDURE()
  CODE
  SELF.nFramePosition = 0
  
TAnimatedImage.TestForAnimatedGIF PROCEDURE()
count                               UNSIGNED, AUTO
DimensionIDs                        &STRING, AUTO
guid1                               LIKE(GUID), AUTO
  CODE
  count = SELF.GetFrameDimensionsCount()
  DimensionIDs &= NEW STRING(count * SIZE(GUID))
  
  !- Get the list of frame dimensions from the Image object.
  SELF.GetFrameDimensionsList(ADDRESS(DimensionIDs), count)
  
  !- Get the number of frames in the first dimension.
  guid1 = DimensionIDs[1 : SIZE(GUID)]
  SELF.nFrameCount = SELF.GetFrameCount(guid1)
  
  !- Get the property item.
  SELF.GetPropertyItem(PropertyTagFrameDelay, SELF.propItem)
  
  DISPOSE(DimensionIDs)
  RETURN CHOOSE(SELF.nFrameCount > 1)
  
TAnimatedImage.Initialize     PROCEDURE()
evName                          CSTRING('')
  CODE
  SELF.nFramePosition = 0
  SELF.nFrameCount = 0
  SELF.hThread = 0
  SELF.bIsInitialized = FALSE
  SELF.bPause = FALSE
  SELF.hExitEvent = winapi::CreateEvent(0, TRUE, FALSE, evName)
  SELF.hPause = winapi::CreateEvent(0, TRUE, TRUE, evName)
  
TAnimatedImage.DrawFrameGIF   PROCEDURE()
pageGuid                        LIKE(GUID), AUTO
adrValue                        LONG, AUTO
lPause                          &LONG, AUTO
  CODE
  winapi::WaitForSingleObject(SELF.hPause, INFINITE)
  pageGuid = FrameDimensionTime
  
  IF NOT SELF.Draw()
    RETURN FALSE
  END
  
  SELF.SelectActiveFrame(pageGuid, SELF.nFramePosition)
  SELF.nFramePosition += 1
  IF SELF.nFramePosition = SELF.nFrameCount
    SELF.nFramePosition = 0
  END
  
  !- get an array element
  adrValue = SELF.propItem.GetValueAddress()
  lPause &= (adrValue + SELF.nFramePosition*4)
  RETURN CHOOSE(winapi::WaitForSingleObject(SELF.hExitEvent, lPause*10) = WAIT_OBJECT_0)
  
TAnimatedImage.Draw           PROCEDURE()
g                               TGdiPlusGraphics
dc                              TDC
gpErr                           GpStatus, AUTO
  CODE
  IF SELF.bVisible
    dc.GetDC(SELF.hWnd)
    gpErr = g.FromHDC(dc.GetHandle())
    IF gpErr = GpStatus:Ok
      g.DrawImage(SELF, SELF.rc)
    END
    dc.ReleaseDC()
  
    RETURN CHOOSE(gpErr = GpStatus:Ok)
  ELSE
    RETURN TRUE
  END
  
TAnimatedImage.ThreadAnimation    PROCEDURE()
bExit                               BOOL, AUTO
  CODE
  SELF.nFramePosition = 0
  bExit = FALSE
  LOOP WHILE bExit = FALSE
    bExit = SELF.DrawFrameGIF()
  END
  
TAnimatedImage.ClearRect      PROCEDURE()
bkColor                         LONG, AUTO
dc                              TDC
g                               TGdiPlusGraphics
brush                           TGdiPlusSolidBrush
  CODE
  IF dc.GetDC(SELF.hWnd)
    g.FromHDC(dc.GetHandle())
    !- determine window background
    bkColor = SELF.w{PROP:Color}
    IF bkColor <> COLOR:NONE
      IF BAND(bkColor, 80000000h)
        bkColor = winapi::GetSysColor(BAND(bkColor, 0ffffh))
      END
    ELSE
      IF SELF.w{PROP:Gray}
        bkColor = COLOR:WINDOWGRAY
      ELSE
        bkColor = COLOR:WHITE
      END
    END
    !- erase background
    brush.CreateSolidBrush(GdipMakeARGB(bkColor))
    g.FillRectangle(brush, SELF.rc)
    brush.DeleteBrush()
  ELSE
    !- window was closed.
!    SELF.Trace(printf('HDC %x', dc.GetHandle()))
  END
  
TAnimatedImage.OnPosChanged   PROCEDURE(LONG lParam)
wp                              &tagWINDOWPOS, AUTO
bPause                          BOOL, AUTO
  CODE
  wp &= (lParam)
  bPause = SELF.IsPaused()
  SELF.SetPause(TRUE)

  SELF.ClearRect()
  
  SELF.rc.left = wp.x
  SELF.rc.top = wp.y
  SELF.rc.Width(wp.cx)
  SELF.rc.Height(wp.cy)
  SELF.Draw()
  
  SELF.SetPause(bPause)
