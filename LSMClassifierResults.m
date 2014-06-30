/*

File: LSMClassifierResults.m

Abstract: LSMResultRef is one of the core datatype in LSM framework. 
		  LSMClassifierResults is a wrapper of LSMResultRef.

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

#import "LSMClassifierResults.h"

NSString * const LSMCResultCategoryKey = @"category";
NSString * const LSMCResultScoreKey = @"score";

@implementation LSMClassifierResults {
	NSMutableArray *_results;
}

- (id)initWithLSMResult:(LSMResultRef)lsmResult
	   usingIdToNameMap:(NSDictionary *)map
{
	self = [super init];
	
	if (self) {
		_results = [NSMutableArray new];
		
		// Put individual result into the array.
		SInt32 count = LSMResultGetCount(lsmResult);
		for (SInt32 i = 0; i < count; i++) {
			NSMutableDictionary *thisResult = [NSMutableDictionary new];
			
			// Get the category id of the ith result.
			NSNumber *categoryId = @(LSMResultGetCategory(lsmResult, i));
			
			// Map id to name.
			NSString *categoryName = map[categoryId];
			
			// Get the score of the ith result.
			NSNumber *score = @(LSMResultGetScore(lsmResult, i));
			
			thisResult[LSMCResultCategoryKey] = categoryName;
			thisResult[LSMCResultScoreKey] = score;
			
			[_results addObject:thisResult];
		}
	}
	
	return self;
}


- (NSUInteger)resultCount
{
	return _results.count;
}

- (NSString *)categoryNameForIndex:(UInt32)index
{
	if (index >= _results.count) {
		return nil;
	}
	else {
		return _results[index][LSMCResultCategoryKey];
	}
}

- (NSNumber *)scoreForIndex:(UInt32)index
{
	if (index >= _results.count) {
		return nil;
	}
	else {
		return _results[index][LSMCResultScoreKey];
	}
}


- (void)enumerateResultsUsingBlock:(void (^)(NSString *categoryName, NSNumber *score, BOOL *stop))block;
{
	for (NSDictionary *thisResult in _results) {
		BOOL stop = NO;
		
		NSString *categoryName = thisResult[LSMCResultCategoryKey];
		NSNumber *score = thisResult[LSMCResultScoreKey];
		block(categoryName, score, &stop);
		
		if (stop)  break;
	}
}

@end
