/*

File: TrainingWindowController.m

Abstract: Controller for training window.

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple,
Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright © 2007 Apple Inc., All Rights Reserved

*/ 

#import "TrainingWindowController.h"
#import "DataInfo.h"
#import "URLLoader.h"
#import <PubSub/PubSub.h>
#import <LSMClassifier.h>

@implementation TrainingWindowController

- (void)awakeFromNib
{
	topLevelDataInfo =  [[CategoryDataInfo alloc] initWithTitle:@"Training categories"];
	_tmpURLDataInfo = [CategoryDataInfo new];
	_urlLoader = [[URLLoader alloc] initWithDelegate:self];
	[outlineView expandItem:topLevelDataInfo];
}


- (IBAction)doLoadLocalTrainingData:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	//[panel setDirectoryURL:[NSURL fileURLWithPath:@"~"]];
	
	if ([panel runModal] == NSOKButton) {
		NSURL *topDataURL = [panel URLs][0];
		[self log:[NSString stringWithFormat:@"Loading data from %@\n", [topDataURL path]]];
        
		// Start loading data from specified directory.
		[self readDataURLsAtURL:topDataURL];
	}
}

- (IBAction)doLoadFeedPlist:(id)sender
{
	// The default plist is the one shipped with the app bundle.
	NSURL *resourcesURL =
    [[NSBundle mainBundle] URLForResource:@"training_rss_categories" withExtension:@"plist"];
    
	NSURL *startupURL;
	//NSString *fileName;
    
	if (resourcesURL) {
		//fileName = [resourcesURL lastPathComponent];
		startupURL = [resourcesURL URLByDeletingLastPathComponent];
	}
	else {
		//fileName = nil;
		startupURL = [[[NSFileManager defaultManager] URLsForDirectory:NSUserDirectory
															  inDomains:NSUserDomainMask] firstObject];
	}
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setDirectoryURL:startupURL];
	// FIXME: Couldn’t find a way to select a default file for an NSOpenPanel.
	
	if ([panel runModal] == NSOKButton) {
		NSURL *plistURL = [panel URLs][0];
		// Start loading from URLs specified by the plist.
		[self readDataSpecifiedByPlistURL:plistURL];
	}
}

- (IBAction)doTrainAndSave:(id)sender
{
	[self setUIAllBusy:@"Training map ..."];
    
	// Sanity check on each category.
	// A category need to contain at least one feed in order to train
	NSEnumerator *catEnum = [topLevelDataInfo childEnumerator];
	CategoryDataInfo *catInfo;
	while (catInfo = [catEnum nextObject]) {
		if ([catInfo numberOfChildren] == 0) {
			[self log:[NSString stringWithFormat:@"ERROR: Category \"%@\" is empty. Training cancelled.\n", catInfo.title]];
			return;
		}
	}
    
	// Create a new classifer and set it to training mode.
	LSMClassifier *classifier = [LSMClassifier new];
	[classifier setMode:kLSMCTraining];
	catEnum = [topLevelDataInfo childEnumerator];
    
	// Add each category in the training data.
	while (catInfo = [catEnum nextObject]) {
		NSString *catName = [catInfo title];
		[classifier addCategory:catName];
		NSEnumerator *feedEnum = [catInfo childEnumerator];
		FeedDataInfo *feedInfo;
        
		// For each category, add each feed’s data.
		while (feedInfo = [feedEnum nextObject]) {
			NSString *feedString = [feedInfo plainText];
			[classifier addTrainingString:feedString
							   toCategory:catName
							  withOptions:0];
		}
	}
    
	// Save the map.
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setTitle:@"Save LSM map"];
	[savePanel setCanSelectHiddenExtension:NO];
	[savePanel setAllowedFileTypes:@[@"lsm"]];
	//[savePanel setDirectoryURL:[NSURL fileURLWithPath:@"~"]];
	[savePanel setNameFieldStringValue:@"map.lsm"];
	
	if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
		NSURL *fileURL = [savePanel URL];
		NSString *filePath = [fileURL path];

		// Train and save the map.
		if ([classifier writeToURL:fileURL] == noErr) {
			[self log:[NSString stringWithFormat:@"Saved map to %@\n", filePath]];
		}
		else {
			[self log:[NSString stringWithFormat:@"Failed to save map to %@\n", filePath]];
		}
	}
    
	[self setUIIdle];
}

- (IBAction)doCancel:(id)sender
{
	[_urlLoader cancel];
	[_tmpURLDataInfo removeAllChildren];
	[self log:@"Loading cancelled by user.\n"];
    
	[self setUIIdle];
}

- (IBAction)doShowHelp:(id)sender
{
	if (![helpTextView string] || ([[helpTextView string] length] <= 0)) {
		NSURL *helpTextURL =
        [[NSBundle mainBundle] URLForResource:@"AppHelp" withExtension:@"txt"];
        
		NSString *helpText = [NSString stringWithContentsOfURL:helpTextURL
													  encoding:NSUTF8StringEncoding
														 error:NULL];
        
		[helpTextView insertText:helpText];
		[helpTextView scrollRangeToVisible:NSMakeRange(0, 0)];
		[helpTextView setEditable:NO];
	}
	[helpWindow makeKeyAndOrderFront:self];
}

////////////////// URLoader delegate //////////////////
- (void)URLLoader:(URLLoader *)theURLLoader didBeginURL:(NSURL *)aURL
{
	[self log:[NSString stringWithFormat:@"Began loading %@\n", aURL]];
}

- (void)URLLoader:(URLLoader *)theURLLoader didFinishURL:(NSURL *)aURL
{
	[self log:[NSString stringWithFormat:@"Finished loading %@\n", aURL]];
}

- (void)URLLoaderDidFinishAll:(URLLoader *)theURLLoader
{
	[self log:@"Finished loading from all URLs\n"];
	[self setUIAllBusy:@"Parsing data ..."];
    
	// Reset outline view data source.
	[topLevelDataInfo removeAllChildren];
    
	// We have done fetching all URI, now parse them.
	NSEnumerator *catEnum = [_tmpURLDataInfo childEnumerator];
	CategoryDataInfo *category;
    
	// Move each category from _tmpURLDataInfo to topLevelDataInfo.
	while (category = [catEnum nextObject]) {
		NSEnumerator *urlInfoEnum = [category childEnumerator];
		URLDataInfo *urlInfo;
        
		// Create a new category.
		CategoryDataInfo *feedCatInfo = [[CategoryDataInfo alloc] initWithTitle:[category title]];
        
		// For each category, use PSFeed to parse data from each feed URL.
		while (urlInfo = [urlInfoEnum nextObject]) {
			NSData *data = [_urlLoader dataForURL:[urlInfo url]];
			if (data == nil) {
				[self log:[NSString stringWithFormat:@"Failed to load from %@\n", [urlInfo url]]];
				continue;
			}
            
			PSFeed *feed = [[PSFeed alloc] initWithData:data URL:[urlInfo url]];
			if ((feed == nil) || ([feed title] == nil)) {
				[self log:[NSString stringWithFormat:@"Failed to parse data from %@\n", [urlInfo url]]];
			}
			else {
				FeedDataInfo *feedDataInfo = [[FeedDataInfo alloc] initWithFeed:feed];
				[feedCatInfo addChild:feedDataInfo];
			}
		}
        
		// Add the newly created category into topLevelDataInfo.
		[topLevelDataInfo addChild:feedCatInfo];
	}
    
	[self reloadOutlineView];
	[_tmpURLDataInfo removeAllChildren];
	[_urlLoader reset];
    
	[self setUIIdle];
}

//////////////////// Private //////////////////////
- (void)readDataURLsAtURL:(NSURL *)topDataURL
{
	[self setUIAllBusy:@"Fetching data ..."];
    
	[_tmpURLDataInfo removeAllChildren];
	NSMutableArray *pendingURLs = [NSMutableArray new];
    
	NSError *error = nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLNameKey];
    
	// Each sub-folder of topDataURL is treated as a category.
	NSArray *categoryURLs = [fileManager contentsOfDirectoryAtURL:topDataURL
									   includingPropertiesForKeys:resourceKeys
														  options:(NSDirectoryEnumerationSkipsHiddenFiles)
															error:&error];
	if (categoryURLs == nil) {
		NSLog(@"%@", error);
		return;
	}
	
	for (NSURL *categoryURL in categoryURLs) {
		NSString *categoryName;
		[categoryURL getResourceValue:&categoryName
							   forKey:NSURLNameKey
								error:NULL];
		
		NSNumber *isDirectory;
		[categoryURL getResourceValue:&isDirectory
							   forKey:NSURLIsDirectoryKey
								error:NULL];
		
		//[fileManager fileExistsAtPath:catPath isDirectory:&isDir];
        
		// Discard it, if it’s not a directory.
		if ([isDirectory boolValue] == NO) {
			continue;
		}
        
		[self log:[NSString stringWithFormat:@"Found category: %@\n", categoryName]];
        
		CategoryDataInfo *catDataInfo = [[CategoryDataInfo alloc] initWithTitle:categoryName];
        
		// Each file in this directory is a piece of training data that belongs to this category.
		NSArray *dataURLs = [fileManager contentsOfDirectoryAtURL:categoryURL
									   includingPropertiesForKeys:resourceKeys
														  options:(NSDirectoryEnumerationSkipsHiddenFiles)
															error:&error];
		if (dataURLs == nil) {
			NSLog(@"%@", error);
			continue;
		}
		
		for (NSURL *datumURL in dataURLs) {
			NSString *datumName;
			[datumURL getResourceValue:&datumName
							   forKey:NSURLNameKey
								error:NULL];
			
			NSNumber *isDir;
			[categoryURL getResourceValue:&isDir
								   forKey:NSURLIsDirectoryKey
									error:NULL];
			

			//[fileManager fileExistsAtPath:datumPath isDirectory:&isDir];
            
			// Discard it, if it’s a directory.
			if ([isDir boolValue] == YES) {
				continue;
			}
			
			URLDataInfo *urlDataInfo = [[URLDataInfo alloc] initWithURL:datumURL
															   andTitle:datumName];
			[pendingURLs addObject:datumURL];
			[catDataInfo addChild:urlDataInfo];
		}
        
		[_tmpURLDataInfo addChild:catDataInfo];
	}
    
	// Start loading.
	[_urlLoader load:pendingURLs];
	[self setUICancellableBusy:@"Fetching data ... "];
}

- (void)readDataSpecifiedByPlistURL:(NSURL *)plistURL
{
	[self setUIAllBusy:@"Fetching data ..."];
    
	NSDictionary *categoryDict = [NSDictionary dictionaryWithContentsOfURL:plistURL];
	if (categoryDict == nil) {
		[self log:[NSString stringWithFormat:@"Failed to load plist %@", [plistURL path]]];
		return;
	}
    
	[_tmpURLDataInfo removeAllChildren];
	NSMutableArray *pendingURLs = [NSMutableArray new];
    
	// The top level of the plist contains all the categories.
	[categoryDict enumerateKeysAndObjectsUsingBlock:^(NSString *categoryName, NSArray *feedArray, BOOL *stop) {
		[self log:[NSString stringWithFormat:@"Found category \"%@\"", categoryName]];
		CategoryDataInfo *catDataInfo = [[CategoryDataInfo alloc] initWithTitle:categoryName];
        
		// Each category contains a list of URL strings.
		for (NSString *feedURLStr in feedArray) {
			NSURL *feedURL = [NSURL URLWithString:feedURLStr];
			URLDataInfo *urlDataInfo = [[URLDataInfo alloc] initWithURL:feedURL
															   andTitle:@""];
			[pendingURLs addObject:feedURL];
			[catDataInfo addChild:urlDataInfo];
		}
        
		[_tmpURLDataInfo addChild:catDataInfo];
	}];
    
	// Start loading.
	[_urlLoader load:pendingURLs];
	[self setUICancellableBusy:@"Fetching data ... "];
}


@end
