@echo off
echo =====================================================
echo    Galaxy Bluetooth MAC Address Scanner
echo =====================================================
echo.

:: 블루투스 서비스 확인
sc query bthserv | find "RUNNING" >nul
if %errorLevel% neq 0 (
    echo [INFO] 블루투스 서비스 시작 중...
    sc start bthserv
    timeout /t 3
)

:: 근처 블루투스 디바이스 스캔
echo [SCAN] 근처 블루투스 디바이스 스캔 중...
powershell -Command "Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq 'OK' -or $_.Status -eq 'Unknown'} | Select-Object Name, InstanceId"

echo.
echo [SCAN] 블루투스 어댑터 정보:
powershell -Command "Get-NetAdapter | Where-Object {$_.InterfaceDescription -like '*Bluetooth*'} | Select-Object Name, MacAddress"

pause
