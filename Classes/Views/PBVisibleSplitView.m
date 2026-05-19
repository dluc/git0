//
//  PBVisibleSplitView.m
//  GitX
//

#import "PBVisibleSplitView.h"

@implementation PBVisibleSplitView

// 6pt uniform divider thickness so vertical column dividers and the
// horizontal diff/staging divider are the same target size for the user.
- (CGFloat)dividerThickness
{
	return 6.0;
}

- (void)drawDividerInRect:(NSRect)rect
{
	// no-op — translucency comes from the sibling NSVisualEffectView.
}

@end
