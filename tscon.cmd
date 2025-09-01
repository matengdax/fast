for /f "skip=1 tokens=3" %%s in ('query user %USERNAME%') do (
  %windir%\System32\tscon.exe %%s /dest:console
)
REM 当你通过远程桌面连接到服务器时，如果需要将当前会话转移回服务器的本地终端（控制台）而不结束会话，可以运行这段脚本
