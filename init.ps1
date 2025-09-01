# --- 1. 优化电源计划 ---

# 复制一份现有的“卓越性能”电源计划。
# "e9a42b02-d5df-448d-aa00-03f14749eb61" 是 "卓越性能" (Ultimate Performance) 模式的唯一标识符(GUID)。
# 如果该计划已存在，此命令可以确保它被正确识别。
powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

# 将刚刚复制或已存在的“卓越性能”电源计划设置为当前激活的计划。
# 这会调整系统设置以获得最高的性能，通常用于需要极致响应速度的任务。
powercfg.exe /setactive e9a42b02-d5df-448d-aa00-03f14749eb61

# --- 2. 下载Python安装程序 ---

# 定义要下载的Python安装程序的URL。这里使用的是阿里云的镜像源，下载速度在国内会很快。
$uri = "https://mirrors.aliyun.com/python-release/windows/python-3.10.11-amd64.exe"

# 从URL中提取出文件名 (例如 "python-3.10.11-amd64.exe") 并存入变量 $fn。
$fn = Split-Path -Leaf $uri

# 使用Windows后台智能传输服务(BITS)来下载文件。
# BITS是一个健壮的下载服务，支持断点续传，比传统的Web请求更可靠。
Start-BitsTransfer -Source $uri -Description $fn

# --- 3. 静默安装Python ---

# 启动下载好的Python安装程序进程。
# -ArgumentList 传递命令行参数给安装程序。
#   "/passive" 表示被动模式安装，用户会看到一个进度条，但无需任何交互。
#   "/PrependPath=1" 是一个关键参数，它告诉安装程序将Python的路径添加到系统环境变量PATH的最前面，确保它被优先找到。
# -Wait 参数让PowerShell脚本等待安装过程完全结束后再继续执行下面的命令。
Start-Process -FilePath $fn -ArgumentList ("/passive", "/PrependPath=1") -Wait

# --- 4. 更新当前会话的环境变量 ---

# 动态查找Python的安装路径。这比写死路径更灵活，因为它会自动找到安装的确切位置。
$py_home = (Get-ChildItem $env:localappdata\Programs\Python\Python*).FullName

# 将Python的主目录添加到当前用户的PATH环境变量中。
# 注意：这一步和下一步主要是为了让当前打开的PowerShell会话立即识别到Python路径。
# 因为安装程序虽然修改了系统设置，但当前会话可能需要重启才能加载新的环境变量。
[System.Environment]::SetEnvironmentVariable("Path", [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + $py_home, "User")

# 将Python的Scripts目录 (pip.exe所在的位置) 也添加到当前用户的PATH环境变量中。
[System.Environment]::SetEnvironmentVariable("Path", [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + $py_home + "\Scripts;", "User")

# --- 5. 配置pip并升级 ---

# 配置pip的全局镜像源为清华大学的镜像。
# 这会让后续使用pip安装库时速度飞快，因为它会从国内的服务器下载。
Start-Process $py_home\python.exe -ArgumentList ("-m", "pip", "config", "set", "global.index-url", "https://pypi.tuna.tsinghua.edu.cn/simple")

# 使用新配置的镜像源来升级pip自身到最新版本。这是一个好习惯，可以避免很多潜在问题。
Start-Process $py_home\python.exe -ArgumentList ("-m", "pip", "install", "--upgrade", "pip")
<#
pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
python -m pip install --upgrade pip
pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple some-package
python -m pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip
#>

net accounts /lockoutthreshold:0
# Set-ADDefaultDomainPasswordPolicy -LockoutThreshold 0
