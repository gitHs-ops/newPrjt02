# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

빌드 단계가 없는 **정적 HTML 앱 두 벌**(로그인 데모 · 진로상담 분석)이며,
장시간 에이전트 작업을 전제로 한 **하네스**(`init.ps1` + `feature_list.json` +
`claude-progress.md`)가 얹혀 있다. 속도보다 **재개 가능성과 실증**이 우선이다.

## ⚠ 분석 엔진 방향 전환 — 완료 (2026-09-02 착수, 2026-09-03 확정)

**분석 엔진을 프록시 자동 호출 → 프롬프트 복사·붙여넣기로 바꿨다.** 앱이 조립한
프롬프트를 사용자가 복사 → 원하는 AI 화면에 붙여넣기 → 받은 md 를 앱에 되돌려 넣는다.
API 키·프록시 배포·요금·Apps Script 6분 한도가 전부 사라진다.

- `paste-001`~`005`, `007`~`009` 는 `passing`. `paste-006`(프록시 경로 은퇴 여부
  결정)도 2026-09-03 **완전 제거**로 확정해 `passing`이다. 남은 건 보류된
  `auth-006`(서버 인증)·`auth-007`(실제 OAuth) 둘뿐
- **2026-09-03: `tools/career_proxy.example.gs` 를 이 저장소에서 완전히 지웠다.**
  이유는 newPrjt01(형제 저장소)에서 같은 백엔드로 실측한 결과다 — 웹검색을 꺼도
  2차 분석이 ~3분(newPrjt02 는 2분 이내)이었고, 이틀 테스트에 API 크레딧 $20 이
  소진됐다. 상세 근거는 `claude-progress.md` Session 016
- 폐기한 기능은 `retired` 상태로 두고 **evidence 를 남겼다** — 지우지 말 것
  (이번 프록시 제거로 `career-008`·`setup-003` 도 `retired` 로 옮겼다)
- **프록시 참고 구현은 이제 이 저장소에 없다.** `careerTest`(형제 프로젝트)와
  구글시트 기록은 계속 동작한다 — 같은 Apps Script 배포의 `doGet` 을 쓰는데, 그
  배포·유지보수는 newPrjt01 이 담당한다(그쪽은 여전히 프록시를 실사용 중이라 사본을
  가지고 있다). **이 저장소에서 그 코드가 다시 필요하면 newPrjt01 의 `tools/career_proxy.example.gs`
  를 본다 — 새로 쓰지 말 것.**

## Commands

```powershell
.\init.ps1                       # 검증만 (저장소 안의 텍스트만 본다)
.\init.ps1 -Start                # 검증 후 http://localhost:8941/ 기동
.\init.ps1 -Start -OpenBrowser   # 기동 + 브라우저
.\init.ps1 -Port 9000 -Start     # 포트 변경
```

```bash
python tools/build-prompts.py            # assets/prompts/*.txt -> assets/career-prompts.js 재생성
python tools/check-report.py <파일.md>   # 저장된 보고서가 끝까지 나왔는지 검사 (exit 0/1)
python tools/check-report.py --kind 2 <파일.md>   # 1차/2차 자동판별을 덮어씀
start http://localhost:8941/tools/obsidian-check.html   # 옵시디언 연결 5단계 실측
```

`init.ps1` 이 이 저장소의 테스트 러너다. 개별 테스트를 고르는 방식이 아니라
전 항목 일괄 실행이며, `[FAIL]` 이 하나라도 있으면 exit 1 이다.
`.claude/launch.json` 의 `newPrjt02-static` 은 같은 서버(`python -m http.server 8941`)를 띄운다.

### 용어 (기록할 때 이 말을 쓴다)

저장소 문서·커밋·`claude-progress.md` 가 이미 이 용어로 씌어 있다. 새 이름을 만들지 말 것.

| 대상 | 이름 |
|---|---|
| `.\init.ps1` | **표준 시작 경로**(Standard startup path) — 검증만 |
| `-Start` / `-Start -OpenBrowser` | 그 경로의 **기동 모드** |
| `python -m http.server 8941` | **Standard start command** |
| 브라우저로 전 경로를 직접 밟아 확인하는 행위 | **실기동 검증** (기록 문구: "실기동 전 경로 통과") |

`init.ps1` 은 저장소 텍스트와 배포본 버전만 본다. **화면 동작·시트 기록·옵시디언 쓰기는
실기동 검증으로만 확인된다** — 하네스를 아무리 다시 돌려도 그쪽은 검증되지 않는다.

## Architecture

### 정적 앱 (빌드 없음, 서버 없음)

로그인 데모 + 진로상담(복사·붙여넣기 방식) 두 벌이다.

- `assets/auth.js` → `window.Auth` — PBKDF2-SHA256(10만회)+솔트 해싱, `np_users`/`np_session`,
  `requireAuth()` 가드. **Web Crypto 를 쓰므로 `file://` 로 열면 동작하지 않는다.**
- `assets/career.js` → `window.Career` — 2026-09-02 **복사·붙여넣기 방식으로 새로 작성**
  (이전 72KB 프록시 자동 호출 버전은 git 이력에만 있다). AI 를 직접 부르지 않는다 —
  프롬프트를 **조립**하고, 사용자가 복사해 원하는 AI 화면에 붙여넣은 뒤 받은 md 를
  앱에 되돌려 넣으면 **보관·렌더**만 한다. 공개 API 26종, `fetch(endpoint)` 같은
  자동 호출 경로 없음(`init.ps1` 이 이를 직접 검사한다 — 되살아나면 FAIL)
- ~~`assets/career-prompts.js`~~ — 폐기됨(생성물 자체가 불필요 — 아래 참고).
  원본 `assets/prompts/*.txt`(43KB)는 그대로 단일 원본이다
- 프롬프트 원문은 `career.js` 가 `assets/prompts/*.txt` 를 **직접 `fetch`** 한다 —
  `tools/build-prompts.py` 로 미리 생성하지 않는다(newPrjt01 은 생성 방식을 쓰지만
  이 저장소는 그 빌드 단계 자체를 없앴다)

흐름: `index → login → career.html`(진입) → `career-step1 → career-report1(붙여넣기)
→ career-step2 → career-report2(붙여넣기)`. `home.html` 은 2026-09-02 완전 폐기했다
(로그인 성공은 `career.html` 로 바로 간다) — 되살아나면 `init.ps1` 이 잡는다.

### AI 프록시 — 이 저장소에서 완전히 제거됨 (2026-09-03, `paste-006`)

**`tools/career_proxy.example.gs` 는 더 이상 이 저장소에 없다.** 진로상담 앱이
API 를 직접 부르지 않으므로 참고 구현을 보관할 이유가 사라졌다 — newPrjt01 실측
(웹검색을 꺼도 느림, 비용 부담)이 그 근거다. `init.ps1` 은 이 파일이 **되살아나면
FAIL**(paste-006 의 반대 방향 뒤집기)한다.

`careerTest`(형제 프로젝트)는 같은 Apps Script 배포의 `doGet` 을 계속 쓰지만, 그건
이 저장소가 지운 파일과 무관하게 원래부터 독립적으로 동작한다 — 그 배포·`.gs`
유지보수는 **newPrjt01** 이 담당한다. 프록시 코드가 다시 필요해지면(예: 대량 처리용
배치 API 검토) `C:\myPrjt01\newPrjt01\tools\career_proxy.example.gs` 를 본다 —
이 저장소에서 새로 쓰지 말 것.

### 자주 밟는 지뢰

- `init.ps1` 은 **UTF-8 BOM** 이어야 한다. 없으면 PS 5.1 이 cp949 로 읽어 파서가 죽는다.
  (init.ps1 이 자기 BOM 을 검사한다.) 나머지 텍스트 파일은 U+FFFD 가 섞이면 실패한다.
- **Windows PowerShell 5.1** 호환만 쓴다 — `&&`, 삼항연산자, `??` 금지.
- 보고서 끝단(STEP 11 최종 브리프·면책 문장) 잘림이 과거(프록시 시절) 네 번 재발했다.
  복사·붙여넣기 방식에서는 **사람이 스크롤 중간에서 복사하거나 전체 선택에 실패해**
  같은 증상이 난다 — `career.js` 의 완결성 검사(`paste-003`)와 `tools/check-report.py`
  가 그걸 잡는다. 붙여넣기 경로를 건드렸으면 눈으로 보지 말고 이걸로 확인한다.
- `sk-ant-` 문자열이 저장소 어디든 들어가면 검증이 실패한다 — 이 앱은 API 키를
  다루지 않으므로 원래 나올 일이 없어야 정상이다.
- 학생 개인정보가 담긴 `*.report.md` / `reports/` 는 커밋 금지(`.gitignore`).
- `tools/career_proxy.example.gs` 를 다시 만들지 말 것 — 위 절 참고.

## Operating Loop

세션 시작 시:

1. `pwd` 로 저장소 루트 확인.
2. `claude-progress.md` 읽기 (최근 세션 로그 + 검증된 상태).
3. `feature_list.json` 읽기 (기능 상태의 단일 원본).
4. `git log --oneline -5`.
5. `.\init.ps1` 실행.
6. 베이스라인이 이미 깨져 있으면 **그것부터** 고친다. 깨진 위에 새 기능을 쌓지 않는다.

그다음 미완 기능을 **정확히 하나** 골라, 검증하거나 막힌 이유를 기록할 때까지 그것만 한다.

## Rules

- 한 번에 한 기능.
- 실행 가능한 근거 없이 완료를 주장하지 않는다.
- 미완을 감추려고 feature list 를 고쳐 쓰지 않는다.
- 통과시키려고 검사를 지우거나 약화하지 않는다.
- 채팅 요약이 아니라 저장소 아티팩트가 기록의 원본이다.

## Completion Gate

`passing` 으로 올리려면 요구된 검증이 실제로 통과하고 그 결과가 기록돼야 한다.
`feature_list.json` 의 `evidence` 가 비어 있는데 `passing` 이면
**`init.ps1` 이 검증을 실패시킨다** — 형식적 규칙이 아니다.

## Before You Stop

1. `claude-progress.md` 갱신 (세션 로그 + Next best step).
2. `feature_list.json` 상태·근거 갱신.
3. 아직 깨졌거나 미검증인 것을 `session-handoff.md` 에 남긴다.
4. 안전한 상태에서 커밋.
5. 다음 세션이 `.\init.ps1` 을 바로 돌릴 수 있는 상태로 둔다.
