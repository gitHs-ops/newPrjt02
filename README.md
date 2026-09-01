# newPrjt02

빌드 단계가 없는 **정적 HTML 앱** 두 벌.

1. **로그인 데모** — 계정은 브라우저 `localStorage` 에만 저장하는 테스트용이며,
   비밀번호는 평문이 아니라 **PBKDF2-SHA256(10만회) + 사용자별 랜덤 솔트** 해시로 보관한다.
2. **진로상담 분석** — 중·고 진로교사용. 학생 정보로 **1차 진로·산업·진학 리서치**를 수행하고,
   추가 경험·학교자료를 더해 **2차 진로 가설 분석**까지 이어간다. 결과는 브라우저에 보존되고
   **md 파일**로 저장할 수 있다. 로그인 성공 화면(`home.html`)에서 진입한다.

## 실행

```powershell
.\init.ps1 -Start
```

→ http://localhost:8941/

| 옵션 | 동작 |
|---|---|
| `.\init.ps1` | 검증만 수행 (63개 항목) |
| `.\init.ps1 -Start` | 검증 후 로컬 서버 기동 |
| `.\init.ps1 -Start -OpenBrowser` | 기동 후 브라우저까지 열기 |
| `-Port 9000` | 포트 변경 (기본 8941) |

> ⚠ `init.ps1` 은 **UTF-8 BOM** 으로 저장해야 한다. BOM 이 없으면 Windows PowerShell 5.1 이
> cp949 로 읽어 한글이 깨지고 파서 오류가 난다.

## 화면

| 파일 | 역할 |
|---|---|
| `index.html` | 랜딩 (로그인 데모 진입) |
| `login.html` | 로그인 — 상태 유지, 비밀번호 찾기(모달), Google 버튼(모의), Enter 키 |
| `signup.html` | 회원가입 — 아이디 중복확인, 비밀번호 재확인, 보기/숨김 토글 |
| `home.html` | 로그인 성공 — 세션 정보 표시, 로그아웃 |
| `error.html` | 로그인 실패 — 사유 표시 |
| `assets/auth.css` | 공통 디자인 시스템 (라이트 글래스모피즘) |
| `assets/auth.js` | 공통 인증 로직 (해싱·세션·검증) |

> `home.html` 의 진로상담 카드는 **재작성 중** 안내로 바뀌어 있다(클릭 불가).
> 새 화면이 서면 다시 링크로 되돌린다.

### 진로상담 (재작성 중 — 2026-09-02)

**화면과 JS 를 전부 폐기했다.** 프롬프트 복사·붙여넣기 방식으로 새로 만든다.
계획은 `feature_list.json` 의 `paste-001`~`006`.

새 방식은 이렇게 동작한다.

1. 앱이 학생 정보로 **프롬프트 전문을 조립**한다
2. 사용자가 **[프롬프트 복사]** → 원하는 AI 화면(Claude·ChatGPT 등)에 붙여넣는다
3. 받은 md 를 **앱에 되돌려 넣으면** 앱이 렌더하고 사례에 저장한다

API 키·프록시 배포·요금·Apps Script 6분 한도가 전부 사라진다.
대신 **사람 손이 경로에 들어온다** — 전체 선택 실패나 스크롤 중간 복사로 보고서가
잘릴 수 있어, 붙여넣은 md 의 완결성 검사(`paste-003`)가 자동 호출 때보다 오히려 중요하다.

남겨 둔 재료:

| 파일 | 역할 |
|---|---|
| `assets/prompts/*.txt` | **프롬프트 원문 43KB** — 이 프로젝트의 핵심 자산 |
| `tools/build-prompts.py` | 원문 → JS 생성기 (새 코드가 같은 방식을 쓰면 그대로 사용) |
| `tools/check-report.py` | 보고서 완결성 검사 — `paste-003` 이 같은 기대 형식을 쓴다 |
| `tools/obsidian-check.html` | 옵시디언 연결 5단계 실측 |
| `tools/career_proxy.example.gs` | AI 프록시 — **careerTest 와 구글시트 기록용으로 유지** |

> 프록시(`.gs`)와 구글시트는 지우지 않았다. 진로상담 앱이 더 이상 부르지 않을 뿐,
> `careerTest` 가 같은 Apps Script 배포의 `doGet` 을 계속 쓴다.
> 그래서 `init.ps1` 의 `.gs` 검사와 `-Live` 도 그대로 남겨 두었다.

폐기한 파일(git 이력에 남아 있다): `career.html`, `career-step1/2.html`,
`career-report1/2.html`, `assets/career.js`, `assets/career.css`, `assets/career-prompts.js`

## 데이터

| 키 | 저장소 | 내용 |
|---|---|---|
| `np_users` | `localStorage` | 계정 목록 — `id`, `salt`, `hash`, `provider`, `createdAt` |
| `np_session` | 상태유지 켬 → `localStorage`<br>끔 → `sessionStorage` | `id`, `provider`, `remember`, `loginAt` |
| `np_career_cases` | `localStorage` | 상담 사례 — `label`, `owner`, `student`, `report1`, `extra2`, `report2` |
| `np_career_config` | `localStorage` | 연결 설정 — 프록시 URL, 모델, max_tokens, 웹검색 옵션, **옵시디언 주소·API 키·폴더** |

초기화: 개발자도구 콘솔에서
`localStorage.removeItem('np_users')` / `localStorage.removeItem('np_career_cases')`

> 사례 이름은 **AI 로 전달되지 않는** 로컬 라벨이다. 학생 실명 대신 별칭을 쓸 것.
> 학교자료 입력란에 개인식별정보·민감정보를 넣지 말 것.

## 한계 (실서비스로 쓰기 전에 반드시 해결)

- **인증이 전부 클라이언트 측이다.** `home.html` 의 접근 제어는 가드일 뿐 보안 경계가 아니다
- **계정이 브라우저별로 격리된다.** 다른 기기·브라우저·시크릿창에서는 보이지 않는다
- **Google 로그인은 실제 OAuth 가 아니다.** 흐름만 재현한 모의 동작이다
- `file://` 로 직접 열면 동작하지 않는다 — Web Crypto 가 보안 컨텍스트를 요구하므로
  반드시 로컬 서버로 띄워야 한다

진로상담 쪽 한계:

- **AI 프록시가 배포되지 않았다.** 지금은 모의 응답으로만 흐름이 돌아간다 (`career-008`)
- ~~옵시디언 전송~~ — **동작 확인됨**(2026-09-01). 플러그인 설치 + [연결 설정]만 하면 된다
- **사례가 브라우저별로 격리된다.** 로그인 데모와 같은 한계다
- **웹검색은 프록시가 배포되어야 실제로 돈다.** 클라이언트는 지시를 보내지만
  프록시가 `web_search` 도구를 켜지 않으면 “확인 불가”가 대량으로 나온다 —
  결과 화면이 **출처 0건 경고**로 알려준다

→ 남은 과제는 `feature_list.json` 의 `career-008`(AI 프록시 배포),
그리고 보류된 `auth-006`(서버 인증) · `auth-007`(실제 OAuth) 참고.

## 에이전트 하네스

이 저장소는 장시간 에이전트 작업을 전제로 구성돼 있다.

| 파일 | 역할 |
|---|---|
| `AGENTS.md` / `CLAUDE.md` | 에이전트 운영 지침 |
| `init.ps1` | 표준 시작·검증 경로 |
| `feature_list.json` | 기능 상태의 단일 원본 |
| `claude-progress.md` | 세션 진행 로그 |
| `session-handoff.md` | 세션 간 인계 노트 |

세션을 시작할 때는 `claude-progress.md` → `feature_list.json` 순으로 읽고 `.\init.ps1` 을 실행한다.

템플릿 출처: [walkinglabs/learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering) (MIT)
