//
//  AvatarItemSource.swift
//  TestAssignmentLibrary
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit

public protocol AvatarItemSourceDelegate {

    func avatarItemSource(_ avatarItemSource: AvatarItemSource, didChangedStateTo state: AvatarItemSource.State)
    func avatarItemSource(_ avatarItemSource: AvatarItemSource, progress: Float)
}

public extension AvatarItemSourceDelegate {
    func avatarItemSource(_ avatarItemSource: AvatarItemSource, didChangedStateTo state: AvatarItemSource.State) {}
    func avatarItemSource(_ avatarItemSource: AvatarItemSource, progress: Float) {}
}

public class AvatarItemSource: NSObject {
    // MARK: - Types

    private class FilePresenterBox: NSObject, NSFilePresenter {
        weak var item: AvatarItemSource?
        public var presentedItemURL: URL?

        public let presentedItemOperationQueue: OperationQueue
        init(_ item: AvatarItemSource) {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.qualityOfService = .utility
            self.presentedItemOperationQueue = queue
            self.item = item
        }
        public func presentedItemDidMove(to newURL: URL) {
            self.item?.localURL = newURL
        }
    }
    
    public enum State: Equatable {
        case notLoaded
        case loading
        case loaded
    }


    // MARK: - Properties
    public private(set) var state: State = .notLoaded {
        didSet {
            self.delegate?.avatarItemSource(self, didChangedStateTo: self.state)
        }
    }
    public let url: URL
    public var delegate: AvatarItemSourceDelegate?

    private let loader: AvatarImageDownloaderToLocalStorage
    private let slicer: AvatarImageSlicerFromFile
    private var filePresenter: FilePresenterBox!
    private var donwloadTask: URLSessionDownloadTask?
    private var localURL: URL! {
        didSet {
            self.filePresenter.presentedItemURL = self.localURL.resolvingSymlinksInPath()
        }
    }

    // MARK: - Constructors

    public convenience init?(urlString: String, _ loader: AvatarImageDownloaderToLocalStorage,_ slicer: AvatarImageSlicerFromFile) {
        guard let url = URL(string: urlString) else {
            return nil
        }
        self.init(url: url, loader, slicer)
    }

    public init(url: URL, _ loader: AvatarImageDownloaderToLocalStorage,_ slicer: AvatarImageSlicerFromFile) {
        self.url = url
        self.loader = loader
        self.slicer = slicer
        super.init()
        self.filePresenter = FilePresenterBox(self)
        NSFileCoordinator.addFilePresenter(self.filePresenter)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self.filePresenter)
    }

    // MARK: - LifeCycle
    public func fetch() {
        self.fetch(nil)
    }
    public func fetch(_ completion:((Result<URL,Error>)->())?) {
        self.donwloadTask?.cancel()
        self.donwloadTask = self.loader.download(url: self.url, invalidateCache: false, progress: { [weak self] (progress) in
            guard let self = self else { return }
            switch progress {
            case .progress(let progress):
                self.delegate?.avatarItemSource(self, progress: progress)
            case .unknownSize(loaded: _):
                self.delegate?.avatarItemSource(self, progress: 0.5)
            }

        }) { [weak self] (result) in
            guard let self = self else { return }
            self.donwloadTask = nil
            switch result {
            case .success(let localURL) :
                self.localURL = localURL
                self.state = .loaded
            case .failure(_):
                self.state = .notLoaded
            }
            guard let completion = completion else { return }
            completion(result)
        }
    }

    public func getImage(for size: CGSize, completion: @escaping ((Result<UIImage, Error>)->()))  {
        if self.state == .loaded {
            guard let image = self.slicer.slice(self.localURL, size: size) else {
                completion(.failure(AvatarImageSlicerError.sliceError))
                return
            }
            completion(.success(image))
            return
        }

        self.fetch { [weak self] (result) in
            guard let self = self else { return }
            self.donwloadTask = nil
            switch result {
            case .success:
                guard let image = self.slicer.slice(self.localURL, size: size) else {
                    completion(.failure(AvatarImageSlicerError.sliceError))
                    return
                }
                completion(.success(image))
                return
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
