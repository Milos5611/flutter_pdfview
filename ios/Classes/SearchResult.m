// SearchResult.m
#import "SearchResult.h"

@implementation SearchResult

- (instancetype)initWithPage:(NSInteger)page x:(CGFloat)x y:(CGFloat)y {
    self = [super init];
    if (self) {
        _page = page;
        _x = x;
        _y = y;
    }
    return self;
}

@end
