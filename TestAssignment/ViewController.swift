//
//  ViewController.swift
//  TestAssignment
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit
import TestAssignmentLibrary

public protocol ViewDelegate: AvatarViewDelegate {
    func viewDidTapNextAvatar(_ view: ViewController )
}

public class ViewController: UIViewController {
    // MARK: - Properties
    
    public var state: AvatarView.State = .none {
        didSet {
            assert(Thread.isMainThread)
            self.avatarView.state = self.state
        }
    }
    public var presenter: Presenter! {
        didSet {
            self.avatarView.delegate = self.presenter
        }
    }
    private var heightC: NSLayoutConstraint!
    private var avatarView: AvatarView

    // MARK: - Constructors
    
    init() {
        self.avatarView = AvatarView(frame: CGRect.zero)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - LifeCycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.lightGray

        self.avatarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.init(item: self.avatarView, attribute: .height, relatedBy: .equal, toItem: self.avatarView, attribute: .width, multiplier: 1, constant: 0).isActive =  true
        self.heightC = NSLayoutConstraint.init(item: self.avatarView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 200)
        self.heightC.isActive = true
        self.avatarView.backgroundColor = UIColor.orange

        let spacer = UIView()
        NSLayoutConstraint.init(item: spacer, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 50).isActive =  true

        let button = UIButton()
        button.setTitleColor(UIColor.black, for: .normal)
        button.layoutMargins = UIEdgeInsets(top: 60, left: 0, bottom: 0, right:     0)
        button.setTitle("Load next avatar", for: .normal)
        button.addTarget(self, action: #selector(clicked), for: .touchUpInside)


        let stack = UIStackView( arrangedSubviews: [self.avatarView, spacer, button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        NSLayoutConstraint.init(item: stack, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint.init(item: stack, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0).isActive = true

    }

    @objc
    private func clicked() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.presenter.viewDidTapNextAvatar(self)
        }
    }
}


