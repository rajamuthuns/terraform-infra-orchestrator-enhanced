<powershell>
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
$Environment = "${environment}"
if ([string]::IsNullOrEmpty($Environment)) { $Environment = "dev" }
$Hostname = "${hostname}"
if ([string]::IsNullOrEmpty($Hostname)) { $Hostname = $env:COMPUTERNAME }

# Install IIS
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures -All -NoRestart
Start-Sleep -Seconds 15

# Configure IIS
Import-Module WebAdministration -Force
Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
Stop-WebAppPool -Name "DefaultAppPool" -ErrorAction SilentlyContinue

# Remove default files
$wwwroot = "C:\inetpub\wwwroot"
Remove-Item "$wwwroot\iisstart.htm" -Force -ErrorAction SilentlyContinue

# Create compact web page
$WebContent = @"
<!DOCTYPE html>
<html><head><title>$Environment Windows Server</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#0078d4,#106ebe);min-height:100vh;padding:20px}
.container{max-width:800px;margin:0 auto;background:rgba(255,255,255,0.95);border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,0.2);overflow:hidden}
.header{background:linear-gradient(135deg,#1e3a8a,#1e40af);color:white;padding:30px;text-align:center}
.content{padding:30px}
.status{background:linear-gradient(135deg,#059669,#10b981);color:white;padding:15px;border-radius:8px;margin-bottom:20px;text-align:center}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px}
.card{background:#f8fafc;padding:20px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,0.1);border-left:4px solid #0078d4}
.metric{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #e2e8f0}
.links a{display:inline-block;margin:5px;padding:8px 16px;background:#0078d4;color:white;text-decoration:none;border-radius:5px}
</style></head>
<body><div class="container">
<div class="header"><h1>Windows Web Server</h1><p>Environment: $Environment | Host: $Hostname</p></div>
<div class="content"><div class="status">IIS Web Server Online - ALB Ready!</div>
<div class="grid"><div class="card"><h2>Instance Info</h2>
<div class="metric"><strong>Environment:</strong><span>$Environment</span></div>
<div class="metric"><strong>Hostname:</strong><span>$Hostname</span></div>
<div class="metric"><strong>OS:</strong><span>Windows Server</span></div>
<div class="metric"><strong>Status:</strong><span>Running</span></div></div>
<div class="card"><h2>Features</h2><ul style="list-style:none">
<li>✓ IIS Web Server</li><li>✓ ALB Health Checks</li><li>✓ HTTP Compression</li><li>✓ Security Headers</li></ul></div>
<div class="card" style="text-align:center"><h2>Links</h2>
<a href="/health.txt">Health</a><a href="/status.html">Status</a></div></div></div></div></body></html>
"@

$WebContent | Out-File -FilePath "$wwwroot\index.html" -Encoding UTF8 -Force

# Health endpoints
"OK" | Out-File -FilePath "$wwwroot\health" -Encoding ASCII -NoNewline -Force
"OK" | Out-File -FilePath "$wwwroot\health.txt" -Encoding ASCII -NoNewline -Force

# Status page
$StatusContent = @"
<!DOCTYPE html><html><head><title>Status</title>
<style>body{font-family:'Segoe UI';margin:40px;background:#f8fafc}.container{max-width:600px;margin:0 auto;background:white;padding:20px;border-radius:10px}.metric{display:flex;justify-content:space-between;padding:10px;border-bottom:1px solid #e2e8f0}.ok{color:#059669;font-weight:bold}</style>
</head><body><div class="container"><h1>Server Status</h1>
<div class="metric"><strong>IIS:</strong><span class="ok">Running</span></div>
<div class="metric"><strong>Health:</strong><span class="ok">OK</span></div>
<div class="metric"><strong>ALB:</strong><span class="ok">Ready</span></div>
<p><a href="/">Back</a></p></div></body></html>
"@
$StatusContent | Out-File -FilePath "$wwwroot\status.html" -Encoding UTF8 -Force

# Set default document
Clear-WebConfiguration -Filter "system.webServer/defaultDocument/files" -PSPath "IIS:\"
Add-WebConfiguration -Filter "system.webServer/defaultDocument/files" -Value @{value="index.html"} -PSPath "IIS:\"
Set-WebConfigurationProperty -Filter "system.webServer/defaultDocument" -Name "enabled" -Value "True" -PSPath "IIS:\"

# Configure firewall
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -Force

# Start services
Start-WebAppPool -Name "DefaultAppPool"
Start-Website -Name "Default Web Site"

# Format disks
$Disks = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' }
$DriveLetters = @('D', 'E', 'F', 'G')
$DriveIndex = 0
foreach ($Disk in $Disks) {
    if ($DriveIndex -lt $DriveLetters.Length) {
        $DriveLetter = $DriveLetters[$DriveIndex]
        Initialize-Disk -Number $Disk.Number -PartitionStyle GPT -PassThru |
        New-Partition -DriveLetter $DriveLetter -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data$DriveIndex" -Confirm:$false
        $DriveIndex++
    }
}

# Health monitoring
$HealthScript = 'try{$r=Invoke-WebRequest -Uri "http://localhost/health.txt" -UseBasicParsing -TimeoutSec 5;Add-Content -Path "C:\health.log" -Value "$(Get-Date): OK"}catch{Add-Content -Path "C:\health.log" -Value "$(Get-Date): FAIL"}'
$HealthScript | Out-File -FilePath "C:\health-check.ps1" -Encoding UTF8 -Force
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\health-check.ps1"
$Trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date).AddMinutes(1)
Register-ScheduledTask -TaskName "HealthCheck" -Action $Action -Trigger $Trigger -User "SYSTEM" -Force

Add-Content -Path "C:\setup-complete.log" -Value "$(Get-Date): Windows setup complete" -Force
</powershell>