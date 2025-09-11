<#
.SYNOPSIS
    使用 Winget 和清华大学镜像源批量安装指定的软件包。

.DESCRIPTION
    此脚本首先确保以管理员权限运行。
    然后，它会配置 Winget 以使用清华大学（TUNA）的镜像源，以加速下载。
    最后，它会遍历一个预定义的列表，并自动安装所有指定的软件包。

.NOTES
    作者: Gemini
    版本: 1.0
#>

# 1. 自动请求管理员权限
# 检查当前是否为管理员，如果不是，则以管理员身份重新运行此脚本
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "需要管理员权限，正在尝试以管理员身份重新运行..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $MyInvocation.MyCommand.Path)
    exit
}

# --- 从这里开始，脚本将以管理员权限运行 ---

Write-Host "脚本已在管理员模式下运行。" -ForegroundColor Green

# 2. 定义镜像源和软件包列表
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
    'PeterPawlowski.foobar2000', # <-- 末尾保留这个逗号
    # ^^^ 未来在这里直接粘贴新的一行即可，无需修改上一行
)

# 3. 检查并配置 Winget 镜像源
Write-Host "`n--- 正在检查和配置 Winget 镜像源 ---" -ForegroundColor Cyan

try {
    # 检查 TUNA 镜像是否已存在
    $source = winget source list --name $mirrorName
    if ($null -eq $source) {
        Write-Host "未找到 '$mirrorName' 镜像源，开始配置..."

        # 为了避免冲突，先尝试移除默认的 winget 源
        Write-Host "正在移除默认 'winget' 源..."
        winget source remove winget --disable-interactivity | Out-Null

        # 添加清华大学镜像源
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
    # 如果配置失败，可以选择退出或继续尝试使用默认源
    exit
}


# 4. 遍历并安装所有指定的软件包
Write-Host "`n--- 开始安装软件包 ---" -ForegroundColor Cyan
Write-Host "共计 $($packagesToInstall.Count) 个软件包需要安装。"

foreach ($packageId in $packagesToInstall) {
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] ==> 正在处理: $packageId" -ForegroundColor Yellow

    # 检查软件包是否已经安装
    $installed = winget list --id $packageId -n 1
    if ($installed) {
        Write-Host "$packageId 已经安装，跳过。" -ForegroundColor Green
        continue
    }

    # 如果未安装，则执行安装命令
    try {
        Write-Host "正在安装 $packageId ..."
        # 使用 -h (--silent) 参数进行静默安装
        # 使用 --accept-package-agreements 和 --accept-source-agreements 自动同意协议
        winget install --id $packageId --silent --accept-package-agreements --accept-source-agreements
        
        # 验证安装是否成功
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

Write-Host "`n--- 所有任务已完成 ---" -ForegroundColor Cyan
