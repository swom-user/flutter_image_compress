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
    format.opaque = YES;
    format.scale = 1.0;
    if (@available(iOS 17.0, *)) {
        format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
    } else if (@available(iOS 12.0, *)) {
        format.prefersExtendedRange = NO;
    }
    return format;
}

// HDR/Extended Range UIImage를 CIContext로 tone-map해 SDR sRGB 8-bit UIImage로
// 정규화. iOS 17+ drawInRect:가 HDR→Standard 렌더러에 그릴 때 검정색으로
// 렌더되는 버그 회피용.
- (UIImage *)bf_normalizedSRGB {
    CGImageRef sourceCGImage = self.CGImage;
    if (!sourceCGImage) {
        return self;
    }
    CIImage *ciImage = [CIImage imageWithCGImage:sourceCGImage];
    if (!ciImage) {
        return self;
    }
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    if (!ciContext) {
        return self;
    }
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!srgb) {
        return self;
    }
    CGImageRef normalized = [ciContext createCGImage:ciImage
                                            fromRect:ciImage.extent
                                              format:kCIFormatRGBA8
                                          colorSpace:srgb];
    CGColorSpaceRelease(srgb);
    if (!normalized) {
        return self;
    }
    UIImage *result = [UIImage imageWithCGImage:normalized
                                          scale:self.scale
                                    orientation:self.imageOrientation];
    CGImageRelease(normalized);
    return result ?: self;
}

-(UIImage *)scaleWithMinWidth: (CGFloat)minWidth minHeight:(CGFloat)minHeight {
    // iOS 26 HDR 카메라 이미지 대응 — scale 전에 SDR sRGB 8-bit로 정규화.
    UIImage *source = [self bf_normalizedSRGB];
    
    float actualHeight = source.size.height;
    float actualWidth = source.size.width;
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
        [source drawInRect:rect];
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
    
    // iOS 26 HDR 이미지 대응 — rotate 전에도 SDR 정규화.
    UIImage *normalized = [oldImage bf_normalizedSRGB];
    
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,normalized.size.width, normalized.size.height)];
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
        CGContextDrawImage(bitmap, CGRectMake(-normalized.size.width / 2, -normalized.size.height / 2, normalized.size.width, normalized.size.height), [normalized CGImage]);
    }];
    return newImage;
}

@end
