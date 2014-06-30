/*

File: LSMClassifier.m

Abstract: LSMClassifier encapsulates common Latent Semantic Mapping (LSM) 
          framework functionalities. By studying this class, you will see
		  how to use LSM framework in common text classification tasks.

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

#import "LSMClassifier.h"
#import "LSMClassifierResultPrivate.h"

NSString * const LSMCategoryNameToIDMapKey = @"NameToIdMap";

// Private methods of LSMClassifier.
@interface LSMClassifier (Private)

//
// Update catIdToNameMap and catNameToIdMap to keep them in sync.
//
- (void)mapCategoryId:(LSMCategory)index toName:(NSString *)name;

@end

@implementation LSMClassifier {
	LSMMapRef _map;
	
	/*!
	 * Switching between training and evaluation mode is expensive. We use this to
	 * store the current mode, and only switch when necessary. You can also explicitly
	 * set the classifier into a particular mode.
	 */
	LSMCMode _currentMode;
	
	/*!
	 * @abstract Category Id to category name map.
	 */
	NSMutableDictionary *_catIdToNameMap;
	
	/*!
	 * @abstract Category name to category Id map.
	 *
	 * So that user can refer to a particular category by a meaningful name.
	 */
	NSMutableDictionary *_catNameToIdMap;
}

- (id)init
{
	self = [super init];
	
	if (self) {
		[self reset];
	}
	
	return self;
}

- (void)dealloc
{
	if (_map != NULL)  CFRelease(_map);
}

- (void)reset
{
	if (_map != NULL)  CFRelease(_map);
	
	// Create the LSM map with the default allocator and option.
	_map = LSMMapCreate(kCFAllocatorDefault, 0);
	
	// Set it to training mode, since the map is brandnew.
	_currentMode = kLSMCTraining;
	
	_catIdToNameMap = [NSMutableDictionary new];
	_catNameToIdMap = [NSMutableDictionary new];
}

- (OSStatus)setMode:(LSMCMode)mode
{
	if (_currentMode != mode) {
		switch (mode) {
			case kLSMCTraining:
				// Set the map to training mode.
				if (LSMMapStartTraining(_map) != noErr) {
					return kLSMSetModeFailed;
				}
				else {
					return noErr;
				}
				
			case kLSMCEvaluation:
				// Compile the map and start evaluation mode.
				if (LSMMapCompile(_map) != noErr) {
					return kLSMSetModeFailed;
				}
				else {
					return noErr;
				}
				
			default:
				return kLSMCNotValidMode;
		}
	}
	
	return noErr;
}

- (OSStatus)addCategory:(NSString *)name
{
	NSNumber *mapId = _catNameToIdMap[name];
	if (mapId) {
		return kLSMCDuplicatedCategory;
	}
	
	[self setMode:kLSMCTraining];
	LSMCategory newCategory = LSMMapAddCategory(_map);
	[self mapCategoryId:newCategory toName:name];
	return noErr;
}

- (OSStatus)addTrainingString:(NSString *)text
				   toCategory:(NSString *)name
				  withOptions:(UInt32)options
{
	NSNumber *mapId = _catNameToIdMap[name];
	if (!mapId) {
		return kLSMCNoSuchCategory;
	}
	
	// Convert the input text into LSMText text.
	LSMTextRef lsmText = LSMTextCreate(kCFAllocatorDefault, _map);
	if (LSMTextAddWords(lsmText, (__bridge CFStringRef)text, CFLocaleGetSystem(), options) != noErr) {
		CFRelease(lsmText);
		return kLSMCErr;
	}
	
	// Store current mode so that we can restore the mode if we fail.
	LSMCMode preMode = _currentMode;
	
	[self setMode:kLSMCTraining];
	LSMCategory category = [mapId unsignedIntValue];
	OSStatus result = LSMMapAddText(_map, lsmText, category);
	CFRelease(lsmText);
	
	if (result != noErr) {
		// Something bad happened.
		// Let’s recover by switching back to the original mode and returning an error.
		if (preMode != _currentMode) {
			[self setMode:preMode];
		}
		return kLSMCErr;
	}
	else {
		return noErr;
	}
}

- (LSMClassifierResult *)getResultsForString:(NSString *)text
							  maxResultCount:(SInt32)numOfResults
									 options:(UInt32)textOption
{
	// Convert input text into LSMText text.
	LSMTextRef lsmText = LSMTextCreate(kCFAllocatorDefault, _map);
	if (LSMTextAddWords(lsmText, (__bridge CFStringRef)text, CFLocaleGetSystem(), textOption) != noErr) {
		CFRelease(lsmText);
		return nil;
	}
	
	// Switch to evaluation mode.
	[self setMode:kLSMCEvaluation];
	LSMResultRef result = LSMResultCreate(kCFAllocatorDefault, _map, lsmText, numOfResults, 0);
	CFRelease(lsmText);
	if (!result) {
		return nil;
	}
	
	LSMClassifierResult *classifierResult = [[LSMClassifierResult alloc] initWithLSMResult:result
																		  usingIdToNameMap:_catIdToNameMap];
	CFRelease(result);
	
	return classifierResult;
}

- (NSUInteger)numberOfCategories
{
	return _catNameToIdMap.count;
}

- (void)enumerateCategoryNamesUsingBlock:(void (^)(NSString *categoryName, BOOL *stop))block;
{
	for (NSString *categoryName in _catNameToIdMap) {
		BOOL stop = NO;
		
		block(categoryName, &stop);
		
		if (stop)  break;
	}
}

- (OSStatus)writeToURL:(NSURL *)url;
{
	// Put _catNameToIdMap into the map’s property list so that
	// we can store it along with the map file.
	// Note, if you plan to store NSDictionary objects in the property list, the keys
	// have to be NSString objects.
	NSMutableDictionary *dict = [NSMutableDictionary new];
	dict[LSMCategoryNameToIDMapKey] = _catNameToIdMap;
	LSMMapSetProperties(_map, (__bridge CFDictionaryRef)dict);
	
	OSStatus status = LSMMapWriteToURL(_map, (__bridge CFURLRef)url, 0);
	
	return (status == noErr) ? noErr : kLSMCWriteError;
}

- (OSStatus)readFromURL:(NSURL *)url
			  usingMode:(LSMCMode)mode;
{
	if (_map != NULL)  CFRelease(_map);
	
	BOOL ok = YES;
	
	_map = LSMMapCreateFromURL(kCFAllocatorDefault, (__bridge CFURLRef)url, kLSMMapLoadMutable);
	
	if (!_map) {
		ok = NO;
	}
	else {
		NSDictionary *idNameMaps = (__bridge NSDictionary *)LSMMapGetProperties(_map);
		if (idNameMaps) {
			NSDictionary *dict = idNameMaps[LSMCategoryNameToIDMapKey];
			if (dict) {
				_catNameToIdMap = [[NSMutableDictionary alloc] initWithDictionary:dict];
				_catIdToNameMap = [NSMutableDictionary new];

				for (NSString *key in _catNameToIdMap) {
					_catIdToNameMap[_catNameToIdMap[key]] = key;
				}
			}
			else {
				ok = NO;
			}
		}
		else {
			ok = NO;
		}
	}
	
	if (ok) {
		return [self setMode:mode];
	}
	else {
		// Oops, something wrong. Reset the classifier and bail.
		[self reset];
		return kLSMCErr;
	}
}

///// private methods /////
- (void)mapCategoryId:(LSMCategory)index toName:(NSString *)name
{
	NSNumber *idNumber = @(index);
	_catIdToNameMap[idNumber] = name;
	_catNameToIdMap[name] = idNumber;
}

@end
