//
//  KCStoreManager.h
//  KCStoreKit
//
//  Created by Kumar C on 4/22/16.
//  Copyright © 2016 Kumar C. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KCStoreKitUtil.h"

@interface KCStoreManager : KCStoreKitUtil

/**
 *  The shared Store Manager singleton for all operations;
 *
 *  @return Singleton object
 */
+ (nullable instancetype) sharedManager;

/**
 *  Initializes the KCStoreManager
 *
 *  @param dictionary The dictionary should contain three values. Example
 * NSdictionary *attributes = @{
                                KCStoreBundleIdKey : @"<Your application bundle Id>",
                                KCStoreBundleVersionKey : @"<Your applicatioj bundle version. The is CFBundleVersion>",
                                KCStoreProductIdentifiersKey : [NSSet setWithObjects : @"com.companyname.appname.productname01", @"com.companyname.appname.productname02", nil]
                                };
 *
 *  @return The shared instance of KCStoreManager
 */
+ (nullable instancetype) storeWithAttributes : (nonnull NSDictionary *) attributes;

@end
