import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fehviewer/common/service/ehsetting_service.dart';
import 'package:fehviewer/const/const.dart';
import 'package:fehviewer/extension.dart';
import 'package:fehviewer/network/request.dart';
import 'package:fehviewer/store/db/entity/tag_translat.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../global.dart';

const String kApiUrl =
    'https://api.github.com/repos/EhTagTranslation/Database/releases/latest';
const String kCDNApiUrl =
    'https://ghproxy.homeboyc.cn/https://api.github.com/repos/EhTagTranslation/Database/releases/latest';
const String kCDNPrefix = 'https://ghproxy.homeboyc.cn/';
const int kConnectTimeout = 20000;
const int kReceiveTimeout = 30000;

class TagTransController extends GetxController {
  final EhSettingService ehSettingService = Get.find();

  String? _dbUrl;
  String? _remoteVer;

  List<String?> _namespaces = [];

  @override
  void onInit() {
    super.onInit();
    getNamespace().then((value) {
      logger.d('getNamespace $value');
      return _namespaces = value;
    });
  }

  Future<List<String?>> getNamespace() async {
    return await isarHelper.findAllTagNamespace();
  }

  /// 检查更新
  Future<bool> checkUpdate({bool force = false}) async {
    late final String apiUrl;
    if (ehSettingService.enableTagTranslateCDN) {
      apiUrl = kCDNApiUrl;
    } else {
      apiUrl = kApiUrl;
    }

    final _urlJson = await getGithubApi(apiUrl);
    // 获取发布时间 作为远程版本号
    _remoteVer = _urlJson['published_at']?.trim() as String;

    // 获取当前本地版本
    final String localVer = ehSettingService.tagTranslatVer.value;

    if (_remoteVer == localVer && force == false) {
      return false;
    }

    final List<dynamic> assList = _urlJson['assets'] as List<dynamic>;
    final Map<String, String> assMap = <String, String>{};
    for (final dynamic assets in assList) {
      assMap[assets['name'] as String? ?? ''] =
          assets['browser_download_url'] as String;
    }
    _dbUrl = assMap['db.raw.json.gz'] ?? '';

    if (ehSettingService.enableTagTranslateCDN) {
      _dbUrl = '$kCDNPrefix$_dbUrl';
    }

    logger.d(_dbUrl);
    return true;
  }

  /// 获取数据
  Future<List> _fetchData({bool silence = false}) async {
    logger.t('_fetchData start');

    if (_dbUrl == null) {
      return [];
    }

    final gzFilePath = path.join(Global.appDocPath, 'db.raw.json.gz');
    await ehDownload(url: _dbUrl!, savePath: gzFilePath);
    List<int> bytes = File(gzFilePath).readAsBytesSync();
    List<int> data = GZipDecoder().decodeBytes(bytes);
    final String dbJson = utf8.decode(data);

    final dbDataMap = jsonDecode(dbJson);
    final List listData = dbDataMap['data'] as List;

    final head = dbDataMap['head'] as Map;
    final committer = head['committer'] as Map;
    _remoteVer = committer['when'] as String;
    logger.d('_remoteVer $_remoteVer');

    return listData;
  }

  /// 更新数据库数据
  Future<void> updateDB({bool silence = false}) async {
    List listData = await _fetchData();
    if (listData.isEmpty) {
      return;
    }

    final List<TagTranslat> tagTranslats = <TagTranslat>[];

    for (final data in listData) {
      loggerNoStack.v('${data['namespace']}  ${data['count']}');
      final String _namespace = data['namespace'] as String;
      Map mapC = data['data'] as Map;
      mapC.forEach((key, value) {
        final String _key = key as String;
        final String _name = (value['name'] ?? '') as String;
        final String _intro = (value['intro'] ?? '') as String;
        final String _links = (value['links'] ?? '') as String;

        tagTranslats.add(TagTranslat(
            namespace: _namespace,
            key: _key,
            name: _name,
            intro: _intro,
            links: _links));
      });
    }

    // loggerNoStack.d('tag中文翻译数量 ${tagTranslats.length}');

    // tagTranslatDao.insertAllTagTranslats(tagTranslats);

    // await isarHelper.putAllTagTranslate(tagTranslats);
    await isarHelper.putAllTagTranslateIsolate(tagTranslats);
    ehSettingService.tagTranslatVer.value = _remoteVer ?? '';
  }

  /// 获取翻译结果
  Future<String?> _getTagTransStr(String key, {String? namespace}) async {
    // final TagTranslatDao tagTranslatDao = await _getTagTranslatDao();
    // TagTranslat? tr;
    // if (namespace != null && namespace.isNotEmpty) {
    //   tr = await tagTranslatDao.findTagTranslatByKey(
    //       key.trim(), namespace.trim());
    // } else {
    //   final List<TagTranslat> trans =
    //       await tagTranslatDao.findAllTagTranslatsByKey(key);
    //   if (trans.isNotEmpty) {
    //     tr = trans.last;
    //   }
    // }
    TagTranslat? tr =
        await isarHelper.findTagTranslate(key, namespace: namespace);

    return tr?.nameNotMD ?? key;
  }

  Future<String?> getTranTagWithNameSpase(String tag,
      {String namespace = ''}) async {
    if (tag.contains(':')) {
      final RegExp rpfx = RegExp(r'(\w+):"?([^\$]+)\$?"?');
      final RegExpMatch? rult = rpfx.firstMatch(tag.toLowerCase());
      String _nameSpase = rult?.group(1) ?? '';
      if (_nameSpase.length == 1) {
        _nameSpase = EHConst.prefixToNameSpaceMap[_nameSpase] ?? _nameSpase;
      }

      final String _tag = rult?.group(2) ?? '';
      final String _nameSpaseTran =
          EHConst.translateTagType[_nameSpase] ?? _nameSpase;
      final String _transTag =
          await _getTagTransStr(_tag, namespace: _nameSpase) ?? _tag;

      return '$_nameSpaseTran:$_transTag';
    } else {
      return await _getTagTransStr(tag.toLowerCase(), namespace: namespace);
    }
  }

  /// 自动拆分解析匹配查询tag翻译
  Future<String?> getTranTagWithNameSpaseAuto(String text) async {
    if (!text.trim().contains(' ')) {
      return await getTranTagWithNameSpase(text);
    }
    logger.t(text);
    final array = text.split(RegExp(r'\s+'));
    logger.t(array.map((e) => '[$e]').join(','));

    for (int i = 0; i < array.length; i++) {
      if (array[i].startsWith(RegExp(r'-?\w+:"?'))) {
        if (!RegExp(r'\$"?$').hasMatch(array[i])) {
          final tempArray = array.sublist(i);
          final offset = tempArray
              .indexWhere((element) => RegExp(r'\$"?$').hasMatch(element));
          for (int j = 0; j < offset; j++) {
            array[i] = '${array[i]} ${array[i + 1]}';
            array.removeAt(i + 1);
          }
        }
      }
    }

    logger.t(array.map((e) => '[$e]').join(''));

    final _translateList = [];
    for (final text in array) {
      final String? translate = await getTranTagWithNameSpase(text);
      _translateList.add(translate ?? text);
    }

    return _translateList.join('   ');
  }

  Future<String?> getTagTranslateText(String text, {String? namespace}) async {
    if (text.contains(':')) {
      final RegExp rpfx = RegExp(r'(\w):(.+)');
      final RegExpMatch? rult = rpfx.firstMatch(text.toLowerCase());
      final String pfx = rult?.group(1) ?? '';
      final String? _nameSpase = EHConst.prefixToNameSpaceMap[pfx];
      final String _tag = rult?.group(2) ?? '';
      final String? _transTag =
          await _getTagTransStr(_tag, namespace: _nameSpase);

      return _transTag != null ? '$pfx:$_transTag' : text;
    } else {
      // logger.d('namespace $namespace');
      String? _tempNamespace;
      if (_namespaces.contains(namespace)) {
        _tempNamespace = namespace;
      }
      return await _getTagTransStr(text.toLowerCase(),
          namespace: _tempNamespace);
    }
  }

  Future<TagTranslat?> getTagTranslate(String text, String namespace) async {
    // final TagTranslatDao tagTranslatDao = await _getTagTranslatDao();
    // final TagTranslat? _translates =
    //     await tagTranslatDao.findTagTranslatByKey(text, namespace);

    final TagTranslat? _translates =
        await isarHelper.findTagTranslate(text, namespace: namespace);

    logger.t(_translates?.intro);
    // 查询code字段
    final qryMap = {};
    final RegExp regCode = RegExp(r'`((\w+\s+?)*\w+)`');
    final matches = regCode.allMatches(_translates?.intro ?? '');
    for (final match in matches) {
      final _ori = match.group(1);
      if (_ori != null) {
        final _translateCode = await getTagTranslateText(_ori);
        if (_translateCode != null && _translateCode != _ori) {
          qryMap[_ori] = _translateCode;
        }
      }
    }

    final _intro = _translates?.intro?.replaceAllMapped(
        regCode, (match) => ' `${qryMap[match.group(1)]}(${match.group(1)})` ');
    logger.t(_intro);

    return _translates?.copyWith(intro: _intro);
  }

  Future<List<TagTranslat>> getTagTranslatesLike(
      {String text = '', int limit = 100}) async {
    logger.d('getTagTranslatesLike $text');
    if (text.isEmpty) {
      return [];
    }
    // final TagTranslatDao tagTranslatDao = await _getTagTranslatDao();

    // final List<TagTranslat> _translates = await tagTranslatDao
    //     .findTagTranslatsWithLike('%$text%', '%$text%', '%$text%', limit);

    final List<TagTranslat> _translates =
        await isarHelper.findTagTranslateContains(text, limit);

    return _translates;
  }

  Future<void> tapTagTranslate(TagTranslat tagTranslat) async {
    await isarHelper.tapTagTranslate(tagTranslat);
  }
}
