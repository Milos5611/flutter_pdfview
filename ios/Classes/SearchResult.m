// SearchResult.m
#import "SearchResult.h"

@implementation SearchResult

- (instancetype)initWithPage:(NSString *)text page:(NSInteger)page {
    self = [super init];
    if (self) {
        _page = page;
        _text = [text copy];
    }
    return self;
}

@end
