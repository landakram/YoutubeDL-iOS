//
//  DetailViewController.swift
//  YoutubeDL
//
//  Created by Pieter de Bie on 01/10/2016.
//  Copyright © 2016 Pieter de Bie. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import Dispatch
import WebImage
import MediaPlayer

class PlaylistViewController: UITableViewController {

    var playlist: Playlist?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.rowHeight = 120
        self.tableView.estimatedRowHeight = 120
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return playlist?.videos.count ?? 0;
    }
    
    @IBAction func refreshPlaylist(_ sender: UIRefreshControl) {
        DownloadManager.sharedDownloadManager.refreshPlaylist(playlist: playlist!) {
            [weak self] in
            self?.tableView.reloadData()
            sender.endRefreshing()
            DataStore.sharedStore.saveToDisk()
        }
    }

    func playerUrl(video: Video) -> URL {
        if video.hasBeenDownloaded() {
            return video.downloadLocation()
        }
        let fileManager = FileManager.default
        
        // Assume we have partial, otherwise why would this have been called?
        let partialLocation = video.partialDownloadLocation
        let linkLocation = partialLocation.appendingPathExtension("mp4")
        if !fileManager.fileExists(atPath: linkLocation.path) {
            do {
                try fileManager.createSymbolicLink(at: linkLocation, withDestinationURL: partialLocation)
            } catch _ {
                print("Error creating symbolic link for partial playback of \(video.id)")
                // Whoops
            }
        }
        return linkLocation
        
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showVideo" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                guard let video = playlist?.videos[indexPath.row] else {
                    return;
                }

                let controller = segue.destination as! AVPlayerViewController
                
                controller.updatesNowPlayingInfoCenter = false
                
                let player = AVPlayer(url: playerUrl(video: video))
                if video.watchedPosition > 0 {
                    player.seek(to: CMTime(seconds: Double(video.watchedPosition), preferredTimescale: 1))
                }
                
                SDWebImageManager.shared()?.downloadImage(with: video.thumbnailUrl, options: [], progress: nil, completed: {
                    (image, err, cacheType, finished, imageUrl) in
                    player.addPeriodicTimeObserver(forInterval: CMTime.init(seconds: 1.0, preferredTimescale: 1), queue: nil, using: {
                        [weak self] (time) in
                        video.watchedPosition = Int(time.seconds)
                        DataStore.sharedStore.saveToDisk()
                        self?.tableView.reloadRows(at: [indexPath], with: .none)
                        self?.updateNowPlaying(player: player, video: video, thumbnailImage: image)
                    })
                    
                    
                    self.setupRemoteTransportControls(player: player)
                    controller.player = player
                    player.play()
                })
            }
        }
    }
    
    func updateNowPlaying(player: AVPlayer, video: Video, thumbnailImage: UIImage?) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = video.title

        if let image = thumbnailImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
        }
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = "YoutubeDL"
                
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func setupRemoteTransportControls(player: AVPlayer) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { event in
            if player.rate == 0.0 {
                player.play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { event in
            if player.rate == 1.0 {
                player.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(15)]
        commandCenter.skipForwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            guard let command = event.command as? MPSkipIntervalCommand else {
                return .noSuchContent
            }
            
            player.seek(to: player.currentTime() + CMTime(seconds: command.preferredIntervals.first!.doubleValue, preferredTimescale: 1))
            return .success
        }
        
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(15)]
        commandCenter.skipBackwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            guard let command = event.command as? MPSkipIntervalCommand else {
                return .noSuchContent
            }
            
            player.seek(to: player.currentTime() - CMTime(seconds: command.preferredIntervals.first!.doubleValue, preferredTimescale: 1))
            return .success
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! VideoViewCell
        
        let video = playlist!.videos[indexPath.row]
        cell.updateFrom(video: video)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let video = playlist!.videos[indexPath.row]
        if video.hasBeenDownloaded() || video.progress?.status == .Downloading {
            performSegue(withIdentifier: "showVideo", sender: self)
        } else {
            self.tableView.beginUpdates()
            DownloadManager.sharedDownloadManager.downloadVideo(video: video) {_ in
                self.tableView.reloadData()
            }
            self.tableView.deselectRow(at: indexPath, animated: true)
            self.tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            editActionsForRowAt indexPath: IndexPath)
        -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete Download") { (action, indexPath) in
            self.playlist?.videos[indexPath.row].deleteFile()
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
            
        let video = playlist!.videos[indexPath.row]
        if video.hasBeenDownloaded() {
            return [deleteAction]
        }
        else {
            return []
        }
    }

    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
}

