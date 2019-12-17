//
//  Model.swift
//  TestAssignment
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import Foundation
import TestAssignmentLibrary

public protocol ModelDelegate: class {
    func model(_ model: Model, didChange avatarItemSource: AvatarItemSource)
}

extension ModelDelegate {
    func model(_ model: Model, didChange avatarItemSource: AvatarItemSource) {}
}

public class Model {
    // MARK: - Properties

    public weak var delegate: ModelDelegate?
    public private(set) var avatarItemSource: AvatarItemSource?

    private let downloader: FileDownloader
    private var currentIndex = -1
    private let urls: [URL]

    // MARK: - Constructors
    
    init(with urls: [URL] = []) {
        self.urls = urls
        let paths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0].appendingPathComponent("AvatarCache", isDirectory: true)
        let cache = try! FileDownloaderCache(cacheFolderURL: documentsDirectory)
        self.downloader = FileDownloader(cache)
    }
    
    // MARK: - LifeCycle

    public func getNextAvatar() {
        guard self.urls.count > 0 else {
            return
        }
        self.currentIndex += 1;
        if self.currentIndex == self.urls.count {
            self.currentIndex = 0
        }
        let url = self.urls[currentIndex]
        let avatarItemSource = AvatarItemSource(url: url, self.downloader, AvatarItemSlicer())
        self.avatarItemSource = avatarItemSource
        DispatchQueue.global().async {[weak self] in
            guard let self = self, let avatarItemSource = self.avatarItemSource else { return }
            self.delegate?.model(self, didChange: avatarItemSource)
        }
    }
}
