//
//  AppDelegate.swift
//  action
//
//  Created by zpc on 2018/10/21.
//  Copyright © 2018年 zpc. All rights reserved.
//

import UIKit
import CoreData
import CloudKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var ubiquityIdentityToken: (NSCoding & NSCopying & NSObjectProtocol)?
    var userCacheOrNil: UserLocalCache?
    
    // Keep the share we accepted so that we can select the zone when the share comes in.
    //
    private var shareMetadataToOpen: CKShare.Metadata?
    
    // Use CKContainer(identifier: <your custom container ID>) if not the default container.
    // Note that:
    // 1. iCloud container ID starts with "iCloud.".
    // 2. This will error out if iCloud / CloudKit entitlement is not well set up.
    //
    let container = CKContainer.default()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Observe the .zoneCacheDidChange and .zoneDidSwitch to update the topic cache if needed.
        //
        
        // Register for remote notification.
        // The local caches rely on subscription notifications, so notifications have to be granted in this sample.
        //
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
            
            if let error = error {
                print("notificationCenter.requestAuthorization returns error: \(error)")
            }
            if granted != true {
                print("notificationCenter.requestAuthorization is not granted!")
            }
        }
        application.registerForRemoteNotifications()
        
        application.applicationIconBadgeNumber = 0
        
        // Save the current user token for user-switching check later.
        //
        ubiquityIdentityToken = FileManager.default.ubiquityIdentityToken
        
        // Checking account availability. Create local cache objects if the accountStatus is available.
        // .zoneCacheDidChange will be posted after the zone cache is built, which triggers the creation
        // of topic local cache.
        //
        checkAccountStatus(for: container) { available in
            guard available else { return self.handleAccountUnavailable() }
            self.userCacheOrNil = UserLocalCache()
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        application.applicationIconBadgeNumber = 0 // Clear the badge number.
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    func application(
        _ application: UIApplication,didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // When the app is transiting from background to foreground, appWillEnterForeground should have already
        // refreshed the local cache, so simply return when application.applicationState == .inactive.
        //
        guard let userInfo = userInfo as? [String: NSObject],
            application.applicationState != .inactive else { return }
        
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        // Only notifications with a subscriptionID are interested in this sample.
        //
        guard let subscriptionID = notification.subscriptionID else { return }
        
    }
    
    // Report the error when failed to register the notifications.
    //
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
        print("!!! didFailToRegisterForRemoteNotificationsWithError: \(error)")
    }
    
    // To be able to accept a share, add a CKSharingSupported entry in the info.plist and set it to true.
    // This is mentioned in the WWDC 2016 session 226 “What’s New with CloudKit”.
    //
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        
        shareMetadataToOpen = cloudKitShareMetadata
        
        let acceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        acceptSharesOperation.acceptSharesCompletionBlock = { error in
            guard handleCloudKitError(error, operation: .acceptShare, alert: true) == nil else { return }
        }
        container.add(acceptSharesOperation)
    }
    
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        backgroundCompletionHandler = completionHandler
    }
    
    var backgroundCompletionHandler : (() -> Void)?

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "action")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}


extension AppDelegate { // MARK: - Account status checking.
    
    // Checking account availability. We do account check when the app comes back to foreground.
    // This method should be called from the main thread.
    //
    private func checkAccountStatus(for container: CKContainer,
                                    completionHandler: @escaping ((Bool) -> Void)) {
        
        var success = false, completed = false
        let task = {
            container.accountStatus { (status, error) in
                
                if handleCloudKitError(error, operation: .accountStatus, alert: true) == nil &&
                    status == CKAccountStatus.available {
                    success = true
                }
                completed = true
            }
        }
        
        // Do a second check a while (0.2 second) after the first failure.
        //
        let retryQueue = DispatchQueue(label: "retryQueue")
        let times = 2, interval = [0.0, 0.2]
        
        for index in 0..<times {
            retryQueue.asyncAfter(deadline: .now() + interval[index]) { task() }
            
            while completed == false {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
            }
            if success {
                break
            }
        }
        completionHandler(success)
    }
    
    private func handleAccountUnavailable() {
        
        let title = "iCloud account is unavailable."
        let message = "Be sure to sign in iCloud and turn on iCloud Drive before using this sample."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        window?.rootViewController?.present(alert, animated: true)
        
    }
}

