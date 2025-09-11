# ===================================================================
# PowerShell 高级初始化配置脚本 v2.0
#
# 新增功能:
# - 全局关闭 Windows 防火墙
# - 全局禁用 UAC、Windows Search 索引器、网络发现
# - 全局启用远程桌面
# - 为新用户 (包括 sa) 预设 Windows 界面和功能选项
# ===================================================================

# --- 脚本初始化 ---
Write-Host "开始执行高级系统初始化配置脚本..." -ForegroundColor Green
Write-Host "警告: 此脚本将对系统进行大量修改，包括安全设置。" -ForegroundColor Yellow

# ===================================================================
# --- 第一部分: 全局系统配置 ---
# ===================================================================
Write-Host "`n--- 正在执行全局系统配置 ---" -ForegroundColor Cyan

# --- 1. 添加用户 ---
Write-Host "正在创建用户 'sa' 和 'agent'..."
$password = ConvertTo-SecureString "qwer1234" -AsPlainText -Force
if (-not (Get-LocalUser -Name "sa" -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name "sa" -Password $password -FullName "SA User"
    Add-LocalGroupMember -Group "Administrators" -Member "sa"
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member "sa"
    Set-LocalUser -Name "sa" -PasswordNeverExpires $true
    Write-Host "用户 'sa' 创建成功，已设为管理员和远程桌面用户。"
} else { Write-Host "用户 'sa' 已存在。" }

if (-not (Get-LocalUser -Name "agent" -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name "agent" -Password $password -FullName "Agent User"
    Set-LocalUser -Name "agent" -PasswordNeverExpires $true
    Write-Host "用户 'agent' 创建成功。"
} else { Write-Host "用户 'agent' 已存在。" }

# --- 2. 设置 OpenSSH ---
Write-Host "正在安装和配置 OpenSSH Server..."
if (-not (Get-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" -ErrorAction SilentlyContinue).State) {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force -ErrorAction SilentlyContinue
Write-Host "OpenSSH Server 配置完成。"

# --- 3. 关闭 Windows Defender ---
Write-Host "正在禁用 Windows Defender..."
Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true -DisablePrivacyMode $true -MAPSReporting Disabled -SubmitSamplesConsent Never -Force
Write-Host "Windows Defender 实时保护功能已禁用。"

# --- 4. 禁用自动更新 ---
Write-Host "正在禁用 Windows 自动更新服务..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Set-Service -Name wuauserv -StartupType Disabled
Write-Host "Windows Update 服务已禁用。"

# --- 5. 设置账户锁定策略 ---
Write-Host "正在配置账户锁定策略以允许无限次登录尝试..."
net accounts /lockoutthreshold:0
Write-Host "账户锁定策略已更新。"

# --- 6. 设置电源为“卓越性能” ---
Write-Host "正在设置电源计划为“卓越性能”..."
$UltimatePerformanceGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
powercfg -duplicatescheme $UltimatePerformanceGuid
powercfg /setactive $UltimatePerformanceGuid
Write-Host "电源计划已设置为“卓越性能”。"

# --- 7. 关闭 Windows 防火墙 (全局) ---
Write-Host "正在关闭所有配置文件的 Windows 防火墙..."
Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled False
Write-Host "Windows 防火墙已为所有配置文件关闭。"

# --- 8. 允许远程连接到此计算机 (全局) ---
Write-Host "正在启用远程桌面..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Write-Host "远程桌面已启用。"

# --- 9. 关闭 UAC 用户账户控制 (全局) ---
Write-Host "正在禁用 UAC (用户账户控制)..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0
Write-Host "UAC 已禁用，重启后完全生效。" -ForegroundColor Yellow

# --- 10. 关闭 Windows Search 索引器服务 (全局) ---
Write-Host "正在禁用 Windows Search 索引器服务..."
Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
Set-Service -Name WSearch -StartupType Disabled
# 清空索引位置 (需要重启服务生效，但我们已经禁用了)
# Get-CimInstance -Namespace "root\CIMV2" -ClassName "Win32_Service" -Filter "Name='WSearch'" | Invoke-CimMethod -MethodName "StopService"
# Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Windows Search 服务已禁用。"

# --- 11. 关闭网络共享/发现 (全局) ---
Write-Host "正在关闭网络发现功能..."
netsh advfirewall firewall set rule group="Network Discovery" new enable=No
Write-Host "网络发现功能已通过防火墙规则禁用。"


# ===================================================================
# --- 第二部分: 新用户默认配置 (针对 SA 及未来所有新用户) ---
# ===================================================================
Write-Host "`n--- 正在为新用户配置默认设置 ---" -ForegroundColor Cyan
Write-Host "此部分将修改默认用户配置文件，影响所有未来创建的新用户。"

# 挂载默认用户的注册表配置单元
$DefaultUserHive = "C:\Users\Default\NTUSER.DAT"
if(Test-Path $DefaultUserHive) {
    reg load "hku\DefaultUser" $DefaultUserHive

    # --- 开始修改注册表 ---
    
    # 2.1 显示文件扩展名
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    
    # 2.2 任务栏: 关闭“任务视图”按钮
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
    
    # 2.3 任务栏: 隐藏搜索框 (0=隐藏, 1=仅图标, 2=搜索框)
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
    
    # 2.4 任务栏: 关闭资讯和兴趣
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2
    
    # 2.5 文件资源管理器: 关闭“在快速访问”中显示最近使用的文件
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0

    # 2.6 文件资源管理器: 关闭“在快速访问”中显示常用文件夹
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0

    # 2.7 文件资源管理器: 搜索不包括系统目录
    Set-ItemProperty -Path "hku:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Search\Preferences" -Name "SearchFindSystemFolders" -Value 0 -Force
    
    # --- 修改结束，卸载配置单元 ---
    reg unload "hku\DefaultUser"
    Write-Host "新用户默认配置已成功应用。"
} else {
    Write-Host "未找到默认用户配置文件(NTUSER.DAT)，跳过此部分。" -ForegroundColor Yellow
}


# ===================================================================
# --- 第三部分: 为 sa 用户安装 Python ---
# ===================================================================
Write-Host "`n--- 正在为用户 'sa' 安装和配置 Python ---" -ForegroundColor Cyan
$PythonInstallerUrl = "https://mirrors.aliyun.com/python-release/windows/python-3.10.11-amd64.exe"
$InstallerPath = Join-Path $env:TEMP "python-installer.exe"

# 下载
try {
    Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $InstallerPath
    Write-Host "Python 安装程序下载成功。"
} catch {
    Write-Host "Python 安装程序下载失败。脚本将终止。" -ForegroundColor Red; exit
}

# 静默安装 Python 给所有用户
Start-Process -FilePath $InstallerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
Write-Host "Python 3.10.11 安装完成。"

# 为 sa 用户配置 pip 镜像
$saProfilePath = "C:\Users\sa"
$pipConfigPath = Join-Path $saProfilePath "AppData\Roaming\pip"
$pipConfigFile = Join-Path $pipConfigPath "pip.ini"
if (-not (Test-Path $pipConfigPath)) { New-Item -Path $pipConfigPath -ItemType Directory -Force }
$pipConfigContent = "[global]`r`nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple"
$pipConfigContent | Out-File -FilePath $pipConfigFile -Encoding utf8 -Force
Write-Host "已为用户 'sa' 配置 pip 清华大学镜像源。"

# 升级 pip 并安装 ipython
try {
    $pythonExe = Get-Command python.exe | Select-Object -ExpandProperty Source
    & $pythonExe -m pip install --upgrade pip
    & $pythonExe -m pip install ipython
    Write-Host "pip 更新和 ipython 安装成功。"
} catch {
    Write-Host "pip 操作失败。请检查 Python 是否正确安装并添加到了系统 PATH。" -ForegroundColor Red
}

# 清理
Remove-Item -Path $InstallerPath -Force
Write-Host "已删除 Python 安装程序。"

# --- 脚本结束 ---
Write-Host "`n所有配置已完成! 部分设置(如UAC)需要重启计算机才能完全生效。" -ForegroundColor Green
