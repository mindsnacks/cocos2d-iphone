/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2010 Ricardo Quesada
 * Copyright (c) 2011 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */


#import "CCFileUtils.h"
#import "../CCConfiguration.h"
#import "../ccMacros.h"
#import "../ccConfig.h"
#import "../ccTypes.h"


#define kComponentBase      0
#define kComponentSuffix    1
#define kComponentExtension 2


static NSMutableDictionary *g_suffixByResolutionType;
static NSMutableDictionary *g_resolutionsByDevice;


NSInteger ccLoadFileIntoMemory(const char *filename, unsigned char **out)
{
	NSCAssert( out, @"ccLoadFileIntoMemory: invalid 'out' parameter");
	NSCAssert( &*out, @"ccLoadFileIntoMemory: invalid 'out' parameter");
    
	size_t size = 0;
	FILE *f = fopen(filename, "rb");
	if( !f ) {
		*out = NULL;
		return -1;
	}
    
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);
    
	*out = malloc(size);
	size_t read = fread(*out, 1, size, f);
	if( read != size ) {
		free(*out);
		*out = NULL;
		return -1;
	}
    
	fclose(f);
    
	return size;
}


@implementation CCFileUtils

static NSBundle *g_defaultBundle;

+ (void)initialize
{
	if( self == [CCFileUtils class] )
    {
        g_defaultBundle = [[NSBundle mainBundle] retain];
        g_suffixByResolutionType = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     @"", @(kCCResolutionUnknown),
                                     @"", @(kCCResolutioniPhone),
                                     @"-hd", @(kCCResolutioniPhoneRetinaDisplay),
                                     @"-568h", @(kCCResolutioniPhoneFourInchDisplay),
                                     @"-ipad", @(kCCResolutioniPad),
                                     @"-ipadhd", @(kCCResolutioniPadRetinaDisplay),
                                     nil] retain];
        
        // Resolutions will be attempted in the following order for each device type.
        g_resolutionsByDevice = [[NSDictionary dictionaryWithObjectsAndKeys:
                                  @[
                                  @(kCCResolutioniPad),
                                  @(kCCResolutioniPhoneRetinaDisplay)
                                  ], @(kCCResolutioniPad),
                                  
                                  @[
                                  @(kCCResolutioniPadRetinaDisplay),
                                  @(kCCResolutioniPad),
                                  @(kCCResolutioniPhoneRetinaDisplay)
                                  ], @(kCCResolutioniPadRetinaDisplay),
                                  
                                  @[
                                  @(kCCResolutioniPhone),
                                  ], @(kCCResolutioniPhone),
                                  
                                  @[
                                  @(kCCResolutioniPhoneFourInchDisplay),
                                  @(kCCResolutioniPhoneRetinaDisplay)
                                  ], @(kCCResolutioniPhoneFourInchDisplay),
                                  
                                  @[
                                  @(kCCResolutioniPhoneRetinaDisplay)
                                  ], @(kCCResolutioniPhoneRetinaDisplay),
                                  
                                  @[
                                  ], @(kCCResolutionUnknown),
                                  
                                  nil] retain];
    }
}

+ (void)setSuffix:(NSString *)suffix forResolutionType:(ccResolutionType)resolutionType
{
    NSAssert(resolutionType != kCCResolutionUnknown, @"Cannot set kCCResolutionUnknown");
    
    g_suffixByResolutionType[@(resolutionType)] = [[suffix copy] autorelease];
}

+ (NSString *)makeAbsolutePathToExistingFile:(NSString *)path
{
    if(![path isAbsolutePath])
    {
        if(path == nil)
        {
            return nil;
        }
        
        NSString *file = [path lastPathComponent];
        NSString *extension = [path pathExtension];
        NSString *fileWithoutExtension = [file stringByDeletingPathExtension];
        NSString *directory = [path stringByDeletingLastPathComponent];
        if([directory length] == 0)
        {
            directory = nil;
        }
        
        // pathForResource also searches in .lproj directories. issue #1230
        path = [g_defaultBundle pathForResource:fileWithoutExtension
                                         ofType:extension
                                    inDirectory:directory];
        if(path == nil)
        {
            return nil;
        }
        
        // The OS will lie to us and silently add suffixes like ~ipad and @2x,
        // so we need to manually regenerate the filename we want.
        directory = [path stringByDeletingLastPathComponent];
        path = [directory stringByAppendingPathComponent:file];
    }

    if(![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        return nil;
    }
    return path;
}

/** Split a path into 3 components:
 * - Base path (everything except suffix and extension)
 * - Suffix (such as -hd, -ipad, @2x, ~ipad)
 * - Extension (such as jog, png)
 *
 * The results will be stored in an array in the order: base path, suffix, extension.
 *
 * @param path The path to examine.
 * @param resolutionType The resolution type to generate a suffix for.
 * @return Path components for the specified resolution.
 */
+ (NSArray *)pathComponents:(NSString*)path forResolutionType:(ccResolutionType)resolutionType
{
	NSString *pathWithoutExtension = [path stringByDeletingPathExtension];
    NSString *extension = [path pathExtension];
	if( [extension isEqualToString:@"ccz"] || [extension isEqualToString:@"gz"] )
	{
		// All ccz / gz files should be in the format filename.xxx.ccz
		// so we need to pull off the .xxx part of the extension as well
		extension = [NSString stringWithFormat:@"%@.%@", [pathWithoutExtension pathExtension], extension];
		pathWithoutExtension = [pathWithoutExtension stringByDeletingPathExtension];
    }
    NSString *suffix = g_suffixByResolutionType[@(resolutionType)];
    return [NSArray arrayWithObjects:pathWithoutExtension, suffix, extension, nil];
}

+ (NSString *)path:(NSString *)path forResolutionType:(ccResolutionType)resolutionType
{
    NSArray *components = [self pathComponents:path forResolutionType:resolutionType];
    return [NSString stringWithFormat:@"%@%@.%@",
            components[kComponentBase],
            components[kComponentSuffix],
            components[kComponentExtension]];
}

+ (BOOL)hasKnownSuffix:(NSString *)path
{
    NSString *pathWithoutExtension = [path stringByDeletingPathExtension];
    for(NSString* suffix in [g_suffixByResolutionType allValues])
    {
        NSUInteger length = [suffix length];
        if(length > 0)
        {
            NSRange range = [pathWithoutExtension rangeOfString:suffix options:NSBackwardsSearch];
            if(range.location == [pathWithoutExtension length] - length)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (BOOL)path:(NSString *)path existsForResolutionType:(ccResolutionType)resolutionType
{
    NSString *fullPath = [self path:path forResolutionType:resolutionType];
    NSString *absPath = [self makeAbsolutePathToExistingFile:fullPath];
    return absPath != nil;
}

+ (NSString *)pathToExistingFile:(NSString*)path
              forResolutionTypes:(NSArray *)resolutionTypes
            chosenResolutionType:(ccResolutionType *)chosenResolutionType
{
    NSArray *components = [self pathComponents:path forResolutionType:kCCResolutionUnknown];
	NSString *pathWithoutExtension = components[kComponentBase];
    NSString *extension = components[kComponentExtension];
    
    for(NSNumber *resolution in resolutionTypes)
    {
        NSString *suffix = g_suffixByResolutionType[resolution];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@.%@", pathWithoutExtension, suffix, extension];
        NSString *absPath = [self makeAbsolutePathToExistingFile:fullPath];
        if(absPath != nil)
        {
            if(chosenResolutionType != nil)
            {
                *chosenResolutionType = [resolution intValue];
            }
            return absPath;
        }
    }
    
    if(chosenResolutionType != nil)
    {
        *chosenResolutionType = kCCResolutionUnknown;
    }
    return nil;
}

+ (NSArray *)resolutionTypesForDevice:(ccResolutionType)device
{
    return g_resolutionsByDevice[@(device)];
}

+ (ccResolutionType)currentDevice
{
#ifdef  __IPHONE_OS_VERSION_MAX_ALLOWED
    
	if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		if( [[UIScreen mainScreen] scale] == 2 )
        {
            return kCCResolutioniPadRetinaDisplay;
		}
        
        return kCCResolutioniPad;
	}
	else
	{
        //four inch support here, UIScreen size always in portrait and in points
        if ([[UIScreen mainScreen] bounds].size.height == 568)
        {
            return kCCResolutioniPhoneFourInchDisplay;
        }
        
		if( [[UIScreen mainScreen] scale] == 2 )
        {
            return kCCResolutioniPhoneRetinaDisplay;
		}
        
        return kCCResolutioniPhone;
	}
    
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
    
    return kCCResolutioniPhone;
    
#endif // __CC_PLATFORM_MAC
}


#pragma mark - API (General) -

+ (void)setDefaultBundle:(NSBundle*) bundle
{
    [g_defaultBundle autorelease];
    g_defaultBundle = [bundle retain];
}

+ (NSBundle *)defaultBundle
{
    return g_defaultBundle;
}

+ (NSString *)fullPathFromRelativePath:(NSString *)relPath
{
	return [self fullPathFromRelativePath:relPath resolutionType:nil];
}


#pragma mark - API (Platform Specific) -

+ (NSString*)fullPathFromRelativePath:(NSString*)relPath resolutionType:(ccResolutionType*)resolutionType
{
	NSAssert(relPath != nil, @"CCFileUtils: Invalid path");
    
#ifdef  __IPHONE_OS_VERSION_MAX_ALLOWED
    
    if([self hasKnownSuffix:relPath])
    {
        return [self makeAbsolutePathToExistingFile:relPath];
    }
    
    ccResolutionType device = [self currentDevice];
    NSArray *resolutionTypes = [self resolutionTypesForDevice:device];
    // Add raw filename lookup
    resolutionTypes = [resolutionTypes arrayByAddingObject:@(kCCResolutionUnknown)];
    
	NSString *fullpath = [self pathToExistingFile:relPath
                               forResolutionTypes:resolutionTypes
                             chosenResolutionType:resolutionType];
    
    return fullpath;
    
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
    
    if(resolutionType != nil)
    {
        *resolutionType = kCCResolutionUnknown;
    }
    
	return [self makeAbsolutePathToExistingFile:relPath];
    
#endif // __CC_PLATFORM_MAC
    
    return nil;
}


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

+ (NSString *)removeSuffixFromFile:(NSString *)path
{
    NSArray *components = [self pathComponents:path forResolutionType:kCCResolutionUnknown];
	NSString *pathWithoutExtension = components[kComponentBase];
    NSString *extension = components[kComponentExtension];
    return [NSString stringWithFormat:@"%@.%@", pathWithoutExtension, extension];
}

+ (void)setiPhoneRetinaDisplaySuffix:(NSString *)suffix
{
    [self setSuffix:suffix forResolutionType:kCCResolutioniPhoneRetinaDisplay];
}

+ (void)setiPhoneFourInchDisplaySuffix:(NSString *)suffix
{
    [self setSuffix:suffix forResolutionType:kCCResolutioniPhoneFourInchDisplay];
}

+ (void)setiPadSuffix:(NSString *)suffix
{
    [self setSuffix:suffix forResolutionType:kCCResolutioniPad];
}

+ (void)setiPadRetinaDisplaySuffix:(NSString *)suffix
{
    [self setSuffix:suffix forResolutionType:kCCResolutioniPadRetinaDisplay];
}


+(BOOL) iPhoneRetinaDisplayFileExistsAtPath:(NSString*)path
{
    return [self path:path existsForResolutionType:kCCResolutioniPhoneRetinaDisplay];
}

+(BOOL) iPhoneFourInchDisplayFileExistsAtPath:(NSString*)path
{
    return [self path:path existsForResolutionType:kCCResolutioniPhoneFourInchDisplay];
}

+(BOOL) iPadFileExistsAtPath:(NSString*)path
{
    return [self path:path existsForResolutionType:kCCResolutioniPad];
}

+(BOOL) iPadRetinaDisplayFileExistsAtPath:(NSString*)path
{
    return [self path:path existsForResolutionType:kCCResolutioniPadRetinaDisplay];
}

#endif //  __IPHONE_OS_VERSION_MAX_ALLOWED

@end
