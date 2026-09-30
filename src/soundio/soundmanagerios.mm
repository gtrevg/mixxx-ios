#include <QDebug>
#include <QtGlobal>

#import <AVFAudio/AVFAudio.h>

namespace mixxx {

namespace {

void activateAVAudioSession() {
    AVAudioSession* session = AVAudioSession.sharedInstance;
    NSError* error = nil;
    // Playback (not Ambient/SoloAmbient) is required for UIBackgroundModes=audio
    // to keep the process alive when the UI is suspended.
    // Avoid MixWithOthers so iOS treats Mixxx as an active media app.
    const AVAudioSessionCategoryOptions options = 0;
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:options
                   error:&error];
    if (error != nil) {
        qWarning() << "Could not initialize AVAudioSession:"
                   << error.localizedDescription;
        error = nil;
    }

    [session setActive:YES error:&error];
    if (error != nil) {
        qWarning() << "Could not activate AVAudioSession:"
                   << error.localizedDescription;
    }
}

} // namespace

void initializeAVAudioSession() {
    activateAVAudioSession();

    // Re-activate after interruptions (phone, Siri, other apps). Do not tear
    // down Mixxx playback state here — only restore the session so PortAudio
    // can keep running once we are allowed to again.
    NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:AVAudioSessionInterruptionNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification* notification) {
                      NSNumber* typeNumber =
                              notification.userInfo[AVAudioSessionInterruptionTypeKey];
                      if (typeNumber == nil) {
                          return;
                      }
                      const auto type =
                              static_cast<AVAudioSessionInterruptionType>(
                                      typeNumber.unsignedIntegerValue);
                      if (type == AVAudioSessionInterruptionTypeEnded) {
                          qDebug() << "AVAudioSession interruption ended; "
                                      "reactivating";
                          activateAVAudioSession();
                      } else {
                          qDebug() << "AVAudioSession interruption began";
                      }
                    }];
}

}; // namespace mixxx
