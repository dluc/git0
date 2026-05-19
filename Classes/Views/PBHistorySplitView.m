//
//  PBHistorySplitView.m
//  GitX
//

#import "PBHistorySplitView.h"

@implementation PBHistorySplitView

- (CGFloat)dividerThickness { return 6.0; }

- (void)drawDividerInRect:(NSRect)rect
{
	[[NSColor separatorColor] set];
	NSRectFill(rect);
}

@end
