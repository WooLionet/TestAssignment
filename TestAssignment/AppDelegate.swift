//
//  AppDelegate.swift
//  TestAssignment
//
//  Created by  Pavel Himach on 08.12.2019.
//  Copyright © 2019 Pavel Khimach. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties

    public var window: UIWindow?

    // MARK: - LifeCycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow.init(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        window.rootViewController = self.bildView()

        self.window = window;
        return true
    }
    // MARK: - Builders
    private func bildView() -> UIViewController {
        let view = ViewController()
        if let image = UIImage.init(named: "placeholder") {
            view.state = .placeholder(image)
        }
        // TODO: - fill urls
        let urls: [URL] = []
        let model = Model(with: urls)
        let presenter = Presenter(model, view: view)
        view.presenter = presenter
        return view
    }
}

