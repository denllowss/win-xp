@echo off
REM ============================================================================
REM Optimasi Otomatis Windows XP SP3 untuk Fast RDP & Cloud Container (Railway)
REM Dieksekusi otomatis saat first-boot dari C:\OEM\install.bat
REM ============================================================================

REM 1. Pastikan Remote Desktop (RDP) aktif, kompatibel dengan klien modern, dan sesi tidak diputus saat idle
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v SecurityLayer /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MinEncryptionLevel /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxDisconnectionTime /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxIdleTime /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 0 /f >nul 2>&1

sc config TermService start= auto >nul 2>&1
net start TermService >nul 2>&1

REM 2. Buka port 3389 (TCP & UDP) di Windows XP Firewall
netsh firewall set service type = REMOTEDESKTOP mode = ENABLE scope = ALL >nul 2>&1
netsh firewall set portopening protocol = TCP port = 3389 name = "Remote Desktop TCP" mode = ENABLE scope = ALL >nul 2>&1
netsh firewall set portopening protocol = UDP port = 3389 name = "Remote Desktop UDP" mode = ENABLE scope = ALL >nul 2>&1

REM 3. Matikan service latar belakang berat (mencegah bug svchost wuauserv 100%% CPU di XP SP3 & hemat I/O disk)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f >nul 2>&1
for %%S in (wuauserv srservice cisvc ERSvc wscsvc Messenger Alerter FastUserSwitchingCompatibility) do (
    net stop %%S >nul 2>&1
    sc config %%S start= disabled >nul 2>&1
)

REM 4. Matikan dialog Error Reporting & Desktop Cleanup Wizard agar desktop bersih & responsif
reg add "HKLM\SOFTWARE\Microsoft\PCHealth\ErrorReporting" /v DoReport /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PCHealth\ErrorReporting" /v ShowUI /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\CleanupWiz" /v NoRun /t REG_DWORD /d 1 /f >nul 2>&1

REM 5. Optimasi TCP/IP untuk responsivitas RDP
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v SackOpts /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 65535 /f >nul 2>&1

REM 6. Tambahkan fallback host.lan pada file hosts jika mode SLIRP tanpa dnsmasq aktif
findstr /I "host.lan" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if errorlevel 1 (
    echo 10.0.2.1 host.lan >> "%SystemRoot%\System32\drivers\etc\hosts"
)

exit /b 0
