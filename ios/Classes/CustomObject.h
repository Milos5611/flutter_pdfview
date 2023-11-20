//
//  CustomObject.h
//  flutter_pdfview
//
//  Created by Milos Nikolic on 20.11.23..
//

#ifndef CustomObject_h
#define CustomObject_h

@interface CustomObject : NSObject

@property (nonatomic, strong) NSString *selectedText;
@property (nonatomic, assign) NSInteger pageNumber;

- (instancetype)initWithSelectedText:(NSString *)text pageNumber:(NSInteger)page;

@end

@implementation CustomObject

- (instancetype)initWithSelectedText:(NSString *)text pageNumber:(NSInteger)page {
    self = [super init];
    if (self) {
        self.selectedText = text;
        self.pageNumber = page;
    }
    return self;
}

@end


#endif /* CustomObject_h */
