//
//  DownloadManager.swift
//  YoutubeDL
//
//  Created by Pieter de Bie on 01/10/2016.
//  Copyright © 2016 Pieter de Bie. All rights reserved.
//

import Foundation
import Dispatch

class DownloadManager {
    
    static let sharedDownloadManager = DownloadManager()

    
    var queue = DispatchQueue(label: "Python", qos: DispatchQoS.utility)
    var activeVideo: Video?
    var updateCallback: ((DownloadProgress) -> ())?
    
    init() {
        queue.async {
            YDL_initialize()
            YDL_setProgressCallback { data in
                let update = DownloadProgress(dict: data!)
                if let video = self.activeVideo {
                    video.progress = update;
                }
                if let updateCb = self.updateCallback {
                    DispatchQueue.main.async {
                      updateCb(update)  
                    }
                }
            }
        }
    }
    
    func refreshPlaylist(playlist: Playlist, onUpdate: @escaping () -> ()) {
        queue.async {
            playlist.state = .Loading
            YDL_playlistDataForUrl(playlist.url, { (data) in
                let attrs = data!["data"]! as! [String: Any]
                let entries = data!["entries"]! as! [[String: Any]]
                
                let entryIds = entries.map { (entry) in entry["id"] as! String }
                let order: [String: Int] = entryIds.enumerated().reduce([String: Int]()) { (acc, arg1) -> [String: Int] in
                    let (offset, element) = arg1
                    var acc = acc
                    acc.updateValue(offset, forKey: element)
                    return acc
                }
                
                playlist.id = attrs["id"] as? String
                playlist.title = attrs["title"] as? String
                playlist.order = order
                
                DispatchQueue.main.async(execute: onUpdate)
                
                self.processEntries(playlist: playlist, entries: entries, onUpdate: onUpdate)
            })
            DispatchQueue.main.async {
                playlist.state = .Loaded
                onUpdate()
            }
        }
    }
    
    func processEntries(playlist: Playlist, entries: [[String: Any]], onUpdate: @escaping () -> ()) {
        playlist._videos.removeAll(where: { (video) -> Bool in
            playlist.order[video.id] == nil
        })
        
        for entry in entries {
            if playlist.findVideo(id: entry["id"] as! String) == nil {
                YDL_loadVideoMetadata(Video.getURL(id: entry["id"] as! String), { (data) in
                    let attrs = data!["data"]! as! [String: Any]
                    let id = attrs["id"] as! String
                    let title = attrs["title"] as! String
                    let duration = attrs["duration"] as? Int ?? 0
                    let details = attrs["description"] as? String ?? ""
                    
                    let video = self.createVideo(id: id, title: title, duration: duration, details: details)
                    
                    playlist.addVideo(video: video)
                    DispatchQueue.main.async(execute: onUpdate)
                })
            }
        }
    }
    
    func createVideo(id: String, title: String, duration: Int, details: String) -> Video {
        let video = Video(id: id, title: title)
        video.duration = duration
        video.details = details
        return video
    }
    
    func downloadVideo(video: Video, onUpdate: @escaping (DownloadProgress) -> ()) {
        video.progress = DownloadProgress(status: .Queued)
        queue.async {
            print("Strating download for \(video.id)")
            self.activeVideo = video
            self.updateCallback = onUpdate
            video.progress = DownloadProgress(status: .Preparing)
            DispatchQueue.main.async { onUpdate(video.progress!) }
            YDL_downloadVideo(video.url, video.downloadLocation())
            video.progress = nil
            self.activeVideo = nil
            self.updateCallback = nil
            print("Done with download for \(video.id)")
        }
    }
}
