//
//  AViews.h
//  类库
//
//  Created by Mac on 16/9/12.
//  Copyright © 2016年 WQ. All rights reserved.
#import "RollBanner.h"
#define KWidth [UIScreen mainScreen].bounds.size.width
#define KLibraryboxPath \
NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject

#define DefaultHeight 110 /** 默认高度 */
#define DefaultTime 5     /** 默认时间 */
#define HORMARGIN 10
#define VERMARGIN 5
#define DES_LABEL_H 20 /** 标题栏的高度 */

@interface RollBanner () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableArray *images;      //轮播的图片数组
@property (nonatomic, strong) UILabel *describeLabel;      //图片描述控件，默认在底部
@property (nonatomic, strong) UIScrollView *scrollView;    //滚动视图
@property (nonatomic, strong) UIPageControl *pageControl;  //分页控件
@property (nonatomic, strong) UIImageView *currImageView;  //当前显示的imageView
@property (nonatomic, strong) UIImageView *otherImageView; //滚动显示的imageView
@property (nonatomic, assign) NSInteger currIndex;         //当前显示图片的索引
@property (nonatomic, assign) NSInteger nextIndex;         //将要显示图片的索引
@property (nonatomic, assign) CGSize pageImageSize;        //pageControl图片大小
@property (nonatomic, strong) NSTimer *timer;              //定时器
@property (nonatomic, strong) NSOperationQueue *queue;     //任务队列
@property (nonatomic, strong) UIImage *placeImage;         //占位图
@end

@implementation RollBanner
/** 创建缓存图片的文件夹 */
+ (void)initialize {
    NSFileManager * m = [NSFileManager defaultManager];
    NSString *cache = [KLibraryboxPath stringByAppendingPathComponent:@"RollBannerViewCache"];
    BOOL isDir = NO;
    BOOL isExists = [m fileExistsAtPath:cache isDirectory:&isDir];
    if (!isExists || !isDir) {
        [m createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark __________________________________________________________ 构造方法
- (instancetype)initWithFrame:(CGRect)frame imageArray:(NSArray *)imageArray {
    if (self = [super initWithFrame:frame]) self.imageArray = imageArray;
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame delegate:(id<RollBannerTouchProtocol>)delegate {
    if (self = [super initWithFrame:frame]) self.delegate = delegate;
    return self;
}
+ (instancetype)carouselViewWithImageArray:(NSArray *)imageArray describeArray:(NSArray *)describeArray {
    RollBanner *adView = [[self alloc] initWithFrame:CGRectMake(0, 0, KWidth, DefaultHeight)];
    adView.imageArray = imageArray;
    adView.describeArray = describeArray;
    return adView;
}
#pragma mark __________________________________________________________ 设置相关方法
- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self addSubview:self.scrollView];
    [self addSubview:self.describeLabel];
    [self addSubview:self.pageControl];
}
#pragma mark __________________________________________________________  设置图片数组
- (void)setImageArray:(NSArray<NSObject *> *)imgArray primaryKey:(NSString *)primaryKey {
    if (imgArray.count <= 0) return;
    NSMutableArray * imageArray = @[].mutableCopy;
    [imgArray enumerateObjectsUsingBlock:^(NSObject *obj, NSUInteger idx, BOOL *stop) {
        @try {
            [imageArray addObject:[obj valueForKey:primaryKey]];
        } @catch (NSException *exception) {} @finally {}
    }];
    [self setImageArray:imageArray.mutableCopy];
}

- (void)setImageArray:(NSArray *)imageArray {
    if (imageArray.count == 0) return;
    _imageArray = imageArray;
    _images = [NSMutableArray array];

    [imageArray enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([imageArray[idx] isKindOfClass:[UIImage class]]) {
            [_images addObject:imageArray[idx]];
        } else if ([imageArray[idx] isKindOfClass:[NSString class]]) {
            [_images addObject:_placeImage ?: [UIImage imageNamed:@"loadingad.jpg"]];
            [self downloadImages:idx];
        }
    }];
    
    /** 防止在滚动过程中重新给imageArray赋值时报错 */
    if (_currIndex >= _images.count) _currIndex = _images.count - 1;
    self.currImageView.image = _images[_currIndex];
    self.describeLabel.text = _describeArray[_currIndex];
    self.pageControl.numberOfPages = _images.count;
    [self layoutSubviews];
    
    /** 缓存 */
    if (self.cacheKey.length <= 0) return;
    if ([imageArray.firstObject isKindOfClass:[UIImage class]]) return;
    NSString *cache = [KLibraryboxPath stringByAppendingPathComponent:@"RollBannerViewCache"];
    NSString * plist = [NSString stringWithFormat:@"%@.plist",_cacheKey];
    NSString *filePathName = [cache stringByAppendingPathComponent:plist];
    [imageArray writeToFile:filePathName atomically:YES];
}

#pragma mark __________________________________________________________ 设置描述数组

- (void)setDescribeArray:(NSArray *)describeArray {
    _describeArray = describeArray;
    if (!describeArray.count) {
        _describeArray = nil;
        self.describeLabel.hidden = YES;
    } else {
        /** 如果描述的个数与图片个数不一致，则补空字符串 */
        if (describeArray.count < _images.count) {
            NSMutableArray *describes = [NSMutableArray arrayWithArray:describeArray];
            for (NSInteger i = describeArray.count; i < _images.count; i++) {
                [describes addObject:@""];
            }
            _describeArray = describes;
        }
        self.describeLabel.hidden = NO;
        _describeLabel.text = _describeArray[_currIndex];
    }
    self.pagePosition = self.pagePosition; /** 重新计算pageControl的位置 */
}

#pragma mark __________________________________________________________  contentSize
- (void)setScrollViewContentSize {
    if (_images.count > 1) {
        self.scrollView.contentSize = CGSizeMake(self.width * 4, 0);
        self.scrollView.contentOffset = CGPointMake(self.width * 2, 0);
        self.currImageView.frame = CGRectMake(self.width * 2, 0, self.width, self.height);
        if (_changeMode == ChangeModeFade) {
            /** 淡入淡出模式，两个imageView都在同一位置，改变透明度就可以了 */
            _currImageView.frame = CGRectMake(0, 0, self.width, self.height);
            _otherImageView.frame = self.currImageView.frame;
            _otherImageView.alpha = 0;
            [self insertSubview:self.currImageView atIndex:0];
            [self insertSubview:self.otherImageView atIndex:1];
        }
        [self startTimer];
    } else {
        /** 只要一张图片时，scrollview不可滚动，且关闭定时器 */
        self.scrollView.contentSize = CGSizeZero;
        self.scrollView.contentOffset = CGPointZero;
        self.currImageView.frame = CGRectMake(0, 0, self.width, self.height);
        [self stopTimer];
    }
}

#pragma mark __________________________________________________________  图片描述

- (void)setDescribeTextColor:(UIColor *)color font:(UIFont *)font bgColor:(UIColor *)bgColor {
    if (color) self.describeLabel.textColor = color;
    if (font) self.describeLabel.font = font;
    if (bgColor) self.describeLabel.backgroundColor = bgColor;
}

#pragma mark __________________________________________________________  pageControl的指示器图片

- (void)setPageImage:(UIImage *)image andCurrentPageImage:(UIImage *)currentImage {
    if (!image || !currentImage) return;
    self.pageImageSize = image.size;
    [self.pageControl setValue:currentImage forKey:@"_currentPageImage"];
    [self.pageControl setValue:image forKey:@"_pageImage"];
}

- (void)setPageColor:(UIColor *)color andCurrentPageColor:(UIColor *)currentColor {
    _pageControl.pageIndicatorTintColor = color;
    _pageControl.currentPageIndicatorTintColor = currentColor;
}

- (void)setPagePosition:(PageControlPosition)pagePosition {
    _pagePosition = pagePosition;
    _pageControl.hidden = (_pagePosition == PositionHide) || (_imageArray.count == 1);
    if (_pageControl.hidden) return;

    CGSize size;
    if (!_pageImageSize.width) { /** 没有设置图片，系统原有样式 */
        size = [_pageControl sizeForNumberOfPages:_pageControl.numberOfPages];
        size.height = 8;
    } else { /** 设置图片了 */
        size = CGSizeMake(_pageImageSize.width * (_pageControl.numberOfPages * 2 - 1), _pageImageSize.height);
    }
    _pageControl.frame = CGRectMake(0, 0, size.width, size.height);

    CGFloat centerY = self.height - size.height * 0.5 - VERMARGIN - (_describeLabel.hidden ? 0 : DES_LABEL_H);
    CGFloat pointY = self.height - size.height - VERMARGIN - (_describeLabel.hidden ? 0 : DES_LABEL_H);

    if (_pagePosition == PositionNone || _pagePosition == PositionBottomCenter) {
        _pageControl.center = CGPointMake(self.width * 0.5, centerY);
    } else if (_pagePosition == PositionTopCenter) {
        _pageControl.center = CGPointMake(self.width * 0.5, size.height * 0.5 + VERMARGIN);
    } else if (_pagePosition == PositionBottomLeft) {
        _pageControl.frame = CGRectMake(HORMARGIN, pointY, size.width, size.height);
    } else {
        _pageControl.frame = CGRectMake(self.width - HORMARGIN - size.width, pointY, size.width, size.height);
    }
}
/** 设置缓存key */
- (void)setCacheKey:(NSString *)cacheKey {
    _cacheKey = cacheKey;
    NSString *cache = [KLibraryboxPath stringByAppendingPathComponent:@"RollBannerViewCache"];
    NSString * plist = [NSString stringWithFormat:@"%@.plist",cacheKey];
    NSString *filePathName = [cache stringByAppendingPathComponent:plist];
    NSArray *dataArray = [NSArray arrayWithContentsOfFile:filePathName];
    if ([dataArray isKindOfClass:[NSArray class]] && dataArray.count > 0) {
        self.imageArray = dataArray.mutableCopy;
    } else {
        self.imageArray = @[[UIImage imageNamed:@"loadingad.jpg"]];
    }
}
#pragma mark __________________________________________________________  设置定时器时间

- (void)setTime:(NSTimeInterval)time {
    _time = time;
    [self startTimer];
}

#pragma mark __________________________________________________________  定时器相关方法

- (void)startTimer {
    if (_images.count <= 1) return;
    if (self.timer) [self stopTimer];
    self.timer = [NSTimer timerWithTimeInterval:_time < 2 ? DefaultTime : _time
                                         target:self
                                       selector:@selector(nextPage)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)nextPage {
    if (_changeMode == ChangeModeFade) {
        /** 淡入淡出模式，不需要修改scrollview偏移量，改变两张图片的透明度即可 */
        self.nextIndex = (self.currIndex + 1) % _images.count;
        self.otherImageView.image = _images[_nextIndex];
        
        [UIView animateWithDuration:1.2 animations:^{
            self.currImageView.alpha = 0;
            self.otherImageView.alpha = 1;
            self.pageControl.currentPage = _nextIndex;
        } completion:^(BOOL finished) { [self changeToNext]; }];
    } else {
        [self.scrollView setContentOffset:CGPointMake(self.width * 3, 0) animated:YES];
    }
}

#pragma mark __________________________________________________________ 其它

- (void)layoutSubviews {
    [super layoutSubviews];
    /**  有导航控制器时，会默认在scrollview上方添加64的内边距，这里强制设置为0 */
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.frame = self.bounds;
    _describeLabel.frame = CGRectMake(0, self.height - DES_LABEL_H, self.width, DES_LABEL_H);
    self.pagePosition = self.pagePosition;
    [self setScrollViewContentSize];
}

#pragma mark 图片点击事件
- (void)imageClick {
    if (self.imageClickBlock) self.imageClickBlock(self.currIndex);
    if (self.delegate && [self.delegate respondsToSelector:@selector(rollBannertouchEvents:)]) {
        [self.delegate rollBannertouchEvents:self.currIndex];
    }
}

#pragma mark __________________________________________________________  下载网络图片
- (void)downloadImages:(NSUInteger)index {
    NSString *key = _imageArray[index];
    NSString *path = [[KLibraryboxPath stringByAppendingPathComponent:@"RollBannerViewCache"] stringByAppendingPathComponent:[key lastPathComponent]];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) {
        _images[index] = [UIImage imageWithData:data];
        return;
    }
    //下载图片
    NSBlockOperation *download = [NSBlockOperation blockOperationWithBlock:^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:key]];
        if (!data) return;
        UIImage *image = [UIImage imageWithData:data];
        /** 取到的data有可能不是图片 */
        if (image) {
            self.images[index] = image;
            /** 如果下载的图片为当前要显示的图片，直接到主线程给imageView赋值，否则要等到下一轮才会显示 */
            if (_currIndex == index) {
                [_currImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
            }
            [data writeToFile:path atomically:YES];
        }
    }];
    [self.queue addOperation:download];
}

#pragma mark __________________________________________________________   清除沙盒中的图片缓存
- (void)clearDiskCache {
    NSString *cache = [KLibraryboxPath stringByAppendingPathComponent:@"RollBannerViewCache"];
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cache error:NULL];
    for (NSString *fileName in contents) {
        [[NSFileManager defaultManager] removeItemAtPath:[cache stringByAppendingPathComponent:fileName] error:nil];
    }
}

#pragma mark __________________________________________________________   当图片滚动过半时就修改当前页码

- (void)changeCurrentPageWithOffset:(CGFloat)offsetX {
    if (offsetX < self.width * 1.5) {
        NSInteger index = self.currIndex - 1;
        if (index < 0) index = self.images.count - 1;
        _pageControl.currentPage = index;
    } else if (offsetX > self.width * 2.5) {
        _pageControl.currentPage = (self.currIndex + 1) % self.images.count;
    } else {
        _pageControl.currentPage = self.currIndex;
    }
}

#pragma mark __________________________________________________________  UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (CGSizeEqualToSize(CGSizeZero, scrollView.contentSize)) return;

    CGFloat offsetX = scrollView.contentOffset.x;
    [self changeCurrentPageWithOffset:offsetX]; //滚动过程中改变pageControl的当前页码

    if (offsetX < self.width * 2) {//向右滚动
        if (_changeMode == ChangeModeFade) {
            self.currImageView.alpha = offsetX / self.width - 1;
            self.otherImageView.alpha = 2 - offsetX / self.width;
        } else {
            self.otherImageView.frame = CGRectMake(self.width, 0, self.width, self.height);
        }

        self.nextIndex = self.currIndex - 1;
        if (self.nextIndex < 0) self.nextIndex = _images.count - 1;
        if (offsetX <= self.width) [self changeToNext];

    } else if (offsetX > self.width * 2) { //向左滚动

        if (_changeMode == ChangeModeFade) {
            self.otherImageView.alpha = offsetX / self.width - 2;
            self.currImageView.alpha = 3 - offsetX / self.width;
        } else {
            self.otherImageView.frame =
                CGRectMake(CGRectGetMaxX(_currImageView.frame), 0, self.width,
                           self.height);
        }

        self.nextIndex = (self.currIndex + 1) % _images.count;
        if (offsetX >= self.width * 3) [self changeToNext];
    }
    self.otherImageView.image = self.images[self.nextIndex];
}

/** 这里开始换图 */
- (void)changeToNext {
    if (_changeMode == ChangeModeFade) {
        self.currImageView.alpha = 1;
        self.otherImageView.alpha = 0;
    }
    /** 切换到下一张图片 确保在主线程 可能有其他操作!!!! */
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currImageView.image = self.otherImageView.image;
        self.scrollView.contentOffset = CGPointMake(self.width * 2, 0);
        self.currIndex = self.nextIndex;
        self.pageControl.currentPage = self.currIndex;
        self.describeLabel.text = self.describeArray[self.currIndex];
    });
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self stopTimer];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self startTimer];
}
#pragma mark __________________________________________________________  frame相关

- (CGFloat)height {
    return self.scrollView.frame.size.height;
}
- (CGFloat)width {
    return self.scrollView.frame.size.width;
}
#pragma mark __________________________________________________________  懒加载

- (NSOperationQueue *)queue {
    if (!_queue) _queue = [[NSOperationQueue alloc] init];
    return _queue;
}
- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.pagingEnabled = YES;
        _scrollView.bounces = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.delegate = self;
        [_scrollView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageClick)]];
        _currImageView = [[UIImageView alloc] init];
        [_scrollView addSubview:_currImageView];
        _otherImageView = [[UIImageView alloc] init];
        [_scrollView addSubview:_otherImageView];
    }
    return _scrollView;
}
- (UILabel *)describeLabel {
    if (!_describeLabel) {
        _describeLabel = [[UILabel alloc] init];
        _describeLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
        _describeLabel.textColor = [UIColor whiteColor];
        _describeLabel.textAlignment = NSTextAlignmentCenter;
        _describeLabel.font = [UIFont systemFontOfSize:13];
        _describeLabel.hidden = YES;
    }
    return _describeLabel;
}

- (UIPageControl *)pageControl {
    if (!_pageControl) {
        _pageControl = [[UIPageControl alloc] init];
        _pageControl.userInteractionEnabled = NO;
    }
    return _pageControl;
}

@end

