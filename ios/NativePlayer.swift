//
//  NativePlayer.swift
//  SoundCloudProject
//
//  Created by Hoang Doan on 6/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import MediaPlayer

@objc(NativePlayer)
class NativePlayer: RCTEventEmitter {
  
  var player: AVQueuePlayer?
  var interruptedOnPlayback = false
  var playing = false
  var isPaused = true
  var didOnce = true
  var isSliding = false
  var observerToken: Any? = nil
  var duration = 0
  var timeString: String?
  var backgroundIdentifier = UIBackgroundTaskInvalid
  var controlHandle = true
  var isCheckingBuffer = false
  var seconds = 60
  var timer =  Timer()
  var isFailed = false
  

  func convertTime(time: Float) -> String {
    
    let hours  = Int(time/3600)
    let minute = Int((Int(time) - hours*3600)/60)
    let second = Int(time) - (hours*3600) - minute*60
    
    return String(format:"%02i:%02i", minute, second)
  }
  
  func playTrack(url: String) {
    sendEvent(event: "loading")
    isCheckingBuffer = false
    let index = url.index(url.startIndex, offsetBy: 4)
    let item: AVPlayerItem?
    print(url)
    if let token = observerToken {
      player?.removeTimeObserver(token)
      observerToken = nil
    }
    if player != nil {
      print("NOT NILL")
      self.unregistedObserver()
      if url.substring(to: index) == "http" {
        item  = AVPlayerItem(url: URL(string:url)!)
      } else {
        let paths: [AnyObject] = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [AnyObject]
        let audioUrl = "/" + url + ".mp3"
        
        let audiofilePath = paths[0].appending(audioUrl)
        
        item = AVPlayerItem(url: URL.init(fileURLWithPath: audiofilePath))
      }
      
      
      if isFailed {
        player = AVQueuePlayer.init(items: [item!])
        player?.actionAtItemEnd = AVPlayerActionAtItemEnd.none
      } else {
        player?.insert(item!, after: nil)
        player?.advanceToNextItem()
        print("NEXT")
      }
      
    } else {
      print("NILL")
      print(url.substring(to: index))
      if url.substring(to: index) == "http" {
        item  = AVPlayerItem(url: URL(string:url)!)
      } else {
        let paths: [AnyObject] = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [AnyObject]
        let audioUrl = "/" + url + ".mp3"
        
        let audiofilePath = paths[0].appending(audioUrl)

        item = AVPlayerItem(url: URL.init(fileURLWithPath: audiofilePath))
      }
      
      player = AVQueuePlayer.init(items: [item!])
      player?.actionAtItemEnd = AVPlayerActionAtItemEnd.none
      
    }
    self.configureBackgroundAudioTask()
    observerToken = player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: CMTimeScale(60000)), queue: .main, using: { (time) in
      let currentTimeSeconds = CMTimeGetSeconds(time)
      
      guard let current = self.player?.currentItem?.currentTime() else {
        return
      }
      
      guard let loadTime = self.player?.currentItem?.loadedTimeRanges else {
        return
      }
      
      if loadTime.count != 0 {
        
        let remain = Double(self.duration)/1000 - CMTimeGetSeconds(current)
        
        let percent = Float(CMTimeGetSeconds(current)) / (Float(self.duration)/1000)
        
        let playingTime = self.convertTime(time: Float(currentTimeSeconds))
        let remainTime = self.convertTime(time: Float(remain))
        
        if (self.timeString != remainTime) {
          MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(currentTimeSeconds)
          self.timeString = remainTime
          if (!self.isSliding) {
            print("Percent: ", percent)
            let body: [String: Any] = ["name": "progress", "playingTime": playingTime, "remainingTime": remainTime, "percent": percent]
            //self.bridge.eventDispatcher().sendDeviceEvent(withName: "StreamingPlayer", body: body)
            self.sendEvent(withName: "StreamingPlayer", body: body)

          }
        }
      }
      
    })
    
    self.registedObserver()
    self.handleNotificationCenter()
    self.unregisterRemoteControlEvents()
    self.registerRemoteControlEvents()
    
  }
  
  @objc(play:duration:)
  func play(url: String, duration: String) {
    sendEvent(event: "loading")
    self.duration = Int(duration)!
    self.playTrack(url: url)
  }
  
  @objc(handleResume)
  func handleResume() {
    guard let player = player else { return }
    if player.isPlaying {
      player.pause()
      sendEvent(event: "pause")
      playing = false
      MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    } else {
      player.play()
      playing = true
      sendEvent(event: "playing")
      MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1

    }
  }
  
  
  func registedObserver() {
    player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: NSKeyValueObservingOptions.new, context: nil)
    player?.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: NSKeyValueObservingOptions.new, context: nil)
    player?.currentItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: NSKeyValueObservingOptions.new, context: nil)
    player?.currentItem?.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
  }
  
  func unregistedObserver() {
    player?.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    player?.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
    player?.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull")
    
    player?.currentItem?.removeObserver(self, forKeyPath: "status")
  }
  
  
  //START handle slide
  @objc(onSlide)
  func onSlide() {
    self.isSliding = true
  }
  
  @objc(endSlide)
  func endSlide() {
    print("END")
    self.isSliding = false
  }
  
  @objc(seekTo:duration:)
  func seekTo(time: String, duration: String) {
    
    guard  let convertTime = Float(time) else {
      return
    }
    
    let seekTime = convertTime/1000 * Float(duration)!
    
    self.player?.seek(to: CMTime(seconds: Double(seekTime), preferredTimescale: 60000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
  }
  
  
  //END handle slide
  
  
  //handle Observer
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if let object = object as? AVPlayerItem, let playerItem = player?.currentItem, object == playerItem {
      switch keyPath!{
      case "status":
        if playerItem.status == AVPlayerItemStatus.readyToPlay {
          debugPrint("AVPLAYER ITEM STATUS: READY TO PLAY")
          sendEvent(event: "ready")
          isFailed = false
          
        } else if playerItem.status == AVPlayerItemStatus.failed {
          sendEvent(event: "error")
          isFailed = true
          debugPrint("AVPLAYER ITEM STATUS: FAILED \(String(describing: playerItem.error))")
          player?.pause()
          sendEvent(event: "pause")
          playing = false
          MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        break
      case "playbackBufferEmpty":
        debugPrint("AVPLAYER ITEM: playbackBufferEmpty")
        if playerItem.isPlaybackBufferEmpty {
          print("isPlaybackBufferEmpty")
        } else {
          print("isNOT PlaybackBufferEmpty")
        }
        break
      case "playbackLikelyToKeepUp":
        debugPrint("AVPLAYER ITEM: playbackLikelyToKeepUp")
        if (!self.isCheckingBuffer) {
          player?.play()
          self.controlHandle = true
          sendEvent(event: "playing")
          self.isCheckingBuffer = true
        }

        if playerItem.isPlaybackLikelyToKeepUp {
          print("YESSSSS")
          
          
        }
        break
      case "playbackBufferFull":
        if playerItem.isPlaybackBufferFull {
          print("isPlaybackBufferFull")
        } else {
          print("is NOT PlaybackBufferFull")
        }
        debugPrint("AVPLAYER ITEM: playbackBufferFull")
        break
      default:
        break
      }
    }
  }
  
  //handle NotifcationCenter
  
  func handleNotificationCenter() {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePlayerFailedToPlayToEnd(_:)), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
    
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
    
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePlayerEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
  }
  
  func handleInterruption(_ notification : Notification) {
    guard let userInfo = notification.userInfo as? [String: AnyObject] else { return }
    guard let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
    guard let interruptionType = AVAudioSessionInterruptionType(rawValue: rawInterruptionType.uintValue) else { return }
    
    switch interruptionType {
    case .began: //interruption started
      guard let player = player else { return }
      if player.isPlaying {
        player.pause()
        playing = false
        sendEvent(event: "pause")
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
      }
    case .ended: //interruption ended
      if let rawInterruptionOption = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber {
        let interruptionOption = AVAudioSessionInterruptionOptions(rawValue: rawInterruptionOption.uintValue)
        if interruptionOption == AVAudioSessionInterruptionOptions.shouldResume {
          guard let player = player else { return }
          if player.isPlaying {
            player.pause()
            playing = false
            sendEvent(event: "pause")
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
          } else {
            sendEvent(event: "playing")
            sendEvent(event: "resume")
            playing = true
            player.play()

            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
          }
        }
      }
    }
  }
  
  func handlePlayerFailedToPlayToEnd(_ notification : Notification) {
    sendEvent(event: "error")
    player?.pause()
    sendEvent(event: "pause")
    playing = false
    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
  }
  
  func handlePlayerEnd(_ notification : Notification){
    sendEvent(event: "end")
  }
  
  func audioRouteChangeListener(_ notification:Notification){
    let audioRouteChangeReason = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
    switch audioRouteChangeReason {
    case AVAudioSessionRouteChangeReason.newDeviceAvailable.rawValue:
      print("Plugin")
    case AVAudioSessionRouteChangeReason.oldDeviceUnavailable.rawValue:
      player?.pause()
      playing = false
      sendEvent(event: "pause")
      MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds((player?.currentItem?.currentTime())!)
      MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    default:
      break
    }
  }
  
  //sendEvent to React Native
  func sendEvent(event: String) {
    let body: [String: Any] = ["name": event]
//    self.bridge.eventDispatcher.sendDeviceEvent(withName: "StreamingPlayer", body: body)
    self.sendEvent(withName: "StreamingPlayer", body: body)
  }
  
  //TODO: configure Media Center 
  
  //TODO: Play Background
  @objc(configureAudioSession)
  func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setActive(true)
      try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
    } catch {
      debugPrint("AUDIO SESSION SET CATEGORY FAILED: \(error)")
    }
    UIApplication.shared.beginReceivingRemoteControlEvents()
    NotificationCenter.default.addObserver(self, selector: #selector(audioRouteChangeListener(_:)),name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
    
  }
  
  //Do Background Task
  func configureBackgroundAudioTask() {
    backgroundIdentifier =  UIApplication.shared.beginBackgroundTask (expirationHandler: { () -> Void in
      UIApplication.shared.endBackgroundTask(self.backgroundIdentifier)
        self.backgroundIdentifier = UIBackgroundTaskInvalid
    })
  }
  
  func stopBackground() {
    UIApplication.shared.endBackgroundTask(backgroundIdentifier)
    backgroundIdentifier = UIBackgroundTaskInvalid
  }
  //END background Task
  
  
  //BEGIN Handle Media Control
  @objc(setPlayingInfoCenter:artist:artwork:duration:)
  func setPlayingInfoCenter(title: String, artist: String, artwork: String, duration: String) {
    
    var nowPlayingInfo: [String: Any] = [MPMediaItemPropertyTitle: title,
                                         MPMediaItemPropertyArtist: artist,
                                         MPNowPlayingInfoPropertyPlaybackRate: 1
    ]
    
    let index = artwork.index(artwork.startIndex, offsetBy: 4)
    
    if artwork.substring(to: index) == "http" {
      if let url = URL.init(string: artwork) {
        do {
          let data = try Data.init(contentsOf: url)
          if let image = UIImage.init(data: data) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.init(image: image)
          }
        } catch {
          debugPrint("load image failed: \(error)")
        }
      }
    } else {
      let paths: [AnyObject] = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [AnyObject]
      let imageUrl = "/" + artwork
      
      let imagePath = paths[0].appending(imageUrl)
      
      let url = URL(fileURLWithPath: imagePath)
      do {
          let data = try Data.init(contentsOf: url)
          if let image = UIImage.init(data: data) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork.init(image: image)
          }
        } catch {
          debugPrint("load image failed: \(error)")
        }
      
    }
    

    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(duration)! / 1000
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    
  }
  
  func handleRemoteCommandCenterNextTrack() {
    print("Next")
    if self.controlHandle == true {
      sendEvent(event: "nextTrack")
      self.controlHandle = false
    }    
  }
  
  func handleRemoteCommandCenterPreviousTrack() {
    if self.controlHandle == true {
      sendEvent(event: "previousTrack")
      self.controlHandle = false
    }
  }
  
  func handleRemoteCmamandCenterPlay() {
    player?.play()
    sendEvent(event: "playing")
    sendEvent(event: "resume")
    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds((player?.currentItem?.currentTime())!)

    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
  }
  
  func handleRemoteCommandCenterPause() {
    player?.pause()
    sendEvent(event: "pause")
    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds((player?.currentItem?.currentTime())!)
    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    
  }
  
  func registerRemoteControlEvents() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.isEnabled = true
    
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.playCommand.isEnabled = true
    commandCenter.pauseCommand.isEnabled = true
    
    commandCenter.togglePlayPauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
      self.handleResume()
      return .success
    }
    
    commandCenter.playCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
      self.handleRemoteCmamandCenterPlay()
      return .success
    }
    commandCenter.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
      self.handleRemoteCommandCenterPause()
      return .success
    }
    commandCenter.previousTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
      self.handleRemoteCommandCenterPreviousTrack()
      return .success
    }
    commandCenter.nextTrackCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
      self.handleRemoteCommandCenterNextTrack()
      return .success
    }
  }
  
  func unregisterRemoteControlEvents() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.removeTarget(self)
    commandCenter.pauseCommand.removeTarget(self)
    commandCenter.nextTrackCommand.removeTarget(self)
    commandCenter.previousTrackCommand.removeTarget(self)
    commandCenter.togglePlayPauseCommand.removeTarget(self)
  }
  
  //END Media Control

  override func supportedEvents() -> [String]! {
    return ["StreamingPlayer"]
  }
  
}

extension AVQueuePlayer {
  var isPlaying: Bool {
    return ((rate != 0) && (error == nil))
  }
}


