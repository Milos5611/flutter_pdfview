// SearchResult.h
#import <Foundation/Foundation.h>

@interface SearchResult : NSObject

@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;

- (instancetype)initWithPage:(NSInteger)page x:(CGFloat)x y:(CGFloat)y;

@end
