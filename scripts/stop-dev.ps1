# ============================================================
#  北辰 CRM 一键停止脚本
#  入口：双击项目根目录的 stop-dev.bat
#  作用：按端口找到后端(java)/前端(node)进程并结束，只动本项目的进程
# ============================================================

$ErrorActionPreference = 'Stop'

# 控制台统一用 UTF-8，避免不同系统代码页下中文乱码（配套 .bat 里已 chcp 65001）
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$BackendPort  = 8080
$FrontendPort = 5180

$Root    = Split-Path -Parent $PSScriptRoot
$LogDir  = Join-Path $Root 'logs'
$PidFile = Join-Path $LogDir 'run.pids'

function Head($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }
function Say($m)  { Write-Host "       $m" }
function Ok($m)   { Write-Host "   OK  $m" -ForegroundColor Green }
function Skip($m) { Write-Host "   --  $m" -ForegroundColor DarkYellow }
function Bad($m)  { Write-Host "   !!  $m" -ForegroundColor Red }

function Test-Port([int]$port) {
    # Vite 默认只监听 [::1]，TcpClient 默认是 IPv4 套接字，需按地址族分别试
    $targets = @(
        @{ Host = '127.0.0.1'; Family = [System.Net.Sockets.AddressFamily]::InterNetwork },
        @{ Host = '::1';       Family = [System.Net.Sockets.AddressFamily]::InterNetworkV6 }
    )
    foreach ($t in $targets) {
        $client = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient($t.Family)
            $async = $client.BeginConnect($t.Host, $port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne(350)) {
                $client.EndConnect($async)
                return $true
            }
        } catch {
        } finally {
            if ($client) { $client.Close() }
        }
    }
    return $false
}

function Get-PidsByPort([int]$port) {
    $result = @()
    # 不加 -p TCP，否则查不到 IPv6 监听（Vite 默认就监听 [::1]）
    $lines = & netstat -ano 2>$null
    foreach ($line in $lines) {
        if ($line -match '^\s*TCP\s+\S+:(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$') {
            if ([int]$Matches[1] -eq $port) {
                $procId = [int]$Matches[2]
                if ($procId -gt 0 -and $result -notcontains $procId) { $result += $procId }
            }
        }
    }
    if ($result.Count -eq 0) {
        try {
            foreach ($c in (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)) {
                $procId = [int]$c.OwningProcess
                if ($procId -gt 0 -and $result -notcontains $procId) { $result += $procId }
            }
        } catch {
        }
    }
    return $result
}

# 只允许结束这些进程名，防止误杀其他程序
$allowed = @('java', 'javaw', 'node', 'cmd', 'npm')

function Stop-ByIdSafe([int]$procId) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $p) {
        Skip "进程 $procId 已不存在"
        return $false
    }
    if ($allowed -notcontains $p.ProcessName.ToLower()) {
        Bad "进程 $procId 是 $($p.ProcessName)，不属于本项目，已跳过"
        return $false
    }
    try {
        Stop-Process -Id $procId -Force -ErrorAction Stop
        Ok "已结束 $($p.ProcessName)（PID $procId）"
        return $true
    } catch {
        try {
            & taskkill /PID $procId /T /F | Out-Null
            Ok "已结束 $($p.ProcessName)（PID $procId，含子进程）"
            return $true
        } catch {
            Bad "结束进程 $procId 失败：$($_.Exception.Message)"
            return $false
        }
    }
}

Write-Host ''
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host '                北辰 CRM  停止服务' -ForegroundColor Cyan
Write-Host '====================================================' -ForegroundColor Cyan

$stopped = 0

# ---------- 1. 按记录文件停 ----------
Head '[1/2] 清理记录的进程'

if (Test-Path $PidFile) {
    foreach ($line in (Get-Content -Path $PidFile -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*(backend|frontend)\s*=\s*(\d+)\s*$') {
            $role = $Matches[1]
            $procId = [int]$Matches[2]
            $label = if ($role -eq 'backend') { '后端' } else { '前端' }
            Say "$label  记录 PID $procId"
            if (Stop-ByIdSafe $procId) { $stopped++ }
        }
    }
} else {
    Skip '没有进程记录文件，改为按端口查找'
}

# ---------- 2. 按端口兜底 ----------
Head '[2/2] 按端口兜底检查'

foreach ($item in @(@{ Port = $BackendPort; Name = '后端' }, @{ Port = $FrontendPort; Name = '前端' })) {
    $port = $item.Port
    $name = $item.Name
    if (-not (Test-Port $port)) {
        Skip "$name  端口 $port 已空闲"
        continue
    }
    $procIds = Get-PidsByPort $port
    if ($procIds.Count -eq 0) {
        Bad "$name  端口 $port 仍被占用，但未找到占用进程（可能需要管理员权限）"
        continue
    }
    foreach ($procId in $procIds) {
        Say "$name  端口 $port 被 PID $procId 占用"
        if (Stop-ByIdSafe $procId) { $stopped++ }
    }
}

# ---------- 收尾 ----------
Start-Sleep -Milliseconds 800

$leftBack  = Test-Port $BackendPort
$leftFront = Test-Port $FrontendPort

Write-Host ''
Write-Host '====================================================' -ForegroundColor Green
if (-not $leftBack -and -not $leftFront) {
    Write-Host '                   已全部停止' -ForegroundColor Green
} else {
    Write-Host '                   部分端口仍被占用' -ForegroundColor Yellow
    if ($leftBack)  { Write-Host "  后端 $BackendPort 仍占用" -ForegroundColor Yellow }
    if ($leftFront) { Write-Host "  前端 $FrontendPort 仍占用" -ForegroundColor Yellow }
    Write-Host '  可尝试以管理员身份运行本脚本' -ForegroundColor DarkGray
}
Write-Host '====================================================' -ForegroundColor Green
Write-Host ''

if ($stopped -eq 0 -and -not $leftBack -and -not $leftFront) {
    Write-Host '  服务本来就是停着的，无需操作。' -ForegroundColor DarkGray
}
Write-Host ''
