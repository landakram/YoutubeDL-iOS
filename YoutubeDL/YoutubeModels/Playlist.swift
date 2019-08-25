//
//  Playlist.swift
//  YoutubeDL
//
//  Created by Pieter de Bie on 01/10/2016.
//  Copyright © 2016 Pieter de Bie. All rights reserved.
//

import Foundation

final class Playlist : NSObject, NSCoding {
    
    var state = Status.Loaded
    var _videos = [Video]()
    var videos: [Video] {
        get {
            let sorted = _videos.sorted { (v1, v2) -> Bool in
                order[v1.id] ?? -1 < order[v2.id] ?? -1
            }
            return sorted
        }
    }

    var title: String?
    var id: String?
    var url: URL
    
    var order = [String: Int]()
    
    enum Status {
        case Loading
        case Loaded
    }
    
    init(url: URL) {
        self.url = url
    }
    
    required convenience init(coder decoder: NSCoder) {
        self.init(url: decoder.decodeObject(forKey: "url") as! URL)
        title = decoder.decodeObject(forKey: "title") as? String
        _videos = decoder.decodeObject(forKey: "videos") as! [Video]
        id = decoder.decodeObject(forKey: "id") as? String
        order = decoder.decodeObject(forKey: "order") as! [String: Int]
    }
    
    func addVideo(video: Video) {
        if findVideo(id: video.id) == nil {
            _videos.append(video);
        }
    }
    
    func findVideo(id: String) -> Video? {
        return _videos.first { $0.id == id }
    }
    
    func deleteFiles() {
        _videos.forEach { (video) in
            video.deleteFile()
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(title, forKey: "title")
        coder.encode(id, forKey: "id")
        coder.encode(url, forKey: "url")
        coder.encode(_videos, forKey: "videos")
        coder.encode(order, forKey: "order")
    }
}
