//
//  Video.swift
//  YoutubeDL
//
//  Created by Pieter de Bie on 01/10/2016.
//  Copyright © 2016 Pieter de Bie. All rights reserved.
//

import Foundation

final class Video : NSObject, NSCoding {
    var id: String
    var title: String
    var progress: DownloadProgress?
    var duration = 0
    var details: String = ""
    var watchedPosition = 0
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
    
    required convenience init(coder decoder: NSCoder) {
        let id = decoder.decodeObject(forKey: "id") as! String
        let title = decoder.decodeObject(forKey: "title") as! String
        self.init(id: id, title: title)
        duration = decoder.decodeInteger(forKey: "duration")
        watchedPosition = decoder.decodeInteger(forKey: "watchedPosition")
        details = decoder.decodeObject(forKey: "details") as! String
    }

    func encode(with coder: NSCoder) {
        coder.encode(title, forKey: "title")
        coder.encode(id, forKey: "id")
        coder.encode(duration, forKey: "duration")
        coder.encode(watchedPosition, forKey: "watchedPosition")
        coder.encode(details, forKey: "details")
    }

    func downloadLocation() -> URL {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("videos").appendingPathComponent("\(id).mp4")
    }
    
    var url: URL {
        return Video.getURL(id: id)
    }
    
    static func getURL(id: String) -> URL {
        return URL(string: "https://www.youtube.com/watch?v=\(id)")!
    }
    
    var partialDownloadLocation: URL {
        return downloadLocation().appendingPathExtension("part")
    }
    
    func deleteFile() {
        do {
            if hasBeenDownloaded() {
                    try FileManager.default.removeItem(at: downloadLocation())
                    print("Checking \(partialDownloadLocation.path)")
            }
            if FileManager.default.fileExists(atPath: partialDownloadLocation.path) {
                print("Removing partial file \(partialDownloadLocation)")
                try FileManager.default.removeItem(at: partialDownloadLocation)
            }
        } catch let error as NSError {
            print("Error deleting file: \(error)")
        }
    }
    
    var formattedWatchPosition: String {
        let minute = watchedPosition / 60
        let second = watchedPosition % 60
        return "\(String(format: "%02d", minute)):\(String(format: "%02d", second))"
    }
    
    var formattedTime: String {
        let minute = duration / 60
        let second = duration % 60
        return "\(String(format: "%02d", minute)):\(String(format: "%02d", second))"
    }
    
    var thumbnailUrl: URL {
        URL(string: "https://i.ytimg.com/vi/\(self.id)/maxresdefault.jpg")!
    }
    
    func hasPartial() -> Bool {
        return FileManager.default.fileExists(atPath: partialDownloadLocation.path)
    }
    
    func hasBeenDownloaded() -> Bool {
        return FileManager.default.fileExists(atPath: downloadLocation().path)
    }
}
