void dispatchCorpusReadyImpl() {}

Future<bool> ensureCropperJsLoadedImpl() async => true;

String? getWebPathnameImpl() => null;

String? getWebSearchImpl() => null;

String? getWebHashImpl() => null;

void setWebHistoryStateImpl(String url, {required bool replace, String? jsonState}) {}

Stream<Object?> webPopStateRawStreamImpl() => const Stream.empty();

void goBackInBrowserHistoryImpl() {}

bool clickExternalAnchorImpl(String safeUrl) => false;

Stream<Map<String, dynamic>> webNotificationClickStreamImpl() =>
    const Stream.empty();
