//
//  PBHistorySplitView.m
//  GitX
//

#import "PBHistorySplitView.h"
#import "PBGitDefaults.h"

@implementation PBHistorySplitView

- (void)awakeFromNib
{
	[super awakeFromNib];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(pb_prefsChanged:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
}

- (void)pb_prefsChanged:(NSNotification *)note
{
	[self setNeedsDisplay:YES];
}

- (CGFloat)dividerThickness { return 6.0; }

- (void)drawDividerInRect:(NSRect)rect
{
	// No-op — the PBBackdropView behind the history view provides the
	// correct surface in both solid and translucent mode.
}

@end
