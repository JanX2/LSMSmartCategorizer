/*
File: EvalWindowController.m

Abstract: Controller of the evaluation window.

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
#import "EvalWindowController.h"
#import "DataInfo.h"
#import "URLLoader.h"
#import <PubSub/PubSub.h>
#import <LSMClassifier.h>

enum {
	kSheetReturnOK,
	kSheetReturnCancel
};

/*!
 * @abstract Private routines.
 */
@interface EvalWindowController (Private)

/*!
 * @abstract Categorize the data.
 */
- (void)processFeedData:(NSData *)data fromURL:(NSURL *)url;

/*!
 * @abstract Callback function used by [NSApp beginSheet:modalForWindow:modalDelegate:didEndSelector:contextInfo:],
 *           when open the sheet to ask users to enter a URL.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
@end

@implementation EvalWindowController

- (void)awakeFromNib
{
	topLevelDataInfo = [[CategoryDataInfo alloc] initWithTitle:@"Categories"];
	_urlLoader = [[URLLoader alloc] initWithDelegate:self];
	_classifier = [LSMClassifier new];
    
	[outlineView expandItem:topLevelDataInfo];
}



- (IBAction)doLoadMap:(id)sender
{
	NSMutableArray *allowedTypes = [NSMutableArray new];
	[allowedTypes addObject:@"lsm"];
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	//[panel setDirectoryURL:[NSURL fileURLWithPath:@"~"]];
	[panel setAllowedFileTypes:allowedTypes];
	
	if ([panel runModal] == NSOKButton) {
		NSURL *mapURL = [panel URLs][0];
        
		//read the map into classifier
		if ([_classifier readFromURL:mapURL usingMode:kLSMCEvaluation] == noErr) {
			[self log:[NSString stringWithFormat:@"Loaded map from %@\n", [mapURL path]]];
			[topLevelDataInfo removeAllChildren];
			
			//add available category names in the map into the outline view data source.
			[_classifier enumerateCategoryNamesUsingBlock:^(NSString *categoryName, BOOL *stop) {
				CategoryDataInfo *catInfo = [[CategoryDataInfo alloc] initWithTitle:categoryName];
				[topLevelDataInfo addChild:catInfo];
			}];
            
			//update the outline view.
			[self reloadOutlineView];
			[self setBusy:NO];
		}
		else {
			[self log:[NSString stringWithFormat:@"Failed to load map from %@\n", [mapURL path]]];
		}
	}
}

- (IBAction)doAddFile:(id)sender
{
	NSMutableArray *allowedTypes = [NSMutableArray new];
	[allowedTypes addObject:@"lsm"];
	
	//Ask the user to choose the file or files in a directory that he/she wants to categorize.
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:YES];
	[panel setAllowsMultipleSelection:YES];
	//[panel setDirectoryURL:[NSURL fileURLWithPath:@"~"]];
	[panel setAllowedFileTypes:allowedTypes];
	
	if ([panel runModal] == NSOKButton) {
		NSArray *selected = [panel URLs];
		NSMutableArray *pendingURLs = [NSMutableArray array];
		for (NSURL *selectedURL in selected) {
			[self appendDescendantURLsOf:selectedURL
								 toArray:pendingURLs];
		}
        
		//Start loading the URLs. (Asynchronously)
		[_urlLoader load:pendingURLs];
        
		//set UI to busy.
		[self setUICancellableBusy:@"Fetching data ..."];
	}
}

- (void)doAddURL:(id)sender
{
	//Open a sheet to ask the user to enter an URL that he/she wants to categorize.
	//we pre-store some URLs in the bundle, read those URLs.
	NSURL *testFileURL =
    [[NSBundle mainBundle] URLForResource:@"test_urls" withExtension:@"plist"];
	if (testFileURL) {
		NSArray *testURLs = [NSArray arrayWithContentsOfURL:testFileURL];
		if (testURLs) {
			[urlBox addItemsWithObjectValues:testURLs];
		}
	}
    
	[urlBox setStringValue:@"http://"];
	[NSApp beginSheet:openURLSheet modalForWindow:window modalDelegate:(self)
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)doCancel:(id)sender
{
	[_urlLoader reset];
	[self log:@"Cancelled by user\n"];
	[self setUIIdle];
}

- (void)doCancelSheet:(id)sender
{
	[NSApp endSheet:openURLSheet returnCode:kSheetReturnCancel];
}

- (void)doOKSheet:(id)sender
{
	[NSApp endSheet:openURLSheet returnCode:kSheetReturnOK];
}

//////////////////// Private //////////////////////
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	[sheet orderOut:self];
    
	//return if user pressed "Cancel"
	if (returnCode == kSheetReturnCancel) {
		return;
	}
    
	NSMutableString *enteredStr = [NSMutableString stringWithString:[[urlBox stringValue] lowercaseString]];
    
	//If the user use "feed:" as URL schema, replace it with "http:",
	//because NSURLConnection doesn't support "feed:".
	if ([enteredStr hasPrefix:@"feed:"]) {
		[enteredStr replaceCharactersInRange:NSMakeRange(0, 5) withString:@"http:"];
	}
    
	NSArray *pendingURLs = @[[NSURL URLWithString:enteredStr]];
    
	//Start loading the URL. (Asynchronously)
	[_urlLoader load:pendingURLs];
    
	//set UI to busy.
	[self setUICancellableBusy:@"Fetching data ..."];
}


- (void)processFeedData:(NSData *)data fromURL:(NSURL *)url
{
	if (data == nil) {
		[self log:[NSString stringWithFormat:@"Failed to read %@\n", url]];
	}
	else {
		//create a PSFeed instance.
		PSFeed *feed = [[PSFeed alloc] initWithData:data URL:url];
		if ((feed == nil) || ([feed title] == nil)) {
			[self log:[NSString stringWithFormat:@"Failed to parse data from %@\n", url]];
		}
		else {
			FeedDataInfo *feedInfo = [[FeedDataInfo alloc] initWithFeed:feed];
            
			//get categorization result. Here we are only interested in the best matching category.
			LSMClassifierResult *result = [_classifier createResultFor:[feedInfo plainText] upTo:1 with:0];
			if (result == nil) {
				[self log:[NSString stringWithFormat:@"Failed to categorize feed \"%@\"\n", [feedInfo title]]];
			}
			else {
				NSString *catName = [result getCategoryName:0];
				[self log:[NSString stringWithFormat:@"feed \"%@\" matches category \"%@\" with score %@\n",
				           [feedInfo title], catName, [result getScore:0]]];
				[feedInfo setScore:[result getScore:0]];
                
				//add the feed into corresponding category in the outline view data source.
				NSEnumerator *catEnum = [topLevelDataInfo childEnumerator];
				CategoryDataInfo *catInfo;
				while (catInfo = [catEnum nextObject]) {
					if ([[catInfo title] isEqualToString:catName]) {
						[catInfo addChild:feedInfo];
						break;
					}
				}
			}
		}
        
	}
	
}

- (void)appendDescendantURLsOf:(NSURL *)url
					   toArray:(NSMutableArray *)array;
{
	NSArray *resourceKeys = @[NSURLIsDirectoryKey];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[url URLByResolvingSymlinksInPath]
										  includingPropertiesForKeys:resourceKeys
															 options:(NSDirectoryEnumerationSkipsPackageDescendants |
																	  NSDirectoryEnumerationSkipsHiddenFiles)
														errorHandler:^BOOL(NSURL *url, NSError *error) {
															// FIXME: Improve?
															return YES;
														}];
	
	for (NSURL *currentURL in enumerator) {
#if 0
		NSDictionary *resourceDict = [currentURL resourceValuesForKeys:resourceKeys
																 error:NULL];
		if (resourceDict != nil) {
			BOOL isDirectory = [(NSNumber *)resourceDict[NSURLIsDirectoryKey] boolValue];
			
			if (isDirectory == NO)  [array addObject:url];
		}
#else
		NSNumber *isDirectory;
		[currentURL getResourceValue:&isDirectory
						   forKey:NSURLIsDirectoryKey
							error:NULL];
		
		if ([isDirectory boolValue] == NO) {
			// If it’s a file, append its path to the array.
			[array addObject:url];
		}
#endif
	}
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
	[self setUIAllBusy:@"Parsing data ..."];
    
	//we have done fetching all URI, now parse them.
	NSEnumerator *urlEnum = [_urlLoader urlEnumerator];
	NSURL *url;
    
	//check if all URLs have been loaded successfully.
	while (url = [urlEnum nextObject]) {
		NSData *data = [_urlLoader dataForURL:url];
		if (data == nil) {
			[self log:[NSString stringWithFormat:@"Failed to load from %@\n", url]];
			continue;
		}
        
		[self processFeedData:data fromURL:url];
		[self reloadOutlineView];
	}
	[_urlLoader reset];
    
	[self setUIIdle];
}


@end
