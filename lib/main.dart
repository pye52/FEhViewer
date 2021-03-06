import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/models/states/advance_search_model.dart';
import 'package:FEhViewer/models/states/dnsconfig_model.dart';
import 'package:FEhViewer/models/states/ehconfig_model.dart';
import 'package:FEhViewer/models/states/history_model.dart';
import 'package:FEhViewer/models/states/local_favorite_model.dart';
import 'package:FEhViewer/models/states/locale_model.dart';
import 'package:FEhViewer/models/states/search_text_model.dart';
import 'package:FEhViewer/models/states/theme_model.dart';
import 'package:FEhViewer/models/states/user_model.dart';
import 'package:FEhViewer/pages/splash_page.dart';
import 'package:FEhViewer/route/application.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';

import 'generated/l10n.dart';

void main() {
  Global.init().then((_) {
    runApp(
      DevicePreview(
        // enabled: Global.inDebugMode,
        enabled: false,
        builder: (context) => MyApp(), // Wrap your app
      ),
    );
  }).catchError((e) {
    print('catchError $e');
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Brightness _brightness = WidgetsBinding.instance.window.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _brightness = WidgetsBinding.instance.window.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget cupertinoApp = Consumer2<LocaleModel, ThemeModel>(builder:
        (BuildContext context, LocaleModel localeModel, ThemeModel themeModel,
            Widget child) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (BuildContext context) => S.of(context).app_title,
        onGenerateRoute: Application.router.generator,
        theme: themeModel.getTheme(context, _brightness),
        // theme: ThemeColors.darkTheme,
        home: const SplashPage(),
        locale: Global.inDebugMode
            ? DevicePreview.locale(context)
            : localeModel.getLocale(),
        builder: DevicePreview.appBuilder,
        supportedLocales: <Locale>[
          const Locale('en', ''),
          ...S.delegate.supportedLocales
        ],
        // ignore: prefer_const_literals_to_create_immutables
        localizationsDelegates: [
          // 本地化的代理类
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        localeResolutionCallback:
            (Locale _locale, Iterable<Locale> supportedLocales) {
          Global.logger.v(
              '${_locale?.languageCode}  ${_locale?.scriptCode}  ${_locale?.countryCode}');
          if (localeModel.getLocale() != null) {
            //如果已经选定语言，则不跟随系统
            return localeModel.getLocale();
          } else {
            Locale locale;
            //APP语言跟随系统语言，如果系统语言不是中文简体或美国英语，
            //则默认使用美国英语
            if (supportedLocales.contains(_locale)) {
              locale = _locale;
            } else {
              locale = const Locale('en', 'US');
            }

            // 中文 简繁体处理
            if (_locale?.languageCode == 'zh') {
              if (_locale?.scriptCode == 'Hant') {
                locale = const Locale('zh', 'HK'); //繁体
              } else {
                locale = const Locale('zh', 'CN'); //简体
              }
            }
            return locale;
          }
        },
      );
    });

    final MultiProvider multiProvider = MultiProvider(
      // ignore: always_specify_types
      providers: [
        ChangeNotifierProvider<UserModel>.value(value: UserModel()),
        ChangeNotifierProvider<LocaleModel>.value(value: LocaleModel()),
        ChangeNotifierProvider<ThemeModel>.value(value: ThemeModel()),
        ChangeNotifierProvider<EhConfigModel>.value(value: EhConfigModel()),
        // 快速搜索词
        ChangeNotifierProvider<SearchTextModel>.value(value: SearchTextModel()),
        // LocalFavModel 本地收藏
        ChangeNotifierProvider<LocalFavModel>.value(value: LocalFavModel()),
        // HistoryModel 历史记录
        ChangeNotifierProvider<HistoryModel>.value(value: HistoryModel()),
        // AdvanceSearchModel
        ChangeNotifierProvider<AdvanceSearchModel>.value(
            value: AdvanceSearchModel()),
        // DnsConfigModel
        ChangeNotifierProvider<DnsConfigModel>.value(value: DnsConfigModel()),
      ],
      child: OKToast(child: cupertinoApp),
    );

    return multiProvider;
  }
}
