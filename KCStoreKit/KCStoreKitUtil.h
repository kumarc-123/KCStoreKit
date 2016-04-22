//
//  KCStoreKitUtil.h
//  KCStoreKit
//
//  Created by Kumar C on 4/22/16.
//  Copyright © 2016 Kumar C. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^KCProductsRequestHandler) (BOOL success, NSArray  * _Nullable products, NSError * _Nullable error);
typedef void (^KCVerificationnHandler) (BOOL success);

@protocol KCStoreDelegate <NSObject>

@required

- (void) storeDidFinishPurchase : (nonnull NSString * const) productIdentifier withTransactionId : (nonnull NSString *) transactionId forPirce : (float) price;

- (void) storeDidFailWithError : (nonnull NSString *) error;

@end

@interface KCStoreKitUtil : NSObject

@property (nullable, nonatomic, copy, readonly) NSString *appBundleId;

@property (nullable, nonatomic, copy, readonly) NSString *bundleVersion;

@property (nonatomic, weak) id <KCStoreDelegate> delegate;

- (nullable instancetype) initWithProductIdentifiers:(nonnull NSSet *)productIdentifiers;

/// Request a list of products defined or supported by the app from iTunes.
- (void) requestProductsWithCompletionHandler : (nonnull KCProductsRequestHandler) completionHandler;

/// Initiates transaction request for a specified product
- (void) buyProduct : (nonnull NSString * const) productIdentifier;

/// Restores previously purchased non-consumable or non-completed purchases for which the user has already paid the amount.
- (void) restoreCompletedTransactions;

@end
