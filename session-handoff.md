# Session Handoff

> 최종 갱신: 2026-09-03 (Session 016 — 프록시 경로 완전 제거, paste-006 확정)
> ⚠ 이 저장소는 2026-09-02 에 `newPrjt01` 에서 분리됐다. 커밋 이력은 이어받지 않았다 —
> 이전 이력은 `gitHs-ops/newPrjt01` 과 로컬 `C:\myPrjt01\newPrjt01` 에 있다.
> 상세 이력은 `claude-progress.md`, 기능 상태는 `feature_list.json` 참고.

## 지금 상태 — 복사·붙여넣기 방식, 전 구간 동작, 프록시 완전 제거

`career.html` → `career-step1`(1차 프롬프트 복사) → `career-report1`(1차 결과 붙여넣기)
→ `career-step2`(추가정보 → 2차 프롬프트 복사) → `career-report2`(2차 결과 + 합본 저장).
API 키·프록시 배포·요금·실행시간 한도가 전부 없다 — 앱은 프롬프트를 조립하고
결과를 보관·렌더할 뿐, AI 를 부르지 않는다.

- `feature_list.json`: **16 passing · 12 retired · 2 not_started**(`auth-006`·`auth-007`,
  둘 다 보류). `in_progress` 0건
- `paste-001`~`005`, `007`~`009` 는 `passing`. **`paste-006`(프록시 경로 은퇴 여부
  결정)도 2026-09-03 확정 — 완전 제거.**
- **`tools/career_proxy.example.gs` 는 이 저장소에 더 이상 없다.** 2026-09-02 에는
  "careerTest 가 같은 배포를 쓰니 참고 구현은 남긴다"는 방향이었으나(당시 초안,
  feature_list.json 에는 실제로 반영되지 않았었다), newPrjt01 에서 같은 백엔드로
  실측한 결과(아래 절)로 완전 제거 쪽으로 뒤집혔다. `init.ps1` 은 이 파일이
  **되살아나면 FAIL**한다(반대 방향 가드, newPrjt01 Session 015 의 home.html 폐기와
  같은 패턴).
- `careerTest`(형제 프로젝트)는 같은 Apps Script 배포의 `doGet` 을 독립적으로 계속
  쓴다 — 영향 없음. 그 배포·`.gs` 유지보수는 **newPrjt01** 이 담당한다.

### 프록시를 완전히 제거한 근거 (newPrjt01 실측, 2026-09-02~03)

newPrjt01 에서 이 프록시를 Vercel Edge Functions 로 옮기고 스트리밍까지 붙여
실측했다. 결과:

- **웹검색을 꺼도 개선 없음** — 2차 분석이 여전히 ~3분. 병목은 검색이 아니라
  Haiku 4.5 자체의 긴 글 생성·이어쓰기였다.
- **이 저장소(프롬프트 복사 방식)가 이미 2분 이내로 더 빠르다.**
- **이틀 테스트에 API 크레딧 $20 소진.** 이 프로젝트를 시작한 원래 동기(학교 단체
  측정 시 비용 폭탄 우려)가 실측으로 재확인됐다.

상세: `C:\myPrjt01\newPrjt01\session-handoff.md`, `C:\myPrjt01\newPrjt01\claude-progress.md`
Session 012.

## `init.ps1` 이 세 방향으로 지키는 것

1. **폐기 코드가 되살아나지 않는가** — `home.html`, `career_proxy.example.gs`,
   `fetch(endpoint)` 류 자동 호출 경로. 셋 다 되살아나면 `[FAIL]`
2. **새 방식이 실제로 갖춰져 있는가** — AI 서비스 선택 드롭다운, 완결성 검사,
   예시 채우기, 붙여넣은 md 이스케이프 등
3. **로그인 데모·프롬프트 원문·구글시트 관련 문서(경위)** — 그대로 유지

## Verified Now

- **로그인 데모** — `index.html` → `login.html` → `career.html`(성공, `home.html`
  경유 안 함) / `error.html`, `signup.html`
- **진로상담(복사·붙여넣기) — 전 구간 동작 확인.**
  - `career.html` 진입 → 사례 생성 → 1차 입력(드롭다운·빠른 선택·예시 채우기)
    → 1차 프롬프트 복사 → (사람이 AI 화면에 붙여넣기) → 결과 붙여넣기 →
    완결성 검사 → 2차 입력 → 2차 프롬프트 복사 → 결과 붙여넣기 → 1·2차 합본 저장
  - 옵시디언 전송은 새 버전에 없다(`career-009` retired). 진단 도구
    `tools/obsidian-check.html` 만 남아 있다
- **실제로 돌린 검증**
  1. `.\init.ps1` → **79개 항목 전부 `[OK]`, exit 0**
  2. 실기동 — 로그인 성공 → `career.html` 직행 확인(Session 015), 클립보드 쓰기·
     예시 채우기·완결성 검사 각각 실제 클릭으로 확인(Session 009~014)
  3. ⚠ **사람이 한 번 확인해야 닫히는 것**: 복사된 프롬프트를 실제 AI 화면에
     붙여넣어 잘리지 않고 들어가는지. `clipboard.readText` 권한과 합성 `Ctrl+V` 가
     막혀 자동 검증이 안 된다 — 쓰기 성공과 글자 수까지만 확인했다

## 지금 이 앱에 붙어 있는 외부 연결

없음. AI 호출·프록시·시트 기록·옵시디언 전송 전부 이 앱 밖(사람 손 또는 미구현)이다.
로그인 데모의 계정·세션은 `localStorage`/`sessionStorage` 뿐이다.

## 바꾸면 안 되는 것

- `init.ps1` 의 검증 게이트를 느슨하게 만들지 말 것 — **추가**하는 방향으로만
- `tools/career_proxy.example.gs` 를 다시 만들지 말 것 — 위 절 참고. 필요하면
  newPrjt01 의 사본을 본다
- `career.js` 에 `fetch(endpoint)` 류 자동 호출 경로를 다시 넣지 말 것 —
  `init.ps1` 이 그 반대(경로 없음)를 검사한다
- `assets/prompts/*.txt` 가 프롬프트의 단일 원본이다 — 화면 문구를 직접 고치지 말 것
- 선택지 목록(과목·산업·계기·일하는 방식·전공 등)은 `newPrjt01` 것 그대로다 —
  특히 "일하는 방식" 9종은 2차 프롬프트가 열거한 항목과 같아야 한다
- 완결성 검사 기대 형식은 `career.js` 와 `tools/check-report.py` 두 곳에 있고
  `init.ps1` 이 갈라짐을 감시한다 — 프롬프트의 출력 구조를 바꾸면 세 곳을 함께 고칠 것

## Next Best Step

1. **실사용 전환 검토** — newPrjt01(GAS 프록시 경로)과 이 저장소(복사·붙여넣기)
   중 어느 쪽을 실제 배포로 밀지 결정. 이번 실측으로 이 저장소 쪽이 유력
2. 사람이 붙여넣는 실제 붙여넣기 테스트를 몇 차례 더 돌려 클립보드 경로의
   신뢰도를 쌓는다
3. 보류된 **`auth-006`(서버 인증)** 재개 — 사례가 브라우저별로 격리되는 한계 해소

## Commands

- **Startup(검증만)**: `.\init.ps1`
- **Startup(서버까지)**: `.\init.ps1 -Start` / 브라우저까지: `.\init.ps1 -Start -OpenBrowser`
- **보고서 완결성 검사**: `python tools/check-report.py "<저장된 보고서.md>"`
  - 잘림·인코딩 사고를 잡는다. 붙여넣기 경로를 고쳤으면 **반드시** 이걸로 확인
- **Focused debug**
  - 서버만: `python -m http.server 8941`
  - 진로상담: http://localhost:8941/career.html (로그인 필요)
  - 옵시디언 연결 진단: http://localhost:8941/tools/obsidian-check.html
  - 초기화: `localStorage.removeItem('np_users' / 'np_career_cases' /
    'np_career_config' / 'np_career_usage')`
