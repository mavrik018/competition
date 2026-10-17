"""Prints the toolkit's internal import graph: for every library file, the
toolkit files it pulls in (transitively) and the packages it needs.

Run from the repo root:  python tool/module_graph.py [--markdown]
Fails (exit 1) if there is an import cycle between files.
"""
import os
import re
import sys

LIB = 'lib'
IMPORT = re.compile(r"^import\s+'([^']+)'", re.M)


def files():
    for root, _, names in os.walk(LIB):
        for n in names:
            if n.endswith('.dart'):
                yield os.path.normpath(os.path.join(root, n)).replace('\\', '/')


def parse(path):
    text = open(path, encoding='utf-8').read()
    internal, packages = set(), set()
    for target in IMPORT.findall(text):
        if target.startswith('package:competition_toolkit/'):
            internal.add('lib/' + target.split('/', 1)[1])
        elif target.startswith('package:'):
            pkg = target[len('package:'):].split('/')[0]
            if pkg not in ('flutter', 'flutter_test'):
                packages.add(pkg)
        elif not target.startswith('dart:'):
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            internal.add(resolved.replace('\\', '/'))
    return internal, packages


graph = {f: parse(f) for f in sorted(files())}


def closure(start):
    seen, stack = set(), [start]
    while stack:
        node = stack.pop()
        for dep in graph[node][0]:
            if dep not in seen:
                seen.add(dep)
                stack.append(dep)
    return seen


# Cycle check (DFS colouring).
WHITE, GREY, BLACK = 0, 1, 2
colour = {f: WHITE for f in graph}
cycles = []


def visit(node, trail):
    colour[node] = GREY
    for dep in graph[node][0]:
        if colour[dep] == GREY:
            cycles.append(trail + [node, dep])
        elif colour[dep] == WHITE:
            visit(dep, trail + [node])
    colour[node] = BLACK


for f in graph:
    if colour[f] == WHITE:
        visit(f, [])

markdown = '--markdown' in sys.argv
if markdown:
    print('| File | Toolkit files needed (transitive) | Packages (transitive) |')
    print('|---|---|---|')
for f, (internal, packages) in graph.items():
    deps = closure(f)
    pkgs = set(packages)
    for d in deps:
        pkgs |= graph[d][1]
    short = f[len('lib/'):]
    if markdown:
        need = ', '.join(sorted(d[len('lib/'):] for d in deps)) or '—'
        print(f'| `{short}` | {len(deps)}: {need} | {", ".join(sorted(pkgs)) or "—"} |')
    else:
        print(f'{short}: {len(deps)} toolkit files, packages={sorted(pkgs)}')

if cycles:
    print('\nIMPORT CYCLES:', file=sys.stderr)
    for c in cycles:
        print('  ' + ' -> '.join(c), file=sys.stderr)
    sys.exit(1)
print(f'\n{len(graph)} files, no import cycles.', file=sys.stderr)
