#import "SpeechToTextPlugin.h"
#import <speech_to_text/speech_to_text-Swift.h>

@implementation SpeechToTextPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSpeechToTextPlugin registerWithRegistrar:registrar];
}
@end
