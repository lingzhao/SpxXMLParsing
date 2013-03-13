//
//  ViewController.m
//  testing
//
//  Created by John on 3/11/13.
//  Copyright (c) 2013 ling. All rights reserved.
//

#import "ViewController.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import "NSString+DDXML.h"

#define SQLITE_FILE_NAME @"SPXLocal.db"

#define kAttendeeTable @"MD_Attendee"
#define kBrandTable @"MD_Brand"
#define kCategoryTable @"MD_Category"
#define kContentTabTable @"MD_ContentTab"
#define kFeaturedProductTable @"MD_FeaturedProduct"
#define kFileTable @"MD_File"
#define kHotSpotTable @"MD_HotSpot"
#define kIndustryTable @"MD_Industry"
#define kProductTable @"MD_Product"
#define kSubCategoryTable @"MD_SubCategory"
#define kSystemTable @"MD_System"
#define kCategoryProductTable @"MP_Category_Product"
#define kHotSpotCategoryTable @"MP_HotSpot_Category"
#define kIndustryProductTable @"MP_Industry_Product"
#define kHotSpotSubCategoryTable @"MP_HotSpot_SubCategory"
#define kSubCategoryProductTable @"MP_SubCategory_Product"


#define kLibraryCachesPath [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define kProductXMLPath [kLibraryCachesPath stringByAppendingString:@"/SPX_DATA/productXML/"]
#define kCategoryMapXMLPath [kLibraryCachesPath stringByAppendingString:@"/SPX_DATA/listXML/"]
#define kindustryMapXMLPath [kLibraryCachesPath stringByAppendingString:@"/SPX_DATA/listXML2/"]


#define FLOATEQUAL(x,y) (fabsf(x - y) < 0.000001)

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dbPath = [NSString stringWithFormat:@"%@/%@",[paths objectAtIndex:0],SQLITE_FILE_NAME];
    
    
    
    
    _sharedDB = [[FMDatabase databaseWithPath:dbPath] retain];
    
    if (![_sharedDB open]) {
        exit(0);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_sharedDB close];
    [_sharedDB release];
    [_xmlTextView release];
    [super dealloc];
}



#pragma mark --  parse xml and store database




- (void)clearDatabase
{
    NSArray *tableArray = [[NSArray alloc] initWithObjects:kAttendeeTable,kBrandTable,kCategoryTable,kContentTabTable,kFileTable,kHotSpotTable,kIndustryTable,kProductTable,kSystemTable,kCategoryProductTable,kHotSpotCategoryTable,kIndustryProductTable,kFeaturedProductTable,kSubCategoryTable,kHotSpotSubCategoryTable,kSubCategoryProductTable,nil];
    
    for (NSUInteger i = 0; i < [tableArray count]; i++) {
        NSString *tableName = [tableArray objectAtIndex:i];
        
        NSString *sqlQuery = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        [_sharedDB executeUpdate:sqlQuery];
        sqlQuery = [NSString stringWithFormat:@"UPDATE sqlite_sequence set seq=0 where name='%@'",tableName];
        [_sharedDB executeUpdate:sqlQuery];
        
    }
    

}


 




- (IBAction)parseXML:(id)sender {
    

    
    
    [self clearDatabase];
    



	HUD = [[MBProgressHUD alloc] initWithView:self.view];
	[self.view addSubview:HUD];
	
	// Set determinate mode
	HUD.mode = MBProgressHUDModeDeterminate;
    
    HUD.dimBackground = YES;
	
	HUD.delegate = self;
    
    
    [HUD showAnimated:YES whileExecutingBlock:^{
        [self initDataBase];
        HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
        HUD.mode = MBProgressHUDModeCustomView;
        HUD.labelText = @"Completed";
        sleep(2);
    } completionBlock:^{
        NSLog(@"The task Finished");

        [HUD removeFromSuperview];
        [HUD release];
    }];
	
	

}


- (void)initDataBase
{
    // Init Database
    
    [self initBrandDB];
    
    [self initProductDB];
    
    [self updateRelatedProdID];
}



- (void)initBrandDB
{
    
    NSError *error = nil;
    
 
    NSArray  *folderArr = [[NSFileManager defaultManager]  contentsOfDirectoryAtPath:kProductXMLPath error:&error];
    
    
    NSLog(@"the folder count is %d",[folderArr count]);
    
    NSUInteger recordID = 1;
    
    NSMutableString *sqlQuery = [[NSMutableString alloc] initWithString:@""];
    
    for (NSString *folderStr in folderArr) {

        if ([folderStr hasPrefix:@"."])
            continue;
        
        NSLog(@"%@",folderStr);
        
       
        
        
        NSString *insertSQL = [NSString stringWithFormat:@"insert into %@ (ID, Name, SampleProducts, Label) values (%d, '%@', '',''); ",kBrandTable,recordID,folderStr];
        
        [sqlQuery appendString:insertSQL];
        
        recordID++;

    }
    
    [_sharedDB executeBatch:sqlQuery error:&error];
    
    [sqlQuery release];
}


- (void)initProductDB
{
    
    NSError *error = nil;
    
    
    NSArray  *folderArr = [[NSFileManager defaultManager]  contentsOfDirectoryAtPath:kProductXMLPath error:&error];
    
    
    NSUInteger prodRecordID = 1;
    NSUInteger contentRecordID = 1;
    NSUInteger fileRecordID = 1;
    
    NSMutableString *prodSqlQuery = [[NSMutableString alloc] initWithString:@""];
    NSMutableString *contentSqlQuery = [[NSMutableString alloc] initWithString:@""];
    NSMutableString *fileSqlQuery = [[NSMutableString alloc] initWithString:@""];
    
    HUD.labelText = @"Initiating";
    
    
    for (NSUInteger i = 0; i < [folderArr count]; i++) {
        
        
        HUD.progress = (1.0f/[folderArr count] * (i+1));
        
        


        
        NSString *folderStr = [folderArr objectAtIndex:i];
        
        if ([folderStr hasPrefix:@"."])
            continue;
        

        
        NSString *productXMLPath = [NSString stringWithFormat:@"%@%@/",kProductXMLPath,folderStr];
        
        NSArray *xmlListArr = [self recursivePathsForResourcesOfType:@"XML" inDirectory:productXMLPath];
        
        
        FMResultSet *rs = [_sharedDB executeQuery:[NSString stringWithFormat:@"select ID from %@ where Name = '%@'",kBrandTable,folderStr]];
        
        
        NSUInteger brandID = 1;
        
        if ([rs next]) {
            brandID = [rs intForColumnIndex:0];
        }


        
        
        //NSLog(@"XML count:%d  files: %@",[xmlListArr count], xmlListArr);
        
        for (NSUInteger i = 0; i < [xmlListArr count]; i++) {
            
            NSString *xmlFilePath = [xmlListArr objectAtIndex:i];
            
            
            DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[NSData dataWithContentsOfFile:xmlFilePath] options:0 error:&error];
            
            DDXMLElement *rootElement= [xmlDoc rootElement];
            
            
             /*********  Parsing Product BEGIN ************/
            
            NSString *prodName = [[[rootElement elementForName:@"DisplayName"] stringValue] trimLRSpaces];
            NSString *brandTxt = [[[rootElement elementForName:@"Brand"] stringValue] trimLRSpaces];
            NSString *prodTitle = [NSString stringWithFormat:@"pd-%@",[[[rootElement elementForName:@"Title"] stringValue] trimLRSpaces]];
            
            NSString *SPXUrl = [NSString stringWithFormat:@"/en/%@/%@/",brandTxt,prodTitle];
            
            NSString *insertSQL = [NSString stringWithFormat:@"insert into %@ (ID, Brand_ID, Name, Label, IsFeatured, ProductType, SPXUrl, RelatedProduct1, RelatedProduct2, RelatedProduct3, RelatedProduct4, RelatedProduct5, RelatedProduct6, RelatedProduct7, RelatedProduct8, RelatedProduct9, RelatedProduct10) values (%d, %d, '%@', '', 'No', 'Filters', '%@', null, null, null, null, null, null, null, null, null, null);",kProductTable,prodRecordID,brandID,prodName,SPXUrl];
            
            [prodSqlQuery appendString:insertSQL];
            
            prodRecordID++;
            
            
            /*********  Parsing Product END ************/
            
            
            
            
            /*********  Parsing ContentTab BEGIN ************/
            
            NSArray * descTabsArr = [xmlDoc nodesForXPath:@"/ProductDetail/Description/TabTitle" error:nil];
            
            NSArray * contentArr = [xmlDoc nodesForXPath:@"/ProductDetail/Description/TabTitle/Content" error:nil];
            
          
                
            for (DDXMLElement *aElement in contentArr) {
                NSString *tabTitle = @"Description";
                NSString *content = [[aElement stringValue] sqlQueryString];
                
                NSString *insertSQL = [NSString stringWithFormat:@"insert into %@ (ID,Product_ID, Name, XMLContent) values (%d,%d, '%@','%@');",kContentTabTable,contentRecordID,prodRecordID,tabTitle,content];
                
                [contentSqlQuery appendString:insertSQL];
                
                contentRecordID++;
                
                
            }
            

                
            for (DDXMLElement *aElement in descTabsArr) {
                

                
                NSLog(@"%@",[aElement elementForName:@"Content"]);
                
                NSString *tabTitle = [aElement stringValue];
                NSString *content = [[[(DDXMLElement *)[aElement parent] elementForName:@"Content"] stringValue] sqlQueryString];
                
                if (tabTitle != nil && content != nil) {
                    NSString *insertSQL = [NSString stringWithFormat:@"insert into %@ (ID,Product_ID, Name, XMLContent) values (%d, %d, '%@','%@');",kContentTabTable,contentRecordID,prodRecordID,tabTitle,content];
                    
                    [contentSqlQuery appendString:insertSQL];
                    
                    contentRecordID++;
                }
                

            }
            
            /*********  Parsing ContentTab END ************/
            
            
            /*********  Parsing Assets BEGIN ************/

            
            NSArray * jpgAssets = [xmlDoc nodesForXPath:@"//Asset[@type='image']" error:nil];
            NSArray * pdfFiles = [xmlDoc nodesForXPath:@"//Asset[@filetype='pdf']" error:nil];
            
            for (NSUInteger i = 0; i < [jpgAssets count]; i++) {
                
                DDXMLElement *aElement = [jpgAssets objectAtIndex:i];
                NSString *name = [[aElement elementForName:@"Title"] stringValue];
                
                NSString *smallImgFileName = [[[aElement elementForName:@"Thumbnail"] attributeForName:@"src"] stringValue];
                
                NSString *midImgFileName = [[[aElement elementForName:@"LargeImage"] attributeForName:@"src"] stringValue];
                
                NSString *largeImgFileName = [[[aElement elementForName:@"FullImage"] attributeForName:@"src"] stringValue];
                
            }
            
            
            for (DDXMLElement *aElement in pdfFiles) {
                
            }
            
            /*********  Parsing Assets END ************/

            
        }
        
 
        
    }
    
    [_sharedDB executeBatch:prodSqlQuery error:&error];
    [_sharedDB executeBatch:contentSqlQuery error:&error];
    [_sharedDB executeBatch:fileSqlQuery error:&error];
    
    [prodSqlQuery release];
    [contentSqlQuery release];
    [fileSqlQuery release];
    
    
    
}


- (void)updateRelatedProdID
{
    
    NSError *error = nil;
    
    
    NSArray  *folderArr = [[NSFileManager defaultManager]  contentsOfDirectoryAtPath:kProductXMLPath error:&error];
    
    
    NSUInteger recordID = 1;
    
    
   HUD.labelText = @"Updating";
    
    
    
    NSMutableString *sqlQuery = [[NSMutableString alloc] initWithString:@""];
    
    for (NSUInteger i = 0; i < [folderArr count]; i++) {
        
        
        HUD.progress = (1.0f/[folderArr count] * (i+1));
        

        
        NSString *folderStr = [folderArr objectAtIndex:i];
        
        if ([folderStr hasPrefix:@"."])
            continue;
        
        
        
        NSString *productXMLPath = [NSString stringWithFormat:@"%@%@/",kProductXMLPath,folderStr];
        
        NSArray *xmlListArr = [self recursivePathsForResourcesOfType:@"XML" inDirectory:productXMLPath];
        
 
        for (NSUInteger i = 0; i < [xmlListArr count]; i++) {
            
            NSString *xmlFilePath = [xmlListArr objectAtIndex:i];
            
            
            
            
            DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[NSData dataWithContentsOfFile:xmlFilePath] options:0 error:&error];
            
 

            
            NSArray *relatedProductsNodes = [xmlDoc nodesForXPath:@"//RelatedProducts" error:nil];
            
            NSMutableArray *relatedProdsList = [[NSMutableArray alloc] init];
            
            BOOL bFound = NO;
            
            for (DDXMLElement* aElement in relatedProductsNodes) {
                
                if ([[[aElement elementForName:@"h2"] stringValue] isEqualToString:@"RELATED PRODUCTS"]) {
                    NSArray *relatedProds = [aElement elementsForName:@"Product"];
                    
                    for (DDXMLElement* aElement in relatedProds)
                    {
                        [relatedProdsList addObject:[[aElement elementForName:@"h3"] stringValue]];
                    }
                    
                }
            }
            
            NSLog(@"relatedProdsList:%@", relatedProdsList);
            
            NSMutableString *relatedProdSqlString  = [[NSMutableString alloc] initWithString:@""];
            
            for (NSUInteger i = 0; i < [relatedProdsList count]; i++) {

                NSString *prodName = [relatedProdsList objectAtIndex:i];
                
                FMResultSet *rs = [_sharedDB executeQuery:[NSString stringWithFormat:@"select ID from %@ where Name = '%@'",kProductTable,prodName]];
                
                
                NSUInteger productID;
                
                if ([rs next]) {
                    productID = [rs intForColumnIndex:0];
                }
                
                [relatedProdSqlString appendFormat:@"RelatedProduct%d = %d, ",i+1,productID];
                
                bFound = YES;
            
            }
            
            if (bFound) {
        
                
                NSString *updateSQL = [NSString stringWithFormat:@"update %@ set %@ where ID = %d;",kProductTable,[relatedProdSqlString substringToIndex:[relatedProdSqlString length] - 2],recordID];
                
                [sqlQuery appendString:updateSQL];
                
            }
            
            recordID++;
            
            [relatedProdsList release];
            [relatedProdSqlString release];
            
        }
        
        
        
    }
    

    [_sharedDB executeBatch:sqlQuery error:&error];

    [sqlQuery release];
    
    
    
    
    
    
}


#pragma mark -- utilities


- (NSArray *) recursivePathsForResourcesOfType: (NSString *)type inDirectory: (NSString *)directoryPath{
    
    NSMutableArray *filePaths = [[[NSMutableArray alloc] init] autorelease];
    
    // Enumerators are recursive
    NSDirectoryEnumerator *enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:directoryPath] retain] ;
    
    NSString *filePath;
    
    while ( (filePath = [enumerator nextObject] ) != nil ){
        
        // If we have the right type of file, add it to the list
        // Make sure to prepend the directory path
        if( [[[filePath pathExtension] lowercaseString] isEqualToString:[type lowercaseString]] ){
            [filePaths addObject:[directoryPath stringByAppendingString: filePath]];
        }
    }
    
    [enumerator release];
    
    return filePaths;
}


@end
