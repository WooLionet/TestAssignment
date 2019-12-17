//
//  TestAssignmentLibrary.swift
//  TestAssignmentLibrary
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit

public enum AvatarImageDownloaderProgress {
    case unknownSize(loaded: Int64)
    case progress(Float)
}
public protocol AvatarImageDownloaderToLocalStorage {

    func download(url: URL, invalidateCache: Bool, progress: ((AvatarImageDownloaderProgress)->())?, completion: @escaping (Result<URL,Error>)->()) -> URLSessionDownloadTask?
}
public enum AvatarImageSlicerError: Error {
    case sliceError
}

public protocol AvatarImageSlicerFromFile {
    func slice(_ imageLocalURL: URL, size: CGSize) -> UIImage?
}
