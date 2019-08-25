//
//  VideoViewCell.swift
//  YoutubeDL
//
//  Created by Pieter de Bie on 03/10/2016.
//  Copyright © 2016 Pieter de Bie. All rights reserved.
//

import UIKit

class VideoViewCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var detail: UILabel!
    @IBOutlet weak var thumbnail: UIImageView!  
    
    func detailText(video: Video) -> String {
        if video.hasBeenDownloaded() {
            if (video.watchedPosition == 0) {
                return "\(video.formattedTime) - NEW"
            } else {
                return "\(video.formattedTime) - Watched up to \(video.formattedWatchPosition)"
            }
        }

        if let progress = video.progress {
            switch progress.status {
            case .Preparing:
                return "Preparing for Download"
            case .Queued:
                return "Queued"
            default:
                return "Downloading \(Int((progress.progress) * 100))% - \(Int(progress.speed / 1024))KB/s"
            }
        }

        if video.hasPartial() {
            return "\(video.formattedTime) -- Partially Downloaded. Tap to resume."
        }
        return video.duration == 0 ? "" : "\(video.formattedTime)"
    }
    
    func updateFrom(video: Video) {
        title.text = video.title
        title.lineBreakMode = .byWordWrapping
        detail.text = detailText(video: video)
        thumbnail.sd_setImage(with: URL(string: "https://i.ytimg.com/vi/\(video.id)/maxresdefault.jpg")!)
        thumbnail.alpha = video.hasBeenDownloaded() ? 1 : 0.2
    }
}
