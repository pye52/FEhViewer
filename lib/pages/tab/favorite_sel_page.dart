import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/common/parser/gallery_fav_parser.dart';
import 'package:FEhViewer/generated/l10n.dart';
import 'package:FEhViewer/models/entity/favorite.dart';
import 'package:FEhViewer/pages/tab/gallery_base.dart';
import 'package:FEhViewer/route/navigator_util.dart';
import 'package:FEhViewer/values/const.dart';
import 'package:FEhViewer/values/theme_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 收藏夹选择页面 列表
class SelFavoritePage extends StatefulWidget {
  const SelFavoritePage({this.favcatItemBean});

  final FavcatItemBean favcatItemBean;

  @override
  _SelFavorite createState() => _SelFavorite();
}

/// 收藏夹选择页面 列表
class _SelFavorite extends State<SelFavoritePage> {
  final List<FavcatItemBean> favItemBeans = [];

  @override
  void initState() {
    super.initState();
    // _initData();
  }

  /// 初始化收藏夹选择数据
  // void _initData() async {
  //   // 增加延时
  //   await Future<void>.delayed(const Duration(milliseconds: 100));
  //   final List<Map<String, String>> favList =
  //       await GalleryFavParser.getFavcat() ?? EHConst.favList;
  //   for (final Map<String, String> catmap in favList) {
  //     final String favTitle = catmap['favTitle'];
  //     final String favId = catmap['favId'];
  //
  //     favItemBeans.add(
  //       FavcatItemBean(favTitle, ThemeColors.favColor[favId], favId: favId),
  //     );
  //   }
  //   setState(() {
  //     favItemBeans
  //         .add(FavcatItemBean('所有收藏', ThemeColors.favColor['a'], favId: 'a'));
  //   });
  // }

  Future<List<FavcatItemBean>> _getFavItemBeans() async {
    Global.logger.v('_getFavItemBeans');
    final List<FavcatItemBean> _favItemBeans = <FavcatItemBean>[];
    // await Future<void>.delayed(const Duration(milliseconds: 200));
    final List<Map<String, String>> favList =
        await GalleryFavParser.getFavcat() ?? EHConst.favList;
    for (final Map<String, String> catmap in favList) {
      final String favTitle = catmap['favTitle'];
      final String favId = catmap['favId'];

      _favItemBeans.add(
        FavcatItemBean(favTitle, ThemeColors.favColor[favId], favId: favId),
      );
    }

    _favItemBeans
        .add(FavcatItemBean('所有收藏', ThemeColors.favColor['a'], favId: 'a'));

    _favItemBeans
        .add(FavcatItemBean('本地收藏', ThemeColors.favColor['l'], favId: 'l'));
    return _favItemBeans;
  }

  List<FavcatItemBean> _initFavItemBeans() {
    final List<FavcatItemBean> _favItemBeans = <FavcatItemBean>[];
    for (final Map<String, String> catmap in EHConst.favList) {
      final String favTitle = catmap['favTitle'];
      final String favId = catmap['favId'];

      _favItemBeans.add(
        FavcatItemBean(favTitle, ThemeColors.favColor[favId], favId: favId),
      );
    }

    _favItemBeans
        .add(FavcatItemBean('所有收藏', ThemeColors.favColor['a'], favId: 'a'));

    _favItemBeans
        .add(FavcatItemBean('本地收藏', ThemeColors.favColor['l'], favId: 'l'));
    return _favItemBeans;
  }

  @override
  Widget build(BuildContext context) {
    final S ln = S.of(context);
    final String _title = ln.favcat;
    final CupertinoPageScaffold sca = CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(_title),
          transitionBetweenRoutes: false,
        ),
        child: SafeArea(
          child: FutureBuilder<List<FavcatItemBean>>(
              future: _getFavItemBeans(),
              initialData: _initFavItemBeans(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<FavcatItemBean>> snapshot) {
                // return ListViewFavorite(favItemBeans);
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.active:
                  case ConnectionState.waiting:
                    return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(bottom: 50),
                      child: const CupertinoActivityIndicator(
                        radius: 14.0,
                      ),
                    );
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: GalleryErrorPage(
                            onTap: () {
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    } else {
                      return ListViewFavorite(snapshot.data);
                    }
                }
                return null;
              }),
        ));

    return sca;
  }
}

class ListViewFavorite extends StatelessWidget {
  const ListViewFavorite(this.favItemBeans);

  final List<FavcatItemBean> favItemBeans;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: favItemBeans.length,

      //列表项构造器
      itemBuilder: (BuildContext context, int index) {
        return FavSelItemWidget(
          favcatItemBean: favItemBeans[index],
          index: index,
        );
      },
    );
  }
}

/// 收藏夹选择单项
class FavSelItemWidget extends StatefulWidget {
  const FavSelItemWidget({this.index, this.favcatItemBean});

  final int index;
  final FavcatItemBean favcatItemBean;

  @override
  _FavSelItemWidgetState createState() => _FavSelItemWidgetState();
}

class _FavSelItemWidgetState extends State<FavSelItemWidget> {
  Color _colorTap;

  @override
  Widget build(BuildContext context) {
    final Widget container = Container(
      color: _colorTap,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            // 图标
            Icon(
//              EHCupertinoIcons.heart_solid,
              FontAwesomeIcons.solidHeart,
              color: widget.favcatItemBean.color,
            ),
            Container(
              width: 8,
            ), // 占位 宽度8
            Text(
              widget?.favcatItemBean?.title ?? '',
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
            const Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  CupertinoIcons.forward,
                  size: 24.0,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ]),
        ],
      ),
    );

    return GestureDetector(
      child: Column(
        children: <Widget>[
          container,
          _settingItemDivider(),
        ],
      ),
      // 不可见区域点击有效
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 返回 并带上参数
        NavigatorUtil.goBackWithParams(context, widget.favcatItemBean);
      },
      onTapDown: (_) => _updatePressedColor(),
      onTapUp: (_) {
        Future<void>.delayed(const Duration(milliseconds: 100), () {
          _updateNormalColor();
        });
      },
      onTapCancel: () => _updateNormalColor(),
    );
  }

  void _updateNormalColor() {
    setState(() {
      _colorTap = null;
    });
  }

  void _updatePressedColor() {
    setState(() {
      _colorTap =
          CupertinoDynamicColor.resolve(CupertinoColors.systemGrey4, context);
    });
  }

  /// 设置项分隔线
  Widget _settingItemDivider() {
    return Divider(
      height: 1.0,
      indent: 48,
      color:
          CupertinoDynamicColor.resolve(CupertinoColors.systemGrey4, context),
    );
  }
}
