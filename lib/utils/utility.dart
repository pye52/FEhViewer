import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/common/parser/gallery_detail_parser.dart';
import 'package:FEhViewer/common/parser/gallery_list_parser.dart';
import 'package:FEhViewer/models/galleryItem.dart';
import 'package:FEhViewer/models/index.dart';
import 'package:FEhViewer/utils/https_proxy.dart';
import 'package:FEhViewer/utils/toast.dart';
import 'package:FEhViewer/values/const.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dns_client/dns_client.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share/share.dart';
import 'package:tuple/tuple.dart';

import 'dio_util.dart';

class EHUtils {
  bool get isInDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true); //如果debug模式下会触发赋值
    return inDebugMode;
  }

  static String getLangeage(String value) {
    for (final String key in EHConst.iso936.keys) {
      if (key.toUpperCase().trim() == value.toUpperCase().trim()) {
        return EHConst.iso936[key];
      }
    }
    return '';
  }

  /// list 分割
  static List<List<T>> splitList<T>(List<T> list, int len) {
    if (len <= 1) {
      return [list];
    }

    final List<List<T>> result = [];
    int index = 1;

    while (true) {
      if (index * len < list.length) {
        final List<T> temp = list.skip((index - 1) * len).take(len).toList();
        result.add(temp);
        index++;
        continue;
      }
      final List<T> temp = list.skip((index - 1) * len).toList();
      result.add(temp);
      break;
    }
    return result;
  }

  // 位图转map
  static Map<String, bool> convNumToCatMap(int catNum) {
    final List<String> catList = EHConst.catList;
    final Map catsNumMaps = EHConst.cats;
    final Map<String, bool> catMap = <String, bool>{};
    for (int i = 0; i < catList.length; i++) {
      final String catName = catList[i];
      final int curCatNum = catsNumMaps[catName];
      if (catNum & curCatNum != curCatNum) {
        catMap[catName] = true;
      } else {
        catMap[catName] = false;
      }
    }
    return catMap;
  }

  static int convCatMapToNum(Map<String, bool> catMap) {
    int totCatNum = 0;
    final Map catsNumMaps = EHConst.cats;
    catMap.forEach((String key, bool value) {
      if (!value) {
        totCatNum += catsNumMaps[key];
      }
    });
    return totCatNum;
  }

  static List<Map<String, String>> getFavListFromProfile() {
    final List<Map<String, String>> favcatList = <Map<String, String>>[];
    for (final dynamic mapObj in Global.profile.user.favcat) {
      // Global.logger.v('$mapObj');
      final Map<String, String> map = <String, String>{
        'favId': mapObj['favId'],
        'favTitle': mapObj['favTitle']
      };
      favcatList.add(map);
    }

    return favcatList;
  }
}

// ignore: avoid_classes_with_only_static_members
class Api {
  //改为使用 PersistCookieJar，在文档中有介绍，PersistCookieJar将cookie保留在文件中，
  // 因此，如果应用程序退出，则cookie始终存在，除非显式调用delete
  static PersistCookieJar _cookieJar;

  static Future<PersistCookieJar> get cookieJar async {
    // print(_cookieJar);
    if (_cookieJar == null) {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      print('获取的文件系统目录 appDocPath： ' + appDocPath);
      _cookieJar = PersistCookieJar(dir: appDocPath);
    }
    return _cookieJar;
  }

  static Future<String> getIpByDoH(String url) async {
    final DnsOverHttps dns = DnsOverHttps.cloudflare();
    final List<InternetAddress> response = await dns.lookup(url);
    if (response.isNotEmpty) {
      return response.first.address;
    } else {
      return url;
    }
  }

  static String getAdvanceSearchText() {
    final AdvanceSearch advanceSearch = Global.profile.advanceSearch;

    final String para =
        '&f_sname=${advanceSearch.searchGalleryName ?? false ? "on" : ""}'
        '&f_stags=${advanceSearch.searchGalleryTags ?? false ? "on" : ""}'
        '&f_sdesc=${advanceSearch.searchGalleryDesc ?? false ? "on" : ""}'
        '&f_storr=${advanceSearch.searchToreenFilenames ?? false ? "on" : ""}'
        '&f_sto=${advanceSearch.onlyShowWhithTorrents ?? false ? "on" : ""}'
        '&f_sdt1=${advanceSearch.searchLowPowerTags ?? false ? "on" : ""}'
        '&f_sdt2=${advanceSearch.searchDownvotedTags ?? false ? "on" : ""}'
        '&f_sh=${advanceSearch.searchExpunged ?? false ? "on" : ""}'
        '&f_sr=${advanceSearch.searchWithminRating ?? false ? "on" : ""}'
        '&f_srdd=${advanceSearch.minRating ?? ""}'
        '&f_sp=${advanceSearch.searchBetweenpage ?? false ? "on" : ""}'
        '&f_spf=${advanceSearch.startPage ?? ""}'
        '&f_spt=${advanceSearch.endPage ?? ""}'
        '&f_sfl=${advanceSearch.disableDFLanguage ?? false ? "on" : ""}'
        '&f_sfu=${advanceSearch.disableDFUploader ?? false ? "on" : ""}'
        '&f_sft=${advanceSearch.disableDFTags ?? false ? "on" : ""}';

    return para;
  }

  static HttpManager _getHttpManager() {
    final String _baseUrl =
        EHConst.getBaseSite(Global.profile.ehConfig.siteEx ?? false);
    final bool _doh = Global.profile.dnsConfig.doh ?? false;
    if (_doh) {
      return HttpManager.withProxy(_baseUrl);
    } else {
      return HttpManager.getInstance(_baseUrl);
    }
  }

  static String _getBaseUrl() {
    return EHConst.getBaseSite(Global.profile.ehConfig.siteEx ?? false);
  }

  /// 获取热门画廊列表
  static Future<Tuple2<List<GalleryItem>, int>> getPopular() async {
//    Global.logger.v("获取热门");

    const String url = '/popular?inline_set=dm_l';

    await CustomHttpsProxy.instance.init();
    try {
      await DnsUtil.dohToProfile(_getBaseUrl());
    } catch (e, stack) {
      Global.logger.v('$stack');
      rethrow;
    }

    final String response = await _getHttpManager().get(url);

    final Tuple2<List<GalleryItem>, int> tuple =
        await GalleryListParser.parseGalleryList(response);

    return tuple;
  }

  /// 获取画廊列表
  static Future<Tuple2<List<GalleryItem>, int>> getGallery({
    int page,
    String fromGid,
    String serach,
    int cats,
  }) async {
    String url = '/';
    String qry = '?page=${page ?? 0}&inline_set=dm_l';

    if (Global.profile.ehConfig.safeMode) {
      qry = '$qry&f_cats=767';
    } else if (cats != null) {
      qry = '$qry&f_cats=$cats';
    }

    if (fromGid != null) {
      qry = '$qry&from=$fromGid';
    }

    if (Global.profile.ehConfig.safeMode) {
      serach = 'parody:gundam\$';
    }

    if (serach != null) {
      final List<String> searArr = serach.split(':');
      if (searArr.length > 1) {
        String _end = '';
        if (searArr[0] != 'uploader') {
          _end = '\$';
        }
        final String _search =
            Uri.encodeQueryComponent('${searArr[0]}:"${searArr[1]}$_end"');
        qry = '$qry&f_search=$_search';
      } else {
        final String _search = Uri.encodeQueryComponent('$serach');
        qry = '$qry&f_search=$_search';
      }
    }

    url = '$url$qry';

    /// 高级搜索处理
    if (Global.profile.enableAdvanceSearch ?? false) {
      url = '$url&advsearch=1${getAdvanceSearchText()}';
    }

    final Options options = Options(headers: {
      'Referer': 'https://e-hentai.org',
    });

    Global.logger.v(url);

    await CustomHttpsProxy.instance.init();
    final String response = await _getHttpManager().get(url, options: options);

    return await GalleryListParser.parseGalleryList(response);
  }

  /// 获取收藏
  static Future<Tuple2<List<GalleryItem>, int>> getFavorite(
      {String favcat, int page}) async {
    String _getUrl({String inlineSet}) {
      //收藏时间排序
      final String _order = Global?.profile?.ehConfig?.favoritesOrder;

      String url = '/favorites.php/';
      String qry = '?page=${page ?? 0}';
      if (favcat != null && favcat != 'a' && favcat.isNotEmpty) {
        qry = '$qry&favcat=$favcat';
      }
      qry = "$qry&inline_set=${inlineSet ?? _order ?? ''}";
      url = '$url$qry';

      Global.logger.v(url);
      return url;
    }

    final String url = _getUrl();

    await CustomHttpsProxy.instance.init();
    final String response = await _getHttpManager().get(url);

    final bool isDml = GalleryListParser.isGalleryListDmL(response);
    if (isDml) {
      return await GalleryListParser.parseGalleryList(response,
          isFavorite: true);
    } else {
      final String url = _getUrl(inlineSet: 'dm_l');
      final String response = await _getHttpManager().get(url);
      return await GalleryListParser.parseGalleryList(response,
          isFavorite: true);
    }
  }

  /// 获取画廊详细信息
  /// ?inline_set=ts_m 小图,40一页
  /// ?inline_set=ts_l 大图,20一页
  /// c=1#comments 显示全部评论
  /// nw=always 不显示警告
  static Future<GalleryItem> getGalleryDetail(
      {String inUrl, GalleryItem inGalleryItem}) async {
    // final HttpManager httpManager = HttpManager.getInstance();
    final String url = inUrl + '?hc=1&inline_set=ts_l&nw=always';
    // final String url = inUrl + '?hc=1&nw=always';

    // 不显示警告的处理 cookie加上 nw=1
    // 在 url使用 nw=always 未解决 自动写入cookie 暂时搞不懂 先手动设置下
    // todo 待优化
    final PersistCookieJar cookieJar = await Api.cookieJar;
    final List<Cookie> cookies = cookieJar.loadForRequest(Uri.parse(inUrl));
    cookies.add(Cookie('nw', '1'));
    cookieJar.saveFromResponse(Uri.parse(url), cookies);

    Global.logger.i('获取画廊 $url');
    await CustomHttpsProxy.instance.init();
    final String response = await _getHttpManager().get(url);

    // TODO 画廊警告问题 使用 nw=always 未解决 待处理 怀疑和Session有关
    if ('$response'.contains(r'<strong>Offensive For Everyone</strong>')) {
      Global.logger.v('Offensive For Everyone');
      showToast('Offensive For Everyone');
    }

    final GalleryItem galleryItem =
        await GalleryDetailParser.parseGalleryDetail(response,
            inGalleryItem: inGalleryItem);

    // Global.logger.v(galleryItem.toJson());

    return galleryItem;
  }

  /// 获取画廊缩略图
  /// [inUrl] 画廊的地址
  /// [page] 缩略图页码
  static Future<List<GalleryPreview>> getGalleryPreview(String inUrl,
      {int page}) async {
    //?inline_set=ts_m 小图,40一页
    //?inline_set=ts_l 大图,20一页
    //hc=1#comments 显示全部评论
    //nw=always 不显示警告

    // final HttpManager httpManager = HttpManager.getInstance();
    final String url = inUrl + '?p=$page';

    // Global.logger.v(url);

    // 不显示警告的处理 cookie加上 nw=1
    // 在 url使用 nw=always 未解决 自动写入cookie 暂时搞不懂 先手动设置下
    // todo 待优化
    final PersistCookieJar cookieJar = await Api.cookieJar;
    final List<Cookie> cookies = cookieJar.loadForRequest(Uri.parse(inUrl));
    cookies.add(Cookie('nw', '1'));
    cookieJar.saveFromResponse(Uri.parse(url), cookies);

    await CustomHttpsProxy.instance.init();
    final String response = await _getHttpManager().get(url);

    return GalleryDetailParser.parseGalleryPreviewFromHtml(response);
  }

  /// 由图片url获取解析图库 showkey
  /// [href] 画廊图片展示页面的地址
  static Future<String> getShowkey(String href) async {
    // final HttpManager httpManager = HttpManager.getInstance();

    final String url = href;

    await CustomHttpsProxy.instance.init();
    final String response = await _getHttpManager().get(url);

    final RegExp regShowKey = RegExp(r'var showkey="([0-9a-z]+)";');

    final String showkey = regShowKey.firstMatch(response)?.group(1) ?? '';

//    Global.logger.v('$showkey');

    return showkey;
  }

  /// 由api获取画廊图片的url
  /// [href] 爬取的页面地址 用来解析gid 和 imgkey
  /// [showKey] api必须
  /// [index] 索引 从 1 开始
  static Future<String> getShowInfo(String href, String showKey,
      {int index}) async {
    // final HttpManager httpManager = HttpManager.getInstance(EHConst.EH_BASE_URL);
    const String url = '/api.php';

    final String cookie = Global.profile?.user?.cookie ?? '';

    final Options options = Options(headers: {
      'Cookie': cookie,
    });

//    Global.logger.v('href = $href');

    final RegExp regExp =
        RegExp(r'https://e[-x]hentai.org/s/([0-9a-z]+)/(\d+)-(\d+)');
    final RegExpMatch regRult = regExp.firstMatch(href);
    final int gid = int.parse(regRult.group(2));
    final String imgkey = regRult.group(1);
    final int page = int.parse(regRult.group(3));

    final Map<String, Object> reqMap = {
      'method': 'showpage',
      'gid': gid,
      'page': page,
      'imgkey': imgkey,
      'showkey': showKey,
    };
    final String reqJsonStr = jsonEncode(reqMap);

//    Global.logger.v('$reqJsonStr');

    await CustomHttpsProxy.instance.init();
    final Response response = await _getHttpManager().postForm(
      url,
      options: options,
      data: reqJsonStr,
    );

//    Global.logger.v('$response');

    final rultJson = jsonDecode('$response');

    final RegExp regImageUrl = RegExp('<img[^>]*src=\"([^\"]+)\" style');
    final imageUrl = regImageUrl.firstMatch(rultJson['i3']).group(1);

//    Global.logger.v('$imageUrl');

    return imageUrl;
  }

  /// 通过api请求获取更多信息
  /// 例如
  /// 画廊评分
  /// 日语标题
  /// 等等
  static Future<List<GalleryItem>> getMoreGalleryInfo(
      List<GalleryItem> galleryItems) async {
    // Global.logger.i('api qry items ${galleryItems.length}');
    if (galleryItems.isEmpty) {
      return galleryItems;
    }

    // 通过api获取画廊详细信息
    List _gidlist = [];

    galleryItems.forEach((GalleryItem galleryItem) {
      _gidlist.add([galleryItem.gid, galleryItem.token]);
    });

    // 25个一组分割
    List _group = EHUtils.splitList(_gidlist, 25);

    List rultList = [];

    // 查询 合并结果
    for (int i = 0; i < _group.length; i++) {
      Map reqMap = {'gidlist': _group[i], 'method': 'gdata'};
      final String reqJsonStr = jsonEncode(reqMap);

      await CustomHttpsProxy.instance.init();
      final rult = await getGalleryApi(reqJsonStr);

      final jsonObj = jsonDecode(rult.toString());
      final tempList = jsonObj['gmetadata'];
      rultList.addAll(tempList);
    }

    final HtmlUnescape unescape = HtmlUnescape();

    for (int i = 0; i < galleryItems.length; i++) {
      galleryItems[i].englishTitle = unescape.convert(rultList[i]['title']);
      galleryItems[i].japaneseTitle =
          unescape.convert(rultList[i]['title_jpn']);

      final rating = rultList[i]['rating'];
      galleryItems[i].rating = rating != null
          ? double.parse(rating)
          : galleryItems[i].ratingFallBack;

      final String thumb = rultList[i]['thumb'];
      galleryItems[i].imgUrlL = thumb;
      /*final String imageUrl = thumb.endsWith('-jpg_l.jpg')
          ? thumb.replaceFirst('-jpg_l.jpg', '-jpg_250.jpg')
          : thumb;

      galleryItems[i].imgUrl = imageUrl;*/

      // Global.logger.v('${rultList[i]["tags"]}');

      galleryItems[i].filecount = rultList[i]['filecount'] as String;
      galleryItems[i].uploader = rultList[i]['uploader'] as String;
      galleryItems[i].category = rultList[i]['category'] as String;
      final List<String> tags = List<String>.from(
          rultList[i]['tags'].map((e) => e as String).toList());
      galleryItems[i].tagsFromApi = tags;

      /// 判断获取语言标识
      // galleryItems[i].translated = '';
      // if (tags.contains('translated')) {
      //   Global.logger.v('hase translated');
      //   galleryItems[i].translated = EHUtils.getLangeage(tags[0]);
      // }
      if (tags.isNotEmpty) {
        galleryItems[i].translated = EHUtils.getLangeage(tags[0]) ?? '';
      }

      // Global.logger
      //     .v('${galleryItems[i].translated}   ${galleryItems[i].tagsFromApi}');
    }

    return galleryItems;
  }

  static Future<void> getMoreGalleryInfoOne(GalleryItem galleryItem) async {
    final RegExp urlRex = RegExp(r'http?s://e(-|x)hentai.org/g/(\d+)/(\w+)?/$');
    Global.logger.v(galleryItem.url);
    final RegExpMatch urlRult = urlRex.firstMatch(galleryItem.url);
    Global.logger.v(urlRult.groupCount);

    final String gid = urlRult.group(2);
    final String token = urlRult.group(3);

    galleryItem.gid = gid;
    galleryItem.token = token;

    final List<GalleryItem> reqGalleryItems = <GalleryItem>[galleryItem];

    await getMoreGalleryInfo(reqGalleryItems);
  }

  /// 获取api
  static Future getGalleryApi(String req) async {
    const String url = '/api.php';

    await CustomHttpsProxy.instance.init();
    final Response response = await _getHttpManager().postForm(url, data: req);

    return response;
  }

  /// 分享图片
  static Future<void> shareImage(String imageUrl) async {
    final CachedNetworkImage image = CachedNetworkImage(imageUrl: imageUrl);
    final DefaultCacheManager manager =
        image.cacheManager ?? DefaultCacheManager();
    final Map<String, String> headers = image.httpHeaders;
    final File file = await manager.getSingleFile(
      image.imageUrl,
      headers: headers,
    );
    Share.shareFiles(<String>[file.path]);
  }

  /// 保存图片到相册
  ///
  /// 默认为下载网络图片，如需下载资源图片，需要指定 [isAsset] 为 `true`。
  static Future<bool> saveImage(BuildContext context, String imageUrl,
      {bool isAsset = false}) async {
    Future<void> _jumpToAppSettings(context) async {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('页面跳转'),
            content: Container(
              child: const Text('您禁用了应用的必要权限:\n读写手机存储,是否到设置里允许?'),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('取消'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              CupertinoDialogAction(
                child: const Text('确定'),
                onPressed: () {
                  // 跳转
                  openAppSettings();
                },
              ),
            ],
          );
        },
      );
    }

    if (Platform.isIOS) {
      Global.logger.v('check ios photos Permission');
      final PermissionStatus status = await Permission.photos.status;
      Global.logger.v(status);
      if (status.isPermanentlyDenied) {
        _jumpToAppSettings(context);
        return false;
      } else {
        if (await Permission.photos.request().isGranted) {
          return _saveImage(imageUrl);
          // Either the permission was already granted before or the user just granted it.
        } else {
          throw '无法存储图片,请先授权~';
        }
      }
    } else {
      final PermissionStatus status = await Permission.storage.status;
      Global.logger.v(status);
      if (await Permission.storage.status.isPermanentlyDenied) {
        if (await Permission.storage.request().isGranted) {
          _saveImage(imageUrl);
        } else {
          await _jumpToAppSettings(context);
          return false;
        }
      } else {
        if (await Permission.storage.request().isGranted) {
          // Either the permission was already granted before or the user just granted it.
          return _saveImage(imageUrl);
        } else {
          throw '无法存储图片,请先授权~';
        }
      }
    }
    return false;
  }

  static Future<bool> _saveImage(String imageUrl,
      {bool isAsset = false}) async {
    try {
      if (imageUrl == null) throw '保存失败,图片不存在!';

      /// 保存的图片数据
      Uint8List imageBytes;

      if (isAsset == true) {
        /// 保存资源图片
        final ByteData bytes = await rootBundle.load(imageUrl);
        imageBytes = bytes.buffer.asUint8List();
      } else {
        /// 保存网络图片
        final CachedNetworkImage image = CachedNetworkImage(imageUrl: imageUrl);
        final DefaultCacheManager manager =
            image.cacheManager ?? DefaultCacheManager();
        final Map<String, String> headers = image.httpHeaders;
        final File file = await manager.getSingleFile(
          image.imageUrl,
          headers: headers,
        );
        imageBytes = await file.readAsBytes();

        ExtendedNetworkImageProvider _image = ExtendedNetworkImageProvider(
          imageUrl,
          cache: true,
        );
        Uint8List _imageBytes = await _image.getNetworkImageData();
      }

      /// 保存图片
      final result = await ImageGallerySaver.saveImage(imageBytes);

      if (result == null || result == '') throw '图片保存失败';

      print('保存成功');
      return true;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }
}

enum DohResolve {
  google,
  cloudflare,
}

class DnsUtil {
  static Future<String> doh(String host,
      {DohResolve dhoResolve = DohResolve.cloudflare}) async {
    final DnsOverHttps dns = dhoResolve == DohResolve.cloudflare
        ? DnsOverHttps.cloudflare()
        : DnsOverHttps.google();
    final List<InternetAddress> response = await dns.lookup(host.trim());
    return (response..shuffle()).first.address;
  }

  static Future<void> dohToProfile(String url) async {
    if (!Global.profile.dnsConfig.doh ?? false) {
      return;
    }
    // 解析host
    final String _host = Uri.parse(url).host;
    final String _addr = await doh(_host);
    Global.logger.v('$_host  $_addr');
    final List<DnsCache> dnsCacheList = Global.profile.dnsConfig.cache;
    dnsCacheList.add(DnsCache()
      ..host = _host
      ..addrs = <String>[_addr]);

    for (DnsCache cache in dnsCacheList) {
      // Global.hosts[cache.host] = cache.addrs.first;
    }
  }
}
