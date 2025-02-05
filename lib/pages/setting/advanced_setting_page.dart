import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:fehviewer/common/controller/cache_controller.dart';
import 'package:fehviewer/common/service/dns_service.dart';
import 'package:fehviewer/common/service/ehsetting_service.dart';
import 'package:fehviewer/common/service/layout_service.dart';
import 'package:fehviewer/common/service/theme_service.dart';
import 'package:fehviewer/fehviewer.dart';
import 'package:fehviewer/pages/setting/webview/mode.dart';
import 'package:fehviewer/utils/import_export.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../component/setting_base.dart';
import 'setting_items/selector_Item.dart';

class AdvancedSettingPage extends StatelessWidget {
  const AdvancedSettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget cps = Obx(() {
      return CupertinoPageScaffold(
          backgroundColor: !ehTheme.isDarkMode
              ? CupertinoColors.secondarySystemBackground
              : null,
          navigationBar: CupertinoNavigationBar(
            // transitionBetweenRoutes: true,
            middle: Text(L10n.of(context).advanced),
          ),
          child: const SafeArea(
            bottom: false,
            child: ListViewAdvancedSetting(),
          ));
    });

    return cps;
  }
}

class ListViewAdvancedSetting extends StatelessWidget {
  const ListViewAdvancedSetting({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final EhSettingService _ehSettingService = Get.find();
    final DnsService _dnsService = Get.find();
    final CacheController _cacheController = Get.find();

    void _handleDoHChanged(bool newValue) {
      // if (!newValue && !_dnsService.enableCustomHosts) {
      //   /// 清除hosts 关闭代理
      //   logger.d(' 关闭代理');
      //   HttpOverrides.global = null;
      // } else if (newValue) {
      //   /// 设置全局本地代理
      //   HttpOverrides.global = Global.httpProxy;
      // }
      _dnsService.enableDoH = newValue;
    }

    void _handleDFChanged(bool newValue) {
      _dnsService.enableDomainFronting = newValue;
      if (!newValue) {
        HttpOverrides.global = null;
      } else {
        HttpOverrides.global = ehHttpOverrides..skipCertificateCheck = true;
        final HttpClient eClient =
            ExtendedNetworkImageProvider.httpClient as HttpClient;
        eClient.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          return true;
        };
      }
    }

    final List<Widget> _list = <Widget>[
      SelectorSettingItem(
        title: L10n.of(context).image_block,
        selector: '',
        onTap: () {
          Get.toNamed(
            EHRoutes.imageHide,
            id: isLayoutLarge ? 2 : null,
          );
        },
      ),
      SelectorSettingItem(
        hideDivider: true,
        title: L10n.of(context).blockers,
        onTap: () {
          Get.toNamed(
            EHRoutes.blockers,
            id: isLayoutLarge ? 2 : null,
          );
        },
      ),

      const ItemSpace(),
      // 清除缓存
      _cacheController.obx(
          (String? state) => SelectorSettingItem(
                title: L10n.of(context).clear_cache,
                selector: state ?? '',
                hideDivider: true,
                onTap: () {
                  logger.d(' clear_cache');
                  _cacheController.clearAllCache();
                },
              ),
          onLoading: SelectorSettingItem(
            title: L10n.of(context).clear_cache,
            selector: '',
            hideDivider: true,
            onTap: () {
              logger.d(' clear_cache');
              _cacheController.clearAllCache();
            },
          )),
      const ItemSpace(),
      Obx(() => SelectorSettingItem(
            title: L10n.of(context).proxy,
            selector:
                getProxyTypeModeMap(context)[_ehSettingService.proxyType] ?? '',
            onTap: () {
              Get.toNamed(
                EHRoutes.proxySetting,
                id: isLayoutLarge ? 2 : null,
              );
            },
            hideDivider: true,
          )),
      // TextSwitchItem(
      //   L10n.of(context).domain_fronting,
      //   value: _dnsService.enableDomainFronting,
      //   onChanged: _handleDFChanged,
      //   desc: 'By pass SNI',
      // ),

      // Obx(() => SelectorSettingItem(
      //       title: L10n.of(context).custom_hosts,
      //       selector: _dnsService.enableCustomHosts
      //           ? L10n.of(context).on
      //           : L10n.of(context).off,
      //       onTap: () {
      //         if (!_dnsService.enableDomainFronting) {
      //           return;
      //         }
      //         Get.toNamed(
      //           EHRoutes.customHosts,
      //           id: isLayoutLarge ? 2 : null,
      //         );
      //       },
      //       titleColor: !_dnsService.enableDomainFronting
      //           ? CupertinoColors.secondaryLabel
      //           : null,
      //       hideDivider: true,
      //     )),
      // TextSwitchItem(
      //   'DNS-over-HTTPS',
      //   intValue: _dnsConfigController.enableDoH.value,
      //   onChanged: _handleDoHChanged,
      //   desc: '优先级低于自定义hosts',
      // ),
      const ItemSpace(),
      // webDAVMaxConnections
      _buildWebDAVMaxConnectionsItem(context, hideDivider: true),
      const ItemSpace(),
      TextSwitchItem(
        L10n.of(context).vibrate_feedback,
        value: _ehSettingService.vibrate.value,
        onChanged: (bool val) => _ehSettingService.vibrate.value = val,
        hideDivider: true,
      ),
      const ItemSpace(),

      TextItem(
        L10n.of(context).export_app_data,
        subTitle: L10n.of(context).export_app_data_summary,
        onTap: () async {
          // exportAppDataToFile(base64: !kDebugMode);
          exportAppDataToFile();
        },
      ),

      TextItem(
        L10n.of(context).import_app_data,
        subTitle: L10n.of(context).import_app_data_summary,
        onTap: () async {
          importAppDataFromFile();
        },
        hideDivider: true,
      ),
      const ItemSpace(),
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
        TextSwitchItem(
          L10n.of(context).native_http_client_adapter,
          value: _ehSettingService.nativeHttpClientAdapter,
          onChanged: (bool val) =>
              _ehSettingService.nativeHttpClientAdapter = val,
        ),
      SelectorSettingItem(
        title: 'Log',
        onTap: () {
          Get.toNamed(
            EHRoutes.logfile,
            id: isLayoutLarge ? 2 : null,
          );
        },
      ),
      TextSwitchItem(
        'Log debugMode',
        value: _ehSettingService.debugMode,
        onChanged: (bool val) => _ehSettingService.debugMode = val,
        hideDivider: true,
      ),
    ];

    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (BuildContext context, int index) {
        return _list[index];
      },
    );
  }
}

Widget _buildWebDAVMaxConnectionsItem(BuildContext context,
    {bool hideDivider = false}) {
  final String _title = L10n.of(context).webdav_max_connections;
  final EhSettingService ehSettingService = Get.find();

  // map from EHConst.webDAVConnections
  final Map<int, String> actionMap = Map.fromEntries(
      EHConst.webDAVConnections.map((e) => MapEntry(e, e.toString())));

  return Obx(() {
    return SelectorItem<int>(
      title: _title,
      hideDivider: hideDivider,
      actionMap: actionMap,
      initVal: ehSettingService.webDAVMaxConnections,
      onValueChanged: (val) => ehSettingService.webDAVMaxConnections = val,
    );
  });
}
