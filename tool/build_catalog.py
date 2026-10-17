"""Builds CATALOG.md from tool/catalog/*.txt and verifies it against the code.

  python tool/build_catalog.py           # write CATALOG.md
  python tool/build_catalog.py --check   # verify only (exit 1 on problems)

Each component is one block in tool/catalog/NN_*.txt:

    ### 111 | Smart Priority Scoring | Algorithm module
    src: lib/13_smart_features/priority_scoring.dart
    symbol: scorePriority
    desc: Ranks items by urgency, importance, effort and age.
    use: Task managers, ticketing, appointments, incident reports
    in: PriorityInput(due, importance 1–5, effortHours, createdAt), PriorityRules
    out: PriorityScore(score 0–100, band, reasons); rankByPriority → sorted list
    deps: Pure Dart
    integ: Map your model → PriorityInput → scorePriority / rankByPriority → show band + reasons
    cx: Low
    defend: Weighted sum of normalised factors, ...
    tests: test/13_smart_features/rules_and_scoring_test.dart :: group:priority scoring
    status: full
    edge: Overdue + importance ≥ 4 is always critical; ...
    limits: Importance is self-reported; ...
    example:
    final p = scorePriority(PriorityInput(due: due, importance: 4), now: DateTime.now());
    ---

`tests:` takes `file :: selector` items separated by ` ; `. Selectors:
`group:Name` (tests inside that group), `name:text` (test descriptions
containing text, case-insensitive), `all` (whole file). The generator
counts the tests itself, checks every file exists, that the first `symbol`
or another symbol is in each source, and each test file mentions one
(comma-separated: the class plus the tested helpers).
`status:` is one of full | partial | external | partial+external, with an
optional `| note`.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

STATUS = {
    'full': '✅ Fully tested',
    'partial': '🟡 Partially tested',
    'external': '🔌 Requires external configuration',
    'partial+external': '🟡🔌 Partially tested · requires external configuration',
}


# ── Test file parsing ────────────────────────────────────────────────────────

def _matching_paren(text, open_index):
    depth, i, n = 0, open_index, len(text)
    quote = None
    while i < n:
        c = text[i]
        if quote:
            if c == '\\':
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in '\'"':
            quote = c
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n


_TEST = re.compile(r'\b(test|testWidgets)\(\s*(?:\'((?:[^\'\\]|\\.)*)\'|"((?:[^"\\]|\\.)*)")', re.S)
_GROUP = re.compile(r'\bgroup\(\s*\'((?:[^\'\\]|\\.)*)\'', re.S)
_cache = {}


def parse_tests(path):
    """[(description, [enclosing group names])] for one test file."""
    if path in _cache:
        return _cache[path]
    text = open(path, encoding='utf-8').read()
    groups = []
    for m in _GROUP.finditer(text):
        open_paren = text.index('(', m.start())
        groups.append((m.group(1), m.start(), _matching_paren(text, open_paren)))
    tests = []
    for m in _TEST.finditer(text):
        name = m.group(2) if m.group(2) is not None else m.group(3)
        enclosing = [g for g, s, e in groups if s < m.start() < e]
        tests.append((name, enclosing))
    _cache[path] = tests
    return tests


def count_tests(spec, problems, where):
    total = 0
    files = []
    for item in [s.strip() for s in spec.split(' ; ') if s.strip()]:
        path, _, selector = [p.strip() for p in item.partition('::')]
        selector = selector or 'all'
        if not os.path.exists(path):
            problems.append(f'{where}: test file missing: {path}')
            continue
        tests = parse_tests(path)
        if selector == 'all':
            n = len(tests)
        elif selector.startswith('group:'):
            g = selector[len('group:'):]
            n = sum(1 for _, gs in tests if g in gs)
        elif selector.startswith('name:'):
            needle = selector[len('name:'):].lower()
            n = sum(1 for t, _ in tests if needle in t.lower())
        else:
            problems.append(f'{where}: bad selector {selector!r}')
            continue
        if n == 0:
            problems.append(f'{where}: selector {selector!r} matches no test in {path}')
        total += n
        files.append(path)
    return total, files


# ── Catalog data ─────────────────────────────────────────────────────────────

def parse_blocks():
    entries = []
    for path in sorted(glob.glob('tool/catalog/*.txt')):
        text = open(path, encoding='utf-8').read()
        for raw in re.split(r'^---\s*$', text, flags=re.M):
            raw = raw.strip('\n')
            if not raw.strip():
                continue
            lines = raw.split('\n')
            head = lines[0]
            m = re.match(r'^###\s+(\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*$', head)
            if not m:
                raise SystemExit(f'{path}: bad header {head!r}')
            entry = {'n': int(m.group(1)), 'name': m.group(2), 'badge': m.group(3),
                     'file': path}
            example = []
            in_example = False
            for line in lines[1:]:
                if in_example:
                    example.append(line)
                    continue
                if line.strip() == 'example:':
                    in_example = True
                    continue
                if not line.strip():
                    continue
                key, _, value = line.partition(':')
                entry[key.strip()] = value.strip()
            entry['example'] = '\n'.join(example).strip('\n')
            entries.append(entry)
    return sorted(entries, key=lambda e: e['n'])


REQUIRED = ['src', 'symbol', 'desc', 'use', 'in', 'out', 'deps', 'integ', 'cx',
            'defend', 'tests', 'status', 'edge', 'limits']


def build(check_only):
    entries = parse_blocks()
    problems = []
    seen = set()
    for e in entries:
        where = f"#{e['n']} {e['name']}"
        if e['n'] in seen:
            problems.append(f'{where}: duplicate number')
        seen.add(e['n'])
        for key in REQUIRED:
            if not e.get(key):
                problems.append(f'{where}: missing {key}')
        if not e.get('example'):
            problems.append(f'{where}: missing example')
        symbols = [x.strip() for x in e.get('symbol', '').split(',') if x.strip()]
        for src in [s.strip() for s in e.get('src', '').split(',') if s.strip()]:
            if not os.path.exists(src):
                problems.append(f'{where}: source missing: {src}')
            elif symbols and not any(x in open(src, encoding='utf-8').read() for x in symbols):
                problems.append(f"{where}: none of {symbols} found in {src}")
        status = e.get('status', '').split('|')[0].strip()
        if status not in STATUS:
            problems.append(f'{where}: unknown status {status!r}')
        tests = e.get('tests', '')
        if tests.strip() == 'none':
            e['count'], e['test_files'] = 0, []
        else:
            e['count'], e['test_files'] = count_tests(tests, problems, where)
            for f in e['test_files']:
                body = open(f, encoding='utf-8').read()
                if symbols and not any(x in body for x in symbols):
                    problems.append(f"{where}: test file {f} mentions none of {symbols}")
    if problems:
        print('\n'.join(problems))
        print(f'\n{len(problems)} problem(s) in {len(entries)} entries.', file=sys.stderr)
        sys.exit(1)
    if check_only:
        print(f'{len(entries)} entries verified.', file=sys.stderr)
        return
    open('CATALOG.md', 'w', encoding='utf-8').write(render(entries))
    print(f'CATALOG.md written: {len(entries)} components.', file=sys.stderr)


# ── Rendering ────────────────────────────────────────────────────────────────

SECTIONS = [
    (1, '01 · Design system'), (6, '02 · UI elements'), (20, '03 · Feedback'),
    (26, '04 · Dialogs and sheets'), (28, '05 · Forms'), (36, '06 · Screen templates'),
    (39, '07 · Navigation'), (45, '08 · State management'), (49, '09 · Persistence'),
    (53, '10 · Backend'), (61, '11 · Utilities'), (71, '12 · Common features'),
    (75, '02 · UI elements (phase 2)'), (80, '03 / 04 · Feedback and sheets (phase 2)'),
    (82, '05 · Forms (phase 2)'), (85, '06 · Screen templates (phase 2)'),
    (94, '07 / 08 / 09 · Navigation, state, persistence (phase 2)'),
    (98, '10 · Backend (phase 2)'), (100, '12 · Device features (phase 2)'),
    (108, '13 · Smart features — rule-based, offline'), (126, '14 · AI'),
    (129, '09 · Persistence (verification round)'),
]


def anchor(e):
    return f"c{e['n']}"


def status_cell(e):
    status, _, note = e['status'].partition('|')
    label = STATUS[status.strip()]
    return label + (f' — {note.strip()}' if note.strip() else '')


def tests_cell(e):
    if not e['test_files']:
        return 'No automated tests'
    files = ', '.join(f'[`{os.path.basename(f)}`]({f})' for f in e['test_files'])
    return f"{e['count']} automated test{'s' if e['count'] != 1 else ''} · {files}"


def render(entries):
    out = []
    totals = {}
    for e in entries:
        key = e['status'].split('|')[0].strip()
        totals[key] = totals.get(key, 0) + 1
    out.append('# Component catalog\n')
    out.append(
        f'{len(entries)} components. Every card below follows the same format and is '
        'generated by `tool/build_catalog.py` from `tool/catalog/*.txt`, which also '
        '**verifies** it: each source file exists and defines the component, each test '
        'file exists and exercises it, and the test counts are counted from the test '
        'files themselves (not typed by hand). Run `python tool/build_catalog.py --check` '
        'after changing code.\n')
    out.append('**Status legend**\n')
    out.append('| Status | Meaning | Components |')
    out.append('|---|---|---|')
    meaning = {
        'full': 'All of its logic is exercised by passing automated tests; no external setup.',
        'partial': 'Logic is tested; some paths need a device, plugin or OS feature that `flutter test` cannot run (listed on the card).',
        'external': 'Needs a backend project, keys or store setup before it does anything real (listed on the card).',
        'partial+external': 'Both of the above.',
    }
    for key in ['full', 'partial', 'external', 'partial+external']:
        out.append(f'| {STATUS[key]} | {meaning[key]} | {totals.get(key, 0)} |')
    out.append('\nSource apps: **SM** StudyBuddies · **KA** Cookly · **CP** Couple · **TD** TaskFlow · **NEW** written for the toolkit. Complexity is integration effort in a competition: Low (< 15 min), Medium (15–45 min), High (> 45 min or external setup).\n')

    out.append('## Index\n')
    out.append('| # | Component | Type | Complexity | Status | Tests |')
    out.append('|---|---|---|---|---|---|')
    for e in entries:
        st = STATUS[e['status'].split('|')[0].strip()].split(' ')[0]
        out.append(f"| {e['n']} | [{e['name']}](#{anchor(e)}) | {e['badge']} | {e['cx']} | {st} | {e['count']} |")
    out.append('')

    section_starts = dict(SECTIONS)
    for e in entries:
        if e['n'] in section_starts:
            out.append(f"\n## {section_starts[e['n']]}\n")
        out.append(f"<a id=\"{anchor(e)}\"></a>")
        out.append(f"### {e['n']}. {e['name']} `{e['badge']}`\n")
        out.append(f"{e['desc']}\n")
        out.append('| | |')
        out.append('|---|---|')
        rows = [
            ('Use when', e['use']), ('Inputs', e['in']), ('Output', e['out']),
            ('Dependencies', e['deps']), ('Integration', e['integ']),
            ('Complexity', e['cx']), ('Interview defense', e['defend']),
            ('Source', ', '.join(f'[`{s.strip()}`]({s.strip()})' for s in e['src'].split(','))),
            ('Unit tests', tests_cell(e)), ('Status', status_cell(e)),
            ('Edge cases', e['edge']), ('Known limitations', e['limits']),
        ]
        if e.get('origin'):
            rows.insert(3, ('Origin', e['origin']))
        for label, value in rows:
            out.append(f"| **{label}** | {value.replace('|', '¦')} |")
        out.append('\n**Working example**\n')
        out.append('```dart')
        out.append(e['example'])
        out.append('```\n')
    out.append(open('tool/catalog/_footer.md', encoding='utf-8').read()
               if os.path.exists('tool/catalog/_footer.md') else '')
    return '\n'.join(out)


if __name__ == '__main__':
    build('--check' in sys.argv)
