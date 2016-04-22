//
//  KCStoreManager.m
//  KCStoreKit
//
//  Created by Kumar C on 4/22/16.
//  Copyright © 2016 Kumar C. All rights reserved.
//

#import "KCStoreManager.h"
#import "KCConstants.h"

@implementation KCStoreManager

+ (instancetype) sharedManager
{
    static KCStoreManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        NSSet *productIdentifiers = [[NSUserDefaults standardUserDefaults] objectForKey:KCStoreProductIdentifiersKey];
        
        sharedInstance = [[self alloc] initWithProductIdentifiers:productIdentifiers];
    });
    return sharedInstance;
}

+ (instancetype) storeWithAttributes : (NSDictionary *) attributes
{
    NSParameterAssert(attributes != nil && attributes.count == 3);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[attributes objectForKey:KCStoreBundleIdKey] forKey:KCStoreBundleIdKey];
    [defaults setObject:[attributes objectForKey:KCStoreBundleVersionKey] forKey:KCStoreBundleVersionKey];
    [defaults setObject:[attributes objectForKey:KCStoreProductIdentifiersKey] forKey:KCStoreProductIdentifiersKey];

    [defaults synchronize];
    
    return [self sharedManager];
}


@end
