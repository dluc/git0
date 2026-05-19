//
//  PBHistorySplitView.h
//  GitX
//
//  The horizontal divider between the commit list and the detail/diff panes.
//  Unlike PBVisibleSplitView, this split sits on a plain window background
//  with no visual-effect backdrop, so it paints its own separator.
//

#import <Cocoa/Cocoa.h>

@interface PBHistorySplitView : NSSplitView
@end
