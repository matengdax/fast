# 指定目标路径
# $targetPath = Read-Host "请输入目标路径"
  $targetPath = 'D:\'

# 检查路径是否存在
if (-Not (Test-Path -Path $targetPath)) {
    Write-Host "路径不存在，请检查后重新运行脚本。" -ForegroundColor Red
    exit
}

# 获取目标路径下的所有一级子目录
$directories = Get-ChildItem -Path $targetPath -Directory

# 遍历每个子目录并重命名
foreach ($dir in $directories) {
    $oldName = $dir.FullName
    $newName = "$($dir.FullName).7z"

    # 重命名目录
    Rename-Item -Path $oldName -NewName $newName

    Write-Host "已重命名: $oldName -> $newName" -ForegroundColor Green
}

Write-Host "所有一级目录已完成重命名。" -ForegroundColor Cyan
