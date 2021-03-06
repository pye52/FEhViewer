import 'dart:io';

import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/models/user.dart';
import 'package:FEhViewer/utils/dio_util.dart';
import 'package:FEhViewer/utils/utility.dart';
import 'package:FEhViewer/values/const.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

class EhUserManager {
  factory EhUserManager() => _instance;

  EhUserManager._();

  static final EhUserManager _instance = EhUserManager._();

  Future<User> signIn(String username, String passwd) async {
    final HttpManager httpManager =
        HttpManager.getInstance('https://forums.e-hentai.org');
    const String url = '/index.php?act=Login&CODE=01';
    const String referer =
        'https://forums.e-hentai.org/index.php?act=Login&CODE=00';
    const String origin = 'https://forums.e-hentai.org';

    final FormData formData = FormData.fromMap({
      'UserName': username,
      'PassWord': passwd,
      'submit': 'Log me in',
      'temporary_https': 'off',
      'CookieDate': '1',
    });

    final Options options =
        Options(headers: {'Referer': referer, 'Origin': origin});

    Response rult;
    try {
      rult = await httpManager.postForm(url, data: formData, options: options);
    } catch (e) {
      Global.logger.v('$e');
    }

    //  登录异常处理
    final List<String> setcookie = rult.headers['set-cookie'];
    final cookieMap = _parseSetCookieString(setcookie);

    if (cookieMap['ipb_member_id'] == null) {
      throw Exception('login Fail');
    }

    final List<Cookie> cookies = [
      Cookie('ipb_member_id', cookieMap['ipb_member_id']),
      Cookie('ipb_pass_hash', cookieMap['ipb_pass_hash']),
      Cookie('nw', '1'),
    ];

    final PersistCookieJar cookieJar = await Api.cookieJar;

    // 设置EX的cookie
    cookieJar.saveFromResponse(Uri.parse(EHConst.EX_BASE_URL), cookies);

    await _getExIgneous();

    //获取Ex cookies
    final List<Cookie> cookiesEx =
        cookieJar.loadForRequest(Uri.parse(EHConst.EX_BASE_URL));

    Global.logger.v('$cookiesEx');

    // 处理cookie 存入sp 方便里站图片请求时构建头 否则会403
    final Map<String, String> cookieMapEx = <String, String>{};
    cookiesEx.forEach((Cookie cookie) {
      cookieMapEx.putIfAbsent(cookie.name, () => cookie.value);
    });

    final Map<String, String> cookie = <String, String>{
      'ipb_member_id': cookieMapEx['ipb_member_id'],
      'ipb_pass_hash': cookieMapEx['ipb_pass_hash'],
      'igneous': cookieMapEx['igneous'],
    };

    final String cookieStr = getCookieStringFromMap(cookie);
    Global.logger.v(cookieStr);

    final User user = User()
      ..cookie = cookieStr
      ..username = username.replaceFirstMapped(
          RegExp('(^.)'), (Match match) => match[1].toUpperCase());

    return user;
  }

  /// 通过网页登录的处理
  /// 处理cookie
  /// 以及获取用户名
  Future<User> signInByWeb(Map cookieMap) async {
    // key value去空格
    cookieMap = cookieMap.map((key, value) {
      return MapEntry(key.toString().trim(), value.toString().trim());
    });

    final List<Cookie> cookies = [
      Cookie('ipb_member_id', cookieMap['ipb_member_id']),
      Cookie('ipb_pass_hash', cookieMap['ipb_pass_hash']),
      Cookie('nw', '1'),
    ];

    final PersistCookieJar cookieJar = await Api.cookieJar;

    // 设置EH的cookie
    cookieJar.saveFromResponse(Uri.parse(EHConst.EH_BASE_URL), cookies);

    // 设置EX的cookie
    cookieJar.saveFromResponse(Uri.parse(EHConst.EX_BASE_URL), cookies);
    await _getExIgneous();

    final String username = await _getUserName(cookieMap['ipb_member_id']);

    //获取Ex cookies
    final List<Cookie> cookiesEx =
        cookieJar.loadForRequest(Uri.parse(EHConst.EX_BASE_URL));
    // 处理cookie 存入sp 方便里站图片请求时构建头 否则会403
    final Map<String, String> cookieMapEx = <String, String>{};

    for (final Cookie cookie in cookiesEx) {
      cookieMapEx.putIfAbsent(cookie.name, () => cookie.value);
    }

    final Map<String, String> cookie = {
      'ipb_member_id': cookieMapEx['ipb_member_id'],
      'ipb_pass_hash': cookieMapEx['ipb_pass_hash'],
      'igneous': cookieMapEx['igneous'],
    };

    final String cookieStr = getCookieStringFromMap(cookie);
    Global.logger.v(cookieStr);

    final User user = User()
      ..cookie = cookieStr
      ..username = username;

    return user;
  }

  /// 通过Cookie登录
  /// 以及获取用户名
  Future<User> signInByCookie(String id, String hash) async {
    final List<Cookie> cookies = <Cookie>[
      Cookie('ipb_member_id', id),
      Cookie('ipb_pass_hash', hash),
      Cookie('nw', '1'),
    ];

    final PersistCookieJar cookieJar = await Api.cookieJar;

    // 设置EH的cookie
    cookieJar.saveFromResponse(Uri.parse(EHConst.EH_BASE_URL), cookies);

    // 设置EX的cookie
    cookieJar.saveFromResponse(Uri.parse(EHConst.EX_BASE_URL), cookies);
    await _getExIgneous();

    final String username = await _getUserName(id);

    //获取Ex cookies
    final List<Cookie> cookiesEx =
        cookieJar.loadForRequest(Uri.parse(EHConst.EX_BASE_URL));
    // 处理cookie 存入sp 方便里站图片请求时构建头 否则会403
    final Map<String, String> cookieMapEx = <String, String>{};

    for (final Cookie cookie in cookiesEx) {
      cookieMapEx.putIfAbsent(cookie.name, () => cookie.value);
    }

    final Map<String, String> cookie = {
      'ipb_member_id': cookieMapEx['ipb_member_id'],
      'ipb_pass_hash': cookieMapEx['ipb_pass_hash'],
      'igneous': cookieMapEx['igneous'],
    };

    final String cookieStr = getCookieStringFromMap(cookie);
    Global.logger.v(cookieStr);

    final User user = User()
      ..cookie = cookieStr
      ..username = username;

    return user;
  }

  Future<String> _getUserName(String id) async {
    final HttpManager httpManager =
        HttpManager.getInstance('https://forums.e-hentai.org');
    final String url = '/index.php?showuser=$id';

    final String response = await httpManager.get(url);

    // Global.logger.v('$response');

    final RegExp regExp = RegExp(r'Viewing Profile: (\w+)</div');
    final String username = regExp.firstMatch('$response').group(1);

    Global.logger.v('username $username');

    return username;
  }

  Future<void> _getExIgneous() async {
    final HttpManager httpManager =
        HttpManager.getInstance(EHConst.EX_BASE_URL);
    const String url = '/uconfig.php';

    await httpManager.getAll(url);
  }

  /// 处理SetCookie 转为map
  Map _parseSetCookieString(List setCookieStrings) {
    final Map cookie = {};
    final RegExp regExp = RegExp(r'^([^;=]+)=([^;]+);');
    setCookieStrings.forEach((setCookieString) {
//      debugPrint(setCookieString);
      final RegExpMatch found = regExp.firstMatch(setCookieString);
      cookie[found.group(1)] = found.group(2);
    });

    return cookie;
  }

  static String getCookieStringFromMap(Map cookie) {
    final List texts = [];
    cookie.forEach((key, value) {
      texts.add('$key=$value');
    });
    return texts.join('; ');
  }
}
