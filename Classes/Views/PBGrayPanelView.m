//
//  PBGrayPanelView.m
//  GitX
//

#import "PBGrayPanelView.h"
#import "PBGitDefaults.h"

@interface PBGrayPanelView ()
@property (strong) NSView *rightRule;
@end

@implementation PBGrayPanelView

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self pb_setUp];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self pb_setUp];
	}
	return self;
}

static NSString * const kSolidOverlayID = @"PBSolidOverlay";

- (void)pb_setUp
{
	// NSVisualEffectView always stays in translucent mode.
	// A solid opaque overlay is added/removed on top of the blur to
	// simulate the solid state without needing a view restart.
	self.wantsLayer   = YES;
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
	// Remove any existing overlay first.
	for (NSView *v in [self.subviews copy]) {
		if ([v.identifier isEqualToString:kSolidOverlayID])
			[v removeFromSuperview];
	}

	if ([PBGitDefaults isTranslucentUI])
		return;

	// Use a within-window visual effect view — same material, no desktop blur.
	// This gives the correct solid sidebar gray in both light and dark mode,
	// automatically, without hardcoding any color.
	NSVisualEffectView *overlay = [[NSVisualEffectView alloc] init];
	overlay.identifier    = kSolidOverlayID;
	overlay.material      = NSVisualEffectMaterialSidebar;
	overlay.blendingMode  = NSVisualEffectBlendingModeWithinWindow;
	overlay.state         = NSVisualEffectStateActive;
	overlay.translatesAutoresizingMaskIntoConstraints = NO;

	NSView *firstContent = nil;
	for (NSView *v in self.subviews) {
		if (![v.identifier isEqualToString:kSolidOverlayID]) { firstContent = v; break; }
	}
	if (firstContent)
		[self addSubview:overlay positioned:NSWindowBelow relativeTo:firstContent];
	else
		[self addSubview:overlay];

	[NSLayoutConstraint activateConstraints:@[
		[overlay.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
		[overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
		[overlay.topAnchor      constraintEqualToAnchor:self.topAnchor],
		[overlay.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
	]];
}

- (void)viewDidChangeEffectiveAppearance
{
	[super viewDidChangeEffectiveAppearance];
	if (self.rightRule)
		self.rightRule.layer.backgroundColor = [NSColor separatorColor].CGColor;
}

- (void)setRightSeparatorWidth:(CGFloat)rightSeparatorWidth
{
	if (_rightSeparatorWidth == rightSeparatorWidth) return;
	_rightSeparatorWidth = rightSeparatorWidth;

	if (rightSeparatorWidth > 0) {
		if (!self.rightRule) {
			NSView *rule = [[NSView alloc] init];
			rule.wantsLayer = YES;
			rule.translatesAutoresizingMaskIntoConstraints = NO;
			rule.layer.backgroundColor = [NSColor separatorColor].CGColor;
			[self addSubview:rule];
			self.rightRule = rule;

			[NSLayoutConstraint activateConstraints:@[
				[rule.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
				[rule.topAnchor constraintEqualToAnchor:self.topAnchor],
				[rule.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
				[rule.widthAnchor constraintEqualToConstant:rightSeparatorWidth],
			]];
		} else {
			// Update the existing width constraint by finding it.
			for (NSLayoutConstraint *c in self.rightRule.constraints) {
				if (c.firstAttribute == NSLayoutAttributeWidth && c.firstItem == self.rightRule) {
					c.constant = rightSeparatorWidth;
					break;
				}
			}
		}
	} else if (self.rightRule) {
		[self.rightRule removeFromSuperview];
		self.rightRule = nil;
	}
}

@end
