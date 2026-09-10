import 'package:flutter/material.dart';

class CommunityGuidelinesScreen extends StatefulWidget {
  const CommunityGuidelinesScreen({
    super.key,
    required this.onAccept,
    required this.onAccepted,
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

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _saving || _currentPage == 0) return;
    _pageController.animateToPage(
      _currentPage - 1,
      duration: CommunityGuidelinesScreen.pageTransitionDuration,
      curve: Curves.easeInOut,
    );
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
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) => Row(
                      children: [
                        for (
                          var index = 0;
                          index < CommunityGuidelinesScreen.imageAssets.length;
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
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.28,
                                  ),
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
                Expanded(
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
                          fit: BoxFit.contain,
                        ),
                    ],
                  ),
                ),
                if (_currentPage ==
                    CommunityGuidelinesScreen.imageAssets.length - 1)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    color: const Color(0xFF08065F),
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
                                  : (value) =>
                                        setState(() => _agreed = value == true),
                              fillColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? const Color(0xFF6D28D9)
                                    : Colors.white,
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'I have read the Community Guidelines',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
