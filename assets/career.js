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

    var CHOICES = {
        grade:  GRADES,
        /* 학교급에 따라 성적 표기가 다르다 — 중학교는 성취도, 고등학교는 등급.
           손으로 넣으면 "중2인데 2등급" 같은 모순이 생기고, 프롬프트가 그걸
           [확인 필요]로 되돌려 보낸다. 선택지로 원천 차단한다. */
        scoreMiddle: ['대부분 A', 'A~B', 'B~C', 'C~D', 'D~E', '잘 모름'],
        scoreHigh:   ['1~2등급', '2~3등급', '3~4등급', '4~5등급', '5등급 이하', '잘 모름'],
        univ:   ['상위권 대학', '중상위권 대학', '중위권 대학', '지역 거점 국립대',
                 '전문대학', '아직 정하지 않음'],
        region: ['수도권', '충청권', '호남권', '영남권', '강원권', '제주권',
                 '지역 상관없음', '아직 정하지 않음']
    };

    /* input-2nd.txt 의 경험·학교자료 항목 */
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
        entryYearFor: entryYearFor,
        isMiddle: isMiddle,

        /* 복사 */
        copyText: copyText,

        /* 저장소 */
        listCases: listCases,
        getCase: getCase,
        createCase: createCase,
        updateCase: updateCase,
        deleteCase: deleteCase,
        saveReport: saveReport,
        currentOwner: currentOwner,

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
