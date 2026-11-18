# ============================================================
#  北辰 CRM 一键启动脚本
#  入口：双击项目根目录的 start-dev.bat
#  作用：自检环境 -> 必要时打包后端 -> 启动后端 -> 启动前端 -> 打开浏览器
#  说明：后端/前端均以独立进程启动，关掉本窗口不影响服务
# ============================================================

$ErrorActionPreference = 'Stop'

# 控制台统一用 UTF-8，避免不同系统代码页下中文乱码（配套 .bat 里已 chcp 65001）
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ------------------ 可配置项 ------------------
$BackendPort  = 8080
$FrontendPort = 5180
$DbPort       = 3306
$DbPassword   = $env:CRM_DB_PASSWORD   # 从本机环境变量读取
$OpenBrowser  = $true
$BackendWait  = 120        # 等后端就绪的最长秒数（首次建库连接会慢一些）
$FrontendWait = 90
# ---------------------------------------------

if (-not $DbPassword) {
    $secret = Read-Host '请输入本机 MySQL 密码' -AsSecureString
    $DbPassword = [System.Net.NetworkCredential]::new('', $secret).Password
}

# 环境变量优先
if ($env:CRM_DB_PASSWORD) { $DbPassword = $env:CRM_DB_PASSWORD }

$Root       = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $Root 'backend'
$FrontendDir = Join-Path $Root 'frontend'
$JarPath    = Join-Path $BackendDir 'target\crm-backend.jar'
$LogDir     = Join-Path $Root 'logs'
$PidFile    = Join-Path $LogDir 'run.pids'
$StampFile  = Join-Path $BackendDir 'target\.src-stamp'

$BackendLog  = Join-Path $LogDir 'backend.log'
$BackendErr  = Join-Path $LogDir 'backend.err.log'
$FrontendLog = Join-Path $LogDir 'frontend.log'
$FrontendErr = Join-Path $LogDir 'frontend.err.log'

# ------------------ 输出样式 ------------------
function Head($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }
function Say($m)  { Write-Host "       $m" }
function Ok($m)   { Write-Host "   OK  $m" -ForegroundColor Green }
function Skip($m) { Write-Host "   --  $m" -ForegroundColor DarkYellow }
function Bad($m)  { Write-Host "   !!  $m" -ForegroundColor Red }

# ------------------ 工具函数 ------------------
function Test-Port([int]$port) {
    # Vite 默认只监听 [::1]，而 TcpClient 默认是 IPv4 套接字；
    # 必须按地址族分别建套接字去试，否则会漏判（误以为端口空闲）。
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
            # 该地址族连不上，试下一个
        } finally {
            if ($client) { $client.Close() }
        }
    }
    return $false
}

function Get-HttpStatus([string]$url) {
    # 绕开系统代理，避免 localhost 被代理拦截返回 502
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Proxy = $null
        $req.Timeout = 3000
        $req.AllowAutoRedirect = $false
        $res = $req.GetResponse()
        $code = [int]$res.StatusCode
        $res.Close()
        return $code
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    } catch {
        return 0
    }
}

function Wait-Port([int]$port, [int]$timeoutSec, [scriptblock]$alive) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        if (Test-Port $port) { return $true }
        if ($alive -and -not (& $alive)) { return $false }
        Write-Host '.' -NoNewline
        Start-Sleep -Milliseconds 600
    }
    return $false
}

function Resolve-Tool([string]$name) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Resolve-Java {
    if ($env:JAVA_HOME) {
        $p = Join-Path $env:JAVA_HOME 'bin\java.exe'
        if (Test-Path $p) { return $p }
    }
    return (Resolve-Tool 'java.exe')
}

function Get-ViteUrl([string]$logPath, [int]$timeoutSec, [int]$procId) {
    # Vite 发现端口被占用时会自动换端口，所以从日志里读它真实用的是哪个地址
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { return $null }
        if (Test-Path $logPath) {
            $text = Get-Content -Path $logPath -Raw -ErrorAction SilentlyContinue
            if ($text) {
                $clean = $text -replace '\x1b\[[0-9;]*m', ''   # 去掉终端颜色控制符
                $m = [regex]::Match($clean, 'Local:\s+(https?://[^\s]+)')
                if ($m.Success) {
                    $url = $m.Groups[1].Value.Trim()
                    $p = 80
                    try { $p = ([uri]$url).Port } catch { $p = 0 }
                    if ($p -gt 0 -and (Test-Port $p)) { return $url.TrimEnd('/') }
                }
            }
        }
        Write-Host '.' -NoNewline
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Remove-EnvDuplicates {
    # 某些环境（如从 Git Bash / WSL 继承过来的会话）会同时存在 HTTPS_PROXY 和 https_proxy，
    # PowerShell 的 Start-Process 在构造子进程环境块时会因此报「字典中的关键字重复」。
    # Windows 环境变量本就大小写不敏感，删掉重复的小写副本即可，不影响取值。
    $seen = @{}
    foreach ($k in @([System.Environment]::GetEnvironmentVariables().Keys)) {
        $lower = $k.ToLowerInvariant()
        if ($seen.ContainsKey($lower)) {
            $prev = $seen[$lower]
            if ($k -ceq $k.ToUpperInvariant()) {
                [System.Environment]::SetEnvironmentVariable($prev, $null, 'Process')
                $seen[$lower] = $k
            } else {
                [System.Environment]::SetEnvironmentVariable($k, $null, 'Process')
            }
        } else {
            $seen[$lower] = $k
        }
    }
}

function Get-SourceStamp([string]$backendDir) {
    # Spring Boot 打出来的 jar 时间戳被归一化成 1980-01-01（可重现构建），
    # 不能用 jar 的修改时间判断新旧，改为记录源码最新的修改时间。
    $max = [long]0
    $srcDir = Join-Path $backendDir 'src'
    if (Test-Path $srcDir) {
        foreach ($f in (Get-ChildItem -Path $srcDir -Recurse -File -ErrorAction SilentlyContinue)) {
            if ($f.LastWriteTimeUtc.Ticks -gt $max) { $max = $f.LastWriteTimeUtc.Ticks }
        }
    }
    $pom = Join-Path $backendDir 'pom.xml'
    if (Test-Path $pom) {
        $t = (Get-Item $pom).LastWriteTimeUtc.Ticks
        if ($t -gt $max) { $max = $t }
    }
    return $max
}

function Show-Tail([string]$path, [int]$lines = 15) {
    if (Test-Path $path) {
        Write-Host ''
        Write-Host "       --- $path 末尾 $lines 行 ---" -ForegroundColor DarkGray
        Get-Content -Path $path -Tail $lines -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
    }
}

# ------------------ 开始 ------------------
Write-Host ''
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host '                北辰 CRM  一键启动' -ForegroundColor Cyan
Write-Host '====================================================' -ForegroundColor Cyan

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

Remove-EnvDuplicates

$backendPid  = $null
$frontendPid = $null

# ---------- 1. 环境自检 ----------
Head '[1/5] 环境检查'

$java = Resolve-Java
if (-not $java) {
    Bad '找不到 java.exe，请安装 JDK 17 或设置 JAVA_HOME'
    exit 1
}
Ok "java  $java"

if (Test-Port $DbPort) {
    Ok "MySQL  $DbPort 端口可连接"
} else {
    Bad "MySQL 未在 $DbPort 端口监听，后端可能连不上库（先继续尝试启动）"
}

# ---------- 2. 后端 ----------
Head '[2/5] 后端 Spring Boot'

$needStart = $true
if (Test-Port $BackendPort) {
    $st = Get-HttpStatus "http://127.0.0.1:$BackendPort/api/auth/me"
    if ($st -eq 401 -or $st -eq 200) {
        Skip "后端已在 $BackendPort 运行，跳过启动"
        $needStart = $false
    } else {
        Bad "端口 $BackendPort 被其他程序占用（HTTP $st），请先释放该端口"
        exit 1
    }
}

if ($needStart) {
    if (-not (Test-Path $BackendDir)) {
        Bad "找不到后端目录：$BackendDir"
        exit 1
    }

    # 判断是否需要重新打包（jar 时间戳不可靠，用源码时间戳标记）
    $needBuild = $false
    $srcStamp  = Get-SourceStamp $BackendDir
    if (-not (Test-Path $JarPath)) {
        $needBuild = $true
        Say '未找到 crm-backend.jar'
    } elseif (-not (Test-Path $StampFile)) {
        $needBuild = $true
        Say '缺少构建标记，先打包一次'
    } else {
        $lastStamp = 0
        try { $lastStamp = [long]((Get-Content -Path $StampFile -ErrorAction Stop) -join '').Trim() } catch { $lastStamp = 0 }
        if ($lastStamp -eq 0 -or $srcStamp -gt $lastStamp) { $needBuild = $true }
    }

    if ($needBuild) {
        $mvn = Resolve-Tool 'mvn.cmd'
        if (-not $mvn) { $mvn = Resolve-Tool 'mvn' }
        if (-not $mvn) {
            Bad '源码有更新需要重新打包，但找不到 mvn（Maven）'
            exit 1
        }
        Say '源码有更新，正在打包（首次约 1-2 分钟，请稍候）...'
        Push-Location $BackendDir
        try {
            & $mvn -q -DskipTests package
            if ($LASTEXITCODE -ne 0) {
                Bad '打包失败，请查看上方 Maven 输出'
                exit 1
            }
        } finally {
            Pop-Location
        }
        Set-Content -Path $StampFile -Value $srcStamp -Encoding ASCII
        Ok '打包完成'
    } else {
        Skip 'jar 已是最新，跳过打包'
    }

    # 启动后端（独立进程，父窗口关掉也不影响）
    $env:CRM_DB_PASSWORD = $DbPassword
    if (Test-Path $BackendLog) { Remove-Item $BackendLog -Force -ErrorAction SilentlyContinue }
    if (Test-Path $BackendErr) { Remove-Item $BackendErr -Force -ErrorAction SilentlyContinue }

    Say "正在启动后端（端口 $BackendPort）..."
    try {
        $backendProc = Start-Process -FilePath $java `
            -ArgumentList @('-jar', ('"{0}"' -f $JarPath), ("--server.port=$BackendPort")) `
            -WorkingDirectory $BackendDir `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $BackendLog `
            -RedirectStandardError $BackendErr
        $backendPid = $backendProc.Id
    } catch {
        Bad "后端启动失败：$($_.Exception.Message)"
        exit 1
    }

    Write-Host "      等待后端就绪 " -NoNewline
    $bp = $backendPid
    $alive = { $null -ne (Get-Process -Id $bp -ErrorAction SilentlyContinue) }
    $up = Wait-Port $BackendPort $BackendWait $alive
    Write-Host ''

    if (-not $up) {
        if (-not (& $alive)) {
            Bad '后端进程已退出，启动失败'
        } else {
            Bad "等待超时（$BackendWait 秒），后端仍未监听 $BackendPort"
        }
        Show-Tail $BackendErr 15
        Show-Tail $BackendLog 15
        exit 1
    }

    $health = Get-HttpStatus "http://127.0.0.1:$BackendPort/api/auth/me"
    if ($health -eq 401 -or $health -eq 200) {
        Ok "后端已就绪  http://127.0.0.1:$BackendPort"
    } else {
        Bad "后端端口已通但接口异常（HTTP $health），请看日志"
        Show-Tail $BackendLog 15
        exit 1
    }
}

# ---------- 3. 前端 ----------
Head '[3/5] 前端 Vite'

$needFront = $true
$frontendUrl = "http://localhost:$FrontendPort"

if (Test-Port $FrontendPort) {
    $st = Get-HttpStatus "http://localhost:$FrontendPort/"
    if ($st -ge 200 -and $st -lt 500) {
        Skip "前端已在 $FrontendPort 运行，跳过启动"
        $needFront = $false
    } else {
        Bad "端口 $FrontendPort 被其他程序占用（HTTP $st），请先运行 stop-dev.bat 释放"
        exit 1
    }
}

if ($needFront) {
    $npm = Resolve-Tool 'npm.cmd'
    if (-not $npm) { $npm = Resolve-Tool 'npm' }
    if (-not $npm) {
        Bad '找不到 npm，请安装 Node.js'
        exit 1
    }

    if (-not (Test-Path (Join-Path $FrontendDir 'node_modules'))) {
        Say '未找到 node_modules，正在安装前端依赖（约 1-2 分钟）...'
        Push-Location $FrontendDir
        try {
            & $npm install
            if ($LASTEXITCODE -ne 0) {
                Bad 'npm install 失败，请查看上方输出'
                exit 1
            }
        } finally {
            Pop-Location
        }
        Ok '依赖安装完成'
    }

    if (Test-Path $FrontendLog) { Remove-Item $FrontendLog -Force -ErrorAction SilentlyContinue }
    if (Test-Path $FrontendErr) { Remove-Item $FrontendErr -Force -ErrorAction SilentlyContinue }

    # 优先直接用 node 跑 vite，避免 cmd -> npm -> node 三层进程（停止时更好收拾）
    $nodeExe = Resolve-Tool 'node.exe'
    $viteBin = Join-Path $FrontendDir 'node_modules\vite\bin\vite.js'
    if ($nodeExe -and (Test-Path $viteBin)) {
        $launchExe  = $nodeExe
        $launchArgs = @(('"{0}"' -f $viteBin), '--port', "$FrontendPort")
    } else {
        $launchExe  = 'cmd.exe'
        $launchArgs = @('/c', 'npm', 'run', 'dev')
    }

    Say "正在启动前端（端口 $FrontendPort）..."
    try {
        $frontendProc = Start-Process -FilePath $launchExe `
            -ArgumentList $launchArgs `
            -WorkingDirectory $FrontendDir `
            -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $FrontendLog `
            -RedirectStandardError $FrontendErr
        $frontendPid = $frontendProc.Id
    } catch {
        Bad "前端启动失败：$($_.Exception.Message)"
        exit 1
    }

    Write-Host "      等待前端就绪 " -NoNewline
    $actualUrl = Get-ViteUrl $FrontendLog $FrontendWait $frontendPid
    Write-Host ''

    if (-not $actualUrl) {
        Bad "等待超时（$FrontendWait 秒），前端未能启动"
        Show-Tail $FrontendErr 15
        Show-Tail $FrontendLog 15
        exit 1
    }

    $actualPort = $FrontendPort
    try { $actualPort = ([uri]$actualUrl).Port } catch { }
    if ($actualPort -ne $FrontendPort) {
        Bad "端口 $FrontendPort 被占用，Vite 自动换成了 $actualPort"
        Say "先运行 stop-dev.bat 释放 $FrontendPort，再重新启动即可固定端口"
    } else {
        Ok "前端已就绪  $actualUrl"
    }
    $frontendUrl = $actualUrl
}

# ---------- 4. 记录进程 ----------
Head '[4/5] 记录进程'

$pidLines = @()
if ($backendPid)  { $pidLines += "backend=$backendPid" }
if ($frontendPid) { $pidLines += "frontend=$frontendPid" }
if ($pidLines.Count -gt 0) {
    $pidLines | Set-Content -Path $PidFile -Encoding ASCII
    Ok "进程号已写入 $PidFile"
} else {
    Skip '两个服务原本就在运行，无新进程需要记录'
}

# ---------- 5. 打开浏览器 ----------
Head '[5/5] 打开页面'

if ($OpenBrowser) {
    Start-Process $frontendUrl | Out-Null
    Ok "已在默认浏览器打开 $frontendUrl"
} else {
    Skip '按要求不自动打开浏览器'
}

Write-Host ''
Write-Host '====================================================' -ForegroundColor Green
Write-Host '                   启动完成' -ForegroundColor Green
Write-Host '====================================================' -ForegroundColor Green
Write-Host "  前端   $frontendUrl"
Write-Host "  后端   http://127.0.0.1:$BackendPort"
Write-Host "  日志   $LogDir"
Write-Host '  停止   双击项目根目录的 stop-dev.bat'
Write-Host ''
Write-Host '  两个服务都在后台独立运行，关掉本窗口不受影响。' -ForegroundColor DarkGray
Write-Host ''
