import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:fehviewer/pages/image_view/view/view_page.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:fehviewer/widget/preload_photo_view_gallery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:preload_page_view/preload_page_view.dart';

import '../common.dart';
import '../controller/view_controller.dart';
import 'view_image.dart';

class ImagePageView extends GetView<ViewExtController> {
  const ImagePageView({Key? key, this.reverse = false}) : super(key: key);
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final imageView = GetBuilder<ViewExtController>(
      id: idSlidePage,
      builder: (logic) {
        logger.t('logic.pageViewType ${logic.pageViewType}');

        if (logic.vState.columnMode != ViewColumnMode.single) {
          return _buildDoubleView(logic, context);
        } else {
          return _buildSingleView(logic, context);
        }
      },
    );

    // return imageView;

    // 上下滑动图片 返回
    return ExtendedImageSlidePage(
      child: imageView,
      slideAxis: SlideAxis.vertical,
      slideType: SlideType.wholePage,
      resetPageDuration: const Duration(milliseconds: 300),
      slidePageBackgroundHandler: (Offset offset, Size pageSize) {
        double opacity = 0.0;
        opacity = offset.distance /
            (Offset(pageSize.width, pageSize.height).distance / 2.0);
        return CupertinoColors.systemBackground.darkColor
            .withOpacity(min(1.0, max(1.0 - opacity, 0.0)));
      },
      onSlidingPage: (ExtendedImageSlidePageState state) {
        if (controller.vState.showBar) {
          controller.vState.showBar = !state.isSliding;
          controller.update([idViewBar]);
        }
      },
    );
  }

  /// 单页模式
  Widget _buildSingleView(ViewExtController logic, BuildContext context) {
    /// 单页模式
    switch (logic.pageViewType) {
      case PageViewType.photoView:

        /// PhotoView 的看图组件
        /// 存在的问题 子组件和 PhotoViewGallery 没有直接关联
        /// 双击放大图片（子组件的功能）后，PhotoViewGallery 左右滑动时会直接翻页
        /// 需要双指放大图片（PhotoViewGallery），左右滑动才会滑动图片本身
        return PhotoViewGallery.builder(
            backgroundDecoration:
                const BoxDecoration(color: Colors.transparent),
            pageController: logic.pageController,
            itemCount: logic.vState.pageCount,
            onPageChanged: (pageIndex) =>
                controller.handOnPageChanged(pageIndex),
            scrollDirection: Axis.horizontal,
            customSize: context.mediaQuery.size,
            scrollPhysics: const CustomScrollPhysics(),
            reverse: reverse,
            builder: (BuildContext context, int pageIndex) {
              return PhotoViewGalleryPageOptions.customChild(
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 5,
                controller: logic.photoViewController,
                child: ViewImage(
                  imageSer: pageIndex + 1,
                ),
              );
            });
      case PageViewType.preloadPhotoView:

        /// PreloadPhotoView 的看图组件 有预加载功能
        return PreloadPhotoViewGallery.builder(
            backgroundDecoration:
                const BoxDecoration(color: Colors.transparent),
            pageController: logic.preloadPageController,
            itemCount: logic.vState.pageCount,
            onPageChanged: (pageIndex) =>
                controller.handOnPageChanged(pageIndex),
            scrollDirection: Axis.horizontal,
            customSize: context.mediaQuery.size,
            scrollPhysics: const CustomScrollPhysics(),
            reverse: reverse,
            preloadPagesCount:
                max(0, logic.vState.ehSettingService.preloadImage.value),
            builder: (BuildContext context, int pageIndex) {
              return PhotoViewGalleryPageOptions.customChild(
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 5,
                controller: logic.photoViewController,
                childSize: context.mediaQuery.size * 2,
                child: ViewImage(
                  imageSer: pageIndex + 1,
                  mode: ExtendedImageMode.none,
                  // enableSlideOutPage: !GetPlatform.isAndroid,
                  enableSlideOutPage: false,
                ),
              );
            });
      case PageViewType.preloadPageView:

        /// 预渲染的PageView
        /// 可以无缝的进行翻页，可设置预载页范围
        /// 但是不能把图片缩得比原来小
        return PreloadPageView.builder(
          controller: logic.preloadPageController,
          physics: const CustomScrollPhysics(),
          reverse: reverse,
          itemCount: logic.vState.pageCount,
          scrollDirection: Axis.horizontal,
          preloadPagesCount:
              max(0, logic.vState.ehSettingService.preloadImage.value),
          onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
          itemBuilder: (BuildContext context, int index) {
            logger.t('pageIndex $index ser ${index + 1}');

            return Obx(() {
              logic.vState.showPageInterval;
              return AnimatedContainer(
                duration: 200.milliseconds,
                padding: logic.vState.showPageInterval
                    ? const EdgeInsets.symmetric(horizontal: 2)
                    : null,
                child: ViewImage(
                  imageSer: index + 1,
                  mode: ExtendedImageMode.gesture,
                  // enableSlideOutPage: !GetPlatform.isAndroid,
                  enableSlideOutPage: false,
                ),
              );
            });
          },
        );
      case PageViewType.extendedImageGesturePageView:

        /// ExtendedImageGesturePageView 的看图功能
        /// 存在问题。更新 flutter3 后，Android系统下手势操作异常，不能正常进行滑动
        /// 6.2.1 好像可以滑动了
        return ExtendedImageGesturePageView.builder(
          controller: logic.extendedPageController,
          itemCount: logic.vState.pageCount,
          onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
          scrollDirection: Axis.horizontal,
          physics: const CustomScrollPhysics(),
          reverse: reverse,
          itemBuilder: (BuildContext context, int index) {
            logger.t('pageIndex $index ser ${index + 1}');

            /// 单页
            ///
            ///  20220519 initialScale 设置默认超过1的比例，暂时能解决手势不能滑动的问题
            /// 但是 enableSlideOutPage 的效果会丢失
            ///
            /// 更新：extended_image 6.2.1 好像已经解决  不设置超过 1.0 的 initialScale也能滑动了
            return ViewImage(
              imageSer: index + 1,
              // enableDoubleTap: false,
              // initialScale:
              //     logic.vState.showPageInterval ? 1.000001 : 1.000001,
              // initialScale: GetPlatform.isAndroid ? 1.000001 : 1.0,
              mode: ExtendedImageMode.gesture,
              // enableSlideOutPage: !GetPlatform.isAndroid,
              enableSlideOutPage: false,
            );
          },
        );
    }
  }

  /// 双页模式
  Widget _buildDoubleView(ViewExtController logic, BuildContext context) {
    switch (logic.pageViewType) {
      /// ExtendedImageGesturePageView 目前实现的双页模式问题较多，手势功能难搞
      /// 所以不使用 ExtendedImageGesturePageView
      /// 在 PageViewType.extendedImageGesturePageView 时
      /// 依然使用 PageViewType.preloadPageView 的方式
      /// 但是需要在控制器上增加判断 避免使用 extendedPageController 进行页码操作
      case PageViewType.extendedImageGesturePageView: // 兼容模式

      // return ExtendedImageGesturePageView.builder(
      //   controller: logic.extendedPageController,
      //   itemCount: logic.vState.pageCount,
      //   onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
      //   scrollDirection: Axis.horizontal,
      //   physics: const CustomScrollPhysics(),
      //   reverse: reverse,
      //   itemBuilder: (BuildContext context, int pageIndex) {
      //     // 双页
      //     return DoublePageView(
      //       pageIndex: pageIndex,
      //       key: ValueKey(controller.vState.columnMode),
      //     );
      //   },
      // );

      case PageViewType.preloadPageView: // 非兼容模式
        logger.d('preloadPageView');
        Widget doubleView(int pageIndex) {
          return PhotoViewGallery.builder(
            backgroundDecoration:
                const BoxDecoration(color: Colors.transparent),
            itemCount: 1,
            builder: (_, __) {
              return PhotoViewGalleryPageOptions.customChild(
                scaleStateController: controller.photoViewScaleStateController,
                initialScale: PhotoViewComputedScale.contained * 1.0,
                minScale: PhotoViewComputedScale.contained * 1.0,
                maxScale: PhotoViewComputedScale.contained * 2.0,
                scaleStateCycle: lisviewScaleStateCycle,
                child: DoublePageView(
                  pageIndex: pageIndex,
                  key: ValueKey(controller.vState.columnMode),
                ),
              );
            },
          );
        }

        //
        return PreloadPageView.builder(
          controller: logic.preloadPageController,
          physics: const CustomScrollPhysics(),
          reverse: reverse,
          itemCount: logic.vState.pageCount,
          scrollDirection: Axis.horizontal,
          preloadPagesCount:
              max(0, logic.vState.ehSettingService.preloadImage.value ~/ 2),
          onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
          itemBuilder: (BuildContext context, int pageIndex) {
            return Obx(() {
              logic.vState.showPageInterval;
              return AnimatedContainer(
                duration: 200.milliseconds,
                padding: logic.vState.showPageInterval
                    ? const EdgeInsets.symmetric(horizontal: 2)
                    : null,
                child: doubleView(pageIndex),
              );
            });
          },
        );

      case PageViewType.preloadPhotoView: // 没有使用
        return PhotoViewGallery.builder(
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          pageController: logic.pageController,
          itemCount: logic.vState.pageCount,
          onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
          scrollDirection: Axis.horizontal,
          customSize: context.mediaQuery.size,
          scrollPhysics: const CustomScrollPhysics(),
          reverse: reverse,
          builder: (BuildContext context, int pageIndex) {
            // 双页
            return PhotoViewGalleryPageOptions.customChild(
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 5,
              controller: logic.photoViewController,
              // scaleStateController: logic.photoViewScaleStateController,
              // disableGestures: true,
              child: DoublePageView(
                pageIndex: pageIndex,
                key: ValueKey(controller.vState.columnMode),
              ),
            );
          },
        );

      case PageViewType.photoView: // 没有使用
        return PhotoViewGallery.builder(
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          pageController: logic.pageController,
          itemCount: logic.vState.pageCount,
          onPageChanged: (pageIndex) => controller.handOnPageChanged(pageIndex),
          scrollDirection: Axis.horizontal,
          customSize: context.mediaQuery.size,
          scrollPhysics: const CustomScrollPhysics(),
          reverse: reverse,
          builder: (BuildContext context, int pageIndex) {
            // 双页
            return PhotoViewGalleryPageOptions.customChild(
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 5,
              controller: logic.photoViewController,
              child: DoublePageView(
                pageIndex: pageIndex,
                key: ValueKey(controller.vState.columnMode),
              ),
            );
          },
        );
    }
  }
}
