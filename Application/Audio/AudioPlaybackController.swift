//
//  AudioPlaybackController.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 20/01/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import AVFoundation
import Foundation

/* Third-party Frameworks */
import MessageKit

public class AudioPlaybackController {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var isPlaying: Bool { get { !player.items().isEmpty } }
    
    private static var playbackTimer: Timer?
    private static var player = AVQueuePlayer()
    private static var playingCell: AudioMessageCell?
    private static var playingMessage: Message?
    
    //==================================================//
    
    /* MARK: - Playback Methods */
    
    // MARK: Public
    
    public static func resetAudioSession(completion: @escaping(_ exception: Exception?) -> Void = { _ in }) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord,
                                         mode: .default,
                                         options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch { completion(Exception(error, metadata: [#file, #function, #line])) }
    }
    
    public static func startPlayback(for cell: AudioMessageCell) {
        guard !cell.playButton.isSelected,
              !SpeechService.shared.isRecording else {
            stopPlayback()
            return
        }
        
        stopPlaybackForAllVisibleCells()
        ChatServices.defaultMenuControllerService?.stopSpeakingIfNeeded()
        
        guard let currentUserID = RuntimeStorage.currentUserID,
              let message = message(for: cell),
              let audioFilePaths = message.localAudioFilePaths else { return }
        
        let isFromCurrentUser = message.fromAccountIdentifier == currentUserID
        let pathToPlayFrom = isFromCurrentUser ? audioFilePaths.inputPathURL : audioFilePaths.outputPathURL
        
        cell.playButton.isSelected = true
        cell.progressView.progressTintColor = isFromCurrentUser ? .white : .primaryAccentColor
        
        playAudio(url: pathToPlayFrom)
        playingCell = cell
        playingMessage = message
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        startPlaybackTimer()
    }
    
    public static func stopPlayback(playNext: Bool = false) {
        player.removeAllItems()
        
        guard let playingCell,
              let playingMessage,
              let audioFile = properAudioFile(for: playingMessage) else {
            resetVariables()
            return
        }
        
        playingCell.progressView.progress = 0.0
        playingCell.playButton.isSelected = false
        playingCell.durationLabel.text = audioFile.duration.durationString
        
        resetVariables()
        stopPlaybackForAllVisibleCells()
        
        guard playNext else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        
        playNextMessage(for: playingCell)
    }
    
    // MARK: Private
    
    private static func playAudio(url: URL) {
        resetAudioSession { exception in
            guard let exception else { return }
            Logger.log(exception)
        }
        
        player.removeAllItems()
        player.insert(AVPlayerItem(url: url), after: nil)
        player.play()
    }
    
    private static func stopPlaybackForAllVisibleCells() {
        guard let collectionView = RuntimeStorage.messagesVC?.messagesCollectionView else { return }
        
        for cell in collectionView.visibleCells {
            guard let cell = cell as? AudioMessageCell else { continue }
            
            cell.playButton.isSelected = false
            cell.progressView.progress = 0
            
            guard let message = message(for: cell),
                  let audioFile = properAudioFile(for: message) else {
                cell.durationLabel.text = "0:00"
                continue
            }
            
            cell.durationLabel.text = audioFile.duration.durationString
        }
    }
    
    //==================================================//
    
    /* MARK: - Helper Methods */
    
    private static func message(for cell: UICollectionViewCell) -> Message? {
        guard let indexPath = RuntimeStorage.messagesVC?.messagesCollectionView.indexPath(for: cell),
              let messages = RuntimeStorage.currentMessageSlice,
              !messages.isEmpty,
              indexPath.section < messages.count else { return nil }
        
        return messages[indexPath.section]
    }
    
    private static func playNextMessage(for cell: AudioMessageCell) {
        guard let indexPath = RuntimeStorage.messagesVC?.messagesCollectionView.indexPath(for: cell),
              let messages = RuntimeStorage.currentMessageSlice,
              !messages.isEmpty,
              indexPath.section + 1 < messages.count else { return }
        
        let nextIndexPath = IndexPath(row: 0, section: indexPath.section + 1)
        
        guard messages[indexPath.section + 1].audioComponent != nil,
              !messages[indexPath.section + 1].isDisplayingAlternate,
              let nextCell = RuntimeStorage.messagesVC?.messagesCollectionView.cellForItem(at: nextIndexPath) as? AudioMessageCell else { return }
        
        startPlayback(for: nextCell)
    }
    
    private static func properAudioFile(for message: Message) -> AudioFile? {
        guard let audioComponent = message.audioComponent,
              let currentUserID = RuntimeStorage.currentUserID,
              let fileToUse = message.fromAccountIdentifier == currentUserID ? audioComponent.original : audioComponent.translated else { return nil }
        
        return fileToUse
    }
    
    private static func resetVariables() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        playingCell = nil
        playingMessage = nil
    }
    
    //==================================================//
    
    /* MARK: - Timer Methods */
    
    private static func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        playbackTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                             target: self,
                                             selector: #selector(updateProgress),
                                             userInfo: nil,
                                             repeats: true)
    }
    
    @objc private static func updateProgress() {
        guard let playingCell,
              let playingMessage,
              let messageAtCurrentIndexPath = message(for: playingCell),
              playingMessage.identifier == messageAtCurrentIndexPath.identifier,
              let currentItem = player.currentItem else {
            stopPlayback(playNext: true)
            return
        }
        
        playingCell.durationLabel.text = Float(currentItem.currentTime().seconds).durationString
        
        let progress = Float(currentItem.currentTime().seconds / currentItem.duration.seconds)
        
        guard !progress.isNaN else { return }
        playingCell.progressView.setProgress(progress, animated: true)
    }
}
