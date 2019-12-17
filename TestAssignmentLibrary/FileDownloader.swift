//
//  FileDownloader.swift
//  TestAssignmentLibrary
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import Foundation

public class FileDownloader: NSObject {
    // MARK: -types
    private struct taskBlocks {
        let progressObserver:((AvatarImageDownloaderProgress)->())?
        fileprivate let completion: ((Result<URL, Error>) -> ())
    }
    // MARK: -properties
    public var cache: FileDownloaderCache?

    fileprivate var urlSession: URLSession!
    private let syncQueue: DispatchQueue
    private var tasksMap: [URLSessionTask: taskBlocks] = [:]

    // MARK: - Constructors
    
    public init(_ cache: FileDownloaderCache? = nil) {
        self.syncQueue = DispatchQueue(label: "tasksSyncQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: .none)
        super.init()
        self.cache = cache
        self.urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
    }
}

extension FileDownloader: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        var url = location
        if let cache = cache, let cacheURL = try? cache.moveToCache(remoteURL: downloadTask.currentRequest!.url!, fileURL: location){
            url = cacheURL
        }
        syncQueue.sync {
            guard let blocks = self.tasksMap[downloadTask] else {
                return
            }
            blocks.completion(.success(url))
            self.tasksMap[downloadTask] = nil
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            syncQueue.sync {
                guard let blocks = self.tasksMap[task] else {
                    return
                }
                blocks.completion(.failure(error))
                self.tasksMap[task] = nil
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        syncQueue.sync {
            guard let blocks = self.tasksMap[downloadTask] else {
                return
            }
            guard totalBytesExpectedToWrite >= 0 else {
                blocks.progressObserver?(.unknownSize(loaded: totalBytesWritten))
                return
            }

            let progress: Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)

            blocks.progressObserver?(.progress(progress))
        }

    }
}

extension FileDownloader: AvatarImageDownloaderToLocalStorage {
    public func download(url: URL, invalidateCache: Bool, progress: ((AvatarImageDownloaderProgress) -> ())?, completion: @escaping (Result<URL, Error>) -> ()) -> URLSessionDownloadTask? {
        if let fileURL = self.cache?.getCacheUrl(for: url), !invalidateCache {
            completion(.success(fileURL))
            return nil
        }
        let task = self.urlSession.downloadTask(with: url)
        let bloks = taskBlocks(progressObserver: progress, completion: completion)
        self.syncQueue.sync {
            self.tasksMap[task] = bloks
        }
        task.resume()
        return task
    }

}
