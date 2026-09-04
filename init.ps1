<#
    newPrjt02 — 세션 초기화 스크립트 (Windows PowerShell)

    init.sh 를 대체한다. 이 저장소는 빌드 단계가 없는 정적 HTML 앱이라
    설치할 의존성이 없고, 검증은 "파일이 제자리에 있고 형태가 온전한가"로 대체한다.

    사용법:
      .\init.ps1                    검증만 수행 (저장소 안만 본다)
      .\init.ps1 -Start             검증 후 로컬 서버 기동
      .\init.ps1 -Start -OpenBrowser  기동 후 브라우저까지 염

    Windows PowerShell 5.1 호환 (&&, 삼항연산자, ?? 미사용).

    ⚠ 2026-09-03 (paste-006): 프록시 경로를 완전히 제거했다(tools/career_proxy.example.gs
    삭제). 예전에는 -Live 스위치로 careerTest 공유 배포본을 실제로 GET 해 버전을 대조했으나,
    이 저장소가 그 참고 구현을 더 이상 보관하지 않으므로 대조 대상이 없다. 그 실측(배포본
    버전 확인)이 여전히 필요하면 newPrjt01(같은 배포를 공유하는 형제 저장소)에서 한다.
#>

[CmdletBinding()]
param(
    [switch]$Start,
    [switch]$OpenBrowser,
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

# 2) 앱 파일 — 랜딩 + 공통 디자인 시스템(로그인은 2026-09-04 완전 제거, 아래 2e 참고)
$appFiles = @(
    'index.html',
    'assets\auth.css'
)
foreach ($f in $appFiles) {
    if (Test-Path -LiteralPath $f -PathType Leaf) { Write-Ok $f } else { Write-Fail "$f 없음" }
}

# 2b) 남아 있는 진로상담 자산 — 화면·JS 는 2026-09-02 폐기했다(paste-001~006 으로 재작성).
#     프롬프트 원문과 도구는 그대로 쓴다. 이것들이 새 버전의 재료다.
$careerFiles = @(
    'career.html',
    'career-step1.html',
    'career-step2.html',
    'assets\career.js',
    'assets\career.css',
    'assets\prompts\prompt-1st.txt',
    'assets\prompts\prompt-2nd.txt',
    'assets\prompts\input-1st.txt',
    'assets\prompts\input-2nd.txt',
    'tools\build-prompts.py',
    'tools\check-report.py',
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

# 2d) home.html 폐기 확인 — 2026-09-02(Session 015) index.html 의 [시작하기]가 career.html 로
#     바로 가도록 바꿨다(2026-09-04 로그인 자체를 없앤 뒤로는 더더욱 중간 화면이 필요 없다).
#     되살아나면 그 결정이 조용히 무효화된 것이다.
if (Test-Path -LiteralPath 'home.html' -PathType Leaf) {
    Write-Fail "home.html 이 되살아났다 — [시작하기]는 이제 career.html 로 바로 간다(Session 015 폐기)"
} else {
    Write-Ok "home.html 폐기 확인 ([시작하기] -> career.html 직행)"
}

# 2d-2) career-report2.html 폐기 확인 — 2026-09-03 그 내용을 career-step2.html 로
#     합쳤다(프롬프트 복사와 결과 붙여넣기가 같은 화면). 되살아나면 그 결정이
#     조용히 무효화된 것이다.
if (Test-Path -LiteralPath 'career-report2.html' -PathType Leaf) {
    Write-Fail "career-report2.html 이 되살아났다 — 2차 결과 붙여넣기는 career-step2.html 로 합쳐졌다"
} else {
    Write-Ok "career-report2.html 폐기 확인 (2차 결과 붙여넣기는 career-step2.html 에 통합)"
}

# 2d-3) career-report1.html 폐기 확인 — 2026-09-04 그 내용도 career-step2.html 로
#     합쳤다(1차 결과 붙여넣기가 2차보다 앞쪽에 있다). 되살아나면 그 결정이
#     조용히 무효화된 것이다.
if (Test-Path -LiteralPath 'career-report1.html' -PathType Leaf) {
    Write-Fail "career-report1.html 이 되살아났다 — 1차 결과 붙여넣기는 career-step2.html 로 합쳐졌다"
} else {
    Write-Ok "career-report1.html 폐기 확인 (1차 결과 붙여넣기는 career-step2.html 에 통합)"
}

# 2e) 로그인 시스템 완전 제거 확인(2026-09-04) — 되살아나면 FAIL.
#     index.html 의 [시작하기]가 career.html 로 바로 간다(계정·세션 없음). auth.js 의
#     계정·해시·세션 로직 전체가 이 앱에서 더는 안 쓰인다 — auth.css(디자인 시스템)는
#     career 화면이 계속 쓰므로 남긴다. 되살아나면 이 결정이 조용히 무효화된 것이다.
foreach ($f in @('login.html', 'signup.html', 'error.html', 'assets\auth.js')) {
    if (Test-Path -LiteralPath $f -PathType Leaf) {
        Write-Fail "$f 가 되살아났다 — 로그인 시스템은 2026-09-04 완전히 제거했다(계정·세션 없이 바로 사용)"
    } else {
        Write-Ok "$f 폐기 확인 (로그인 없이 career.html 바로 진입)"
    }
}

# 3) HTML 무결성 — 비어 있지 않고 <html> 을 포함하는가
foreach ($f in @('index.html',
                 'career.html', 'career-step1.html', 'career-step2.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $content = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    if ($content.Length -gt 0 -and $content -match '(?i)<html') {
        Write-Ok "$f 형태 정상 (<html> 포함)"
    } else {
        Write-Fail "$f 가 비었거나 <html> 이 없음"
    }
}

# 5b) 진로상담 화면이 공통 자산을 참조하는가 (auth.css 는 디자인 시스템이라 계속 쓴다 —
#     auth.js 는 로그인 제거로 더는 안 쓰므로 여기서 요구하지 않는다)
foreach ($f in @('career.html', 'career-step1.html', 'career-step2.html')) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $c = Get-Content -LiteralPath $f -Raw -Encoding UTF8
    if (($c -match 'assets/career\.css') -and ($c -match 'assets/career\.js') -and ($c -match 'assets/auth\.css')) {
        Write-Ok "$f 가 career.css / career.js / auth.css 를 참조"
    } else {
        Write-Fail "$f 의 공통 자산 참조 누락"
    }
    if ($c -match 'assets/auth\.js') {
        Write-Fail "$f 가 auth.js 를 참조한다 — 로그인 제거(2026-09-04) 이후엔 안 써야 한다"
    }
}

# 5c) career.js — 복사·붙여넣기 방식의 공개 API 가 살아 있는가
if (Test-Path -LiteralPath 'assets\career.js' -PathType Leaf) {
    $cjs = Get-Content -LiteralPath 'assets\career.js' -Raw -Encoding UTF8
    $needed = @('loadPrompts', 'buildPrompt1', 'buildPrompt2', 'copyText', 'saveReport',
                'mdToHtml', 'listCases', 'createCase', 'updateCase', 'deleteCase',
                'downloadMd', 'downloadCombined', 'entryYearFor',
                'FIELDS_2_EXP', 'FIELDS_2_SCHOOL', 'checkReport', 'detectKind',
                'bindQuickPick', 'SAMPLE_1', 'SAMPLE_2', 'QUICK_1', 'QUICK_2_EXP',
                'AI_SERVICES', 'getAiService', 'setAiService', 'openAiPopup')
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
    #   1차·2차 붙여넣기가 둘 다 career-step2.html 에 있다(2026-09-03/04 병합) —
    #   checkReport 호출이 최소 두 번(1차용·2차용) 있어야 한다.
    $cs2 = 'career-step2.html'
    $callCount = 0
    if (Test-Path -LiteralPath $cs2 -PathType Leaf) {
        $body = Get-Content -LiteralPath $cs2 -Raw -Encoding UTF8
        $callCount = ([regex]::Matches($body, 'checkReport')).Count
    }
    if ($callCount -ge 2) {
        Write-Ok "붙여넣기 화면(1·2차 통합)이 완결성 검사를 호출 ($callCount 회)"
    } else {
        Write-Fail "$cs2 에서 완결성 검사(checkReport) 호출이 부족함(1차·2차 각각 필요, 발견 $callCount 회)"
    }

    # 붙여넣은 md 는 AI 출력이며 신뢰 대상이 아니다. 렌더 전에 이스케이프해야 한다.
    if ($cjs -match 'replace\(/&/g' -and $cjs -match 'function esc') {
        Write-Ok "붙여넣은 md 를 이스케이프한 뒤 렌더 (원문 태그가 살아나지 않는다)"
    } else {
        Write-Fail "career.js 의 mdToHtml 에 이스케이프 경로가 없음 — 붙여넣은 내용의 태그가 실행된다"
    }
}

# 5c-2) 프록시 경로 폐기 확인 (paste-006, 2026-09-03) — 되살아나면 FAIL.
#   전에는 여기서 tools/career_proxy.example.gs 의 내용(웹검색·이어달리기·버전 등)과
#   -Live 로 실제 배포본까지 대조했다. 그 참고 구현을 이 저장소에서 완전히 지우기로
#   했으므로(같은 배포를 쓰는 careerTest·시트 기록은 newPrjt01 이 계속 관리한다),
#   대상이 없어진 검사를 Test-Path 가드로 조용히 건너뛰게 두지 않고 반대 방향
#   (파일이 없어야 통과)으로 뒤집는다 — newPrjt01 Session 015 의 home.html 폐기 때와 같은 방식.
if (Test-Path -LiteralPath 'tools\career_proxy.example.gs' -PathType Leaf) {
    Write-Fail "tools\career_proxy.example.gs 가 되살아났다 — paste-006 결정(완전 제거)과 어긋난다"
} else {
    Write-Ok "프록시 참고 구현 폐기 확인 (career_proxy.example.gs 없음)"
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
foreach ($f in @('index.html', 'career.html', 'career-step1.html', 'career-step2.html')) {
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
Write-Host "    http://localhost:$Port/            첫 화면" -ForegroundColor DarkGray
Write-Host "    http://localhost:$Port/career.html  진로상담 (로그인 없음, 바로 진입)" -ForegroundColor DarkGray

if (-not $Start) {
    Write-Host ""
    Write-Host "앱까지 바로 띄우려면 .\init.ps1 -Start 를 실행하세요." -ForegroundColor DarkGray
    exit 0
}

if ($OpenBrowser) {
    Start-Process "http://localhost:$Port/"
}

Write-Head "Starting the app  (Ctrl+C 로 중지)"
& python -m http.server $Port
exit $LASTEXITCODE
