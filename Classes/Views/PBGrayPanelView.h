//
//  PBGrayPanelView.h
//  GitX
//
//  A thin NSVisualEffectView subclass preconfigured with the same
//  translucent "sidebar" material the system uses for source-list
//  backgrounds. Using a vibrant material (rather than a flat layer fill)
//  means the bottom-of-window panel picks up the same blur and tint
//  as the actual sidebar — they read as one continuous surface
//  regardless of where the window is placed over the desktop.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PBGrayPanelView : NSVisualEffectView

/// Pixel-width of a 1pt separator drawn along the right edge. Default 0.
/// Use this to delineate the panel from adjoining content (e.g. the
/// sidebar's right edge against the diff view).
@property (assign) CGFloat rightSeparatorWidth;

@end

NS_ASSUME_NONNULL_END
