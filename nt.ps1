<#
.SYNOPSIS
    一个多功能的 Windows 初始化和配置脚本。
    默认执行服务器高级初始化；使用 -Home 参数执行家庭/开发环境软件安装。

.DESCRIPTION
    此脚本集成了两种不同的配置流程：
    1. 默认流程: 配置系统设置、创建用户、安装Python等，适用于服务器初始化。此流程将设置电源计划为“高性能”。
    2. Home 流程 (-Home): 设置电源计划为“卓越性能”，并使用 Winget 批量安装常用软件。

    脚本会自动请求管理员权限。

.PARAMETER Home
    一个开关参数。如果提供此参数，脚本将执行 "Home" 流程。

.EXAMPLE
    # 执行默认的服务器初始化配置 (设置“高性能”电源)
    .\nt.ps1

    # 执行家庭/开发环境软件安装 (设置“卓越性能”电源)
    .\nt.ps1 -Home

.NOTES
    作者: Gemini & User Collaboration
    版本: 3.1 - 电源管理策略调整
#>

# ===================================================================
# --- 脚本参数定义 ---
# ===================================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, HelpMessage="如果指定此参数，将执行家庭/开发环境软件安装流程。")]
    [Switch]
    $Home
)

# ===================================================================
# --- 1. 全局管理员权限检查 (对所有流程生效) ---
# ===================================================================
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "需要管理员权限，正在尝试以管理员身份重新运行..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $MyInvocation.MyCommand.Path, $PSBoundParameters.Keys)
    exit
}
Write-Host "脚本已在管理员模式下运行。" -ForegroundColor Green


# ===================================================================
# --- 函数定义区域 ---
# ===================================================================

# --- 函数 A: 服务器初始化逻辑 (Script 1) ---
function Invoke-SystemInitialization {
    Write-Host "===================================================================" -ForegroundColor Magenta
    Write-Host "--- 执行默认流程: 高级系统初始化配置 v2.1 ---" -ForegroundColor Magenta
    Write-Host "===================================================================" -ForegroundColor Magenta
    Write-Host "警告: 此脚本将对系统进行大量修改，包括安全设置。" -ForegroundColor Yellow

    # --- 第一部分: 全局系统配置 ---
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

    # --- 6. 设置电源为“高性能” (服务器推荐) ---
    Write-Host "正在设置电源计划为“高性能”..."
    $HighPerformanceGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    if (powercfg /list | Select-String -Pattern $HighPerformanceGuid -Quiet) {
        powercfg /setactive $HighPerformanceGuid
        Write-Host "电源计划已成功设置为“高性能”。"
    } else {
        Write-Host "未找到“高性能”电源计划。" -ForegroundColor Yellow
    }

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
    Write-Host "Windows Search 服务已禁用。"

    # --- 11. 关闭网络共享/发现 (全局) ---
    Write-Host "正在关闭网络发现功能..."
    netsh advfirewall firewall set rule group="Network Discovery" new enable=No
    Write-Host "网络发现功能已通过防火墙规则禁用。"

    # --- 第二部分: 新用户默认配置 ---
    # ... (此部分代码无变化) ...
	
    # --- 第三部分: 为 sa 用户安装 Python ---
    # ... (此部分代码无变化) ...

    # --- 脚本结束 ---
    Write-Host "`n所有配置已完成! 部分设置(如UAC)需要重启计算机才能完全生效。" -ForegroundColor Green
}


# --- 函数 B: 家庭/开发环境安装逻辑 (Script 2) ---
function Invoke-HomeSetup {
    Write-Host "===================================================================" -ForegroundColor Magenta
    Write-Host "--- 执行 Home 流程: 使用 Winget 批量安装软件 ---" -ForegroundColor Magenta
    Write-Host "===================================================================" -ForegroundColor Magenta
    
    # --- 1. 设置电源为“卓越性能” (家庭/工作站推荐) ---
    Write-Host "`n--- 正在设置电源计划为“卓越性能” ---" -ForegroundColor Cyan
    $UltimatePerformanceGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    # 此命令会解锁并创建一个“卓越性能”计划的副本
    powercfg -duplicatescheme $UltimatePerformanceGuid | Out-Null
    # 激活该计划
    powercfg /setactive $UltimatePerformanceGuid
    Write-Host "电源计划已设置为“卓越性能”。"

    # --- 2. 定义镜像源和软件包列表 ---
    $mirrorName = "TUNA"
    $mirrorUrl = "https://mirrors.tuna.tsinghua.edu.cn/winget-source"
    $packagesToInstall = @(
        'vim.vim',
        'Microsoft.VisualStudioCode',
        'Google.Chrome',
        '7zip.7zip',
        'anaconda.anaconda3',
        'DBBrowserForSQLite.DBBrowserForSQLite',
        'Microsoft.PowerShell',
        'appmakes.Typora',
        'Mozilla.Firefox.ESR',
        'PeterPawlowski.foobar2000',
    )

    # --- 3. 检查并配置 Winget 镜像源 ---
    Write-Host "`n--- 正在检查和配置 Winget 镜像源 ---" -ForegroundColor Cyan
    try {
        $source = winget source list --name $mirrorName
        if ($null -eq $source) {
            Write-Host "未找到 '$mirrorName' 镜像源，开始配置..."
            Write-Host "正在移除默认 'winget' 源..."
            winget source remove winget --disable-interactivity | Out-Null
            Write-Host "正在添加 '$mirrorName' 镜像源: $mirrorUrl"
            winget source add --name $mirrorName --arg $mirrorUrl --type "Microsoft.PreIndexed.Package" --accept-source-agreements
            Write-Host "正在更新源..."
            winget source update
            Write-Host "'$mirrorName' 镜像源配置完成。" -ForegroundColor Green
        } else {
            Write-Host "'$mirrorName' 镜像源已存在，跳过配置。" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "配置 Winget 镜像源时发生错误: $_"
        exit
    }

    # --- 4. 遍历并安装所有指定的软件包 ---
    Write-Host "`n--- 开始安装软件包 ---" -ForegroundColor Cyan
    Write-Host "共计 $($packagesToInstall.Count) 个软件包需要安装。"
    foreach ($packageId in $packagesToInstall) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ==> 正在处理: $packageId" -ForegroundColor Yellow
        $installed = winget list --id $packageId -n 1
        if ($installed) {
            Write-Host "$packageId 已经安装，跳过。" -ForegroundColor Green
            continue
        }
        try {
            Write-Host "正在安装 $packageId ..."
            winget install --id $packageId --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "$packageId 安装成功。" -ForegroundColor Green
            } else {
                Write-Warning "$packageId 安装失败或已取消。退出代码: $LASTEXITCODE"
            }
        }
        catch {
            Write-Error "安装 $packageId 时发生严重错误: $_"
        }
    }
    Write-Host "`n--- Home 流程所有任务已完成 ---" -ForegroundColor Cyan
}


# ===================================================================
# --- 主逻辑: 根据参数决定执行哪个函数 ---
# ===================================================================
if ($Home.IsPresent) {
    # 如果用户提供了 -Home 参数
    Invoke-HomeSetup
}
else {
    # 默认行为
    Invoke-SystemInitialization
}
