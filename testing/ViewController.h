//
//  ViewController.h
//  testing
//
//  Created by John on 3/11/13.
//  Copyright (c) 2013 ling. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"
#import "MBProgressHUD.h"

@interface ViewController : UIViewController<MBProgressHUDDelegate>
{
    BOOL _bIsParsingFinished;
    MBProgressHUD *HUD;  
}


@property (retain, nonatomic) IBOutlet UITextView *xmlTextView;
@property (nonatomic,retain)  FMDatabase *sharedDB;
- (IBAction)parseXML:(id)sender;

@end
