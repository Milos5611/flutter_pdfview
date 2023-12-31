// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#import "FlutterPDFView.h"
#import "SearchResult.h"

@implementation FLTPDFViewFactory {
    NSObject <FlutterBinaryMessenger> *_messenger;
}

- (instancetype)initWithMessenger:(NSObject <FlutterBinaryMessenger> *)messenger {
    self = [super init];
    if (self) {
        _messenger = messenger;
    }
    return self;
}

- (NSObject <FlutterMessageCodec> *)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject <FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                     viewIdentifier:(int64_t)viewId
                                          arguments:(id _Nullable)args {
    FLTPDFViewController *pdfviewController = [[FLTPDFViewController alloc] initWithFrame:frame
                                                                           viewIdentifier:viewId
                                                                                arguments:args
                                                                          binaryMessenger:_messenger];
    return pdfviewController;
}

@end

@implementation FLTPDFViewController {
    FLTPDFView *_pdfView;
    int64_t _viewId;
    FlutterMethodChannel *_channel;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject <FlutterBinaryMessenger> *)messenger {
    self = [super init];
    _pdfView = [[FLTPDFView new] initWithFrame:frame arguments:args controler:self];
    _viewId = viewId;

    NSString *channelName = [NSString stringWithFormat:@"plugins.endigo.io/pdfview_%lld", viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
    __weak __typeof__(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        [weakSelf onMethodCall:call result:result];
    }];

    return self;
}

- (void)onMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([[call method] isEqualToString:@"pageCount"]) {
        [_pdfView getPageCount:call result:result];
    } else if ([[call method] isEqualToString:@"currentPage"]) {
        [_pdfView getCurrentPage:call result:result];
    } else if ([[call method] isEqualToString:@"setPage"]) {
        [_pdfView setPage:call result:result];
    } else if ([[call method] isEqualToString:@"updateSettings"]) {
        [_pdfView onUpdateSettings:call result:result];
    } else if ([[call method] isEqualToString:@"highlightSearchText"]) {
        [_pdfView highlightSearchText:call result:result];
        result(nil);
    } else if ([[call method] isEqualToString:@"searchPdfTextForText"]) {
        [_pdfView searchPdfTextForText:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)invokeChannelMethod:(NSString *)name arguments:(id)args {
    [_channel invokeMethod:name arguments:args];
}

- (UIView *)view {
    return _pdfView;
}

@end

@implementation FLTPDFView {
    FLTPDFViewController *_controler;
    PDFView *_pdfView;
    NSNumber *_pageCount;
    NSNumber *_currentPage;
    PDFDestination *_currentDestination;
    BOOL _preventLinkNavigation;
    BOOL _autoSpacing;
    PDFPage *_defaultPage;
    BOOL _defaultPageSet;
}

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(id _Nullable)args
                    controler:(nonnull FLTPDFViewController

*)controler {
    if ([super init]) {
        _controler = controler;

        _pdfView = [[PDFView alloc] initWithFrame:frame];
        _pdfView.delegate = self;

        _autoSpacing = [args[@"autoSpacing"] boolValue];
        BOOL pageFling = [args[@"pageFling"] boolValue];
        BOOL enableSwipe = [args[@"enableSwipe"] boolValue];
        _preventLinkNavigation = [args[@"preventLinkNavigation"] boolValue];

        NSInteger defaultPage = [args[@"defaultPage"] integerValue];

        NSString *filePath = args[@"filePath"];
        FlutterStandardTypedData *pdfData = args[@"pdfData"];

        PDFDocument *document;
        if ([filePath isKindOfClass:[NSString class]]) {
            NSURL *sourcePDFUrl = [NSURL fileURLWithPath:filePath];
            document = [[PDFDocument alloc] initWithURL:sourcePDFUrl];
        } else if ([pdfData isKindOfClass:[FlutterStandardTypedData class]]) {
            NSData *sourcePDFdata = [pdfData data];
            document = [[PDFDocument alloc] initWithData:sourcePDFdata];
        }


        if (document == nil) {
            [_controler invokeChannelMethod:@"onError" arguments:@{
                    @"error": @"cannot create document: File not in PDF format or corrupted."}];
        } else {
            // [document findString:@"" withOptions:NSCaseInsensitiveSearch];

            _pdfView.autoresizesSubviews = true;
            _pdfView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _pdfView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];

            BOOL swipeHorizontal = [args[@"swipeHorizontal"] boolValue];
            if (swipeHorizontal) {
                _pdfView.displayDirection = kPDFDisplayDirectionHorizontal;
            } else {
                _pdfView.displayDirection = kPDFDisplayDirectionVertical;
            }

            _pdfView.autoScales = _autoSpacing;

            [_pdfView usePageViewController:pageFling withViewOptions:nil];
            _pdfView.displayMode = enableSwipe ? kPDFDisplaySinglePageContinuous : kPDFDisplaySinglePage;
            _pdfView.document = document;

            _pdfView.maxScaleFactor = 4.0;
            _pdfView.minScaleFactor = _pdfView.scaleFactorForSizeToFit;

            NSString *password = args[@"password"];
            if ([password isKindOfClass:[NSString class]] && [_pdfView.document isEncrypted]) {
                [_pdfView.document unlockWithPassword:password];
            }

            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
            tapGestureRecognizer.numberOfTapsRequired = 2;
            tapGestureRecognizer.numberOfTouchesRequired = 1;
            [_pdfView addGestureRecognizer:tapGestureRecognizer];

            NSUInteger pageCount = [document pageCount];

            if (pageCount <= defaultPage) {
                defaultPage = pageCount - 1;
            }

            _defaultPage = [document pageAtIndex:defaultPage];
            __weak __typeof__(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf handleRenderCompleted:[NSNumber numberWithUnsignedLong:[document pageCount]]];
            });
        }

        if (@available
        (iOS
        11.0, *)) {
            UIScrollView *_scrollView;

            for (id subview in _pdfView.subviews) {
                if ([subview isKindOfClass:[UIScrollView class]]) {
                    _scrollView = subview;
                }
            }

            _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
            if (@available
            (iOS
            13.0, *)) {
                _scrollView.automaticallyAdjustsScrollIndicatorInsets = NO;
            }
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChanged:) name:PDFViewPageChangedNotification object:_pdfView];
        [self addSubview:_pdfView];

    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _pdfView.frame = self.frame;
    _pdfView.minScaleFactor = _pdfView.scaleFactorForSizeToFit;
    _pdfView.maxScaleFactor = 4.0;
    if (_autoSpacing) {
        _pdfView.scaleFactor = _pdfView.scaleFactorForSizeToFit;
    }

    if (!_defaultPageSet && _defaultPage != nil) {
        [_pdfView goToPage:_defaultPage];
        _defaultPageSet = true;
    }
}

- (UIView *)view {
    return _pdfView;
}


- (void)getPageCount:(FlutterMethodCall *)call result:(FlutterResult)result {
    _pageCount = [NSNumber numberWithUnsignedLong:[[_pdfView document] pageCount]];
    result(_pageCount);
}

- (void)getCurrentPage:(FlutterMethodCall *)call result:(FlutterResult)result {
    _currentPage = [NSNumber numberWithUnsignedLong:[_pdfView.document indexForPage:_pdfView.currentPage]];
    result(_currentPage);
}

- (void)setPage:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary < NSString * , NSNumber * > *arguments = [call arguments];
    NSNumber *page = arguments[@"page"];

    [_pdfView goToPage:[_pdfView.document pageAtIndex:page.unsignedLongValue]];
    result([NSNumber numberWithBool:YES]);
}

- (void)onUpdateSettings:(FlutterMethodCall *)call result:(FlutterResult)result {
    result(nil);
}

- (void)handlePageChanged:(NSNotification *)notification {
    [_controler invokeChannelMethod:@"onPageChanged" arguments:@{
            @"page": [NSNumber numberWithUnsignedLong:[_pdfView.document indexForPage:_pdfView.currentPage]],
            @"total": [NSNumber numberWithUnsignedLong:[_pdfView.document pageCount]]}];
}

- (void)handleRenderCompleted:(NSNumber *)pages {
    [_controler invokeChannelMethod:@"onRender" arguments:@{@"pages": pages}];
}

- (void)PDFViewWillClickOnLink:(PDFView *)sender
                       withURL:(NSURL *)url {
    if (!_preventLinkNavigation) {
        [[UIApplication sharedApplication] openURL:url];
    }
    [_controler invokeChannelMethod:@"onLinkHandler" arguments:url.absoluteString];
}

- (void)onDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if ([_pdfView scaleFactor] == _pdfView.scaleFactorForSizeToFit) {
            CGPoint point = [recognizer locationInView:_pdfView];
            PDFPage *page = [_pdfView pageForPoint:point nearest:YES];
            PDFPoint pdfPoint = [_pdfView convertPoint:point toPage:page];
            PDFRect rect = [page boundsForBox:kPDFDisplayBoxMediaBox];
            PDFDestination *destination = [[PDFDestination alloc] initWithPage:page atPoint:CGPointMake(
                    pdfPoint.x - (rect.size.width / 4), pdfPoint.y + (rect.size.height / 4))];
            [UIView animateWithDuration:0.2 animations:^{
                self->_pdfView.scaleFactor = self->_pdfView.scaleFactorForSizeToFit * 2;
                [self->_pdfView goToDestination:destination];
            }];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self->_pdfView.scaleFactor = self->_pdfView.scaleFactorForSizeToFit;
            }];
        }
    }
}

- (void)searchPdfTextForText:(FlutterMethodCall *)call result:(FlutterResult)result {
    // Create a PDFDocument from the PDF file URL.
    PDFDocument *pdfDocument = _pdfView.document;
    NSDictionary < NSString * , NSString * > *arguments = [call arguments];
    NSString *searchText = arguments[@"searchText"];

    // Create an array to store the found selections.
    NSMutableArray<SearchResult *> *foundSelections = [NSMutableArray array];
//    NSArray <PDFSelection *> *searchResults = [pdfDocument findString:searchText withOptions:NSCaseInsensitiveSearch];
    // Convert custom objects to dictionaries
    NSMutableArray *searchResultsDicts = [NSMutableArray array];
    // Iterate through each page in the PDF document.
    for (NSInteger pageIndex = 0; pageIndex < pdfDocument.pageCount; pageIndex++) {
        PDFPage *pdfPage = [pdfDocument pageAtIndex:pageIndex];

        // Extract the text content from the PDF page.
        NSString *pageText = [pdfPage string];

        // Search for the specified text in the page text.
        NSRange range = [pageText rangeOfString:searchText options:NSCaseInsensitiveSearch];

        if (range.location != NSNotFound) {
            NSUInteger startIndex = (range.location >= 40) ? range.location - 40 : 0;
            NSUInteger endIndex = (range.location + range.length + 40 <= pageText.length) ? range.location + range.length + 40 : pageText.length;
            NSString *cutString = [pageText substringWithRange:NSMakeRange(startIndex, endIndex - startIndex)];

           // Create a custom SearchResult object
            NSDictionary *result = @{@"text": cutString, @"page": @(pageIndex)};
           [foundSelections addObject:result];
        }
    }

    result(foundSelections);
}

- (void)highlightSearchText:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSUInteger pageIndex;
    PDFDocument *pdfDocument = _pdfView.document;
    NSDictionary < NSString * , NSString * > *arguments = [call arguments];
    NSString *searchText = arguments[@"text"];
    [self removeSearchHighlights];

    NSMutableArray *allSelections = [NSMutableArray array];

    for (pageIndex = 0; pageIndex < pdfDocument.pageCount; pageIndex++) {
        PDFPage *pdfPage = [pdfDocument pageAtIndex:pageIndex];
        NSArray < PDFSelection * > *searchResults = [pdfDocument findString:searchText withOptions:NSCaseInsensitiveSearch];

        for (PDFSelection *selection in searchResults) {
            PDFAnnotation *annotation = [[PDFAnnotation alloc] initWithBounds:[selection boundsForPage:pdfPage] forType:PDFAnnotationSubtypeHighlight withProperties:nil];
            annotation.color = [UIColor colorWithRed:0.96 green:0.93 blue:0.76 alpha:1.00]; // Semi-transparent yellow color
            annotation.page = pdfPage;
            [pdfPage addAnnotation:annotation];

            // Set the blending mode for the annotation color
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetBlendMode(context, kCGBlendModeMultiply);
            [annotation drawWithBox:kPDFDisplayBoxMediaBox inContext:context];

            [allSelections addObject:selection];
        }
    }

    _pdfView.highlightedSelections = allSelections;

    // Set the page to the first occurrence of the search text
    PDFSelection *firstOccurrence = [self findFirstOccurrenceOfSearchText:searchText inDocument:pdfDocument];
    if (firstOccurrence) {
        PDFPage *firstOccurrencePage = firstOccurrence.pages[0];
        [_pdfView goToPage:firstOccurrencePage];
    }

    result([NSNumber numberWithBool:YES]);
}


- (PDFSelection *)findFirstOccurrenceOfSearchText:(NSString *)searchText inDocument:(PDFDocument *)pdfDocument {
    for (NSUInteger pageIndex = 0; pageIndex < pdfDocument.pageCount; pageIndex++) {
        PDFPage *pdfPage = [pdfDocument pageAtIndex:pageIndex];
        NSArray < PDFSelection * >
        *searchResults = [pdfDocument findString:searchText withOptions:NSCaseInsensitiveSearch];

        if ([searchResults count] > 0) {
            return [searchResults objectAtIndex:0];
        }
    }
    return nil;
}


- (void)removeSearchHighlights {
    for (NSUInteger pageIndex = 0; pageIndex < _pdfView.document.pageCount; pageIndex++) {
        PDFPage *pdfPage = [_pdfView.document pageAtIndex:pageIndex];
        NSArray < PDFAnnotation * > *annotations = [pdfPage annotations];

        // Iterate through the annotations and remove them if they are highlights
        NSMutableArray < PDFAnnotation * > *annotationsToRemove = [NSMutableArray array];
        for (PDFAnnotation *annotation in annotations) {
            if ([annotation.type isEqualToString:@"Highlight"]) {
                [annotationsToRemove   addObject:annotation];
            }
        }
        for (PDFAnnotation *annotation in annotationsToRemove) {
            [pdfPage removeAnnotation:annotation];
        }
    }
}


@end
