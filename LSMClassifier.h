/*

File: LSMClassifier.h

Abstract: LSMClassifier encapsulates common Latent Semantic Mapping (LSM) 
          framework functionalities. By studying this class, you will see
		  how to use the LSM framework in common text classification tasks.

Based on version: 1.0

Copyright © 2007 Apple Inc., All Rights Reserved
Copyright © 2014 Jan Weiß, geheimwerk.de
 
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 License available:  http://www.opensource.org/licenses/mit-license.html

*/

#ifndef __LSMClassifier__
#define __LSMClassifier__

#import "LSMClassifierResults.h"

/*! @enum Error  codes
 *  @discussion Errors returned by LSMClassifier methods.
 *  @constant kLSMCErr				   Generic error code.
 *  @constant kLSMCDuplicatedCategory  The category to add is already in the map.
 *  @constant kLSMCNoSuchCategory      Invalid category specified.
 *  @constant kLSMCWriteError          An error occurred writing the map
 *  @constant kLSMCBadPath             The URL specified doesn't not exist.
 *  @constant kLSMCNotValidMode        The mode specified is not valid.
 *  @constant kLSMSetModeFailed        Failed to set mode.
 */
typedef NS_ENUM(OSStatus, LSMCError) {
	kLSMCErr                = 1000,
	kLSMCDuplicatedCategory = 1001,
	kLSMCNoSuchCategory     = 1002,
	kLSMCWriteError         = 1003,
	kLSMCBadPath            = 1004,
	kLSMCNotValidMode       = 1005,
	kLSMSetModeFailed       = 1006
};


/*!
 * @abstract Indicate the mode the classifier is currently in, traning mode or
 *           evaluation mode.
 */
typedef NS_ENUM(CFIndex, LSMCMode) {
	kLSMCTraining = 0,
	kLSMCEvaluation
};

/*!
 * @abstract Encapsulate some common routines of the LSM framework.
 */
@interface LSMClassifier : NSObject

/*!
 * @abstract Remove all existing categories, and switch to training mode.
 */
- (void)reset;

/*!
 * @abstract Set classifier mode.
 */
- (OSStatus)setMode:(LSMCMode)mode;

/*!
 * @abstract Add new cateogry.
 *
 * @return noErr The category was successfully added into the map.
 * @return kLSMCDuplicatedCategory The category name has already existed.
 *
 * If current mode is kLSMCEvaluation, on successful return, this method will set
 * mode to kLSMCTraining.
 */
- (OSStatus)addCategory:(NSString *)name;

/*!
 * @abstract Add training text to category specified by name.
 * @return YES On success.
 * @return NO On errors.
 *
 * Can be overridden by subclasses to customize tokenization.
 *
 * options can be kLSMTextPreserveCase, kLSMTextPreserveAcronyms
 * and/or kLSMTextApplySpamHeuristics.
 */
- (BOOL)processString:(NSString *)string
		  intoLSMText:(LSMTextRef)lsmText
		  withOptions:(CFOptionFlags)options;

/*!
 * @abstract Add training data to category specified by name.
 * @return YES On success.
 * @return NO On errors.
 *
 * Can be overridden by subclasses to customize tokenization.
 */
- (BOOL)processData:(NSData *)data
		intoLSMText:(LSMTextRef)lsmText;

/*!
 * @abstract Add training text to category specified by name.
 * @return noErr On success.
 * @return kLSMCNoSuchCategory Specified category doesn't exisit.
 * @return kLSMCErr Other errors.
 *
 * If current mode is kLSMCEvaluation, on successful return, this method will set
 * mode to kLSMCTraining.
 *
 * options can be kLSMTextPreserveCase, kLSMTextPreserveAcronyms
 * and/or kLSMTextApplySpamHeuristics.
 */
- (OSStatus)addTrainingString:(NSString *)text
				   toCategory:(NSString *)name
				  withOptions:(CFOptionFlags)options;

/*!
 * @abstract Add training data to the category specified by name.
 * @return noErr On success.
 * @return kLSMCNoSuchCategory Specified category doesn’t exist.
 * @return kLSMCErr Other errors.
 *
 * If current mode is kLSMCEvaluation, on successful return, this method will set
 * mode to kLSMCTraining.
 */
- (OSStatus)addTrainingData:(NSData *)data
				 toCategory:(NSString *)name;

/**!
 * @abstract Evaluate input text and return the results.
 *
 * @param text			Text to be evaluated.
 * @param numOfResults	Maximum number of results to be returned.
 * @param options		Options for pre-processing of the text. Can be set to kLSMTextPreserveCase,
 *                      kLSMTextPreserveAcronyms and/or kLSMTextApplySpamHeuristics.
 *
 * If current mode is kLSMCTraining, this method will set mode to kLSMCEvaluation.
 */
- (LSMClassifierResults *)getResultsForString:(NSString *)text
							   maxResultCount:(CFIndex)numOfResults
									  options:(CFOptionFlags)options;

/**!
 * @abstract Evaluate input data and return the results.
 *
 * @param data			Data to be evaluated.
 * @param numOfResults	Maximum number of results to be returned.
 *
 * If current mode is kLSMCTraining, this method will set mode to kLSMCEvaluation.
 */
- (LSMClassifierResults *)getResultsForData:(NSData	*)data
							 maxResultCount:(CFIndex)numOfResults;

/**!
 * @abstract Return number of categories in the map.
 */
- (NSUInteger)numberOfCategories;

/**!
 * @abstract Enumerate category names.
 *
 * Call the block for each category name.
 */
- (void)enumerateCategoryNamesUsingBlock:(void (^)(NSString *categoryName, BOOL *stop))block;

/**!
 * @abstract Save the internal data to URL, including LSM map and the category
 *           Id-name maps.
 */
- (OSStatus)writeToURL:(NSURL *)url;

/**!
 * @abstract Load from specified URL, and switch to mode.
 */
- (OSStatus)readFromURL:(NSURL *)url
			  usingMode:(LSMCMode)mode;

@end


#endif //__LSMClassifier__