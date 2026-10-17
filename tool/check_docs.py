"""Checks that the documentation matches the code.

  python tool/check_docs.py

1. Every local path or Markdown link in the docs exists.
2. Every `PascalCase` type and every `functionName(` mentioned in backticks
   is declared in the toolkit (lib/, example/, templates/, tool/, supabase/)
   or is a known Flutter / Dart / package name (EXTERNAL below).

Exit code 1 lists every mismatch, so a renamed class cannot silently leave
stale docs behind.
"""
import glob
import os
import re
import sys

DOCS = sorted(
    set(glob.glob('*.md'))
    | set(glob.glob('lib/*/README.md'))
    | {'example/README.md'}
)
CODE_GLOBS = ['lib/**/*.dart', 'example/lib/**/*.dart', 'templates/**/*.dart',
              'tool/*.dart', 'supabase/functions/**/*.ts', 'test/**/*.dart',
              'example/test/**/*.dart']

# Names that come from Flutter, Dart, platforms or third-party packages.
EXTERNAL = set('''
AboutDialog ActionChip AlertDialog AnimatedOpacity AnimatedScale AppBar
AppLifecycleListener AsyncError AsyncData AsyncLoading AsyncNotifier
AsyncNotifierProvider AsyncValue BuildContext BottomSheet Card Checkbox
CheckboxListTile Chip ChangeNotifier ChoiceChip CircularProgressIndicator
Color ColorScheme Column Completer ConstrainedBox Container CustomPainter
DateTime DeviceMediaPicker DropdownButtonFormField Duration Expanded
FilledButton FilterChip Flexible FloatingActionButton FocusNode Form
FormField Future FutureBuilder FutureOr GestureDetector GoRouter GoRoute
Icon IconButton IconData Icons Image IndexedStack InheritedModel
InheritedNotifier InheritedWidget InkResponse InkWell InputChip Isolate
LayoutBuilder LinearProgressIndicator List ListTile ListView
ListenableBuilder Listenable Map MaterialApp MaterialPageRoute MediaQuery
ModalRoute NavigationBar NavigationRail Navigator Notifier NotifierProvider
Object Offset Padding PageTransitionsTheme Positioned Provider
ProviderContainer ProviderScope RefreshIndicator RenderFlex RepaintBoundary
Row Scaffold ScaffoldMessengerState ScrollBehavior SegmentedButton Semantics
SemanticsService Set ShellRoute SizedBox SliverList Slider SnackBar
SnackBarAction Stack StatefulShellRoute StatefulWidget StatelessWidget State
Stream StreamBuilder StreamController StreamProvider String Switch
SwitchListTile Text TextButton TextEditingController TextField
TextFormField TextScaler Theme ThemeData ThemeMode Timer Uint8List Uri
ValueKey ValueNotifier ValueListenableBuilder View Widget WidgetRef Wrap
Override ConsumerWidget ConsumerStatefulWidget Consumer Ref FlutterView
OutlinedButton Directionality DefaultTabController TabBar
SharedPreferences SharedPreferencesAsync SharedPreferencesWithCache
SupabaseClient Supabase RealtimeChannel FunctionException
PostgrestException AuthException SpeechToText SpeechListenOptions
XFile ShareParams SharePlus MobileScanner PrettyQrView TextRecognizer
Purchases PurchasesConfiguration Geolocator Database DatabaseExecutor
MockClient FakeAsync StateNotifier StateProvider Bloc Cubit BlocProvider
BlocBuilder ConflictAlgorithm JavaVersion AnnounceSemanticsEvent
Assertiveness TextInputAction TextInputType AutofillHints
FlutterLocalNotificationsPlugin DateTimeComponents ScrollController
KeyboardListener TweenAnimationBuilder AnimationController Tween
Duration DOMException Response Request Deno RegExp Random
Exception Error StateError FormatException ArgumentError TypeError
UnimplementedError MissingPluginException Brightness
Hive Box Isar Drift SqfliteRepository_Example Riverpod Flutter
TabBarView PageView PageController Hero Opacity ClipRRect Align Center
GlobalKey Key UniqueKey ObjectKey RichText TextSpan TextStyle
DecoratedBox BoxDecoration InputDecoration InputDecorator Divider
VerticalDivider Spacer SafeArea SingleChildScrollView CustomScrollView
SliverAppBar Tooltip PopupMenuButton DropdownMenuItem DropdownButton
CupertinoIcons Firestore FirebaseFirestore AppCheck Keychain Keystore
WidgetTester Finder EdgeInsets Alignment Radius BorderRadius Curves
Size Rect Canvas Paint Path PictureRecorder TextPainter
TextTheme FittedBox Material NavigatorObserver CustomPaint FadeTransition
IgnorePointer LinearGradient Matrix4 SelectionArea ShaderMask
SizeTransition ScaffoldMessenger CupertinoAlertDialog DateFormat
TapGestureRecognizer HeroMode TimeoutException AuthRetryableFetchException
CustomerInfo InMemorySharedPreferencesAsync SharedPreferencesAsyncPlatform
'''.split())

# Names of the four source apps' classes, or names the toolkit replaced —
# mentioned on purpose as history ("renamed from Badge").
HISTORICAL = set('''
Badge Matcher AuthController AuthNotifier SubscriptionNotifier AISnackBar
AppFeedback CooklyChip CooklyPrimaryButton CooklySearchField ErrorMapper
Failure IosCalendarGrid IosPrimaryButton KeyedProviderScope
RouterRefreshNotifier SMButton ThemeModeNotifier AuthAction Quiz
'''.split())

EXTERNAL_FUNCS = set('''
coreLibraryDesugaring
setState build dispose initState runApp main print debugPrint jsonEncode
jsonDecode showDialog showModalBottomSheet pumpWidget pumpAndSettle pump
tap expect find enterText ensureSemantics meetsGuideline select watch read
listen invalidate onDispose push pop pushNamed go context mounted
openDatabase getInstance setMockInitialValues signIn signUp signOut from
select upsert stream channel subscribe track onBroadcast
sendBroadcastMessage invoke fetch serve handle compute run sort map where
toList toSet fold reduce join split replaceAll toString hashCode
copyWith fromJson toJson parse tryParse now add remove clear contains
overrideWithValue overrideWith notifier state isLoading hasError
unawaited ensureVisible pageBack scrollUntilVisible getSize
setMockDecodedMessageHandler of maybeOf sizeOf textScalerOf
disableAnimationsOf boldTextOf highContrastOf Isolate.run toPlainText
'''.split())

PATH_RE = re.compile(r'`((?:lib|test|example|supabase|tool|templates)/[^`*\s]+?)`')
LINK_RE = re.compile(r'\]\((?!https?://|#|mailto:)([^)\s]+)\)')
TYPE_RE = re.compile(r'`([A-Z][A-Za-z0-9]+)(?:<[^`]*>)?`|`([A-Z][A-Za-z0-9]+)[.(]')
FUNC_RE = re.compile(r'`([a-z][A-Za-z0-9]+)\(')


def declared_names():
    names = set()
    decl = re.compile(
        r'(?:class|enum|mixin|typedef|extension(?:\s+type)?|interface|'
        r'sealed class|abstract (?:interface |final )?class|base class)\s+([A-Za-z_][A-Za-z0-9_]*)')
    func = re.compile(
        r'^\s*(?:static\s+|external\s+|factory\s+)?(?:[A-Za-z_<>?, \[\]]+\s+)?'
        r'([a-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s*\(', re.M)
    named_ctor = re.compile(r'\b([A-Z][A-Za-z0-9]*)\.([a-z][A-Za-z0-9]*)\s*\(')
    getter = re.compile(r'\bget\s+([a-z][A-Za-z0-9]*)')
    ts_func = re.compile(r'(?:function|const|let)\s+([A-Za-z_][A-Za-z0-9_]*)')
    enum_values = re.compile(r'enum\s+\w+\s*\{([^}]*)\}', re.S)
    field = re.compile(r'\bfinal\s+[^;=]*?\b([a-z][A-Za-z0-9]*)\s*;')
    called = re.compile(r'\b([a-z][A-Za-z0-9]*)\s*(?:<[^()]*>)?\s*\(')
    for pattern in CODE_GLOBS:
        for path in glob.glob(pattern, recursive=True):
            raw = open(path, encoding='utf-8').read()
            text = re.sub(r'//.*', '', raw)  # comments mention old names
            names |= set(field.findall(text))
            names |= set(called.findall(text))
            names |= set(decl.findall(text))
            names |= set(func.findall(text))
            names |= set(getter.findall(text))
            names |= set(ts_func.findall(text))
            for cls, ctor in named_ctor.findall(text):
                names.add(ctor)
            for body in enum_values.findall(text):
                names |= set(re.findall(r'\b([a-z][A-Za-z0-9]*)\b', body))
    return names


def main():
    names = declared_names()
    problems = []
    for doc in DOCS:
        text = open(doc, encoding='utf-8').read()
        base = os.path.dirname(doc)
        # Skip fenced code blocks for identifier checks (they contain user
        # code like Task / Note models), but keep them for paths.
        prose = re.sub(r'```.*?```', '', text, flags=re.S)
        # Catalog headings end with a category badge in backticks, not code.
        prose = re.sub(r'^### .*$', '', prose, flags=re.M)
        for target in PATH_RE.findall(text):
            clean = target.split(':')[0].rstrip('.,);')
            if any(c in clean for c in '*{}<>…'):
                continue
            # Folders that exist in apps made by tool/create_app.dart.
            if clean.startswith(('lib/features', 'lib/toolkit', 'test/toolkit')):
                continue
            if not (os.path.exists(clean)
                    or os.path.exists(os.path.join(base, clean))):
                problems.append(f'{doc}: missing path `{clean}`')
        for link in LINK_RE.findall(text):
            clean = link.split('#')[0].split(':')[0]
            if not clean:
                continue
            resolved = os.path.normpath(os.path.join(base, clean))
            if not os.path.exists(resolved):
                problems.append(f'{doc}: broken link ({link})')
        for a, b in TYPE_RE.findall(prose):
            name = a or b
            if (name in names or name in EXTERNAL or name in HISTORICAL
                    or name.isupper() or name.startswith('NS')):
                continue
            problems.append(f'{doc}: unknown type `{name}`')
        for name in FUNC_RE.findall(prose):
            if name in names or name in EXTERNAL_FUNCS:
                continue
            problems.append(f'{doc}: unknown function `{name}(`')
    unique = sorted(set(problems))
    for p in unique:
        print(p)
    print(f'\n{len(DOCS)} documents checked, {len(unique)} problem(s).',
          file=sys.stderr)
    sys.exit(1 if unique else 0)


if __name__ == '__main__':
    main()
