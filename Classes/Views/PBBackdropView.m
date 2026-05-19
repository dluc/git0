//
//  PBBackdropView.m
//  GitX
//

#import "PBBackdropView.h"
#import "PBGitDefaults.h"

@implementation PBBackdropView

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) [self pb_setUp];
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) [self pb_setUp];
	return self;
}

static NSString * const kSolidOverlayID = @"PBBackdropSolidOverlay";

- (void)pb_setUp
{
	self.material     = NSVisualEffectMaterialSidebar;
	self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
	self.state        = NSVisualEffectStateFollowsWindowActiveState;

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(pb_prefsChanged:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	[self pb_updateSolidOverlay];
}

- (void)pb_prefsChanged:(NSNotification *)note
{
	[self pb_updateSolidOverlay];
}

- (void)pb_updateSolidOverlay
{
	for (NSView *v in [self.subviews copy]) {
		if ([v.identifier isEqualToString:kSolidOverlayID])
			[v removeFromSuperview];
	}

	if ([PBGitDefaults isTranslucentUI])
		return;

	NSVisualEffectView *overlay = [[NSVisualEffectView alloc] init];
	overlay.identifier   = kSolidOverlayID;
	overlay.material     = NSVisualEffectMaterialSidebar;
	overlay.blendingMode = NSVisualEffectBlendingModeWithinWindow;
	overlay.state        = NSVisualEffectStateActive;
	overlay.translatesAutoresizingMaskIntoConstraints = NO;
	[self addSubview:overlay positioned:NSWindowBelow relativeTo:self.subviews.firstObject];

	[NSLayoutConstraint activateConstraints:@[
		[overlay.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
		[overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
		[overlay.topAnchor      constraintEqualToAnchor:self.topAnchor],
		[overlay.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
	]];
}

@end
