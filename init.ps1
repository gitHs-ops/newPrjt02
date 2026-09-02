<#
    newPrjt02 — 세션 초기화 스크립트 (Windows PowerShell)

    init.sh 를 대체한다. 이 저장소는 빌드 단계가 없는 정적 HTML 앱이라
    설치할 의존성이 없고, 검증은 "파일이 제자리에 있고 형태가 온전한가"로 대체한다.

    사용법:
      .\init.ps1                    검증만 수행 (저장소 안만 본다)
      .\init.ps1 -Live              + 실제 배포된 프록시까지 확인 (권장)
      .\init.ps1 -Start             검증 후 로컬 서버 기동
      .\init.ps1 -Start -OpenBrowser  기동 후 브라우저까지 염

    Windows PowerShell 5.1 호환 (&&, 삼항연산자, ?? 미사용).
#>

[CmdletBinding()]
param(
    [switch]$Start,
    [switch]$OpenBrowser,
    [switch]$Live,
    [int]$Port = 8941
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$script:Failures = 0

function Write-Head($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    [OK]   $text" -ForegroundColor Green }
function Write-Fail($text) { Write-Host "    [FAIL] $text" -ForegroundColor Red; $script:Failures++ }
function Write-Note($text) { Write-Host "    $text" -ForegroundColor DarkGray }

Write-Head "Working directory: $PSScriptRoot"

# ---------------------------------------------------------------- 의존성
Write-Head "Syncing dependencies"
Write-Note "(정적 HTML 앱 — 설치할 의존성 없음, 건너뜀)"

# ---------------------------------------------------------------- 검증
Write-Head "Running baseline verification"

# 1) 하네스 파일
$harnessFiles = @('AGENTS.md', 'CLAUDE.md', 'feature_list.json', 'claude-progress.md', 'session-handoff.md')
foreach ($f in $harnessFiles) {
    if (Test-Path -LiteralPath $f -PathType Leaf) { Write-Ok $f } else { Write-Fail "$f 없음" }
}

# 2) 앱 파일 — 로그인 데모 일습
$appFiles = @(
    'index.html',
    'login.html',
    'signup.html',
    'error.html',
    'assets\auth.css',
    'assets\auth.js'
)
foreach ($f in $appFiles) {
    if (Test-Path -LiteralPath $f -PathType Leaf) { Write-Ok $f } else { Write-Fail "$f 없음" }
}

# 2b) 남아 있는 진로상담 자산 — 화면·JS 는 2026-09-02 폐기했다(paste-001~006 으로 재작성).
#     프롬프트 원문과 도구는 그대로 쓴다. 이것들이 새 버전의 재료다.
$careerFiles = @(
    'career.html',
    'career-step1.html',
    'career-report1.html',
    'career-step2.html',
    'career-report2.html',
    'assets\career.js',
    'assets\career.css',
    'assets\prompts\prompt-1st.txt',
    'assets\prompts\prompt-2nd.txt',
    'assets\prompts\input-1st.txt',
    'assets\prompts\input-2nd.txt',
    'tools\build-prompts.py',
    'tools\check-report.py',
    'tools\career_proxy.example.gs',
    'tools\obsidian-check.html'
)
foreach ($f in $careerFiles) {
    if (Test-Path -LiteralPath $f -PathType Leaf) { Write-Ok $f } else { Write-Fail "$f 없음" }
}

# 2c) 폐기한 프록시 방식 잔재가 되살아나 있지 않은가 —
#     career-prompts.js(생성물)는 fetch 방식으로 갈아탔으므로 돌아오면 안 된다.
if (Test-Path -LiteralPath 'assets\career-prompts.js' -PathType Leaf) {
    Write-Fail "assets\career-prompts.js 가 되살아났다 — 프롬프트는 fetch 로 직접 읽는다(생성물 낡음 사고 방지)"
} else {
    Write-Ok "프롬프트 생성물 없음 (원문을 fetch 로 직접 읽는다)"
}

# 2d) home.html 폐기 확인 — 2026-09-02(Session 015) 로그인 성공이 career.html 로
#     바로 가도록 바꿨다. 진로상담이 유일한 기능이라 세션 정보만 보여주고 카드 하나로
#     넘겨주던 중간 화면이 더는 필요 없다. 되살아나면 그 결정이 조용히 무효화된 것이다.
if (Test-Path -LiteralPath 'home.html' -PathType Leaf) {
    Write-Fail "home.html 이 되살아났다 — 로그인 성공은 이제 career.html 로 바로 간다(Session 015 폐기)"
} else {
    Write-Ok "home.html 폐기 확인 (로그인 성공 -> career.html 직행)"
}

# 2e) login.html 이 실제로 career.html 로 보내는가 — 폐기한 home.html 참조가 남아 있으면
#     "파일은 지웠는데 코드는 여전히 그리로 가려는" 깨진 상태가 된다.
if (Test-Path -LiteralPath 'login.html' -PathType Leaf) {
    $lg = Get-Content -LiteralPath 'login.html' -Raw -Encoding UTF8
    if ($lg -match "'home\.html'") {
        Write-Fail "login.html 에 home.html 참조가 남아 있음 — career.html 로 통일할 것"
    } elseif ($lg -match "'career\.html'") {
        Write-Ok "login.html 이 로그인 성공 시 career.html 로 이동"
    } else {
        Write-Fail "login.html 의 로그인 성공 이동 대상을 찾지 못함"
    }
}

# 3) HTML 무결성 — 비어 있지 않고 <html> 을 포함하는가
foreach ($f in @('index.html', 'login.html', 'signup.html', 'error.html',
                 'career.html', 'career-step1.html', 'career-report1.html',
                 'career-step2.html', 'career-report2.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $content = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    if ($content.Length -gt 0 -and $content -match '(?i)<html') {
        Write-Ok "$f 형태 정상 (<html> 포함)"
    } else {
        Write-Fail "$f 가 비었거나 <html> 이 없음"
    }
}

# 4) 각 페이지가 공통 자산을 참조하는가 (경로 오타 조기 탐지)
foreach ($f in @('login.html', 'signup.html', 'error.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $content = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    $hasCss = $content -match 'assets/auth\.css'
    $hasJs  = $content -match 'assets/auth\.js'
    if ($hasCss -and $hasJs) {
        Write-Ok "$f 가 auth.css / auth.js 를 참조"
    } else {
        Write-Fail "$f 의 공통 자산 참조 누락 (css=$hasCss js=$hasJs)"
    }
}

# 5) auth.js 의 공개 API 가 살아 있는가
if (Test-Path -LiteralPath 'assets\auth.js' -PathType Leaf) {
    $js = Get-Content -LiteralPath 'assets\auth.js' -Raw -Encoding UTF8
    $needed = @('signup', 'login', 'googleLoginDemo', 'resetPassword',
                'getSession', 'clearSession', 'requireAuth', 'isIdTaken')
    $missing = @()
    foreach ($fn in $needed) {
        if ($js -notmatch [regex]::Escape($fn)) { $missing += $fn }
    }
    if ($missing.Count -eq 0) {
        Write-Ok "auth.js 공개 API $($needed.Count)종 확인"
    } else {
        Write-Fail "auth.js 에서 누락된 API: $($missing -join ', ')"
    }

    # 비밀번호를 평문으로 다루지 않는지 최소 확인
    if ($js -match 'PBKDF2') {
        Write-Ok "비밀번호 해싱(PBKDF2) 경로 존재"
    } else {
        Write-Fail "auth.js 에 PBKDF2 해싱이 보이지 않음 — 평문 저장 여부 확인 필요"
    }
}

# 5b) 진로상담 화면이 공통 자산을 참조하는가
foreach ($f in @('career.html', 'career-step1.html', 'career-report1.html',
                 'career-step2.html', 'career-report2.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $c = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    if (($c -match 'assets/career\.css') -and ($c -match 'assets/career\.js') -and ($c -match 'assets/auth\.js')) {
        Write-Ok "$f 가 career.css / career.js / auth.js 를 참조"
    } else {
        Write-Fail "$f 의 공통 자산 참조 누락"
    }
}

# 5c) career.js — 복사·붙여넣기 방식의 공개 API 가 살아 있는가
if (Test-Path -LiteralPath 'assets\career.js' -PathType Leaf) {
    $cjs = Get-Content -LiteralPath 'assets\career.js' -Raw -Encoding UTF8
    $needed = @('loadPrompts', 'buildPrompt1', 'buildPrompt2', 'copyText', 'saveReport',
                'mdToHtml', 'listCases', 'createCase', 'updateCase', 'deleteCase',
                'downloadMd', 'downloadCombined', 'entryYearFor', 'mountChrome',
                'FIELDS_2_EXP', 'FIELDS_2_SCHOOL', 'checkReport', 'detectKind',
                'bindQuickPick', 'SAMPLE_1', 'SAMPLE_2', 'QUICK_1', 'QUICK_2_EXP',
                'AI_SERVICES', 'getAiService', 'setAiService')
    $missing = @()
    foreach ($fn in $needed) { if ($cjs -notmatch [regex]::Escape($fn)) { $missing += $fn } }
    if ($missing.Count -eq 0) {
        Write-Ok "career.js 공개 API $($needed.Count)종 확인"
    } else {
        Write-Fail "career.js 에서 누락된 API: $($missing -join ', ')"
    }

    # ⚠ 이 방식의 정체성. 앱은 AI 를 부르지 않는다.
    #   fetch 가 프롬프트 원문 읽기 외의 곳에 생기면 자동 호출로 되돌아간 것이다.
    if ($cjs -match 'anthropic|/exec|api\.openai') {
        Write-Fail "career.js 가 AI 를 직접 부르려 한다 — 이 앱은 프롬프트를 조립·복사만 한다"
    } else {
        Write-Ok "career.js 에 AI 자동 호출 경로 없음 (복사·붙여넣기 방식 유지)"
    }

    # 프롬프트 원문을 직접 읽는가 (생성물 낡음 사고를 없앤 경로)
    if ($cjs -match "assets/prompts/prompt-1st\.txt") {
        Write-Ok "프롬프트 원문을 직접 읽는다 (fetch)"
    } else {
        Write-Fail "career.js 가 프롬프트 원문 경로를 갖고 있지 않음"
    }

    # 클립보드 대체 경로 — navigator.clipboard 는 보안 컨텍스트에서만 산다.
    # 이게 없으면 막힌 환경에서 복사가 조용히 실패한다.
    if ($cjs -match 'navigator\.clipboard' -and $cjs -match 'execCommand') {
        Write-Ok "클립보드 대체 경로 존재 (clipboard API + execCommand)"
    } else {
        Write-Fail "career.js 에 클립보드 대체 경로가 없음 — 막힌 환경에서 복사가 실패한다"
    }

    # AI 화면 선택 (paste-004) — Claude 하나로 고정하지 않았는가.
    #   ⚠ "[연결 설정]" 화면을 다시 만들면 안 된다 — 그 문구는 stale-word 검사가 잡는다.
    #   선택은 화면 안 인라인 드롭다운으로 해결한다.
    if ($cjs -match 'AI_SERVICES' -and $cjs -match 'chatgpt' -and $cjs -match 'gemini') {
        Write-Ok "AI 서비스 목록 존재 (Claude 고정이 아니라 선택 가능)"
    } else {
        Write-Fail "career.js 에 AI_SERVICES 목록이 없음 — Claude 로 고정돼 있다"
    }
    $noPicker = @()
    foreach ($f in @('career-step1.html', 'career-step2.html')) {
        if ((Test-Path -LiteralPath $f -PathType Leaf) -and
            ((Get-Content -LiteralPath $f -Raw -Encoding UTF8) -notmatch 'id="aiService"')) { $noPicker += $f }
    }
    if ($noPicker.Count -eq 0) {
        Write-Ok "프롬프트 복사 화면에 AI 서비스 선택 드롭다운 존재 (2화면)"
    } else {
        Write-Fail "AI 서비스 선택이 없는 화면: $($noPicker -join ', ')"
    }

    # 입력 보조 — 반복 입력 부담을 줄이는 장치들. newPrjt01 에서 가져왔다.
    #   빠른 선택이 사라지면 교사가 매 사례마다 같은 문구를 손으로 친다.
    if ($cjs -match 'workStyle' -and $cjs -match 'teamRole' -and $cjs -match 'askedFor') {
        Write-Ok "빠른 선택 목록 존재 (과목·산업·계기·일하는 방식·전공·조별역할·부탁받는 일)"
    } else {
        Write-Fail "career.js 에 빠른 선택 목록이 없음 — 반복 입력 부담이 그대로 돌아온다"
    }

    # 성적 표기는 학교급에 묶여 있다. 중학교에 '등급'을 쓰면 프롬프트가 모순으로 잡는다.
    if ($cjs -match "score:\s*\{" -and $cjs -match '중학교' -and $cjs -match '고등학교') {
        Write-Ok "성적 선택지가 학교급별로 분리됨 (중학교=성취도 / 고등학교=등급)"
    } else {
        Write-Fail "성적 선택지가 학교급별로 갈라져 있지 않음 — 중2에 '등급' 이 들어갈 수 있다"
    }

    # 예시 채우기 — 전 과정을 반복 검증할 때 손으로 채우는 부담을 없앤다
    $noSample = @()
    foreach ($f in @('career-step1.html', 'career-step2.html')) {
        if ((Test-Path -LiteralPath $f -PathType Leaf) -and
            ((Get-Content -LiteralPath $f -Raw -Encoding UTF8) -notmatch 'sampleBtn')) { $noSample += $f }
    }
    if ($noSample.Count -eq 0) {
        Write-Ok "입력 화면에 예시 채우기 존재 (2화면)"
    } else {
        Write-Fail "예시 채우기가 없는 입력 화면: $($noSample -join ', ')"
    }

    # 예시(SAMPLE_2)의 키가 2차 항목 라벨과 어긋나면 예시를 채워도 빈칸이 남는다.
    # 라벨을 고칠 때 예시를 같이 안 고치는 사고를 여기서 잡는다.
    $s2 = ''
    if ($cjs -match '(?s)var SAMPLE_2 = \{(.*?)\n    \};') { $s2 = $Matches[1] }
    $labelMiss = @()
    foreach ($arr in @('FIELDS_2_EXP', 'FIELDS_2_SCHOOL')) {
        if ($cjs -match "(?s)var $arr = \[(.*?)\];") {
            foreach ($m in [regex]::Matches($Matches[1], "'([^']+)'")) {
                if ($s2 -notmatch [regex]::Escape($m.Groups[1].Value)) { $labelMiss += $m.Groups[1].Value }
            }
        }
    }
    if ($s2 -and $labelMiss.Count -eq 0) {
        Write-Ok "예시(SAMPLE_2)가 2차 항목 라벨 17종을 모두 덮는다"
    } elseif (-not $s2) {
        Write-Fail "career.js 에서 SAMPLE_2 를 찾지 못함"
    } else {
        Write-Fail "예시에 빠진 2차 항목: $($labelMiss -join ', ') — 라벨과 예시를 같이 고칠 것"
    }

    # 2차는 1차 결과를 물고 가야 의미가 있다. buildPrompt2 가 report1 을 받지 못하면
    # "1차 결과 없음" 으로 조립돼 분석이 통째로 빗나간다.
    if (Test-Path -LiteralPath 'career-step2.html' -PathType Leaf) {
        $s2 = Get-Content -LiteralPath 'career-step2.html' -Raw -Encoding UTF8
        if ($s2 -match 'buildPrompt2' -and $s2 -match 'report1') {
            Write-Ok "2차 화면이 1차 결과를 프롬프트에 싣는다"
        } else {
            Write-Fail "career-step2.html 이 1차 결과를 싣지 않는다 — 2차 분석이 빈 입력으로 나간다"
        }
    }

    # 완결성 검사가 두 벌 있다 — career.js(저장 시점)와 tools/check-report.py(저장된 파일).
    # 기대 형식이 갈라지면 한쪽만 통과하는 보고서가 생겨 검사 자체를 믿을 수 없게 된다.
    # 두 파일이 같은 기대값 문자열을 갖고 있는지 대조한다.
    if (Test-Path -LiteralPath 'tools\check-report.py' -PathType Leaf) {
        $py = Get-Content -LiteralPath 'tools\check-report.py' -Raw -Encoding UTF8
        $shared = @('본 자료는 진로상담을 시작하기 위한 1차 정보이며',
                    '본 2차 분석은 1차 진로리서치에서',
                    '현재 공식자료로 확인된 내용',
                    '현재 확인할 수 없는 내용',
                    '상담에서의 해석')
        $drift = @()
        foreach ($m in $shared) {
            if (($cjs -notmatch [regex]::Escape($m)) -or ($py -notmatch [regex]::Escape($m))) { $drift += $m }
        }
        if ($drift.Count -eq 0) {
            Write-Ok "완결성 검사 기대값이 career.js 와 check-report.py 에서 일치 ($($shared.Count)종)"
        } else {
            Write-Fail "완결성 검사 기대값이 갈라졌다: $($drift -join ' / ') — 두 파일을 같이 고칠 것"
        }
    }

    # 붙여넣기 화면이 실제로 검사를 부르는가. career.js 에만 있고 화면이 안 부르면 무용지물이다.
    $noCheck = @()
    foreach ($f in @('career-report1.html', 'career-report2.html')) {
        if ((Test-Path -LiteralPath $f -PathType Leaf) -and
            ((Get-Content -LiteralPath $f -Raw -Encoding UTF8) -notmatch 'checkReport')) { $noCheck += $f }
    }
    if ($noCheck.Count -eq 0) {
        Write-Ok "붙여넣기 화면이 완결성 검사를 호출 (2화면)"
    } else {
        Write-Fail "완결성 검사를 부르지 않는 화면: $($noCheck -join ', ')"
    }

    # 붙여넣은 md 는 AI 출력이며 신뢰 대상이 아니다. 렌더 전에 이스케이프해야 한다.
    if ($cjs -match 'replace\(/&/g' -and $cjs -match 'function esc') {
        Write-Ok "붙여넣은 md 를 이스케이프한 뒤 렌더 (원문 태그가 살아나지 않는다)"
    } else {
        Write-Fail "career.js 의 mdToHtml 에 이스케이프 경로가 없음 — 붙여넣은 내용의 태그가 실행된다"
    }
}

# 5c-2) 프록시 참고 구현이 웹검색을 켜는가
if (Test-Path -LiteralPath 'tools\career_proxy.example.gs' -PathType Leaf) {
    $gs = Get-Content -LiteralPath 'tools\career_proxy.example.gs' -Raw -Encoding UTF8
    $needed = @('web_search_20260209', 'pause_turn', 'web_search_tool_result', 'doPost',
                'DEADLINE_MS', 'output_config')
    $missing = @()
    foreach ($k in $needed) {
        if ($gs -notmatch [regex]::Escape($k)) { $missing += $k }
    }
    if ($missing.Count -eq 0) {
        Write-Ok "프록시 예시가 웹검색·이어달리기·시간가드·effort 를 구현 ($($needed.Count)종)"
    } else {
        Write-Fail "career_proxy.example.gs 에서 누락: $($missing -join ', ')"
    }

    # 모델별 요청 형태 차이를 흡수하는가 —
    # Haiku 4.5 는 동적 필터링 웹검색(_20260209)과 output_config.effort 를 받지 못한다.
    # 이 분기가 사라지면 Haiku 로 호출할 때 400 이 난다.
    if ($gs -match 'supportsNewWebTools_' -and $gs -match 'supportsEffort_' -and
        $gs -match 'web_search_20250305') {
        Write-Ok "프록시가 모델별 도구·effort 지원 여부를 분기"
    } else {
        Write-Fail "career_proxy.example.gs 에 모델별 분기가 없음 — Haiku 계열에서 400 이 난다"
    }

    # Apps Script 6분 한도 대비 — 이어달리기를 늘려 놓으면 응답 없이 매달린다(2026-09-01 실제 발생)
    if ($gs -match 'MAX_CONTINUATIONS\s*=\s*[0-2]\b') {
        Write-Ok "이어달리기 상한이 안전 범위(0~2)"
    } else {
        Write-Fail "MAX_CONTINUATIONS 가 너무 큼 — Apps Script 6분 한도를 넘겨 응답 없이 매달린다"
    }

    # 프록시 버전 — 클라이언트(career.js) 쪽 대조는 2026-09-02 사라졌다.
    #   복사·붙여넣기로 바꾸면서 클라이언트가 프록시를 부르지 않는다.
    #   .gs 는 careerTest 와 구글시트 기록 때문에 남아 있으므로, 배포본 대조(-Live)는 계속 쓴다.
    $pv = ''
    if ($gs -match "PROXY_VERSION\s*=\s*'([0-9.]+)'") { $pv = $Matches[1] }
    if ($pv) {
        Write-Ok "프록시 버전 확인 ($pv) — 이제 careerTest·시트 기록 전용이다"
    } else {
        Write-Fail "career_proxy.example.gs 에서 PROXY_VERSION 을 찾지 못함"
    }

    # 5c-4) 실제 배포본 확인 (-Live)
    #   위 검사는 전부 "저장소 안의 텍스트"만 본다. 코드를 고쳐 놓고 Apps Script 재배포를
    #   잊으면 전부 [OK] 인데 실제로는 낡은 프록시가 돌아간다 — 2026-09-01 세션의 최대
    #   시간 손실이 이것이었고, 3분짜리 분석을 돌린 뒤에야 알았다. 여기서 30초에 잡는다.
    if ($Live) {
        $epFile = 'local.endpoint.txt'
        if (-not (Test-Path -LiteralPath $epFile -PathType Leaf)) {
            Write-Fail "-Live 인데 $epFile 이 없다 — 배포된 /exec URL 을 한 줄 넣을 것 (git 추적 안 됨)"
        } else {
            $ep = (Get-Content -LiteralPath $epFile -Raw -Encoding UTF8).Trim()
            if ($ep -notmatch '^https://script\.google\.com/.+/exec$') {
                Write-Fail "$epFile 이 /exec URL 형식이 아니다: $ep"
            } else {
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $resp = Invoke-WebRequest -Uri $ep -UseBasicParsing -TimeoutSec 30
                    $liveVer = ''
                    if ($resp.Content -match '"version"\s*:\s*"([0-9.]+)"') { $liveVer = $Matches[1] }
                    if (-not $liveVer) {
                        Write-Fail "배포본이 version 을 응답하지 않는다 — 낡은 배포이거나 /exec 가 다른 스크립트다"
                    } elseif ($liveVer -eq $pv) {
                        Write-Ok "배포본 살아있음 · 버전 일치 ($liveVer)"
                    } else {
                        Write-Fail "배포본이 낡았다 — 배포=$liveVer / 저장소=$pv (배포 관리 -> 편집 -> 새 버전)"
                    }
                } catch {
                    Write-Fail "배포본에 닿지 못함: $($_.Exception.Message)"
                }
            }
        }
    } else {
        Write-Note "참고: 실제 배포본은 확인하지 않았다 — .\init.ps1 -Live 로 확인할 수 있다"
    }

    # 시트 기록 실패를 조용히 삼키지 않는가 (안 쌓이는 걸 알 방법이 있어야 한다)
    if ($gs -match 'lastLogError' -and $gs -match 'test5_sheet') {
        Write-Ok "시트 기록 실패 노출 · 권한 점검 함수 존재"
    } else {
        Write-Fail "시트 기록 실패가 조용히 묻힌다 — lastLogError / test5_sheet 확인"
    }

    # 잘린 응답 이어쓰기 — 2차 보고서의 최종 브리프·면책 문장이 끝에 있어 필수다
    if ($gs -match 'MAX_TEXT_CONTINUATIONS' -and $gs -match 'supportsPrefill_' -and
        $gs -match 'COMPLETION_SUFFIX') {
        Write-Ok "잘린 응답 이어쓰기 · 끝맺음 지시 존재"
    } else {
        Write-Fail "career_proxy.example.gs 에 이어쓰기 경로가 없음 — 보고서 끝단이 잘려 나간다"
    }

    # 토큰 사용량 기록 — careerTest 공용 탭 형식을 건드리면 그쪽이 깨진다
    if ($gs -match 'logUsage_' -and $gs -match 'SHARED_HEADERS' -and $gs -match 'USAGE_SHEET_NAME') {
        Write-Ok "토큰 사용량 시트 기록 경로 존재 (전용 탭 + 되돌릴 수 있는 미러링 코드)"
    } else {
        Write-Fail "career_proxy.example.gs 에 토큰 사용량 기록 경로가 없음"
    }

    # v1.8.0 — 공용 '토큰로그' 탭 미러링을 껐다(한 분석이 두 탭에 이중으로 남던 문제).
    # 코드는 되돌릴 수 있게 남겨 두므로, 플래그가 다시 true 로 새어 들어오지 않는지 본다.
    if ($gs -match 'MIRROR_TO_SHARED\s*=\s*false') {
        Write-Ok "공용 탭 미러링 꺼짐 (전용 탭에만 기록 — 이중 기록 없음)"
    } else {
        Write-Fail "MIRROR_TO_SHARED 가 false 가 아님 — 공용 '토큰로그' 탭에 이중 기록된다"
    }

    # careerTest 와 배포를 공유하므로 기존 GET 경로가 살아 있어야 한다
    if ($gs -match 'function doGet' -and $gs -match 'CAREERTEST_SYSTEM') {
        Write-Ok "프록시 예시가 careerTest GET 경로를 보존 (배포 공유 가능)"
    } else {
        Write-Fail "career_proxy.example.gs 에 careerTest 용 doGet 경로가 없음 — 배포를 덮으면 careerTest 가 죽는다"
    }
}

# 5c-3) API 키가 저장소에 섞여 들어가지 않았는가 (careerTest 프록시 복사 사고 방지)
$keyHits = @()
foreach ($f in (Get-ChildItem -Recurse -File -Include *.gs, *.js, *.html, *.md, *.json, *.ps1, *.py |
                Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    if ($t -match 'sk-ant-[A-Za-z0-9]') { $keyHits += $f.Name }
}
if ($keyHits.Count -eq 0) {
    Write-Ok "저장소에 Anthropic API 키 문자열 없음"
} else {
    Write-Fail "API 키로 보이는 문자열 발견: $($keyHits -join ', ') — 즉시 제거하고 키를 폐기할 것"
}

# 5c-5) 배포된 /exec URL 이 소스에 박혀 있지 않은가
#   GitHub Pages 로 공개 배포하면 소스가 그대로 노출된다. /exec URL 만 알면 누구나
#   이쪽 API 키로 호출할 수 있고 요금은 이 계정에 붙는다. sk-ant- 검사로는 안 잡힌다
#   — 키가 아니라 URL 이라서다. 브라우저마다 [연결 설정]에 입력하는 것이 귀찮다고
#   DEFAULT_CONFIG.endpoint 에 박아 넣는 지름길을 여기서 막는다.
#   `.../exec` 같은 자리표시자는 걸리지 않는다 (배포 ID 20자 이상만 본다).
$execHits = @()
foreach ($f in (Get-ChildItem -Recurse -File -Include *.gs, *.js, *.html, *.md, *.json, *.ps1, *.py |
                Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne 'career_proxy.gs' })) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    if ($t -match 'script\.google\.com/macros/s/[A-Za-z0-9_-]{20,}/exec') { $execHits += $f.Name }
}
if ($execHits.Count -eq 0) {
    Write-Ok "소스에 배포된 /exec URL 없음 (연결 설정으로만 주입)"
} else {
    Write-Fail "소스에 /exec URL 이 박혀 있음: $($execHits -join ', ') — 공개 배포 시 누구나 호출한다. local.endpoint.txt 로 옮길 것"
}

# 5d) 프롬프트 원문이 살아 있는가 —
#     생성물(career-prompts.js) 대조는 2026-09-02 제거했다. 클라이언트를 새로 쓰는 중이라
#     생성물이 아직 없다. 원문 자체는 이 프로젝트의 핵심 자산이므로 크기까지 본다.
$pTotal = 0
$pMissing = @()
foreach ($f in @('prompt-1st.txt', 'prompt-2nd.txt', 'input-1st.txt', 'input-2nd.txt')) {
    $src = Join-Path 'assets\prompts' $f
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        $pTotal += (Get-Item -LiteralPath $src).Length
    } else { $pMissing += $f }
}
if ($pMissing.Count -eq 0 -and $pTotal -gt 30000) {
    Write-Ok "프롬프트 원문 4종 존재 ($([int]($pTotal/1024))KB)"
} elseif ($pMissing.Count -gt 0) {
    Write-Fail "프롬프트 원문 누락: $($pMissing -join ', ')"
} else {
    Write-Fail "프롬프트 원문이 비정상적으로 작다 ($pTotal bytes) — 내용이 날아갔는지 확인할 것"
}

# 5d-2) 화면에 프록시 시절 잔재가 남아 있지 않은가 —
#   "AI 연결됨" 배지·"모의 모드"·"토큰 사용량"·"연결 설정" 은 앱이 AI 를 직접 부르던 시절의
#   표시다. 이제 앱은 프롬프트를 만들 뿐이므로 남아 있으면 사용자를 오도한다.
#   ⚠ 주석과 <script> 안은 뺀다 — 경위를 설명하는 주석까지 잡으면 기록을 지우게 된다.
$staleWords = @('AI 연결됨', 'AI 미설정', '모의 모드', '토큰 사용량', '연결 설정', '분석 실행')
$stalePages = @()
foreach ($f in @('index.html', 'career.html', 'career-step1.html',
                 'career-report1.html', 'career-step2.html', 'career-report2.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $body = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    $body = [regex]::Replace($body, '(?s)<script.*?</script>', '')
    $body = [regex]::Replace($body, '(?s)<!--.*?-->', '')
    foreach ($w in $staleWords) {
        if ($body -match [regex]::Escape($w)) { $stalePages += ($f + ':' + $w) }
    }
}
if ($stalePages.Count -eq 0) {
    Write-Ok "화면에 프록시 시절 표시 없음 (복사·붙여넣기 방식에 맞는 안내만)"
} else {
    Write-Fail "프록시 시절 표시가 화면에 남아 있음: $($stalePages -join ', ')"
}

# 랜딩이 아직 "작업중" 자리표시자인가 — 동작하는 앱이 있는데 그렇게 보이면 안 된다
if (Test-Path -LiteralPath 'index.html' -PathType Leaf) {
    $idx = Get-Content -LiteralPath 'index.html' -Raw -Encoding UTF8
    if ($idx -match 'Coming soon' -or $idx -match '작업중입니다') {
        Write-Fail "index.html 이 아직 '작업중' 자리표시자다 — 앱이 무엇인지 말해야 한다"
    } else {
        Write-Ok "index.html 이 앱을 설명한다 (자리표시자 아님)"
    }
}

# 6) feature_list.json 이 올바른 JSON 인가
if (Test-Path -LiteralPath 'feature_list.json' -PathType Leaf) {
    try {
        $raw = Get-Content -LiteralPath 'feature_list.json' -Raw -Encoding UTF8
        $features = ($raw | ConvertFrom-Json).features
        Write-Ok "feature_list.json 파싱 성공 (기능 $($features.Count)개)"

        $blocked = @($features | Where-Object { $_.status -eq 'blocked' })
        if ($blocked.Count -gt 0) {
            Write-Note "주의: blocked 상태 기능 $($blocked.Count)건 — $($blocked.id -join ', ')"
        }

        # 이 저장소의 규칙 passing_requires_evidence 를 실제로 집행한다.
        # 규칙을 적어만 두고 검사하지 않으면 "코드를 넣었으니 passing" 이 슬금슬금 들어온다.
        $noEvidence = @($features | Where-Object {
            $_.status -eq 'passing' -and (@($_.evidence).Count -eq 0)
        })
        if ($noEvidence.Count -eq 0) {
            Write-Ok "passing 기능 전부에 근거가 기록돼 있음 ($(@($features | Where-Object { $_.status -eq 'passing' }).Count)건)"
        } else {
            Write-Fail "근거 없이 passing 인 기능: $($noEvidence.id -join ', ')"
        }
    } catch {
        Write-Fail "feature_list.json 이 올바른 JSON 이 아님: $($_.Exception.Message)"
    }
}

# 6b) git 위생 — 비밀이 새는 경로와 직전 세션의 잔재를 본다
if (Test-Path -LiteralPath '.gitignore' -PathType Leaf) {
    $gi = Get-Content -LiteralPath '.gitignore' -Raw -Encoding UTF8
    $mustIgnore = @('career_proxy.gs', 'local.endpoint.txt')
    $giMissing = @()
    foreach ($m in $mustIgnore) { if ($gi -notmatch [regex]::Escape($m)) { $giMissing += $m } }
    if ($giMissing.Count -eq 0) {
        Write-Ok ".gitignore 가 실 프록시·로컬설정을 막고 있음"
    } else {
        Write-Fail ".gitignore 에 누락: $($giMissing -join ', ')"
    }
} else {
    Write-Fail ".gitignore 가 없음 — API 키가 든 career_proxy.gs 가 그대로 커밋될 수 있다"
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $dirty = @(& git status --porcelain 2>$null)
    if ($dirty.Count -eq 0) {
        Write-Ok "작업트리 깨끗함 (이어받기 안전)"
    } else {
        Write-Note "참고: 커밋되지 않은 변경 $($dirty.Count)건 — 직전 세션의 잔재인지 먼저 확인할 것"
    }
}

# 6c) 인코딩 — 한글이 cp949/UTF-8 사이에서 깨진 채 커밋되면 되돌리기 어렵다
$badEnc = @()
foreach ($f in (Get-ChildItem -Recurse -File -Include *.ps1, *.gs, *.js, *.html, *.md, *.json, *.py, *.txt |
                Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    if ($t -and $t.Contains([char]0xFFFD)) { $badEnc += $f.Name }
}
if ($badEnc.Count -eq 0) {
    Write-Ok "텍스트 파일에 깨진 문자 없음"
} else {
    Write-Fail "깨진 문자(U+FFFD) 발견: $($badEnc -join ', ')"
}

# init.ps1 자신은 BOM 이 있어야 PowerShell 5.1 이 한글을 바로 읽는다 (AGENTS.md 의 지뢰)
$initBytes = [System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'init.ps1'))
if ($initBytes.Length -ge 3 -and $initBytes[0] -eq 0xEF -and
    $initBytes[1] -eq 0xBB -and $initBytes[2] -eq 0xBF) {
    Write-Ok "init.ps1 이 UTF-8 BOM 으로 저장돼 있음"
} else {
    Write-Fail "init.ps1 에 BOM 이 없음 — PowerShell 5.1 이 cp949 로 읽어 한글이 깨진다"
}

# 6d) 보고서 완결성 검사기 — 잘림 회귀를 사람 눈이 아니라 명령으로 잡는다
if (Test-Path -LiteralPath 'tools\check-report.py' -PathType Leaf) {
    Write-Ok "tools\check-report.py 존재 (저장된 보고서 검사용)"
} else {
    Write-Fail "tools\check-report.py 가 없음 — 보고서 잘림을 눈으로만 확인하게 된다"
}

# 7) 실행에 필요한 python
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    $ver = (& python --version 2>&1 | Out-String).Trim()
    Write-Ok "python 사용 가능 ($ver)"
} else {
    Write-Fail "python 을 찾을 수 없음 — 서버를 기동할 수 없다"
}

# 8) 포트 점유 여부 (실패가 아니라 정보)
$inUse = $null
try {
    $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
} catch {
    $inUse = $null
}
if ($inUse) {
    Write-Note "참고: 포트 $Port 를 이미 누군가 듣고 있음 (기동 시 충돌 가능)"
} else {
    Write-Ok "포트 $Port 사용 가능"
}

# ---------------------------------------------------------------- 결과
if ($script:Failures -gt 0) {
    Write-Host ""
    Write-Head "검증 실패 — [FAIL] $($script:Failures)건. 위 항목을 먼저 해결할 것."
    exit 1
}

Write-Head "검증 통과"

# ---------------------------------------------------------------- 기동
Write-Head "Startup command"
Write-Host "    python -m http.server $Port" -ForegroundColor Yellow
Write-Host "    http://localhost:$Port/           첫 화면" -ForegroundColor DarkGray
Write-Host "    http://localhost:$Port/login.html 로그인" -ForegroundColor DarkGray
Write-Host "    http://localhost:$Port/signup.html 회원가입" -ForegroundColor DarkGray
Write-Host "    http://localhost:$Port/career.html 진로상담 (로그인 필요)" -ForegroundColor DarkGray

if (-not $Start) {
    Write-Host ""
    Write-Host "앱까지 바로 띄우려면 .\init.ps1 -Start 를 실행하세요." -ForegroundColor DarkGray
    exit 0
}

if ($OpenBrowser) {
    Start-Process "http://localhost:$Port/login.html"
}

Write-Head "Starting the app  (Ctrl+C 로 중지)"
& python -m http.server $Port
exit $LASTEXITCODE
