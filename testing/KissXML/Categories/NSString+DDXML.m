#import "NSString+DDXML.h"


@implementation NSString (DDXML)

- (const xmlChar *)xmlChar
{
	return (const xmlChar *)[self UTF8String];
}

#ifdef GNUSTEP
- (NSString *)stringByTrimming
{
	return [self stringByTrimmingSpaces];
}
#else
- (NSString *)stringByTrimming
{
	NSMutableString *mStr = [self mutableCopy];
	CFStringTrimWhitespace((CFMutableStringRef)mStr);
	
	NSString *result = [mStr copy];
	
	[mStr release];
	return [result autorelease];
}
#endif


- (NSString *)trimLRSpaces
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)sqlQueryString
{
    self = [self stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    return self;
    
     
}


- (NSString *)rightSubString:(NSString *)aString
{
    
    NSRange range = [self rangeOfString:aString];
    
    if (range.length!=0) {
        return [self substringFromIndex:(range.location + range.length)];
    }
    else
    {
        return self;
    }
    
}

@end
