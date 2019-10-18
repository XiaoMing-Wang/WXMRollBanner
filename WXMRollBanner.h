//
//  AViews.h
//  类库
//
//  Created by Mac on 16/9/12.
//  Copyright © 2016年 WQ. All rights reserved.
//
#import <UIKit/UIKit.h>

@protocol WXMRollBannerTouchProtocol <NSObject>
- (void)wxmRollBannertouchEvents:(NSInteger)index;
- (void)wxmRollBannerEvents:(id)object;
@end

typedef enum {
    PositionNone,         /** 默认 == PositionBottomCenter */
    PositionHide,         /** 隐藏 */
    PositionTopCenter,    /** 中上 */
    PositionBottomLeft,   /** 左下 */
    PositionBottomCenter, /** 中下 */
    PositionBottomRight   /** 右下 */
} PageControlPosition;

/** 图片切换的方式 */
typedef enum {
    ChangeModeDefault, /** 轮播滚动 */
    ChangeModeFade     /** 淡入淡出 */
} ChangeMode;

@interface WXMRollBanner : UIView

#pragma mark 属性
@property (nonatomic, copy) NSString *cacheKey;                       /** 缓存key */
@property (nonatomic, weak) id <WXMRollBannerTouchProtocol>delegate;  /** 代理 */
@property (nonatomic, assign) ChangeMode changeMode;                  /** 图片切换的模式 */
@property (nonatomic, assign) PageControlPosition pagePosition;       /** 分页控件位置 */
@property (nonatomic, strong) NSArray *imageArray;                    /** 轮播的图片数组 */
@property (nonatomic, strong) NSArray *describeArray;                 /** 标题 */
@property (nonatomic, assign) NSTimeInterval time;                    /** 停留时间默认为5s，最少2s */
@property (nonatomic, copy) void (^imageClickBlock)(NSInteger index); /** 点击图片后要执行的操作 */

#pragma mark 构造方法
- (instancetype)initWithFrame:(CGRect)frame delegate:(id<WXMRollBannerTouchProtocol>)delegate;

#pragma mark 方法

/** 开启定时器 */
- (void)startTimer;

/** 停止定时器 */
- (void)stopTimer;

/** 设置分页控件指示器的图片 */
- (void)setPageImage:(UIImage *)image andCurrentPageImage:(UIImage *)currentImage;

/** 设置分页控件指示器的颜色 */
- (void)setPageColor:(UIColor *)color andCurrentPageColor:(UIColor *)currentColor;
- (void)setDescribeTextColor:(UIColor *)color font:(UIFont *)font bgColor:(UIColor *)bgColor;

/** 清除沙盒中的图片和plist缓存 */
- (void)clearDiskCache;
@end
