//
//  CIAudioManager.h
//
//  Created by Jeremy FAIVRE on 28/09/2016.
//  Copyright © 2016 Jeremy FAIVRE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/** Some audio sequencer */
@interface CIAudioSequencer : NSObject

// @property (nonatomic, readonly) NSString *name;
//
// /** The duration of the loop */
// @property (nonatomic) NSTimeInterval loopDuration;
//
// @property (nonatomic, copy, nullable) NSString * (^blockName)(NSString *, NSString *argsJson);

+ (void *(^_Nullable)(NSString *, CGFloat youpi))blockForName:(void(^_Nullable)(NSString *, CGFloat *youpi))name;

// // Some method
// - (instancetype)initWithLoopDuration:(NSTimeInterval)loopDuration;
//
// - (void)dispose;
//
// - (void)pause;
//
// - (void)pauseSynchronized:(BOOL)runSync;
//
// /* More comment
// */
// - (void)resume;
//
//
//
// - (void)startLooping;
//
// - (void)stopLooping;
//
// /// Some comment
// // Some other comment (and testing a method written on several lines)
// - (void)putLoopSound:
// (NSString *)path
// atChannel:  (NSInteger) channel;
//
// - (void)removeLoopSoundAtChannel:(NSInteger)channel;
//
// - (void)setVolume:(CGFloat)volume atChannel:(NSInteger)channel;
//
// - (CGFloat)volumeAtChannel:(NSInteger)channel;


@end
