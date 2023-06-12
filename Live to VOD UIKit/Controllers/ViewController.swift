//
//  ViewController.swift
//  Live to VOD UIKit
//
//  Created by Uldis Zingis on 15/02/2022.
//

import UIKit
import AmazonIVSPlayer

class ViewController: UIViewController {

    // MARK: IBOutlet
    @IBOutlet private var livePlayerView: IVSPlayerView!
    @IBOutlet private var vodPlayerView: IVSPlayerView!
    @IBOutlet private var bufferIndicator: UIActivityIndicatorView!
    @IBOutlet private var controlsView: UIView!
    @IBOutlet private var playButton: UIButton!
    @IBOutlet private var pauseButton: UIButton!
    @IBOutlet private var currentPositionLabel: UILabel!
    @IBOutlet private var currentProgressLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var seekSlider: UISlider!
    @IBOutlet private var bufferedRangeProgressView: UIProgressView!
    @IBOutlet private var gradientView: UIView!
    @IBOutlet private var liveLabel: UIView!
    @IBOutlet private var recordedLabel: UIView!
    @IBOutlet private var back60Button: UIButton!
    @IBOutlet private var forward60Button: UIButton!
    @IBOutlet private var backToLiveButton: UIButton!
    @IBOutlet private var controlButtonsView: UIView!
    @IBOutlet private var seekView: UIView!
    @IBOutlet private var errorLabel: UILabel!
    @IBOutlet private var errorView: UIView!

    // MARK: IBAction

    @IBAction private func playTapped(_ sender: Any) {
        isLive ? startLivePlayback() : startVODPlayback()
    }

    @IBAction private func pauseTapped(_ sender: Any) {
        let wasLive = isLive
        isLive ? pauseLivePlayback() : pauseVODPlayback()
        isLive = wasLive
    }

    @IBAction private func onSeekSliderValueChanged(_ sender: UISlider, event: UIEvent) {
        updateStatusLabelPosition()

        guard let touchEvent = event.allTouches?.first else {
            seek(toFractionOfDuration: sender.value)
            return
        }

        switch touchEvent.phase {
            case .began, .moved:
                seekStatus = .choosing(sender.value)

            case .ended:
                seekSliderChanged(sender.value)

            case .cancelled:
                seekStatus = nil

            default: ()
        }
    }

    @IBAction func backToLiveTapped(_ sender: Any) {
        playLive()
        toggleControls(show: true)
    }

    @IBAction func back60Tapped(_ sender: Any) {
        if isLive {
            playVOD()
            let targetTime = CMTimeSubtract(vodPlayer!.duration, CMTime(seconds: 60, preferredTimescale: 1))
            let targetFraction = targetTime.seconds / vodPlayer!.duration.seconds
            playVOD(atFractionOfDuration: Float64(targetFraction))
        } else {
            seek(to: CMTimeSubtract(vodPlayer!.position, CMTime(seconds: 60, preferredTimescale: 1)))
        }
    }

    @IBAction func forward60Tapped(_ sender: Any) {
        guard let current = vodPlayer?.position, let duration = vodPlayer?.duration.seconds else { return }
        let newPos = CMTimeAdd(CMTime(seconds: 60, preferredTimescale: 1), current)
        if newPos.seconds < duration {
            seek(to: newPos)
        } else {
            playLive()
        }
    }

    var controlsDismissWorkItem: DispatchWorkItem?
    var isLive: Bool = false {
        didSet {
            backToLiveButton.isHidden = isLive
        }
    }

    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        currentPositionLabel.text = ""
        liveLabel.layer.cornerRadius = 10
        liveLabel.layer.zPosition = 5
        recordedLabel.layer.cornerRadius = 10
        recordedLabel.layer.zPosition = 5
        backToLiveButton.layer.cornerRadius = 10
        errorView.layer.cornerRadius = 10
        seekSlider.setThumbImage(UIImage(named: "seekBar_handle"), for: .normal)
        setPlaybackButtonImages(UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.isPortrait ?? false)
        livePlayerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleControls)))
        vodPlayerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleControls)))
        controlsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleControls)))
        errorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleErrorView)))
        seekView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToSeek(_:))))

        connectProgress()

        Networking.shared.getStreamMetadata { [weak self] success in
            self?.loadVODStream(from: Networking.shared.vodUrl)
            self?.playLive()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setUpDisplayLink()

        startControlButtonsTimeout()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        pauseLivePlayback()
        pauseVODPlayback()

        tearDownDisplayLink()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setPlaybackButtonImages(UIDevice.current.orientation.isPortrait)
    }

    // MARK: Application Lifecycle
    private var didPauseOnBackground = false

    @objc private func applicationDidEnterBackground(notification: Notification) {
        if livePlayer?.state == .playing || livePlayer?.state == .buffering ||
            vodPlayer?.state == .playing || vodPlayer?.state == .buffering {
            didPauseOnBackground = true
            pauseLivePlayback()
            pauseVODPlayback()
        } else {
            didPauseOnBackground = false
        }
    }

    @objc private func applicationDidBecomeActive(notification: Notification) {
        if didPauseOnBackground && vodPlayer?.error == nil && livePlayer?.error == nil {
            if isLive {
                startLivePlayback()
            } else {
                startVODPlayback()
            }
            didPauseOnBackground = false
        }
    }

    private func addApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func removeApplicationLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    // MARK: State display
    private var playbackPositionDisplayLink: CADisplayLink?

    private func setUpDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(playbackDisplayLinkDidFire(_:)))
        displayLink.preferredFramesPerSecond = 5
        displayLink.isPaused = vodPlayer?.state != .playing
        displayLink.add(to: .main, forMode: .common)
        playbackPositionDisplayLink = displayLink
    }

    private func tearDownDisplayLink() {
        playbackPositionDisplayLink?.invalidate()
        playbackPositionDisplayLink = nil
    }

    @objc private func playbackDisplayLinkDidFire(_ displayLink: CADisplayLink) {
        self.updatePositionDisplay()
        self.updateBufferProgress()
    }

    private func seekSliderChanged(_ toValue: Float) {
        if toValue == 1 {
            if !isLive {
                playLive()
            }
        } else {
            seek(toFractionOfDuration: toValue)
        }
        isLive ? startLivePlayback() : startVODPlayback()
    }

    private let hourDisplayFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private let minuteDisplayFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private func updatePositionDisplay() {
        guard let player = vodPlayer else {
            currentPositionLabel.text = nil
            return
        }
        let playerPosition = player.position
        let duration = player.duration
        let position: CMTime
        switch seekStatus {
            case let .choosing(fractionOfDuration):
                position = CMTimeMultiplyByFloat64(duration, multiplier: Float64(fractionOfDuration))
                if isLive {
                    playVOD(atFractionOfDuration: Float64(fractionOfDuration))
                }
                backToLiveButton.isHidden = true
            case let .requested(seekPosition):
                position = seekPosition
                backToLiveButton.isHidden = isLive
            case nil:
                position = playerPosition
                updateSeekSlider(position: position, duration: duration)
        }
        if position.seconds.isNormal && duration.seconds.isNormal {
            let currentPosition = CMTimeSubtract(duration, position)
            if currentPosition.seconds >= 3600 {
                currentPositionLabel.text = "-\(hourDisplayFormatter.string(from: currentPosition.seconds) ?? "0")"
            } else {
                currentPositionLabel.text = "-\(minuteDisplayFormatter.string(from: currentPosition.seconds) ?? "0")"
            }
        }
        updateStatusLabelPosition()
    }

    private var bufferedRangeProgress: Progress? {
        didSet {
            connectProgress()
        }
    }

    private func connectProgress() {
        bufferedRangeProgressView?.observedProgress = bufferedRangeProgress
    }

    private func updateBufferProgress() {
        guard let duration = vodPlayer?.duration, let buffered = vodPlayer?.buffered,
              duration.isNumeric, buffered.isNumeric else {
                  bufferedRangeProgress?.completedUnitCount = 0
                  return
              }
        let scaledBuffered = buffered.convertScale(duration.timescale, method: .default)
        bufferedRangeProgress?.completedUnitCount = scaledBuffered.value
    }

    private enum SeekStatus: Equatable {
        case choosing(Float)
        case requested(CMTime)
    }

    private var seekStatus: SeekStatus? {
        didSet {
            updatePositionDisplay()
        }
    }

    private func updateSeekSlider(position: CMTime, duration: CMTime) {
        if duration.isNumeric && position.isNumeric {
            let scaledPosition = position.convertScale(duration.timescale, method: .default)
            let progress = Double(scaledPosition.value) / Double(duration.value)
            seekSlider.setValue(Float(progress), animated: false)
            updateStatusLabelPosition()
        }
    }

    private func updateStatusLabelPosition() {
        let trackRect = seekSlider.trackRect(forBounds: seekSlider.bounds)
        let thumbRect = seekSlider.thumbRect(forBounds: seekSlider.bounds,
                                             trackRect: trackRect,
                                             value: seekSlider.value)
        currentProgressLeadingConstraint.constant = max(
            thumbRect.origin.x + seekSlider.frame.origin.x - (currentPositionLabel.bounds.size.width / 3),
            0
        )
    }

    private func updateForState(_ state: IVSPlayer.State) {
        playbackPositionDisplayLink?.isPaused = state != .playing

        let showPause = state == .playing || state == .buffering
        pauseButton.isHidden = !showPause
        playButton.isHidden = showPause

        if isLive {
            seekSlider.setValue(1, animated: false)
        }

        if state == .playing {
            liveLabel.isHidden = !isLive
            recordedLabel.isHidden = isLive
        } else {
            liveLabel.isHidden = true
        }
        currentPositionLabel.isHidden = isLive

        if state == .buffering {
            bufferIndicator?.startAnimating()
        } else {
            bufferIndicator?.stopAnimating()
        }
    }

    private func updateForDuration(duration: CMTime) {
        if duration.isIndefinite {
            seekSlider.isHidden = false
            seek(to: duration)
            bufferedRangeProgressView.isHidden = true
            bufferedRangeProgress = nil
        } else if duration.isNumeric {
            seekSlider.isHidden = false
            bufferedRangeProgress = Progress.discreteProgress(totalUnitCount: duration.value)
            updateBufferProgress()
            bufferedRangeProgressView.isHidden = false
        } else {
            seekSlider.isHidden = true
            bufferedRangeProgressView.isHidden = true
            bufferedRangeProgress = nil
        }
    }

    private func presentError(_ error: Error, componentName: String) {
        errorLabel.text = String(reflecting: error)
        errorView.isHidden = false
    }

    @objc
    private func toggleErrorView() {
        errorView.isHidden.toggle()
    }

    private func presentActionSheet(title: String, actions: [UIAlertAction], sourceView: UIView) {
        let actionSheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(
            UIAlertAction(title: "Close", style: .cancel, handler: { _ in
                actionSheet.dismiss(animated: true)
            })
        )
        actions.forEach { actionSheet.addAction($0) }
        actionSheet.popoverPresentationController?.sourceView = sourceView
        actionSheet.popoverPresentationController?.sourceRect = sourceView.bounds
        present(actionSheet, animated: true)
    }

    private func setPlaybackButtonImages(_ forPortrait: Bool) {
        if forPortrait {
            playButton.setImage(UIImage(named: "play_portrait"), for: .normal)
            pauseButton.setImage(UIImage(named: "pause_portrait"), for: .normal)
        } else {
            playButton.setImage(UIImage(named: "play_landscape"), for: .normal)
            pauseButton.setImage(UIImage(named: "pause_landscape"), for: .normal)
        }
    }

    @objc
    private func toggleControls(hide: Bool = false, show: Bool = false) {
        if show {
            controlButtonsView.isHidden = false
            seekView.isHidden = false
            gradientView.isHidden = false
            backToLiveButton.isHidden = false
            startControlButtonsTimeout()
        } else if hide {
            controlButtonsView.isHidden = true
            seekView.isHidden = true
            gradientView.isHidden = true
            backToLiveButton.isHidden = true
        } else {
            controlButtonsView.isHidden.toggle()
            seekView.isHidden.toggle()
            gradientView.isHidden.toggle()
            if !isLive || !backToLiveButton.isHidden {
                backToLiveButton.isHidden.toggle()
            }
            if !controlButtonsView.isHidden {
                startControlButtonsTimeout()
            }
        }
    }

    @objc
    private func tapToSeek(_ sender: UITapGestureRecognizer) {
        let seekPosition = sender.location(in: seekView).x / seekView.frame.width
        seekSliderChanged(Float(seekPosition))
        playVOD()
    }

    private func startControlButtonsTimeout() {
        controlsDismissWorkItem?.cancel()
        controlsDismissWorkItem = DispatchWorkItem {
            if self.seekStatus == nil {
                self.toggleControls(hide: true)
            } else {
                self.startControlButtonsTimeout()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: controlsDismissWorkItem!)
    }

    // MARK: - Player
    var livePlayer: IVSPlayer? {
        didSet {
            if oldValue != nil {
                removeApplicationLifecycleObservers()
            }
            livePlayerView?.player = livePlayer
            seekStatus = nil
            updatePositionDisplay()
            if livePlayer != nil {
                addApplicationLifecycleObservers()
            }
        }
    }

    var vodPlayer: IVSPlayer? {
        didSet {
            vodPlayerView?.player = vodPlayer
            seekStatus = nil
            updatePositionDisplay()
        }
    }

    // MARK: Playback Control
    func loadLiveStream(from url: String) {
        guard let streamURL = URL(string: url) else {
            print("❌ could not create url from: \(url)")
            return
        }
        let livePlayer: IVSPlayer
        if let existingPlayer = self.livePlayer {
            livePlayer = existingPlayer
        } else {
            livePlayer = IVSPlayer()
            livePlayer.delegate = self
            self.livePlayer = livePlayer
            print("Live player initialized: version \(livePlayer.version)")
        }
        livePlayer.load(streamURL)
    }

    func loadVODStream(from url: String) {
        guard let streamURL = URL(string: url) else {
            print("❌ could not create url from: \(url)")
            return
        }
        let vodPlayer: IVSPlayer
        if let existingPlayer = self.vodPlayer {
            vodPlayer = existingPlayer
        } else {
            vodPlayer = IVSPlayer()
            vodPlayer.delegate = self
            self.vodPlayer = vodPlayer
            print("VOD player initialized: version \(vodPlayer.version)")
        }
        vodPlayer.load(streamURL)
    }

    private func seek(toFractionOfDuration fraction: Float) {
        guard let vodPlayer = vodPlayer else {
            seekStatus = nil
            return
        }
        let position = CMTimeMultiplyByFloat64(
            vodPlayer.duration,
            multiplier: Float64(fraction == 0 ? 0.000001 : fraction)
        )
        seek(to: position)
    }

    private func seek(to position: CMTime) {
        guard let vodPlayer = vodPlayer else {
            seekStatus = nil
            return
        }
        seekStatus = .requested(position)
        vodPlayer.seek(to: position) { [weak self] _ in
            guard let self = self else {
                return
            }
            if self.seekStatus == .requested(position) {
                self.seekStatus = nil
            }
        }
    }

    private func startLivePlayback() {
        livePlayerView.isHidden = false
        vodPlayerView.isHidden = true
        currentPositionLabel.isHidden = true
        pauseVODPlayback()
        livePlayer?.play()
        isLive = true
    }

    private func startVODPlayback() {
        livePlayerView.isHidden = true
        vodPlayerView.isHidden = false
        currentPositionLabel.isHidden = false
        pauseLivePlayback()
        vodPlayer?.play()
    }

    private func pauseLivePlayback() {
        livePlayer?.pause()
        isLive = false
    }

    private func pauseVODPlayback() {
        vodPlayer?.pause()
    }

    func playLive() {
        print("Playing LIVE")
        livePlayer = nil
        forward60Button.isEnabled = false
        updatePositionDisplay()
        Networking.shared.getStreamMetadata { [weak self] success in
            self?.loadLiveStream(from: Networking.shared.liveUrl)
            self?.startLivePlayback()
        }
    }

    func playVOD(atFractionOfDuration fraction: CGFloat = 0) {
        guard let playerDuration = vodPlayer?.duration else {
            return
        }
        let seekTime = CMTimeMultiplyByFloat64(playerDuration, multiplier: Float64(fraction))
        print("Playing VOD at \(seekTime)")
        forward60Button.isEnabled = true
        if fraction != 0 {
            seek(to: seekTime)
        }
        updatePositionDisplay()
        startVODPlayback()
    }
}

// MARK: - IVSPlayer.Delegate
extension ViewController: IVSPlayer.Delegate {

    func player(_ player: IVSPlayer, didChangeState state: IVSPlayer.State) {
        updateForState(state)
    }

    func player(_ player: IVSPlayer, didFailWithError error: Error) {
        presentError(error, componentName: "Player")
    }

    func player(_ player: IVSPlayer, didChangeDuration duration: CMTime) {
        updateForDuration(duration: duration)
    }

    func player(_ player: IVSPlayer, didOutputCue cue: IVSCue) {
        switch cue {
            case let textMetadataCue as IVSTextMetadataCue:
                print("Received Timed Metadata (\(textMetadataCue.textDescription)): \(textMetadataCue.text)")
            case let textCue as IVSTextCue:
                print("Received Text Cue: “\(textCue.text)”")
            default:
                print("Received unknown cue (type \(cue.type))")
        }
    }

    func playerWillRebuffer(_ player: IVSPlayer) {
        print("Player will rebuffer and resume playback")
    }
}
