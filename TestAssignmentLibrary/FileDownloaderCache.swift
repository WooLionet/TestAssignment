//
//  FileDownloaderCache.swift
//  TestAssignmentLibrary
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import Foundation
import RealmSwift

class FileDownloaderCacheEntity: Object {
    @objc dynamic var urlKey: String!
    @objc dynamic var destinationKey: String!
    @objc dynamic var createdAt: Date = Date()
    @objc dynamic var size: Int64 = 0
    override static func primaryKey() -> String? {
        return "urlKey"
    }
}

public class FileDownloaderCache {
    // MARK: - Types
    typealias Entity = FileDownloaderCacheEntity
    private struct Constants {
        static let dbName = "db.realm"
    }

    public enum Limit {
        case unlimited
        case limit(Int64)
    }

    // MARK: - Properties

    public var cacheSize: Limit {
        didSet {
            self.freeSpaceIfNeeded(self.cacheSize)
        }
    }
    public var cacheCount: Limit {
        didSet {
            self.removeFilesIfNeeded(self.cacheCount)
        }
    }
    
    public let cacheFolderURL: URL
    private let realm: Realm
    private let syncQueue: DispatchQueue
    private var cacheLinks:[URL: URL]
    private var count: Int {
        self.cacheLinks.count
    }

    // MARK: - Constructors

    public init(cacheFolderURL: URL) throws {
        try FileManager.default.createDirectory(at: cacheFolderURL, withIntermediateDirectories: true, attributes: nil)
        self.syncQueue = DispatchQueue(label: "cacheQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: .none)
        self.cacheSize = .limit(10_000_000)
        self.cacheCount = .limit(10)
        self.cacheFolderURL = cacheFolderURL
        let config = Realm.Configuration(fileURL: self.cacheFolderURL.appendingPathComponent(Constants.dbName))
        self.realm = try! Realm(configuration: config)
        self.cacheLinks = [:]
        self.syncQueue.async {
            self.syncDBWithFolder()
            DispatchQueue.main.sync {
                self.realm.objects(FileDownloaderCacheEntity.self).forEach { (row) in
                    let urlKey = URL(string: row.urlKey!)!
                    let fileURL = self.cacheFolderURL.appendingPathComponent(row.destinationKey)
                    self.cacheLinks[urlKey] = fileURL
                }
            }
        }
    }
    // MARK: - LifeCycle

    public func moveToCache(remoteURL: URL, fileURL: URL) throws -> URL? {
        guard self.canCacheFile(fileURL) else {
            return nil
        }
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize!;
        var cacheFileURL = self.cacheFolderURL.appendingPathComponent(UUID().uuidString)
        while FileManager.default.fileExists(atPath: cacheFileURL.path) {
            cacheFileURL = self.cacheFolderURL.appendingPathComponent(UUID().uuidString)
        }
        try FileManager.default.moveItem(at: fileURL, to: cacheFileURL)

        self.syncQueue.sync {
            if let existingCache = self.cacheLinks[remoteURL] {
                try! FileManager.default.removeItem(at: existingCache)
            }
            self.cacheLinks[remoteURL] = cacheFileURL
            DispatchQueue.main.sync {

                let cacheRow = self.realm.object(ofType: Entity.self, forPrimaryKey: remoteURL.absoluteString) ?? Entity()
                try! self.realm.write {
                    if cacheRow.urlKey ==  nil {
                        cacheRow.urlKey = remoteURL.absoluteString
                    }
                    cacheRow.destinationKey = cacheFileURL.lastPathComponent
                    cacheRow.size = Int64(fileSize)
                    self.realm.add(cacheRow)
                }
            }
        }
        return cacheFileURL
    }

    private func syncDBWithFolder() {
        self.syncRemoveDBRows()
        self.syncRemoveFiles()
    }

    private func syncRemoveDBRows() {
        do {
            let cachedFiles = try FileManager.default.contentsOfDirectory(at: self.cacheFolderURL, includingPropertiesForKeys: nil).filter({!$0.path.contains(Constants.dbName)})
            let filesSet = Set(cachedFiles.map({$0.lastPathComponent}))
            DispatchQueue.main.sync {
                let results = self.realm.objects(FileDownloaderCacheEntity.self).filter({ !filesSet.contains($0.destinationKey) })
                
                try! self.realm.write {
                    realm.delete(results)
                }
            }

        } catch {
            print(error)
        }
    }

    private func syncRemoveFiles() {
        do {
            var filesSet: Set<String>!
            DispatchQueue.main.sync {
                let  results = realm.objects(FileDownloaderCacheEntity.self)
                filesSet = Set(results.map({$0.destinationKey}))
            }

            let cachedFiles = try FileManager.default.contentsOfDirectory(at: self.cacheFolderURL, includingPropertiesForKeys: nil).filter({!$0.path.contains(Constants.dbName)})
            let filesToDelete = cachedFiles.filter({!filesSet.contains($0.lastPathComponent)})
            filesToDelete.forEach({ self.removeOrMoveToTemp($0) })
        } catch {
            print(error)
        }
    }
    public func getCacheUrl(for url: URL) -> URL? {
        guard let fileURL = self.cacheLinks[url] else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    private func removeCache(by url: URL) {
        guard let fileURL = self.cacheLinks[url] else {
            return
        }
        let block = {
            do{
                self.removeOrMoveToTemp(fileURL)
                guard let cacheRow = self.realm.object(ofType: Entity.self, forPrimaryKey: url.absoluteString) else {
                    return
                }
                try self.realm.write {
                    self.realm.delete(cacheRow)
                }
            } catch {
                print(error)
            }
        }
        if (Thread.isMainThread){
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }
    private func canCacheFile(_ url: URL) -> Bool{
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return false
        }
        let fileSize = Int64(size)
        switch self.cacheSize {
        case .limit(let maxSize):
            guard maxSize >= fileSize else {
                return false
            }
            var  keysToDelete: [URL] = []
            let realmBlock =  { () -> Bool in
                let result = self.realm.objects(Entity.self).sorted(byKeyPath: "createdAt")
                var usedSpace: Int64 = result.reduce(0, {$0 + $1.size})
                var resultSlice = result.dropFirst(0)
                while fileSize + usedSpace > maxSize {
                    guard let row = resultSlice.first else {
                        return false
                    }
                    usedSpace -= row.size
                    keysToDelete.append(URL(string: row.urlKey)!)
                    resultSlice = resultSlice.dropFirst()
                }
                return true
            }
            var canToFreeSpace = false
            if (Thread.isMainThread){
                canToFreeSpace = realmBlock()
            } else {
                canToFreeSpace = DispatchQueue.main.sync(execute: realmBlock)
            }
            guard canToFreeSpace else {
                return false
            }
            keysToDelete.forEach({self.removeCache(by: $0)})
        case .unlimited:
            break
        }
        switch self.cacheCount {
        case .limit(let maxCount):
            guard maxCount > 0 else {
                return false
            }

            let realmBlock =  { () -> URL? in
                guard let urlString = self.realm.objects(Entity.self).sorted(byKeyPath: "createdAt").first?.urlKey else {
                    return nil
                }
                return URL(fileURLWithPath: urlString)
            }
            var urlToRemove: URL?
            if (Thread.isMainThread){
                urlToRemove = realmBlock()
            } else {
                urlToRemove = DispatchQueue.main.sync(execute: realmBlock)
            }
            if let urlToRemove = urlToRemove {
                self.removeCache(by: urlToRemove)
            }
        case .unlimited:
            break
        }
        return true
    }

    public func reset() {
        self.syncQueue.async {
            if let cachedFiles = try? FileManager.default.contentsOfDirectory(at: self.cacheFolderURL, includingPropertiesForKeys: nil).filter({!$0.path.contains(Constants.dbName)}) {
                cachedFiles.forEach({ self.removeOrMoveToTemp($0) })
            }
            DispatchQueue.main.sync {
                try? self.realm.write {
                    self.realm.deleteAll()
                }
            }
            self.cacheLinks = [:]
        }
    }

    private func removeOrMoveToTemp(_ fileURL: URL) {
        let fileURL = fileURL.resolvingSymlinksInPath()
        let filePresenters = NSFileCoordinator.filePresenters.filter({ $0.presentedItemURL == fileURL })
        if filePresenters.count > 0 {
            let path = FileManager.default.temporaryDirectory
            var newURL = path.appendingPathComponent(fileURL.lastPathComponent)
            while FileManager.default.fileExists(atPath: newURL.path) {
                newURL = path.appendingPathComponent(UUID().uuidString)
            }
            do {
                try FileManager.default.moveItem(at: fileURL, to: newURL)
                filePresenters.forEach { (presenter) in
                    presenter.presentedItemOperationQueue.addOperation {
                        presenter.presentedItemDidMove?(to: newURL)
                    }
                }
            } catch {
                print(error)
            }
        } else {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func freeSpaceIfNeeded(_ spaceLimit: Limit) {
        self.syncQueue.async {
            switch spaceLimit {
            case .limit(let maxSize):
                var  keysToDelete: [URL] = []
                let realmBlock =  { () -> Bool in
                    let result = self.realm.objects(Entity.self).sorted(byKeyPath: "createdAt")
                    var usedSpace: Int64 = result.reduce(0, {$0 + $1.size})
                    var resultSlice = result.dropFirst(0)
                    while usedSpace > maxSize {
                        guard let row = resultSlice.first else {
                            return false
                        }
                        usedSpace -= row.size
                        keysToDelete.append(URL(string: row.urlKey)!)
                        resultSlice = resultSlice.dropFirst()
                    }
                    return true
                }
                let canToFreeSpace = DispatchQueue.main.sync(execute: realmBlock)
                guard canToFreeSpace else {
                    self.reset()
                    return
                }
                keysToDelete.forEach({self.removeCache(by: $0)})
            case .unlimited:
                break
            }
        }
    }

    private func removeFilesIfNeeded(_ filesCountLimit: Limit) {
        switch filesCountLimit {
        case .limit(let maxCount):
            guard maxCount > 0 else {
                self.reset()
                return
            }
            var  keysToDelete: [URL] = []
            let realmBlock =  { () -> Bool in
                let result = self.realm.objects(Entity.self).sorted(byKeyPath: "createdAt")
                if result.count <= maxCount { return true }
                result.dropLast(result.count - Int(maxCount)).forEach { (row) in
                    keysToDelete.append(URL(string: row.urlKey)!)
                }
                return true
            }
            let canToFreeCount = DispatchQueue.main.sync(execute: realmBlock)
            guard canToFreeCount else {
                self.reset()
                return
            }
            keysToDelete.forEach({self.removeCache(by: $0)})
        case .unlimited:
            break
        }
    }
}
