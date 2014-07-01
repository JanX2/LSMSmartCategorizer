/*

File: LSMClassifierResults.m

Abstract: LSMResultRef is one of the core datatype in LSM framework. 
		  LSMClassifierResults is a wrapper for LSMResultRef.

Based on version: 1.0

Copyright © 2007 Apple Inc., All Rights Reserved
Copyright © 2014 Jan Weiß, geheimwerk.de
 
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 License available:  http://www.opensource.org/licenses/mit-license.html

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
