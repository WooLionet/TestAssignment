//
//  Presenter.swift
//  TestAssignment
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit
import TestAssignmentLibrary

public class Presenter {
    // MARK: - Properties

    public let model: Model
    public weak var view: ViewController?
    public private(set) var avatarSource: AvatarItemSource?
    
    private var avatarSize: CGSize = .zero

    // MARK: - Constructors

    init(_ model: Model, view: ViewController) {
        self.model = model
        self.model.delegate = self
        self.view = view
    }

    // MARK: - LifeCycle
    
    private func updateImage() {
        self.avatarSource?.getImage(for: self.avatarSize, completion: {[weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let image):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.view?.state = .image(image)
                }
            case .failure(let error):
                print(error)

            }
        })
    }
}

extension Presenter: ModelDelegate {
    public func model(_ model: Model, didChange avatarItemSource: AvatarItemSource) {
        self.avatarSource = avatarItemSource
        avatarItemSource.delegate = self
        self.updateImage()
    }
}

extension Presenter: ViewDelegate {
    public func viewDidTapNextAvatar(_ view: ViewController) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.model.getNextAvatar()
        }
    }
}

extension Presenter: AvatarViewDelegate {
    public func avatarView(_ avatarView: AvatarView, didChangeAvatarSizeTo size: CGSize) {
        self.avatarSize = size
        self.updateImage()
    }
}

extension Presenter: AvatarItemSourceDelegate {
    public func avatarItemSource(_ avatarItemSource: AvatarItemSource, progress: Float) {
        DispatchQueue.main.async {
            self.view?.state = .loading(progress)
        }
    }
}
