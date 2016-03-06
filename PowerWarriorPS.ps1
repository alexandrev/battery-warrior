Param(
    $computer = "localhost",
    $logPath = "C:\Windows\Temp",
    $sleepTime = 60,
    $appData = "D:\Projects\GitHub\battery-warrior\apps.data"
)

Import-Module PSLogging
Start-Log -LogPath $logPath -LogName "battery-warrior.log" -ScriptVersion "1.0" | out-null
$fullLogPath = $logPath + "/battery-warrior.log" 

Function loadIcon {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

    $objNotifyIcon.Icon = "D:\Projects\GitHub\battery-warrior\resources\icon.ico"
    return $objNotifyIcon;  
}

Function showMessage {    
    Param(
    $title = "Battery Warrior",
    $text = "Sample Text",  
    $obj = $null     
    )

    $obj.BalloonTipIcon = "Info" 
    $obj.BalloonTipText = $text
    $obj.BalloonTipTitle = $title
    $obj.Visible = $True 
    $obj.ShowBalloonTip(10000)
}

Function isOnAC
{
Param(
[string]$computer
)
$batteryStatus = (Get-WmiObject -Class BatteryStatus -Namespace root\wmi -ComputerName $computer)
[BOOL]$batteryStatus.PowerOnLine -or -not $batteryStatus.PowerOnLine -and -not $batteryStatus.Discharging
} 


Function managingApps
{
Param(
   [string]$filePath = $appData,
   [string]$mode = "1"
)
$reader = [System.IO.File]::OpenText($filePath)
try {
    Write-LogInfo -LogPath $fullLogPath -Message  "Starting to managing the applications" -TimeStamp
    for(;;) {
        $line = $reader.ReadLine()
        if ($line -eq $null) { break }
            Write-LogInfo -LogPath $fullLogPath -Message  "Managing the application:  $line" -TimeStamp
        if ($mode -eq "1"){
            $absolutePath = resolve-path $line
            $Process = Get-Process | Where-Object {$_.Path -like $absolutePath}
            if($Process.Path -eq $null){
                Write-LogInfo -LogPath $fullLogPath -Message  "Started process $absolutePath" -TimeStamp
                Start-Process $line
                Write-LogInfo -LogPath $fullLogPath -Message  "Started process" -TimeStamp                 
            }
            else{
                Write-LogInfo -LogPath $fullLogPath -Message  "Process $absolutePath is already running" -TimeStamp  
            }

        }
        else{
            Get-Process | Where-Object {$_.Path -like $line} | Stop-Process
            Write-LogInfo -LogPath $fullLogPath -Message  "Stop process" -TimeStamp
        }
    }
    Write-LogInfo -LogPath $fullLogPath -Message  "Managing the applications finished" -TimeStamp
}
finally {
    $reader.Close()
}
}


Write-LogInfo -LogPath $fullLogPath -Message "Starting the execution of the BatteryWarrior." -TimeStamp
$obj = loadIcon
$WorkingFlag = $true
$CurrentMode = "-1"
try{
    while ($WorkingFlag -eq $true){    
        Write-LogInfo -LogPath $fullLogPath -Message  "Checking for a change of state of the laptop"  -TimeStamp   
        $isPowered = (isOnAC -computer $computer)
        Write-LogInfo -LogPath $fullLogPath -Message  "The laptop is currently under AC power: $isPowered" -TimeStamp
        if($isPowered -eq $true){
            Write-LogInfo -LogPath $fullLogPath -Message  "Analyzing the $CurrentMode and comparing to the laptop status" -TimeStamp
            if(-not ($CurrentMode -eq "1")) {
                showMessage -obj $obj -title "Battery Warrior" -text "Launching High Power Consuming Apps" 
                Write-LogInfo -LogPath $fullLogPath -Message  "Launching High Power Consuming Apps" -TimeStamp
                managingApps -mode "1" -filePath $appData
                $CurrentMode = "1"
            }
        }else{
            Write-LogInfo -LogPath $fullLogPath -Message  "2 Analyzing the $CurrentMode and comparing to the laptop status" -TimeStamp
            if(-not ($CurrentMode -eq "0")) {
                showMessage -obj $obj -title "Battery Warrior" -text "Killing High Power Consuming Apps"
                Write-LogInfo -LogPath $fullLogPath -Message  "Killing High Power Consuming Apps" -TimeStamp
                managingApps -mode "0" -filePath $appData
                $CurrentMode = "0"
            }
        }
        
        Write-LogInfo -LogPath $fullLogPath -Message  "Current Mode: $CurrentMode" -TimeStamp
        Write-LogInfo -LogPath $fullLogPath -Message  "Sleeping for $sleepTime seconds" -TimeStamp
        sleep $sleepTime    
    }

}finally
{
    $obj.Dispose()
    Stop-Log -LogPath $fullLogPath
}
