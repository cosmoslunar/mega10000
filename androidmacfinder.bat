@echo off
setlocal enabledelayedexpansion
title Galaxy Aggressive Scanner
color 0C

echo =====================================================
echo     Galaxy Aggressive Bluetooth Scanner
echo =====================================================

sc query bthserv | find "RUNNING" >nul
if %errorLevel% neq 0 (
    sc start bthserv >nul 2>&1
    timeout /t 3 >nul
)

echo [SCAN] 강제 블루투스 디스커버리 시작...

powershell -ExecutionPolicy Bypass -Command "& {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 })[0]
    
    function Await($WinRtTask, $ResultType) {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }
    
    try {
        [Windows.Devices.Bluetooth.BluetoothAdapter,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
        [Windows.Devices.Bluetooth.BluetoothDevice,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
        [Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher,Windows.Devices.Bluetooth,ContentType=WindowsRuntime] | Out-Null
        
        $adapter = Await ([Windows.Devices.Bluetooth.BluetoothAdapter]::GetDefaultAsync()) ([Windows.Devices.Bluetooth.BluetoothAdapter])
        
        if ($adapter -ne $null) {
            Write-Host '[SUCCESS] 블루투스 어댑터 활성화됨'
            
            $watcher = [Windows.Devices.Bluetooth.Advertisement.BluetoothLEAdvertisementWatcher]::new()
            $watcher.ScanningMode = [Windows.Devices.Bluetooth.Advertisement.BluetoothLEScanningMode]::Active
            
            $foundDevices = @{}
            
            $received = {
                param($sender, $args)
                $address = $args.BluetoothAddress
                $mac = '{0:X12}' -f $address
                $mac = $mac -replace '(.{2})(?=.)', '$1:'
                $name = $args.LocalName
                $rssi = $args.RawSignalStrengthInDBm
                
                if (-not $foundDevices.ContainsKey($address)) {
                    $foundDevices[$address] = $true
                    
                    if ([string]::IsNullOrEmpty($name)) {
                        $name = 'Unknown Device'
                    }
                    
                    if ($name -like '*Galaxy*' -or $name -like '*Samsung*' -or $name -like '*SM-*' -or $mac -like '08:*' -or $mac -like 'AC:*' -or $mac -like 'E4:*') {
                        Write-Host '[TARGET FOUND]' -ForegroundColor Red
                        Write-Host 'Name: ' $name -ForegroundColor Yellow
                        Write-Host 'MAC: ' $mac -ForegroundColor Cyan
                        Write-Host 'RSSI: ' $rssi ' dBm' -ForegroundColor White
                        Write-Host '=========================' -ForegroundColor Red
                    } else {
                        Write-Host '[DEVICE]' $name '|' $mac '|' $rssi 'dBm' -ForegroundColor Gray
                    }
                }
            }
            
            Register-ObjectEvent -InputObject $watcher -EventName 'Received' -Action $received | Out-Null
            
            Write-Host '[SCAN] 30초간 적극적 스캔 시작...'
            $watcher.Start()
            Start-Sleep -Seconds 30
            $watcher.Stop()
            
            Write-Host '[INFO] 총 ' $foundDevices.Count ' 개 디바이스 발견'
            
        } else {
            Write-Host '[ERROR] 블루투스 어댑터를 찾을 수 없습니다.'
        }
    } catch {
        Write-Host '[ERROR] ' $_.Exception.Message
    }
}"

pause
