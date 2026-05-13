//
//  PBQLOutlineView.m
//  GitX
//
//  Created by Pieter de Bie on 6/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBQLOutlineView.h"
#import "PBGitTree.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface PBQLOutlineView () <NSFilePromiseProviderDelegate>
@end

@implementation PBQLOutlineView

- initWithCoder:(NSCoder *)coder
{
	id a = [super initWithCoder:coder];
	[a setDataSource:a];
	[a registerForDraggedTypes:@[ NSPasteboardTypeFileURL ]];
	return a;
}

/* Needed to drag outside application */
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	return NSDragOperationCopy;
}

- (void)keyDown:(NSEvent *)event
{
	if ([[event characters] isEqualToString:@" "]) {
		[controller toggleQLPreviewPanel:self];
		return;
	}

	[super keyDown:event];
}

#pragma mark - File promise (modern replacement for NSFilesPromisePboardType)

// Modern NSOutlineView drag source hook. Returning an NSFilePromiseProvider
// per item replaces the legacy writeItems:toPasteboard: + promised-files
// path that relied on NSFilesPromisePboardType (deprecated in macOS 10.14).
- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item
{
	PBGitTree *tree = [item representedObject];
	NSString *extension = [tree.path pathExtension];

	UTType *type = nil;
	if (extension.length) {
		type = [UTType typeWithFilenameExtension:extension];
	}
	NSString *typeIdentifier = type.identifier ?: (NSString *)UTTypeData.identifier;

	NSFilePromiseProvider *provider = [[NSFilePromiseProvider alloc] initWithFileType:typeIdentifier
																			 delegate:self];
	// Stash the tree so the delegate callbacks can recover it.
	provider.userInfo = tree;
	return provider;
}

- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider fileNameForType:(NSString *)fileType
{
	PBGitTree *tree = (PBGitTree *)filePromiseProvider.userInfo;
	NSString *name = tree.path.lastPathComponent;
	return name.length ? name : @"file";
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
		  writePromiseToURL:(NSURL *)url
		  completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
	PBGitTree *tree = (PBGitTree *)filePromiseProvider.userInfo;

	// The system-provided URL already encodes <dropDestination>/<filename>,
	// where <filename> came from -filePromiseProvider:fileNameForType:.
	// Since tree.path is a single component for the items the outline view
	// exposes, [tree saveToFolder:parent.path] writes the blob (or directory
	// tree) at exactly the URL we were handed — same on-disk result as the
	// legacy namesOfPromisedFilesDroppedAtDestination: code path.
	NSString *parentPath = url.URLByDeletingLastPathComponent.path;
	if (!parentPath) {
		NSDictionary *info = @{ NSLocalizedDescriptionKey : @"No parent directory for drop destination" };
		completionHandler([NSError errorWithDomain:@"PBQLOutlineView" code:1 userInfo:info]);
		return;
	}

	[tree saveToFolder:parentPath];
	completionHandler(nil);
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSEventTypeRightMouseDown) {
		// get the current selections for the outline view.
		NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];

		// select the row that was clicked before showing the menu for the event
		NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		NSInteger row = [self rowAtPoint:mousePoint];

		// figure out if the row that was just clicked on is currently selected
		if ([selectedRowIndexes containsIndex:row] == NO) {
			NSIndexSet *index = [NSIndexSet indexSetWithIndex:row];
			[self selectRowIndexes:index byExtendingSelection:NO];
		}
	}

	return [controller contextMenuForTreeView];
}

/* Implemented to satisfy datasourcee protocol */
- (BOOL)outlineView:(NSOutlineView *)ov
	isItemExpandable:(id)item
{
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)ov
	numberOfChildrenOfItem:(id)item
{
	return 0;
}

- (id)outlineView:(NSOutlineView *)ov
			child:(NSInteger)index
		   ofItem:(id)item
{
	return nil;
}

- (id)outlineView:(NSOutlineView *)ov
	objectValueForTableColumn:(NSTableColumn *)col
					   byItem:(id)item
{
	return nil;
}
@end
