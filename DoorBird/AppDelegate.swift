//
//  AppDelegate.swift
//  DoorBird
//
//  Created by Admin on 04/04/2023.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {


    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window?.overrideUserInterfaceStyle = .light
        }
        let vc = Bundle.main.loadNibNamed("HomeVC", owner: nil, options: nil)![0] as! HomeVC
        self.window?.rootViewController =   UINavigationController(rootViewController: vc)
//       self.window?.rootViewController =   CustomerTabbarVC()
        
        self.window?.makeKeyAndVisible()
        return true
    }




}

