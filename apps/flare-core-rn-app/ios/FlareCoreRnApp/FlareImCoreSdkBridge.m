#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(FlareImCoreSdk, NSObject)

RCT_EXTERN_METHOD(invoke:(NSString *)operation
                  requestJson:(NSString *)requestJson
                  descriptorJson:(NSString *)descriptorJson
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
