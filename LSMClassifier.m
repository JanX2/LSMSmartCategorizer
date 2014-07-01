/*

File: LSMClassifier.m

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

#import "LSMClassifier.h"
#import "LSMClassifierResultsPrivate.h"

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

- (BOOL)processString:(NSString *)string
		  intoLSMText:(LSMTextRef)lsmText
		  withOptions:(CFOptionFlags)options;
{
	OSStatus result = LSMTextAddWords(lsmText, (__bridge CFStringRef)string, CFLocaleGetSystem(), options);
	return result == noErr;
}

- (OSStatus)addTrainingString:(NSString *)string
				   toCategory:(NSString *)name
				  withOptions:(CFOptionFlags)options
{
	NSNumber *mapId = _catNameToIdMap[name];
	if (!mapId) {
		return kLSMCNoSuchCategory;
	}
	
	// Convert the input text into LSMText text.
	LSMTextRef lsmText = LSMTextCreate(kCFAllocatorDefault, _map);
	if ([self processString:string intoLSMText:lsmText withOptions:options] == NO) {
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

- (LSMClassifierResults *)getResultsForString:(NSString *)string
							   maxResultCount:(CFIndex)numOfResults
									  options:(CFOptionFlags)options
{
	// Convert input text into LSMText text.
	LSMTextRef lsmText = LSMTextCreate(kCFAllocatorDefault, _map);
	if ([self processString:string intoLSMText:lsmText withOptions:options] == NO) {
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
	
	LSMClassifierResults *classifierResults = [[LSMClassifierResults alloc] initWithLSMResult:result
																			 usingIdToNameMap:_catIdToNameMap];
	CFRelease(result);
	
	return classifierResults;
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
