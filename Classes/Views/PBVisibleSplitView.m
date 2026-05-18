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

// The XIB places an NSVisualEffectView (sidebar material) as a sibling
// directly behind this split view, with the same frame. Each pane is
// opaque so it covers the backdrop where it sits; the only gap is the
// divider strip between panes, where the backdrop's translucent gray
// shows through. Painting our own fill here would defeat that, so we
// no-op and let the system divider stay transparent.
- (void)drawDividerInRect:(NSRect)rect
{
	// no-op — translucency comes from the sibling NSVisualEffectView.
}

@end
