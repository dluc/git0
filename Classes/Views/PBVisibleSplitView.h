//
//  PBVisibleSplitView.h
//  GitX
//
//  An NSSplitView that paints its dividers with the system separator
//  colour, so they're actually visible against light panel backdrops.
//  The stock thin/thick styles render very close to the panel colour on
//  modern macOS and effectively disappear — making the divider hard to
//  grab. Use this subclass on any split view where the divider needs
//  to read as a real drag handle.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PBVisibleSplitView : NSSplitView
@end

NS_ASSUME_NONNULL_END
