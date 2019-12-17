//
//  AvatarView.swift
//  TestAssignmentLibrary
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit

public protocol AvatarViewDelegate: class {
    func avatarView(_ avatarView: AvatarView, didChangeAvatarSizeTo size: CGSize)
}

public class AvatarView: UIView {

    // MARK: - Types
    struct Constants {
        static let animationDuration: TimeInterval = 0.5
        static let progressWidth: CGFloat = 12
        static let progressbarColor: UIColor = UIColor.blue
    }
    public enum State: Equatable {
        case none
        case placeholder(UIImage)
        case loading(Float)
        case image(UIImage)
    }

    // MARK: - Properties

    override public var backgroundColor: UIColor? {
        set {
            guard newValue != self.backgroundColor else {
                return
            }
            self.imageView.backgroundColor = newValue;
        }
        get {
            self.imageView.backgroundColor
        }
    }

    override public var bounds: CGRect {
        didSet {
            guard oldValue != self.bounds else {
                return
            }

            self.layoutImageView()
            switch self.state {
            case .loading(let progress):
                self.setCurrentProgress(loadingProgress: progress)
            case .image(_), .none, .placeholder(_):
                break
            }
        }
    }

    public var state: State = .none {
        didSet {
            assert(Thread.isMainThread)
            self.render(state)
        }
    }
    public var progressbarColor: UIColor {
        didSet {
            assert(Thread.isMainThread)
            switch self.state {
            case .loading(let progress):
                self.setCurrentProgress(loadingProgress: progress)
            case .image(_), .none, .placeholder(_):
                break
            }
        }
    }
    public var delegate: AvatarViewDelegate?
    private let imageView: UIImageView
    private var progressLayer: CAShapeLayer?

    // MARK: - Constructors

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override init(frame: CGRect) {
        self.imageView = UIImageView.init(frame: CGRect.zero);
        imageView.clipsToBounds = true
        self.progressbarColor = Constants.progressbarColor
        super.init(frame: frame)
        self.addSubview(imageView)
        imageView.contentMode = .scaleAspectFill
        self.layoutImageView()
    }

    // MARK: - LifeCycle

    private func layoutImageView() {
        let d = min(self.bounds.height, self.bounds.width)
        let r = d/2
        let centerX = self.bounds.midX
        let centerY = self.bounds.midY
        self.imageView.frame = CGRect(x: min(0, centerX - r), y: min(0, centerY - r), width: d, height: d);
        self.imageView.layer.cornerRadius = r
        self.imageView.layer.borderColor =  UIColor.black.cgColor
        self.imageView.layer.borderWidth = 1
        DispatchQueue.global().async { [weak self] in
             guard let self = self else { return }
            self.delegate?.avatarView(self, didChangeAvatarSizeTo: CGSize(width: d, height: d))
        }
    }

    private func render(_ state: State) {
        switch state {
        case .none:
            self.hideProgressBar()
            self.changeImageWithAnimation(nil)
            break;
        case .loading(let progress):
            self.showProgressBarIfNeeded()
            self.setCurrentProgress(loadingProgress: progress)
            break;
        case .image(let image):
            self.hideProgressBar()
            self.changeImageWithAnimation(image)
            break;
        case .placeholder(let placeholderImage):
            self.hideProgressBar()
            self.changeImageWithAnimation(placeholderImage)
            break;
        }
    }

    func changeImageWithAnimation(_ image: UIImage?) {
        guard image != self.imageView.image else {
            return
        }
        UIView.transition(with: self.imageView,
                          duration: Constants.animationDuration,
                          options: [.transitionCrossDissolve],
                          animations: {
                            self.imageView.image = image
        }, completion: nil)
    }

    // MARK: - progressbar

    private func showProgressBarIfNeeded() {
        guard self.progressLayer?.superlayer == nil else {
            return
        }
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineWidth = Constants.progressWidth
        layer.strokeStart = 0
        layer.strokeEnd = 0
        self.imageView.layer.addSublayer(layer)
        self.progressLayer = layer
    }

    private func setCurrentProgress(loadingProgress: Float) {
        let d = min(self.bounds.height, self.bounds.width)
        let r = d/2
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: r, y: r), radius: r, startAngle: -.pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
        self.progressLayer?.path = circularPath.cgPath
        self.progressLayer?.strokeEnd = CGFloat(loadingProgress)
        self.progressLayer?.strokeColor = self.progressbarColor.cgColor
    }

    public func hideProgressBar() {
        guard self.progressLayer?.superlayer != nil else {
            return
        }
        self.progressLayer?.removeFromSuperlayer()
    }
}
