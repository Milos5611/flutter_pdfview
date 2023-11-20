// SearchResult.h
#import <Foundation/Foundation.h>
#import "SearchResult.h"

@interface SearchResult : NSObject

@property (nonatomic, assign) NSInteger page;
@property (nonatomic, strong) NSString *text;

- (instancetype)initWithPage:(NSString *)text page:(NSInteger)page;

@end
