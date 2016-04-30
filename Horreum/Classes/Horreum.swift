//
// Created by Georg Kitz on 17/12/15.
// Copyright (c) 2015 Alpic GmbH. All rights reserved.
//

import Foundation
import CoreData

public class Horreum: NSObject {
    
    struct Static {
        static var instance: Horreum?
    }

    public class var instance: Horreum? {
        get {
            return Static.instance
        }
        set {
            Static.instance = newValue
        }
    }

    public class func create(modelURL: NSURL, storeURL: NSURL, storeType: String, options: HorreumStoreOptions) {
        instance = Horreum(modelURL: modelURL, storeURL: storeURL, storeType: storeType, options: options)
    }

    public class func destory() throws {
        try instance?.destroy()
        instance = nil
    }

    private let model: NSManagedObjectModel
    private let storeCoordinator: NSPersistentStoreCoordinator
    private let store: NSPersistentStore

    private let masterContext: NSManagedObjectContext
    public let mainContext: NSManagedObjectContext

    init?(modelURL: NSURL, storeURL: NSURL, storeType: String, options: HorreumStoreOptions) {

        //this should be change as soon as Swift allows to have failable initialisers without
        //initialising all stored properties. For now this will simply crash if the file can't be found
        //at the given URL
        //http://stackoverflow.com/questions/26495586/best-practice-to-implement-a-failable-initializer-in-swift
        model = NSManagedObjectModel(contentsOfURL: modelURL)!

        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        store = try! storeCoordinator.addPersistentStoreWithType(storeType, configuration: nil, URL: storeURL, options: options.optionsDictionary())

        masterContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        masterContext.persistentStoreCoordinator = storeCoordinator
        masterContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        masterContext.stalenessInterval = 0

        mainContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        mainContext.parentContext = masterContext
        mainContext.stalenessInterval = 0
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "saveNotification:", name:NSManagedObjectContextDidSaveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public func workerContext() -> NSManagedObjectContext {
        let workerContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        workerContext.parentContext = mainContext
        return workerContext
    }

    public func destroy() throws {
        try self.storeCoordinator.removePersistentStore(self.store)

        if let storeURL = store.URL {
            try NSFileManager().removeItemAtURL(storeURL)
        }
    }

    func saveNotification(notification: NSNotification) {

        let context  = notification.object as! NSManagedObjectContext?

        if let context = context where context != masterContext {

            let persistentStoreCoordinator = context.persistentStoreCoordinator

            if let parentContext = context.parentContext where storeCoordinator != persistentStoreCoordinator {

                parentContext.performBlock {
                    
                    do {
                        
                        try parentContext.save()
                    } catch {
                        
                        print("Failed to merge changes with error: \(error)")
                    }
                }
            } else {

                masterContext.performBlock {
                    self.masterContext.mergeChangesFromContextDidSaveNotification(notification)
                }
            }
        }
    }
}

public struct HorreumStoreOptions {
    let migrateAutomatically: Bool
    let inferMappingModelAutomatically: Bool
    
    public init(migrateAutomatically: Bool = true, inferMappingModelAutomatically: Bool = true) {
        self.migrateAutomatically = migrateAutomatically
        self.inferMappingModelAutomatically = inferMappingModelAutomatically
    }
    
    public func optionsDictionary() -> [NSObject: AnyObject] {
        return [
            NSMigratePersistentStoresAutomaticallyOption: migrateAutomatically,
            NSInferMappingModelAutomaticallyOption: inferMappingModelAutomatically
        ]
    }
}