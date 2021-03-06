import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/common/tag_database.dart';
import 'package:FEhViewer/models/states/ehconfig_model.dart';
import 'package:FEhViewer/models/states/user_model.dart';
import 'package:FEhViewer/values/const.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'setting_base.dart';

class EhSettingPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _EhSettingPage();
}

class _EhSettingPage extends State<EhSettingPage> {
  final String _title = 'EH设置';

  Future<bool> _getDelayed() async {
    final int _delayed = (Global.isFirstReOpenEhSetting ?? true) ? 200 : 1;
    // Global.logger.v('$_delayed');
    await Future<void>.delayed(Duration(milliseconds: _delayed));
    Global.isFirstReOpenEhSetting = false;
    return Future<bool>.value(true);
  }

  @override
  Widget build(BuildContext context) {
    final CupertinoPageScaffold cps = CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(_title),
        ),
        child: SafeArea(
          child: FutureBuilder<bool>(
              future: _getDelayed(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return ListViewEhSetting();
                  // return Container();
                } else {
                  return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 50, bottom: 100),
                      child: const CupertinoActivityIndicator(
                        radius: 14,
                      ));
                }
              }),
        ));

    return cps;
  }
}

class ListViewEhSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final EhConfigModel ehConfigModel =
        Provider.of<EhConfigModel>(context, listen: false);
    final bool _siteEx = ehConfigModel.siteEx;
    final bool _jpnTitle = ehConfigModel.jpnTitle;
    final bool _tagTranslat = ehConfigModel.tagTranslat;
    final bool _galleryImgBlur = ehConfigModel.galleryImgBlur;
    final bool _favLongTap = ehConfigModel.favLongTap;

    void _handleSiteChanged(bool newValue) {
      ehConfigModel.siteEx = newValue;
    }

    void _handleJpnTitleChanged(bool newValue) {
      ehConfigModel.jpnTitle = newValue;
    }

    void _handleTagTranslatChanged(bool newValue) {
      ehConfigModel.tagTranslat = newValue;
      if (newValue) {
        try {
          EhTagDatabase.generateTagTranslat();
        } catch (e) {
          debugPrint('更新翻译异常 $e');
        }
      }
    }

    void _handleGalleryListImgBlurChanged(bool newValue) {
      ehConfigModel.galleryImgBlur = newValue;
    }

    void _handleFavLongTapChanged(bool newValue) {
      ehConfigModel.favLongTap = newValue;
    }

    List<Widget> _list = <Widget>[
      if (Provider.of<UserModel>(context, listen: false).isLogin)
        TextSwitchItem(
          '站点切换',
          intValue: _siteEx,
          onChanged: _handleSiteChanged,
          desc: 'E-Hentai',
          descOn: 'ExHentai',
        ),
      TextSwitchItem('显示标签中文翻译',
          intValue: _tagTranslat,
          onChanged: _handleTagTranslatChanged,
          desc:
              '需要下载数据文件,当前版本:${Global.profile.ehConfig.tagTranslatVer ?? "无"}'),
      TextSwitchItem('显示日文标题',
          intValue: _jpnTitle,
          onChanged: _handleJpnTitleChanged,
          desc: '如果该画廊有日文标题则优先显示'),
      TextSwitchItem('画廊封面模糊',
          intValue: _galleryImgBlur,
          onChanged: _handleGalleryListImgBlurChanged,
          desc: '画廊列表封面模糊效果'),
      TextSwitchItem(
        '画廊收藏夹选择方式',
        intValue: _favLongTap,
        onChanged: _handleFavLongTapChanged,
        desc: '每一次都要选择收藏夹',
        descOn: '默认使用上次收藏夹，长按弹出选择框',
      ),
      TextSwitchItem(
        '收藏夹排序方式',
        onChanged: _handleJpnTitleChanged,
        desc: '按更新时间排序',
        descOn: '按收藏时间排序',
      ),
      _buildListModeItem(context),
      _buildHistoryMaxItem(context),
    ];

    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (BuildContext context, int index) {
        return _list[index];
      },
    );
  }
}

/// 列表模式切换
Widget _buildListModeItem(BuildContext context) {
  const String _title = '浏览模式';
  final EhConfigModel ehConfigModel =
      Provider.of<EhConfigModel>(context, listen: false);

  final Map<ListModeEnum, String> modeMap = <ListModeEnum, String>{
    ListModeEnum.list: '列表 - 中',
    ListModeEnum.simpleList: '列表 - 小',
    ListModeEnum.waterfall: '瀑布流',
  };

  List<Widget> _getModeList(BuildContext context) {
    return List<Widget>.from(modeMap.keys.map((ListModeEnum element) {
      return CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context, element);
          },
          child: Text(modeMap[element]));
    }).toList());
  }

  Future<ListModeEnum> _showDialog(BuildContext context) {
    return showCupertinoModalPopup<ListModeEnum>(
        context: context,
        builder: (BuildContext context) {
          final CupertinoActionSheet dialog = CupertinoActionSheet(
            // title: const Text('列表模式选择'),
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('取消')),
            actions: <Widget>[
              ..._getModeList(context),
            ],
          );
          return dialog;
        });
  }

  return Selector<EhConfigModel, String>(
      selector: (BuildContext context, EhConfigModel ehConfigModel) =>
          modeMap[ehConfigModel.listMode ?? ListModeEnum.list],
      builder: (BuildContext context, String listModeText, _) {
        return SelectorSettingItem(
          title: _title,
          selector: listModeText,
          onTap: () async {
            Global.logger.v('tap ModeItem');
            final ListModeEnum _result = await _showDialog(context);
            if (_result != null) {
              // ignore: unnecessary_string_interpolations
              Global.logger.v('${EnumToString.convertToString(_result)}');
              ehConfigModel.listMode = _result;
            }
          },
        );
      });
}

/// 历史记录数量切换
Widget _buildHistoryMaxItem(BuildContext context) {
  const String _title = '最大历史记录数';
  final EhConfigModel ehConfigModel =
      Provider.of<EhConfigModel>(context, listen: false);

  String _getMaxNumText(int max) {
    if (max == 0) {
      return '无限制';
    } else {
      return '$max';
    }
  }

  List<Widget> _getModeList(BuildContext context) {
    return List<Widget>.from(EHConst.historyMax.map((int element) {
      return CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context, element);
          },
          child: Text(_getMaxNumText(element)));
    }).toList());
  }

  Future<int> _showDialog(BuildContext context) {
    return showCupertinoModalPopup<int>(
        context: context,
        builder: (BuildContext context) {
          final CupertinoActionSheet dialog = CupertinoActionSheet(
            // title: const Text('列表模式选择'),
            cancelButton: CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('取消')),
            actions: <Widget>[
              ..._getModeList(context),
            ],
          );
          return dialog;
        });
  }

  return Selector<EhConfigModel, int>(
      selector: (BuildContext context, EhConfigModel ehConfigModel) =>
          ehConfigModel.maxHistory,
      builder: (BuildContext context, int maxHistory, _) {
        return SelectorSettingItem(
          title: _title,
          selector: _getMaxNumText(maxHistory) ?? '',
          onTap: () async {
            Global.logger.v('tap ModeItem');
            final int _result = await _showDialog(context);
            if (_result != null) {
              ehConfigModel.maxHistory = _result;
            }
          },
        );
      });
}
