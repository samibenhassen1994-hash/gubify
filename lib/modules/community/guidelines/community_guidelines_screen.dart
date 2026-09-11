import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef CommunityGuidelinesLauncher = Future<bool> Function(Uri uri);

class CommunityGuidelinesScreen extends StatefulWidget {
  const CommunityGuidelinesScreen({
    super.key,
    required this.onAccept,
    required this.onAccepted,
    this.launchGuidelines,
  });

  static const Duration autoAdvanceDuration = Duration(seconds: 10);
  static const Duration pageTransitionDuration = Duration(milliseconds: 350);
  static const List<String> imageAssets = <String>[
    'assets/images/onboarding/community/community_01.png',
    'assets/images/onboarding/community/community_02.png',
    'assets/images/onboarding/community/community_03.png',
    'assets/images/onboarding/community/community_04.png',
    'assets/images/onboarding/community/community_05.png',
  ];

  final Future<void> Function() onAccept;
  final VoidCallback onAccepted;
  final CommunityGuidelinesLauncher? launchGuidelines;

  static final Uri guidelinesUri = Uri.parse('https://gubify.com/guidelines');

  @override
  State<CommunityGuidelinesScreen> createState() =>
      _CommunityGuidelinesScreenState();
}

class _CommunityGuidelinesScreenState extends State<CommunityGuidelinesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late final AnimationController _progressController;
  int _currentPage = 0;
  bool _agreed = false;
  bool _saving = false;
  bool _appIsActive = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: CommunityGuidelinesScreen.autoAdvanceDuration,
    )..addStatusListener(_handleProgressStatus);
    _startProgress();
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _currentPage >= CommunityGuidelinesScreen.imageAssets.length - 1 ||
        _saving) {
      return;
    }
    _pageController.animateToPage(
      _currentPage + 1,
      duration: CommunityGuidelinesScreen.pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  void _startProgress() {
    if (_currentPage >= CommunityGuidelinesScreen.imageAssets.length - 1 ||
        !_appIsActive ||
        _saving) {
      _progressController.stop(canceled: false);
      return;
    }
    _progressController.forward();
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
      _error = null;
    });
    _progressController
      ..stop()
      ..reset();
    _startProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    _appIsActive = isActive;
    if (isActive) {
      _startProgress();
    } else {
      _progressController.stop(canceled: false);
    }
  }

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    _progressController.stop(canceled: false);
    try {
      await widget.onAccept();
      if (!mounted) return;
      widget.onAccepted();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save your acceptance. Please try again.';
      });
    }
  }

  Future<void> _openGuidelines() async {
    final launcher =
        widget.launchGuidelines ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    try {
      final opened = await launcher(CommunityGuidelinesScreen.guidelinesUri);
      if (!opened && mounted) {
        setState(() => _error = 'Unable to open Community Guidelines.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to open Community Guidelines.');
      }
    }
  }

  void _goBack() {
    if (_saving) return;
    if (_currentPage == 0) {
      Navigator.maybePop(context);
      return;
    }
    _pageController.animateToPage(
      _currentPage - 1,
      duration: CommunityGuidelinesScreen.pageTransitionDuration,
      curve: Curves.easeInOut,
    );
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _saving || _currentPage == 0) return;
    _goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressController
      ..removeStatusListener(_handleProgressStatus)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_saving && _currentPage == 0,
      onPopInvokedWithResult: _handleBack,
      child: ColoredBox(
        color: const Color(0xFF08065F),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SizedBox.expand(
                key: const Key('community-guidelines-artwork-viewport'),
                child: PageView(
                  key: const Key('community-guidelines-pages'),
                  controller: _pageController,
                  physics: _saving
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _handlePageChanged,
                  children: [
                    for (
                      var index = 0;
                      index < CommunityGuidelinesScreen.imageAssets.length;
                      index++
                    )
                      Image.asset(
                        CommunityGuidelinesScreen.imageAssets[index],
                        key: Key('community-guidelines-page-$index'),
                        fit: BoxFit.cover,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) => Row(
                            children: [
                              for (
                                var index = 0;
                                index <
                                    CommunityGuidelinesScreen
                                        .imageAssets
                                        .length;
                                index++
                              )
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          index ==
                                              CommunityGuidelinesScreen
                                                      .imageAssets
                                                      .length -
                                                  1
                                          ? 0
                                          : 5,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        key: Key(
                                          'community-guidelines-progress-$index',
                                        ),
                                        minHeight: 4,
                                        value: index < _currentPage
                                            ? 1
                                            : index == _currentPage
                                            ? (_currentPage ==
                                                      CommunityGuidelinesScreen
                                                              .imageAssets
                                                              .length -
                                                          1
                                                  ? 1
                                                  : _progressController.value)
                                            : 0,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.28),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: const CircleBorder(),
                            child: IconButton(
                              key: const Key('community-guidelines-back'),
                              tooltip: 'Back',
                              onPressed: _saving ? null : _goBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: Colors.white,
                              disabledColor: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentPage ==
                  CommunityGuidelinesScreen.imageAssets.length - 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      key: const Key('community-guidelines-acceptance-overlay'),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      color: const Color(0xE608065F),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                key: const Key('community-guidelines-checkbox'),
                                value: _agreed,
                                onChanged: _saving
                                    ? null
                                    : (value) => setState(
                                        () => _agreed = value == true,
                                      ),
                                fillColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                      ? const Color(0xFF6D28D9)
                                      : Colors.white,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'I have read the ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    InkWell(
                                      key: const Key(
                                        'community-guidelines-official-link',
                                      ),
                                      onTap: _saving ? null : _openGuidelines,
                                      child: const Text(
                                        'Community Guidelines',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 24,
                            child: _error == null
                                ? null
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFFB4AB),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: !_agreed || _saving ? null : _accept,
                              child: _saving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('I understand and continue'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
