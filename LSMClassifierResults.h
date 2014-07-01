/*

File: LSMClassifierResults.h

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
#ifndef __LSMClassifierResults__
#define __LSMClassifierResults__

#import <Foundation/Foundation.h>
#import <LatentSemanticMapping/LatentSemanticMapping.h>

/*!
 * Internally LSMClassfierResult is an array of all available results,
 * which are sorted by their scores.
 */
@interface LSMClassifierResults : NSObject

/*!
 * @abstract Return total number of results.
 */
- (NSUInteger)resultCount;

/*!
 * @abstract Get the category name of result specified by index.
 *
 * return nil if the index is not valid.
 */
- (NSString *)categoryNameForIndex:(UInt32)index;

/*!
 * @abstract Get the score of result specified by index.
 *
 * return nil if the index is not valid.
 *
 * The underlying type of the score is float.
 */
- (NSNumber *)scoreForIndex:(UInt32)index;


/**!
 * @abstract Enumerate results.
 *
 * Call the block for each results.
 */
- (void)enumerateResultsUsingBlock:(void (^)(NSString *categoryName, NSNumber *score, BOOL *stop))block;

@end

#endif //__LSMClassifierResults__
