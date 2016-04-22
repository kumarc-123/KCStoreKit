//
//  KCStoreKitUtil.m
//  KCStoreKit
//
//  Created by Kumar C on 4/22/16.
//  Copyright © 2016 Kumar C. All rights reserved.
//

#import "KCStoreKitUtil.h"
#import <StoreKit/StoreKit.h>
#import "KCConstants.h"

@interface KCStoreKitUtil () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
    struct {
        unsigned int storeKitDidFinishPurchase:1;
        unsigned int storeKitDidFailWithError:1;
    } delegateRespondsTo;
    
    
    KCProductsRequestHandler productsRequestHandler;
}

BOOL isValidReciept ();

@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSSet *productIdentifiers;
@property (nonatomic, strong) NSMutableSet *purchasedProductIdentifiers;

@property (nonatomic, strong) NSArray *loadedProducts;

- (instancetype) initWithProductIdentifiers : (nonnull NSSet *) productIdentifiers;

@end


@implementation KCStoreKitUtil
- (instancetype) initWithProductIdentifiers:(NSSet *)productIdentifiers
{
    NSParameterAssert(productIdentifiers != nil && [productIdentifiers isKindOfClass:[NSSet class]] && productIdentifiers.count > 0);
    if ((self = [super init])) {
        
        _productIdentifiers = productIdentifiers;
        
        _bundleVersion = [[NSUserDefaults standardUserDefaults] objectForKey:KCStoreBundleVersionKey];
        _appBundleId = [[NSUserDefaults standardUserDefaults] objectForKey:KCStoreBundleIdKey];
        
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString * productIdentifier in _productIdentifiers) {
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"Previously purchased: %@", productIdentifier);
            } else {
                NSLog(@"Not purchased: %@", productIdentifier);
            }
        }
        
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
    }
    return self;
}

- (void)requestProductsWithCompletionHandler:(KCProductsRequestHandler)completionHandler {
    
    
    productsRequestHandler = [completionHandler copy];
    
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
    
}

- (BOOL)productPurchased:(NSString *)productIdentifier {
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(NSString *)productIdentifier {
    
    NSParameterAssert(productIdentifier != nil);
    
//    NSLog(@"Buying %@...", productIdentifier);
    
    if (_loadedProducts == nil) {
        [self requestProductsWithCompletionHandler:^(BOOL success, NSArray *products, NSError * _Nullable error) {
            if (success && products && products.count > 0) {
                NSLog(@"Loaded : %@", products);
                
                _loadedProducts = products;
                for (SKProduct *product in _loadedProducts) {
                    if ([[product productIdentifier] isEqualToString:productIdentifier]) {
                        SKPayment * payment = [SKPayment paymentWithProduct:product];
                        [[SKPaymentQueue defaultQueue] addPayment:payment];
                        break;
                    }
                }
            }
            else
            {
                NSLog(@"Error : %@", error);
                
                if ([_delegate respondsToSelector:@selector(storeDidFailWithError:)]) {
                    [_delegate storeDidFailWithError:[error.userInfo valueForKey:NSLocalizedDescriptionKey]];
                }
            }
        }];
    }
    else if (_loadedProducts.count > 0)
    {
        for (SKProduct *product in _loadedProducts) {
            if ([[product productIdentifier] isEqualToString:productIdentifier]) {
                SKPayment * payment = [SKPayment paymentWithProduct:product];
                [[SKPaymentQueue defaultQueue] addPayment:payment];
                break;
            }
        }
    }
    else
    {
        if ([_delegate respondsToSelector:@selector(storeDidFailWithError:)]) {
            [_delegate storeDidFailWithError:@"Unable to load products."];
        }
    }
}

- (void)validateReceiptForTransaction:(SKPaymentTransaction *)transaction {
    
    if (isValidReciept()) {
        NSLog(@"Successfully verified receipt!");
        NSString *pId = transaction.payment.productIdentifier;
        for (SKProduct *product in _loadedProducts) {
            if ([product.productIdentifier isEqualToString:pId]) {
                [self provideContentForProductIdentifier:transaction.payment.productIdentifier withTransactionId:transaction.transactionIdentifier price:product.price.floatValue];
                break;
            }
        }
    }
    else
    {
        [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        if ([_delegate respondsToSelector:@selector(storeDidFailWithError:)]) {
            [_delegate storeDidFailWithError:@"Unable to validate reciept."];
        }
    }
//    RecieptValidator * verifier = [RecieptValidator sharedInstance];
//    [verifier verifyPurchase:transaction completionHandler:^(BOOL success) {
//        if (success) {
//            NSLog(@"Successfully verified receipt!");
//            NSString *pId = transaction.payment.productIdentifier;
//            for (SKProduct *product in _loadedProducts) {
//                if ([product.productIdentifier isEqualToString:pId]) {
//                    [self provideContentForProductIdentifier:transaction.payment.productIdentifier withTransactionId:transaction.transactionIdentifier price:product.price.floatValue];
//                    break;
//                }
//            }
//        } else {
//            NSLog(@"Failed to validate receipt.");
//            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
//        }
//    }];
}

-(int)daysRemainingOnSubscription {
    
    NSDate * expiryDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExpirationDate"];
    
    NSDateFormatter *dateformatter = [NSDateFormatter new];
    [dateformatter setDateFormat:@"dd MM yyyy"];
    NSTimeInterval timeInt = [[dateformatter dateFromString:[dateformatter stringFromDate:expiryDate]] timeIntervalSinceDate: [dateformatter dateFromString:[dateformatter stringFromDate:[NSDate date]]]]; //Is this too complex and messy?
    int days = timeInt / 60 / 60 / 24;
    
    if (days >= 0) {
        return days;
    } else {
        return 0;
    }
}

-(NSString *)getExpiryDateString {
    if ([self daysRemainingOnSubscription] > 0) {
        NSDate *today = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExpirationDate"];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
        [dateFormat setDateFormat:@"dd/MM/yyyy"];
        return [NSString stringWithFormat:@"Subscribed! \nExpires: %@ (%i Days)",[dateFormat stringFromDate:today],[self daysRemainingOnSubscription]];
    } else {
        return @"Not Subscribed";
    }
}

-(NSDate *)getExpiryDateForMonths:(int)months {
    
    NSDate *originDate;
    
    if ([self daysRemainingOnSubscription] > 0) {
        originDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExpirationDate"];
    } else {
        originDate = [NSDate date];
    }
    NSDateComponents *dateComp = [[NSDateComponents alloc] init];
    [dateComp setMonth:months];
    [dateComp setDay:1]; //an extra days grace because I am nice...
    return [[NSCalendar currentCalendar] dateByAddingComponents:dateComp toDate:originDate options:0];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
//    NSLog(@"Loaded list of products...");
    _productsRequest = nil;
    
    NSArray * skProducts = response.products;
//    for (SKProduct * skProduct in skProducts) {
//        NSLog(@"Found product: %@ %@ %0.2f",
//              skProduct.productIdentifier,
//              skProduct.localizedTitle,
//              skProduct.price.floatValue);
//    }
    
    if (productsRequestHandler) {
        productsRequestHandler (YES, skProducts, nil);
        productsRequestHandler = nil;
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
//    NSLog(@"Failed to load list of products.");
    _productsRequest = nil;
    
    if (productsRequestHandler) {
        productsRequestHandler (NO, nil, error);
        productsRequestHandler = nil;
    }
}

#pragma mark SKPaymentTransactionOBserver

- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    for (SKPaymentTransaction * transaction in queue.transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void) paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
//    NSLog(@"Error : %@", error);
    if ([_delegate respondsToSelector:@selector(storeDidFailWithError:)]) {
        [_delegate storeDidFailWithError:[error.userInfo valueForKey:NSLocalizedDescriptionKey]];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
//    NSLog(@"completeTransaction...");
    
    [self validateReceiptForTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
//    NSLog(@"restoreTransaction...");
    
    [self validateReceiptForTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
//    NSLog(@"failedTransaction...");
//    if (transaction.error.code != SKErrorPaymentCancelled)
//    {
//        NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
//    }
    
    
    if ([_delegate respondsToSelector:@selector(storeDidFailWithError:)]) {
        [_delegate storeDidFailWithError:[transaction.error.userInfo valueForKey:NSLocalizedDescriptionKey]];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];

}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier withTransactionId : (NSString *) transactionId price : (float) price{
    
    [_purchasedProductIdentifiers addObject:productIdentifier];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if ([_delegate respondsToSelector:@selector(storeDidFinishPurchase:withTransactionId:forPirce:)]) {
        [_delegate storeDidFinishPurchase:productIdentifier withTransactionId:transactionId forPirce:price];
    }
}

- (void)restoreCompletedTransactions {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end


#import <Security/Security.h>

#include <openssl/pkcs7.h>
#include <openssl/objects.h>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/err.h>



BOOL isValidReciept (NSString *_bundleId, NSString *_bundleVersion )
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *receiptURL = [mainBundle appStoreReceiptURL];
    NSError *receiptError;
    BOOL isPresent = [receiptURL checkResourceIsReachableAndReturnError:&receiptError];
    if (!isPresent) {
        return NO;
    }
    
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    
    BIO *receiptBIO = BIO_new(BIO_s_mem());
    BIO_write(receiptBIO, [receiptData bytes], (int) [receiptData length]);
    PKCS7 *receiptPKCS7 = d2i_PKCS7_bio(receiptBIO, NULL);
    if (!receiptPKCS7) {
        return NO;
    }
    
    if (!PKCS7_type_is_signed(receiptPKCS7)) {
        return NO;
    }
    
    if (!PKCS7_type_is_data(receiptPKCS7->d.sign->contents)) {
        return NO;
    }
    
    // Load the Apple Root CA (downloaded from https://www.apple.com/certificateauthority/)
    NSURL *appleRootURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    NSData *appleRootData = [NSData dataWithContentsOfURL:appleRootURL];
    BIO *appleRootBIO = BIO_new(BIO_s_mem());
    BIO_write(appleRootBIO, (const void *) [appleRootData bytes], (int) [appleRootData length]);
    X509 *appleRootX509 = d2i_X509_bio(appleRootBIO, NULL);
    
    X509_STORE *store = X509_STORE_new();
    X509_STORE_add_cert(store, appleRootX509);
    
    OpenSSL_add_all_digests();
    
    int result = PKCS7_verify(receiptPKCS7, NULL, store, NULL, NULL, 0);
    if (result != 1) {
        return NO;
    }
    
    ASN1_OCTET_STRING *octets = receiptPKCS7->d.sign->contents->d.data;
    const unsigned char *ptr = octets->data;
    const unsigned char *end = ptr + octets->length;
    const unsigned char *str_ptr;
    
    int type = 0, str_type = 0;
    int xclass = 0, str_xclass = 0;
    long length = 0, str_length = 0;
    
    NSString *bundleIdString = nil;
    NSString *bundleVersionString = nil;
    NSData *bundleIdData = nil;
    NSData *hashData = nil;
    NSData *opaqueData = nil;
    NSDate *expirationDate = nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_SET) {
        return NO;
    }
    
    while (ptr < end) {
        ASN1_INTEGER *integer;
        
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_SEQUENCE) {
            return NO;
        }
        
        const unsigned char *seq_end = ptr + length;
        long attr_type = 0;
        long attr_version = 0;
        
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_INTEGER) {
            return NO;
        }
        integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
        attr_type = ASN1_INTEGER_get(integer);
        ASN1_INTEGER_free(integer);
        
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_INTEGER) {
            return NO;
        }
        integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
        attr_version = ASN1_INTEGER_get(integer);
        ASN1_INTEGER_free(integer);
        
        ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
        if (type != V_ASN1_OCTET_STRING) {
            return NO;
        }
        
        switch (attr_type) {
            case 2:
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    bundleIdString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                    bundleIdData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                }
                break;
                
            case 3:
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_UTF8STRING) {
                    bundleVersionString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                }
                break;
                
            case 4:
                opaqueData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                break;
                
            case 5:
                hashData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
                break;
                
            case 21:
                str_ptr = ptr;
                ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
                if (str_type == V_ASN1_IA5STRING) {
                    NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
                    expirationDate = [formatter dateFromString:dateString];
                }
                break;
                
                // You can parse more attributes...
                
            default:
                break;
        }
        
        ptr += length;
    }
    
    if (bundleIdString == nil ||
        bundleVersionString == nil ||
        opaqueData == nil ||
        hashData == nil) {
        return NO;
    }
    
    if (![bundleIdString isEqualToString:_bundleId]) {
        return NO;
    }
    
    if (![bundleVersionString isEqualToString:_bundleVersion]) {
        return NO;
    }
    
    UIDevice *device = [UIDevice currentDevice];
    NSUUID *identifier = [device identifierForVendor];
    uuid_t uuid;
    [identifier getUUIDBytes:uuid];
    NSData *guidData = [NSData dataWithBytes:(const void *)uuid length:16];
    
    unsigned char hash[20];
    
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    SHA1_Update(&ctx, [guidData bytes], (size_t) [guidData length]);
    SHA1_Update(&ctx, [opaqueData bytes], (size_t) [opaqueData length]);
    SHA1_Update(&ctx, [bundleIdData bytes], (size_t) [bundleIdData length]);
    SHA1_Final(hash, &ctx);
    
    NSData *computedHashData = [NSData dataWithBytes:hash length:20];
    if (![computedHashData isEqualToData:hashData]) {
        return NO;
    }
    
    return YES;
}
