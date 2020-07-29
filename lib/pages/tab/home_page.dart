import 'package:FEhViewer/common/global.dart';
import 'package:FEhViewer/generated/l10n.dart';
import 'package:FEhViewer/utils/toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'favorite_page.dart';
import 'gallery_page.dart';
import 'popular_page.dart';
import 'setting_page.dart';

class FEhHome extends StatefulWidget {
  @override
  _FEhHomeState createState() => _FEhHomeState();
}

class _FEhHomeState extends State<FEhHome> {
  DateTime _lastPressedAt; //上次点击时间

  var _scrollControllerList = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

  // tab控制器 可设置默认tab
  CupertinoTabController _controller = CupertinoTabController();
  int _currentIndex = 0;
  bool _tapAwait = true;

  // 底部菜单栏图标数组
  var tabIcon;

  // 页面内容
  List<Widget> _pages = [];

  // 菜单文案
  var _tabTitles = [];

  void initData() {
    final _iconSize = 24.0;
    if (tabIcon == null) {
      tabIcon = [
        Icon(
          FontAwesomeIcons.fire,
          size: _iconSize,
        ),
        Icon(
          FontAwesomeIcons.list,
          size: _iconSize,
        ),
        Icon(
          FontAwesomeIcons.solidHeart,
          size: _iconSize,
        ),
        Icon(
          FontAwesomeIcons.cog,
          size: _iconSize,
        ),
      ];
    }

    if (_pages.isEmpty) {
      _addPopularPage();
      _addGalleryPage();
      _addFavoritePage();
      _addSettingPage();
    }

    _tabTitles = [
      S.of(context).tab_popular,
      S.of(context).tab_gallery,
      S.of(context).tab_favorite,
      S.of(context).tab_setting
    ];
  }

  _addPopularPage() {
    int index = _pages.length;
    Global.logger.v(index);
    _pages.add(PopularListTab(
      tabIndex: index,
      scrollController: _scrollControllerList[index],
    ));
  }

  _addGalleryPage() {
    int index = _pages.length;
    _pages.add(GalleryListTab(
      tabIndex: index,
      scrollController: _scrollControllerList[index],
    ));
  }

  _addFavoritePage() {
    int index = _pages.length;
    _pages.add(FavoriteTab(
      tabIndex: index,
      scrollController: _scrollControllerList[index],
    ));
  }

  _addSettingPage() {
    int index = _pages.length;
    _pages.add(SettingTab(
      tabIndex: index,
      scrollController: _scrollControllerList[index],
    ));
  }

  // 获取图标
  Icon getTabIcon(int curIndex) {
    return tabIcon[curIndex];
  }

  // 获取标题文本
  Text getTabTitle(int curIndex) {
    return Text(
      _tabTitles[curIndex],
      // style: TextStyle(fontFamilyFallback: [EHConst.FONT_FAMILY]),
//      style: getTabTextStyle(curIndex),
    );
  }

  // 获取BottomNavigationBarItem
  List<BottomNavigationBarItem> getBottomNavigationBarItem() {
    List<BottomNavigationBarItem> list = [];
    for (int index = 0; index < 4; index++) {
      list.add(BottomNavigationBarItem(
          icon: getTabIcon(index), title: getTabTitle(index)));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initData();
    _tapAwait = false;
  }

  @override
  Widget build(BuildContext context) {
    var _listBottomNavigationBarItem = getBottomNavigationBarItem();
    CupertinoTabScaffold cupertinoTabScaffold = CupertinoTabScaffold(
      controller: _controller,
      tabBar: CupertinoTabBar(
        items: _listBottomNavigationBarItem,
        onTap: (index) async {
          if (index == _currentIndex &&
              index != _listBottomNavigationBarItem.length - 1) {
            await _doubleTapBar(
              duration: Duration(milliseconds: 800),
              awaitComplete: false,
              onTap: () {
                _scrollControllerList[index].animateTo(0,
                    duration: Duration(milliseconds: 500), curve: Curves.ease);
              },
              onDoubleTap: () {
                _scrollControllerList[index].animateTo(-100,
                    duration: Duration(milliseconds: 500), curve: Curves.ease);
              },
            );
          } else {
            _currentIndex = index;
          }
        },
      ),
      tabBuilder: (context, index) {
        return _pages[index];
//        return CupertinoTabView(
//          builder: (BuildContext context) {
//            return _pages[index];
//          },
//        );
      },
    );

    WillPopScope willPopScope = WillPopScope(
      onWillPop: doubleClickBack,
      child: cupertinoTabScaffold,
    );

    return willPopScope;
  }

  Future<void> _doubleTapBar(
      {VoidCallback onTap,
      VoidCallback onDoubleTap,
      Duration duration,
      bool awaitComplete}) async {
    var _duration = duration ?? Duration(milliseconds: 500);
    if (!_tapAwait || _tapAwait == null) {
      _tapAwait = true;

      if (awaitComplete ?? false) {
        await Future.delayed(_duration);
        if (_tapAwait) {
//        Global.loggerNoStack.v('等待结束 执行单击事件');
          _tapAwait = false;
          onTap();
        }
      } else {
        onTap();
        await Future.delayed(_duration);
        _tapAwait = false;
      }
    } else if (onDoubleTap != null) {
//      Global.loggerNoStack.v('等待时间内第二次点击 执行双击事件');
      _tapAwait = false;
      onDoubleTap();
    }
  }

  Future<bool> doubleClickBack() async {
    Global.loggerNoStack.v("click back");
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt) > Duration(seconds: 1)) {
      showToast(S.of(context).double_click_back);
      //两次点击间隔超过1秒则重新计时
      _lastPressedAt = DateTime.now();
      return false;
    }
    return true;
  }
}