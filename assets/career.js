/* newPrjt02 — 진로상담 공통 로직 (프롬프트 복사·붙여넣기 방식)
   2026-09-02 새로 작성. 이전 프록시 자동 호출 버전(72KB)은 폐기했다.

   이 방식의 핵심:
     앱은 프롬프트를 **조립**하고 결과를 **보관·렌더**할 뿐, AI 를 부르지 않는다.
     사용자가 복사 → 원하는 AI 화면에 붙여넣기 → 받은 md 를 앱에 되돌려 넣는다.
     그래서 API 키·프록시·요금·실행시간 한도가 존재하지 않는다.

   프롬프트 원문은 assets/prompts/*.txt 를 **직접 fetch** 한다.
   이전 버전은 build-prompts.py 로 만든 career-prompts.js 를 썼는데,
   "원문을 고치고 생성기를 안 돌려 낡은 프롬프트가 나가는" 사고가 구조적으로 가능했다
   (init.ps1 이 그걸 잡는 검사를 따로 갖고 있었을 정도다). fetch 로 그 부류를 없앤다.
   대신 서버가 필요한데, Web Crypto 때문에 어차피 file:// 로는 못 쓴다. */
(function (g) {
    'use strict';

    var CASES_KEY = 'np_career_cases';

    var PROMPT_SRC = {
        first:       'assets/prompts/prompt-1st.txt',
        second:      'assets/prompts/prompt-2nd.txt',
        inputFirst:  'assets/prompts/input-1st.txt',
        inputSecond: 'assets/prompts/input-2nd.txt'
    };

    /* ---------------------------------------------------------- 프롬프트 원문 */

    var _prompts = null;

    /** 프롬프트 원문 4종을 받아 캐시한다. 실패하면 이유를 그대로 올린다 —
        조용히 빈 프롬프트를 복사해 주는 것이 최악이다. */
    function loadPrompts() {
        if (_prompts) { return Promise.resolve(_prompts); }
        var keys = Object.keys(PROMPT_SRC);
        return Promise.all(keys.map(function (k) {
            return fetch(PROMPT_SRC[k], { cache: 'no-cache' }).then(function (r) {
                if (!r.ok) { throw new Error(PROMPT_SRC[k] + ' 를 읽지 못했습니다 (HTTP ' + r.status + ')'); }
                return r.text();
            });
        })).then(function (texts) {
            var out = {};
            keys.forEach(function (k, i) { out[k] = texts[i].replace(/\r\n/g, '\n').replace(/^﻿/, ''); });
            if (!out.first || out.first.length < 10000) {
                throw new Error('1차 프롬프트 원문이 비었거나 너무 짧습니다 (' + out.first.length + '자)');
            }
            _prompts = out;
            return out;
        });
    }

    /* ---------------------------------------------------------- 입력 정의 */

    /* input-1st.txt 의 항목과 순서를 그대로 따른다. 여기서 어긋나면
       프롬프트가 기대하는 입력 형식이 깨진다. */
    var FIELDS_1 = [
        { key: 'grade',     label: '학교급 및 학년',              required: true,  type: 'select' },
        { key: 'job',       label: '희망 직업 / 직무 / 계열',     required: true,  type: 'text',
          hint: '학생이 말한 표현 그대로 적으십시오 — 프롬프트가 그 표현 자체를 해석 대상으로 삼습니다.' },
        { key: 'subject',   label: '현재 관심 과목 및 강점',      required: true,  type: 'textarea' },
        { key: 'industry',  label: '관심 있는 산업 또는 분야',    required: false, type: 'textarea' },
        { key: 'trigger',   label: '관심을 갖게 된 계기',         required: false, type: 'textarea' },
        { key: 'style',     label: '좋아하는 활동 또는 문제해결 방식', required: false, type: 'textarea' },
        { key: 'major',     label: '현재 생각하고 있는 전공',     required: false, type: 'textarea' },
        { key: 'score',     label: '현재 교과 성적 또는 대략적인 수준', required: false, type: 'select' },
        { key: 'univ',      label: '희망 대학 또는 대학 수준',    required: false, type: 'select' },
        { key: 'region',    label: '희망 지역',                   required: false, type: 'select' },
        { key: 'entryYear', label: '대학 진학 예정 연도',         required: false, type: 'select' },
        { key: 'ask',       label: '추가적으로 알고 싶은 내용',   required: false, type: 'textarea' }
    ];

    var GRADES = ['중학교 1학년', '중학교 2학년', '중학교 3학년',
                  '고등학교 1학년', '고등학교 2학년', '고등학교 3학년'];

    /* 선택지 목록은 newPrjt01 에서 그대로 가져왔다. 실제 상담에서 쓰던 어휘라
       새로 지어내면 프롬프트가 기대하는 표현과 어긋난다. */
    var CHOICES = {
        grade: GRADES,

        /* 성적은 학교급에 따라 체계가 다르다. 중학교에 "등급"을 쓰면
           프롬프트가 일관성 검증에서 [확인 필요] 로 걸어야 하는 모순이 된다. */
        score: {
            중학교: ['성취도 A (90점 이상)', '성취도 B (80점대)', '성취도 C (70점대)',
                     '성취도 D (60점대)', '성취도 E (60점 미만)',
                     '전반적으로 상위권', '전반적으로 중위권', '전반적으로 하위권'],
            고등학교: ['내신 1~2등급', '내신 3~4등급', '내신 5~6등급', '내신 7~9등급',
                       '과목별 편차가 큼', '전반적으로 상위권', '전반적으로 중위권', '전반적으로 하위권']
        },
        univ: ['최상위권 대학', '수도권 상위권 대학', '수도권 4년제', '지방 거점 국립대',
               '지방 4년제', '전문대학', '특성화대학·폴리텍', '아직 정하지 않음'],
        region: ['서울', '수도권(경기·인천)', '충청권', '강원권', '영남권(부산·대구·경남북)',
                 '호남권', '제주', '지역은 상관없음', '아직 정하지 않음'],

        /* 아래는 자유입력란에 **덧붙이는** 빠른 선택이다. 고르면 사라지지 않고 쌓인다. */
        subject: ['국어', '영어', '수학', '통합과학', '물리', '화학', '생명과학', '지구과학',
                  '정보·컴퓨터', '기술·가정', '사회', '역사', '지리', '경제',
                  '미술', '음악', '체육', '제2외국어'],
        industry: ['반도체', '디스플레이', '이차전지', '자동차·모빌리티', '조선·해양', '항공우주',
                   '로봇·자동화', 'AI·소프트웨어', '게임', '콘텐츠·미디어', '바이오·제약', '의료·헬스케어',
                   '화학·소재', '에너지·신재생', '건설·인프라', '금융', '물류·유통', '식품',
                   '환경·탄소중립', '교육', '공공·행정'],
        trigger: ['수업에서 배우고 흥미가 생김', '동아리 활동', '다큐멘터리·영상', '뉴스·기사',
                  '책', '게임·취미', '가족·지인의 영향', '진로체험·박람회', '학교 진로수업',
                  '친구 이야기', '특정 기업·제품을 보고'],

        /* 2차 프롬프트가 열거한 '일하는 방식' 9종을 그대로 쓴다 —
           1차 입력과 2차 분석의 어휘를 맞추면 대조가 쉬워진다. */
        workStyle: ['원리 탐구 — 왜 그런지 알아내는 것', '분석·문제해결 — 원인을 찾아 하나씩 확인',
                    '설계·개발 — 구조나 방법을 새로 만드는 것', '제작·현장 — 도구·장비를 직접 다루는 것',
                    '기획·구조화 — 목표와 순서를 세우는 것', '데이터·계산 — 숫자와 패턴으로 푸는 것',
                    '설명·소통 — 이해한 것을 남에게 설명하는 것', '사람지원 — 남을 돕고 문제를 풀어주는 것',
                    '표현·콘텐츠 — 글·영상·디자인으로 표현하는 것'],
        major: ['전자공학과', '전기공학과', '기계공학과', '컴퓨터공학과', '소프트웨어학과',
                '신소재공학과', '화학공학과', '산업공학과', '조선해양공학과', '항공우주공학과',
                '건축학과', '토목공학과', '생명공학과', '의예과', '간호학과', '약학과',
                '물리학과', '화학과', '수학과', '통계학과', '경영학과', '경제학과',
                '심리학과', '교육학과', '디자인학과', '미디어커뮤니케이션학과'],
        teamRole: ['기획·리더 역할', '자료조사', '발표', '정리·기록', '제작·실습',
                   '아이디어 제시', '갈등 조정', '특별히 정해진 역할 없음'],
        askedFor: ['공부·과제 설명해 주기', '문제 풀이 도와주기', '컴퓨터·기기 문제 해결',
                   '발표 맡기', '자료 정리·정돈', '만들기·꾸미기', '중재·상담',
                   '특별히 부탁받는 일 없음']
    };

    /* input-2nd.txt 의 경험·학교자료 항목. 순서와 문구를 그대로 따른다 —
       프롬프트가 이 라벨로 입력을 읽는다. */
    var FIELDS_2_EXP = [
        '기억에 남는 수행평가', '좋아했던 활동', '싫었던 활동',
        '실패했지만 다시 해보고 싶은 경험', '조별활동에서 주로 맡는 역할',
        '친구들이 자주 부탁하는 일', '혼자 있을 때 자주 하는 활동',
        '결과가 좋았던 경험', '학생이 스스로 잘한다고 느끼는 것'
    ];
    var FIELDS_2_SCHOOL = [
        '교과성적', '세부능력 및 특기사항', '수행평가', '탐구활동',
        '동아리', '자율활동', '진로활동', '기타 학생을 이해하는 데 필요한 학교자료'
    ];

    /* 1차 자유입력란 <- 어떤 빠른 선택을 붙일지 */
    var QUICK_1 = {
        subject:  'subject',
        industry: 'industry',
        trigger:  'trigger',
        style:    'workStyle',
        major:    'major'
    };

    /* 2차 경험 항목(FIELDS_2_EXP 인덱스) <- 빠른 선택 */
    var QUICK_2_EXP = {
        1: 'workStyle',   /* 좋아했던 활동 */
        2: 'workStyle',   /* 싫었던 활동 */
        4: 'teamRole',    /* 조별활동에서 주로 맡는 역할 */
        5: 'askedFor',    /* 친구들이 자주 부탁하는 일 */
        8: 'workStyle'    /* 스스로 잘한다고 느끼는 것 */
    };

    /**
     * 빠른 선택 -> 자유입력란에 **덧붙인다**(덮어쓰지 않는다).
     * 이미 들어 있는 값은 무시한다. 고른 뒤 드롭다운은 첫 항목으로 돌아가
     * 연달아 여러 개를 담을 수 있다 — 반복 입력 부담을 줄이는 것이 목적이다.
     */
    function bindQuickPick(selectId, targetId, sep) {
        var sel = document.getElementById(selectId);
        var box = document.getElementById(targetId);
        if (!sel || !box) { return; }
        sep = sep || ', ';
        sel.addEventListener('change', function () {
            var v = sel.value;
            sel.selectedIndex = 0;
            if (!v) { return; }
            var cur = box.value.trim();
            if (cur.split(/\s*,\s*|\n/).indexOf(v) >= 0) { return; }
            box.value = cur ? cur + sep + v : v;
            box.dispatchEvent(new Event('input', { bubbles: true }));
            box.focus();
        });
    }

    /* 테스트용 예시 — 전 과정을 반복 검증할 때 매번 손으로 채우는 부담을 없앤다.
       newPrjt01 에서 쓰던 값 그대로다. */
    var SAMPLE_1 = {
        grade: '고등학교 2학년',
        job: '반도체를 하고 싶다',
        subject: '물리, 수학',
        industry: '반도체, 자동차·모빌리티',
        trigger: '수업에서 배우고 흥미가 생김',
        style: '분석·문제해결 — 원인을 찾아 하나씩 확인',
        major: '전자공학과',
        score: '내신 3~4등급',
        univ: '수도권 4년제',
        region: '수도권(경기·인천)',
        ask: '이 전공이 어떤 산업들과 연결되는지 알고 싶다'
    };

    var SAMPLE_2 = {
        exp: {
            '기억에 남는 수행평가': '물리 수행평가에서 브레드보드로 간단한 회로를 만들어 발표했다',
            '좋아했던 활동': '분석·문제해결 — 원인을 찾아 하나씩 확인',
            '싫었던 활동': '표현·콘텐츠 — 글·영상·디자인으로 표현하는 것',
            '실패했지만 다시 해보고 싶은 경험': '동아리 로봇이 계속 멈춰서 끝내 원인을 못 찾았는데 다시 해보고 싶다고 함',
            '조별활동에서 주로 맡는 역할': '자료조사',
            '친구들이 자주 부탁하는 일': '컴퓨터·기기 문제 해결',
            '혼자 있을 때 자주 하는 활동': '유튜브에서 기계 분해·조립 영상을 자주 본다',
            '결과가 좋았던 경험': '과학탐구대회 교내 장려상',
            '학생이 스스로 잘한다고 느끼는 것': '분석·문제해결 — 원인을 찾아 하나씩 확인'
        },
        school: {
            '교과성적': '수학·물리 상위권, 국어·영어는 중위권',
            '세부능력 및 특기사항': '실험에서 오차 원인을 스스로 찾아 재실험을 제안함',
            '수행평가': '물리 회로 제작, 화학 반응속도 실험',
            '탐구활동': '태양광 패널 각도에 따른 발전량 비교',
            '동아리': '과학탐구 동아리 2년째',
            '자율활동': '학급 기자재 관리 담당',
            '진로활동': '반도체 기업 견학, 전자공학과 학과 체험',
            '기타 학생을 이해하는 데 필요한 학교자료': '조용한 편이나 관심 주제에는 질문이 많음'
        },
        teacherAsk: '이 학생에게 공대 진학이 현실적인지, 대안 경로가 있는지'
    };

    /** 학년에서 진학 예정 연도를 계산한다. 손으로 넣으면 학년과 어긋나고,
        프롬프트가 그 모순을 검증 항목으로 두고 있다. */
    function entryYearFor(grade, thisYear) {
        var y = thisYear || new Date().getFullYear();
        var m = /(중학교|고등학교)\s*(\d)학년/.exec(grade || '');
        if (!m) { return null; }
        var left = (m[1] === '중학교' ? (3 - Number(m[2])) + 3 : 3 - Number(m[2]));
        return y + left + 1;
    }

    function isMiddle(grade) { return /중학교/.test(grade || ''); }

    /* ---------------------------------------------------------- 프롬프트 조립 */

    function line(label, value) {
        var v = (value || '').toString().trim();
        return '* ' + label + ': ' + (v || '(입력 없음)');
    }

    /** 1차 — 프롬프트 원문 + [입력 데이터]. 이 문자열 전체가 클립보드로 간다. */
    function buildPrompt1(student) {
        return loadPrompts().then(function (p) {
            var s = student || {};
            var body = ['[입력 데이터]', '', '# 학생 정보', ''];
            FIELDS_1.forEach(function (f) { body.push(line(f.label, s[f.key])); });
            return p.first.trim() + '\n\n---\n\n' + body.join('\n') + '\n';
        });
    }

    /** 2차 — 프롬프트 원문 + 1차 결과 + 추가 정보 */
    function buildPrompt2(report1Md, extra) {
        return loadPrompts().then(function (p) {
            var x = extra || {};
            var out = ['[입력 데이터]', '', '## [1차 진로·산업·진학 리서치 결과]', '',
                       (report1Md || '').trim() || '(1차 결과 없음)', '',
                       '## [학생의 추가 경험·행동 정보]', ''];
            if (x.hasExp) {
                FIELDS_2_EXP.forEach(function (label) { out.push(line(label, (x.exp || {})[label])); });
            } else {
                out.push('추가 정보 없음');
            }
            out.push('', '## [학교 자료 정보]', '');
            if (x.hasSchool) {
                FIELDS_2_SCHOOL.forEach(function (label) { out.push(line(label, (x.school || {})[label])); });
            } else {
                out.push('학교자료 없음');
            }
            out.push('', '## [교사가 특별히 확인하고 싶은 내용]', '',
                     (x.teacherAsk || '').trim() || '(없음)');
            return p.second.trim() + '\n\n---\n\n' + out.join('\n') + '\n';
        });
    }

    /* ------------------------------------------------------ AI 화면 선택 */

    var AI_SERVICE_KEY = 'np_ai_service';

    /* 링크만 연다 — 자동 입력은 하지 않는다(각 서비스 약관·로그인 문제).
       url 은 새 대화창을 바로 여는 주소로 고른다. */
    var AI_SERVICES = [
        { key: 'claude',     label: 'Claude',     url: 'https://claude.ai/new' },
        { key: 'chatgpt',    label: 'ChatGPT',    url: 'https://chatgpt.com/' },
        { key: 'gemini',     label: 'Gemini',     url: 'https://gemini.google.com/app' },
        { key: 'perplexity', label: 'Perplexity', url: 'https://www.perplexity.ai/' }
    ];

    /** 교사가 마지막으로 고른 AI 서비스. 화면마다 다시 고르지 않도록 기억한다. */
    function getAiService() {
        var saved = localStorage.getItem(AI_SERVICE_KEY);
        var hit = AI_SERVICES.filter(function (s) { return s.key === saved; });
        return hit.length ? hit[0] : AI_SERVICES[0];
    }
    function setAiService(key) {
        if (AI_SERVICES.some(function (s) { return s.key === key; })) {
            localStorage.setItem(AI_SERVICE_KEY, key);
        }
    }

    /** [AI 화면 열기] 를 새 탭이 아니라 별도 팝업 창으로 연다 — 프롬프트를
     *  복사해 둔 화면과 나란히 놓고 붙여넣기 하라는 뜻이다. 같은 창 이름을
     *  써서 다시 누르면 새 창을 또 띄우지 않고 기존 팝업을 재사용한다. */
    function openAiPopup(url) {
        var w = 1000, h = 880;
        var left = Math.max(0, Math.round((screen.width  - w) / 2));
        var top  = Math.max(0, Math.round((screen.height - h) / 2));
        /* noopener 를 주면 창 이름이 무시돼(스펙상 매번 새 창) 재사용이 안 된다 —
           AI_SERVICES 목록의 고정 주소만 여는 거라 opener 노출 위험이 없어 뺐다. */
        window.open(url, 'npAiPopup',
            'width=' + w + ',height=' + h + ',left=' + left + ',top=' + top +
            ',menubar=no,toolbar=no,location=yes,status=no');
    }

    /* ---------------------------------------------------------- 클립보드 */

    /**
     * 텍스트를 클립보드에 넣는다. 26KB 넘는 프롬프트가 대상이다.
     *
     * navigator.clipboard 는 보안 컨텍스트(https 또는 localhost)에서만 산다.
     * 막힌 환경을 위해 textarea + execCommand 로 떨어진다.
     * 둘 다 실패하면 **조용히 넘어가지 않고** 이유를 올린다 —
     * 복사된 줄 알고 빈 클립보드를 붙여넣는 것이 이 방식의 최악 시나리오다.
     */
    function copyText(text) {
        if (!text) { return Promise.reject(new Error('복사할 내용이 비어 있습니다.')); }

        if (g.navigator && g.navigator.clipboard && g.isSecureContext) {
            return g.navigator.clipboard.writeText(text).catch(function (e) {
                return legacyCopy(text, e);
            });
        }
        return legacyCopy(text, null);
    }

    function legacyCopy(text, prevErr) {
        return new Promise(function (resolve, reject) {
            var ta = document.createElement('textarea');
            ta.value = text;
            /* 화면 밖으로 밀되 display:none 은 안 된다 — 선택이 되지 않는다. */
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.top = '-1000px';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            try {
                ta.select();
                ta.setSelectionRange(0, text.length);   /* iOS 는 select() 만으로 부족하다 */
                var ok = document.execCommand('copy');
                document.body.removeChild(ta);
                if (ok) { resolve(); }
                else {
                    reject(new Error('브라우저가 복사를 거부했습니다' +
                        (prevErr ? ' (' + prevErr.message + ')' : '') +
                        '. 아래 원문을 직접 선택해 복사하십시오.'));
                }
            } catch (e) {
                if (ta.parentNode) { document.body.removeChild(ta); }
                reject(new Error('복사에 실패했습니다: ' + (e && e.message || e) +
                                 '. 아래 원문을 직접 선택해 복사하십시오.'));
            }
        });
    }

    /* ---------------------------------------------------------- 사례 저장소 */

    function currentOwner() {
        var s = g.Auth && g.Auth.getSession && g.Auth.getSession();
        return (s && s.id) || '';
    }

    function readAll() {
        try { return JSON.parse(localStorage.getItem(CASES_KEY) || '[]'); }
        catch (e) { return []; }
    }
    function writeAll(list) { localStorage.setItem(CASES_KEY, JSON.stringify(list)); }

    function listCases() {
        var owner = currentOwner();
        return readAll().filter(function (c) { return c.owner === owner; })
                        .sort(function (a, b) { return (b.at || '').localeCompare(a.at || ''); });
    }
    function getCase(id) {
        var hit = readAll().filter(function (c) { return c.id === id; });
        return hit.length ? hit[0] : null;
    }
    function createCase(label) {
        var c = {
            id: 'c' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            label: (label || '').trim() || '이름 없는 사례',
            owner: currentOwner(),
            at: new Date().toISOString(),
            student: {}, report1: null, extra2: null, report2: null
        };
        var all = readAll(); all.push(c); writeAll(all);
        return c;
    }
    function updateCase(id, patch) {
        var all = readAll(), found = null;
        all.forEach(function (c) {
            if (c.id === id) { Object.keys(patch).forEach(function (k) { c[k] = patch[k]; }); found = c; }
        });
        if (found) { writeAll(all); }
        return found;
    }
    function deleteCase(id) {
        writeAll(readAll().filter(function (c) { return c.id !== id; }));
    }

    /** 붙여넣은 보고서를 사례에 넣는다. 자동 호출이 아니라 사람 손에서 왔다는 사실을 남긴다. */
    function saveReport(id, round, md) {
        var text = (md || '').trim();
        if (!text) { throw new Error('붙여넣은 내용이 비어 있습니다.'); }
        var rec = { md: text, at: new Date().toISOString(), source: 'paste', chars: text.length };
        var patch = {};
        patch[round === 2 ? 'report2' : 'report1'] = rec;
        updateCase(id, patch);
        return rec;
    }

    /* ------------------------------------------------------ 보고서 완결성 검사 */

    /* tools/check-report.py 와 **같은 기대 형식**이다. 한쪽만 고치면 두 검사가 갈라진다.
       두 곳 모두 assets/prompts/*.txt 의 출력 규정에서 나온 값이므로,
       프롬프트의 A~L / STEP 구조를 바꾸면 여기와 check-report.py 를 함께 고쳐야 한다. */
    var FIRST_SECTIONS = 'ABCDEFGHIJKL'.split('');
    var FIRST_TAIL_HEADS = ['현재 공식자료로 확인된 내용', '현재 확인할 수 없는 내용', '상담에서의 해석'];
    var FIRST_DISCLAIMER = '본 자료는 진로상담을 시작하기 위한 1차 정보이며';
    var SECOND_DISCLAIMER = '본 2차 분석은 1차 진로리서치에서';
    var MOCK_MARK = '모의 응답';
    var BROKEN_CHAR = String.fromCharCode(0xFFFD);
    var TAIL_WINDOW = 25;      /* 면책 문장은 문서 끝부분에 있어야 한다 */
    var MIN_CHARS = 3000;

    function reFind(text, pattern) { return new RegExp(pattern, 'm').test(text); }

    /** 1차인지 2차인지 스스로 판별한다. 잘린 문서일수록 이게 중요하다 —
        그래야 "무엇이 빠졌는지" 를 말해 줄 수 있다. 0 이면 판별 불가. */
    function detectKind(text) {
        if (text.indexOf(SECOND_DISCLAIMER) >= 0 || reFind(text, '^#{1,3}\\s*STEP\\s*\\d+\\b')) { return 2; }
        var secs = text.match(/^#{1,3}\s*[A-L]\./gm);
        if (text.indexOf(FIRST_DISCLAIMER) >= 0 || (secs && secs.length >= 3)) { return 1; }
        return 0;
    }

    /**
     * 붙여넣은 보고서가 끝까지 왔는지 본다.
     *
     * 자동 호출 시절에는 프록시의 이어쓰기가 잘림을 막았다. 복사·붙여넣기에서는
     * **사람이 스크롤 중간에서 복사하거나 전체 선택에 실패해** 같은 결과가 난다.
     * 그래서 이 검사는 이 방식에서 더 중요하다.
     *
     * 저장을 막지는 않는다 — 판단은 사용자 몫이고, 잘린 보고서라도 남겨 둘 이유가 있다.
     */
    function checkReport(md, kind) {
        var text = (md || '').replace(/\r\n/g, '\n').replace(/^﻿/, '');
        var out = { chars: text.length, kind: 0, problems: [], passes: [] };

        if (!text.trim()) { out.problems.push('내용이 비어 있습니다.'); return out; }

        if (text.indexOf(BROKEN_CHAR) >= 0) {
            out.problems.push('깨진 문자가 있습니다 — 인코딩 사고이거나 복사가 어긋났습니다.');
        }

        var k = kind || detectKind(text);
        out.kind = k;
        if (k === 0) {
            out.problems.push('1차/2차 어느 쪽인지 판별되지 않습니다 — 통째로 잘렸을 수 있습니다.');
            return out;
        }

        if (text.indexOf(MOCK_MARK) >= 0) {
            out.problems.push('"모의 응답" 표시가 있습니다 — 실제 분석 결과가 아닙니다.');
        }

        var disclaimer;
        if (k === 1) {
            var missSec = FIRST_SECTIONS.filter(function (s) {
                return !reFind(text, '^#{1,3}\\s*' + s + '\\.');
            });
            if (missSec.length) { out.problems.push('섹션 누락: ' + missSec.join(', ')); }
            else { out.passes.push('A~L 섹션 12개 모두 존재'); }

            var missTail = FIRST_TAIL_HEADS.filter(function (h) { return text.indexOf(h) < 0; });
            if (missTail.length) { out.problems.push('출처 구분 소제목 누락: ' + missTail.join(', ')); }
            else { out.passes.push('출처 구분 소제목 3개 존재'); }

            disclaimer = FIRST_DISCLAIMER;
        } else {
            var missStep = [];
            for (var n = 1; n <= 11; n++) {
                if (!reFind(text, '^#{1,3}\\s*STEP\\s*' + n + '\\b')) { missStep.push('STEP ' + n); }
            }
            if (missStep.length) { out.problems.push('단계 누락: ' + missStep.join(', ')); }
            else { out.passes.push('STEP 1~11 모두 존재'); }

            disclaimer = SECOND_DISCLAIMER;
        }

        /* "있는가" 만으로는 부족하다 — 끝에 있어야 끝까지 나온 것이다. */
        var lines = text.split('\n').filter(function (l) { return l.trim(); });
        var tail = lines.slice(-TAIL_WINDOW);
        if (text.indexOf(disclaimer) < 0) {
            out.problems.push('면책 문장이 없습니다 — 뒤쪽이 잘렸습니다.');
        } else if (!tail.some(function (l) { return l.indexOf(disclaimer) >= 0; })) {
            out.problems.push('면책 문장이 본문 중간에 있습니다 — 뒤쪽이 잘렸습니다.');
        } else {
            out.passes.push('면책 문장이 문서 끝에 있음');
        }

        if (text.length < MIN_CHARS) {
            out.problems.push('본문이 너무 짧습니다 (' + text.length.toLocaleString() +
                              '자) — 정상 보고서는 수천~수만 자입니다.');
        }
        return out;
    }

    /* ---------------------------------------------------------- 마크다운 */

    function esc(s) {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    /** 보고서 표시용 최소 렌더러. 입력은 AI 가 만든 md 이고 신뢰 대상이 아니므로
        먼저 이스케이프한 뒤 우리가 아는 문법만 되살린다 — 원문의 태그는 살아나지 않는다. */
    function mdToHtml(md) {
        var lines = esc((md || '').replace(/\r\n/g, '\n')).split('\n');
        var out = [], inList = false, inCode = false;

        function closeList() { if (inList) { out.push('</ul>'); inList = false; } }

        lines.forEach(function (raw) {
            if (/^```/.test(raw)) {
                closeList();
                out.push(inCode ? '</pre>' : '<pre>');
                inCode = !inCode;
                return;
            }
            if (inCode) { out.push(raw); return; }

            var h = /^(#{1,6})\s+(.*)$/.exec(raw);
            if (h) { closeList(); out.push('<h' + h[1].length + '>' + inline(h[2]) + '</h' + h[1].length + '>'); return; }
            if (/^\s*([-*+]|\d+\.)\s+/.test(raw)) {
                if (!inList) { out.push('<ul>'); inList = true; }
                out.push('<li>' + inline(raw.replace(/^\s*([-*+]|\d+\.)\s+/, '')) + '</li>');
                return;
            }
            if (/^\s*(---|===)\s*$/.test(raw)) { closeList(); out.push('<hr>'); return; }
            if (!raw.trim()) { closeList(); return; }
            closeList();
            out.push('<p>' + inline(raw) + '</p>');
        });
        closeList();
        if (inCode) { out.push('</pre>'); }
        return out.join('\n');
    }

    function inline(s) {
        return s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
                .replace(/`([^`]+)`/g, '<code>$1</code>');
    }

    /* ---------------------------------------------------------- md 저장 */

    function fileName(kase, round) {
        var d = new Date();
        var pad = function (n) { return (n < 10 ? '0' : '') + n; };
        /* 숫자면 "1차", 이미 말이 되는 라벨이면 그대로 — 합본이 "1-2합본차" 가 되지 않게. */
        var part = /^\d+$/.test(String(round)) ? round + '차' : String(round);
        return '진로상담_' + (kase.label || '사례').replace(/[\\/:*?"<>|]/g, '_') +
               '_' + part + '_' +
               d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + '_' +
               pad(d.getHours()) + pad(d.getMinutes()) + '.md';
    }

    function withFrontMatter(kase, round, md) {
        return ['---',
                'case: ' + (kase.label || ''),
                'round: ' + round,
                'saved: ' + new Date().toISOString(),
                'source: newPrjt02 career (복사·붙여넣기)',
                '---', '', md, ''].join('\n');
    }

    function saveBlob(text, name) {
        var blob = new Blob([text], { type: 'text/markdown;charset=utf-8' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    }

    function downloadMd(kase, round, md) {
        saveBlob(withFrontMatter(kase, round, md), fileName(kase, round));
    }

    /** 1·2차 합본. 상담 기록으로 한 파일에 남기려는 용도다. */
    function downloadCombined(kase) {
        var k = getCase(kase.id) || kase;
        if (!k.report1 || !k.report2) {
            throw new Error('합본은 1차와 2차 결과가 모두 있어야 만들 수 있습니다.');
        }
        var body = [
            '# ' + (k.label || '진로상담') + ' — 1·2차 합본', '',
            '## 1차 진로·산업·진학 리서치', '',
            k.report1.md, '', '---', '',
            '## 2차 진로 가설 분석', '',
            k.report2.md, ''
        ].join('\n');
        saveBlob(withFrontMatter(k, '1-2', body), fileName(k, '1-2합본'));
    }

    /* ---------------------------------------------------------- UI 보조 */

    function toast(msg, kind) {
        var el = document.getElementById('toast');
        if (!el) { return; }
        el.textContent = msg;
        el.className = 'toast show' + (kind ? ' ' + kind : '');
        clearTimeout(toast._t);
        toast._t = setTimeout(function () { el.className = 'toast'; }, 3200);
    }

    /** 로그인 가드 + 공통 헤더. 진로상담 화면은 전부 로그인이 필요하다. */
    function mountChrome() {
        if (g.Auth && g.Auth.requireAuth && !g.Auth.requireAuth()) { return false; }
        var who = document.getElementById('whoami');
        if (who) { who.textContent = currentOwner() || '(알 수 없음)'; }
        return true;
    }

    g.Career = {
        /* 프롬프트 */
        loadPrompts: loadPrompts,
        buildPrompt1: buildPrompt1,
        buildPrompt2: buildPrompt2,

        /* 입력 정의 */
        FIELDS_1: FIELDS_1,
        FIELDS_2_EXP: FIELDS_2_EXP,
        FIELDS_2_SCHOOL: FIELDS_2_SCHOOL,
        CHOICES: CHOICES,
        QUICK_1: QUICK_1,
        QUICK_2_EXP: QUICK_2_EXP,
        bindQuickPick: bindQuickPick,
        SAMPLE_1: SAMPLE_1,
        SAMPLE_2: SAMPLE_2,
        entryYearFor: entryYearFor,
        isMiddle: isMiddle,

        /* 복사 */
        copyText: copyText,

        /* AI 화면 선택 */
        AI_SERVICES: AI_SERVICES,
        getAiService: getAiService,
        setAiService: setAiService,
        openAiPopup: openAiPopup,

        /* 저장소 */
        listCases: listCases,
        getCase: getCase,
        createCase: createCase,
        updateCase: updateCase,
        deleteCase: deleteCase,
        saveReport: saveReport,
        currentOwner: currentOwner,

        /* 완결성 검사 — tools/check-report.py 와 같은 기대 형식 */
        checkReport: checkReport,
        detectKind: detectKind,

        /* 출력 */
        mdToHtml: mdToHtml,
        withFrontMatter: withFrontMatter,
        fileName: fileName,
        downloadMd: downloadMd,
        downloadCombined: downloadCombined,

        /* UI */
        toast: toast,
        mountChrome: mountChrome
    };
})(window);
