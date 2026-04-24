//
// Created by cjl on 2018/9/8.
//

#import "UIImage+scale.h"
#import "ImageCompressPlugin.h"

@implementation UIImage (scale)
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
    
    // iOS 26.0+ 호환 — UIGraphicsBeginImageContext가 assert로 앱을 죽이므로
    // UIGraphicsImageRenderer 사용.
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = 1.0;
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
    
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // iOS 26.0+ 호환 — UIGraphicsBeginImageContext → UIGraphicsImageRenderer
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rotatedSize format:format];
    UIImage *newImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGContextRef bitmap = rendererContext.CGContext;
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
        
        //   // Rotate the image context
        CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
        
        // Now, draw the rotated/scaled image into the context
        CGContextScaleCTM(bitmap, 1.0, -1.0);
        CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    }];
    return newImage;
}

@end
