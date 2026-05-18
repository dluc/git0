//
//  PBGrayPanelView.m
//  GitX
//

#import "PBGrayPanelView.h"

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

- (void)pb_setUp
{
	// Match the source-list sidebar exactly: sidebar material, behind-window
	// blending, follows window active state. AppKit handles dark/light mode
	// resolution automatically.
	self.material = NSVisualEffectMaterialSidebar;
	self.blendingMode = NSVisualEffectBlendingModeBehindWindow;
	self.state = NSVisualEffectStateFollowsWindowActiveState;
	self.wantsLayer = YES;
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

- (void)viewDidChangeEffectiveAppearance
{
	[super viewDidChangeEffectiveAppearance];
	// separatorColor resolves to different RGBA in dark mode; refresh the
	// rule layer's cached CGColor.
	if (self.rightRule) {
		self.rightRule.layer.backgroundColor = [NSColor separatorColor].CGColor;
	}
}

@end
