//
//  PBChangedFile.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBChangedFile.h"

@implementation PBChangedFile

@synthesize path, status, hasStagedChanges, hasUnstagedChanges, commitBlobSHA, commitBlobMode;

// Cocoa bindings observe these computed properties via KVO. Without these
// hooks the table cells would not refresh when underlying state changes
// (e.g. staging a NEW file flips its unstagedIcon from "new" to "modified").
+ (NSSet *)keyPathsForValuesAffectingStagedIcon
{
	return [NSSet setWithObjects:@"status", nil];
}

+ (NSSet *)keyPathsForValuesAffectingUnstagedIcon
{
	return [NSSet setWithObjects:@"status", @"hasStagedChanges", nil];
}

+ (NSSet *)keyPathsForValuesAffectingIcon
{
	return [NSSet setWithObjects:@"status", nil];
}

- (id)initWithPath:(NSString *)p
{
	self = [super init];

	if (self) {
		path = p;
	}
	return self;
}

- (NSString *)indexInfo
{
	NSAssert(status == NEW || self.commitBlobSHA, @"File is not new, but doesn't have an index entry!");
	if (!self.commitBlobSHA)
		return [NSString stringWithFormat:@"0 0000000000000000000000000000000000000000\t%@\0", self.path];
	else
		return [NSString stringWithFormat:@"%@ %@\t%@\0", self.commitBlobMode, self.commitBlobSHA, self.path];
}

// `status` describes the file's overall state against HEAD (NEW/MODIFIED/
// DELETED). That's the correct lens for the staged-changes list — a file
// shown there has its index entry differing from HEAD in that way.
//
// The unstaged list, however, shows the working tree against the index.
// If a file is NEW (against HEAD) AND was staged AND then edited again,
// the unstaged side represents a *modification* of the staged blob, not a
// new file. Picking the icon by `status` alone makes the unstaged row
// show the "new file" badge even though the unstaged change is a delta
// on top of a staged version.
//
// `stagedIcon` and `unstagedIcon` express each side independently and
// fall back to a sensible default when only one side has changes.
- (NSImage *)icon
{
	return [self stagedIcon];
}

- (NSImage *)stagedIcon
{
	return [NSImage imageNamed:[self imageNameForStatus:status]];
}

- (NSImage *)unstagedIcon
{
	// If the file has been staged at least once, the unstaged delta is by
	// definition a MODIFICATION of what's in the index — regardless of how
	// the file relates to HEAD. Only a never-staged DELETED or genuinely
	// untracked NEW file should show its raw status icon on the unstaged
	// side.
	PBChangedFileStatus effective = status;
	if (status == NEW && hasStagedChanges) {
		effective = MODIFIED;
	}
	return [NSImage imageNamed:[self imageNameForStatus:effective]];
}

- (NSString *)imageNameForStatus:(PBChangedFileStatus)s
{
	switch (s) {
		case NEW:
			return @"new_file";
		case DELETED:
			return @"deleted_file";
		default:
			return @"empty_file";
	}
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return NO;
}

@end
