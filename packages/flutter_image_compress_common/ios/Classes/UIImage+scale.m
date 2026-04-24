//
// Created by cjl on 2018/9/8.
//

#import "UIImage+scale.h"
#import "ImageCompressPlugin.h"

@implementation UIImage (scale)

// iOS 26 호환 SDR 강제 렌더러 빌더 — HDR/Dolby Vision 메타데이터를 제거해
// 후속 UIImageJPEGRepresentation에서 vImage null-pointer 크래시 방지.
+ (UIGraphicsImageRendererFormat *)bf_sdrRendererFormat {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = 1.0;
    if (@available(iOS 17.0, *)) {
        format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
    } else if (@available(iOS 12.0, *)) {
        format.prefersExtendedRange = NO;
    }
    return format;
}

-(UIImage *)scaleWithMinWidth: (CGFloat)minWidth minHeight:(CGFloat)minHeight {
    float actualHeight = self.size.height;
    float actualWidth = self.size.width;
    float imgRatio = actualWidth/actualHeight;
    float maxRatio = minWidth/minHeight;
    float scaleRatio = 1;
    
    if(imgRatio < maxRatio) {
        scaleRatio = minWidth / actualWidth;
    } else {
        scaleRatio = minHeight / actualHeight;
    }
    scaleRatio = fminf(1, scaleRatio);

    actualWidth = floor(scaleRatio * actualWidth);
    actualHeight = floor(scaleRatio * actualHeight);
    
    CGRect rect = CGRectMake(0.0, 0.0, actualWidth, actualHeight);
    
    // iOS 26.0+ 호환 — UIGraphicsBeginImageContext(assert 크래시) 대신
    // UIGraphicsImageRenderer + SDR preferredRange 사용.
    UIGraphicsImageRendererFormat *format = [UIImage bf_sdrRendererFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format];
    UIImage *newImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [self drawInRect:rect];
    }];
    
    if([ImageCompressPlugin showLog]){
        NSLog(@"scale = %.2f", scaleRatio);
        NSLog(@"dst width = %.2f", rect.size.width);
        NSLog(@"dst height = %.2f", rect.size.height);
    }
    
    return newImage;
}

- (UIImage *)rotate:(CGFloat) rotate{
    return [self imageRotatedByDegrees:self deg:rotate];
}

- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
    if([ImageCompressPlugin showLog]) {
        NSLog(@"will rotate %f",degrees);
    }
    
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // iOS 26.0+ 호환 — SDR 강제 렌더러 사용
    UIGraphicsImageRendererFormat *format = [UIImage bf_sdrRendererFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rotatedSize format:format];
    UIImage *newImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGContextRef bitmap = rendererContext.CGContext;
        CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
        CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
        CGContextScaleCTM(bitmap, 1.0, -1.0);
        CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    }];
    return newImage;
}

@end
