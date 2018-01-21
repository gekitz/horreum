//
// Created by Georg Kitz on 17/12/15.
// Copyright (c) 2015 Alpic GmbH. All rights reserved.
//

import Foundation
import CoreData

open class Horreum: NSObject {
    
    struct Static {
        static var instance: Horreum?
    }

    open class var instance: Horreum? {
        get {
            return Static.instance
        }
        set {
            Static.instance = newValue
        }
    }

    open class func create(_ modelURL: URL, storeURL: URL, storeType: String, options: HorreumStoreOptions) {
        instance = Horreum(modelURL: modelURL, storeURL: storeURL, storeType: storeType, options: options)
    }

    open class func destory() throws {
        try instance?.destroy()
        instance = nil
    }

    fileprivate let model: NSManagedObjectModel
    fileprivate let storeCoordinator: NSPersistentStoreCoordinator
    fileprivate let store: NSPersistentStore

    open let masterContext: NSManagedObjectContext
    open let mainContext: NSManagedObjectContext

    init?(modelURL: URL, storeURL: URL, storeType: String, options: HorreumStoreOptions) {

        //this should be change as soon as Swift allows to have failable initialisers without
        //initialising all stored properties. For now this will simply crash if the file can't be found
        //at the given URL
        //http://stackoverflow.com/questions/26495586/best-practice-to-implement-a-failable-initializer-in-swift
        model = NSManagedObjectModel(contentsOf: modelURL)!

        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        store = try! storeCoordinator.addPersistentStore(ofType: storeType, configurationName: nil, at: storeURL, options: options.optionsDictionary())

        masterContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        masterContext.persistentStoreCoordinator = storeCoordinator
        masterContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        masterContext.stalenessInterval = 0

        mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainContext.parent = masterContext
        mainContext.automaticallyMergesChangesFromParent = true
        mainContext.stalenessInterval = 0
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.saveNotification), name:NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open func workerContext() -> NSManagedObjectContext {
        let workerContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        workerContext.parent = mainContext
        return workerContext
    }

    open func destroy() throws {
        try self.storeCoordinator.remove(store)
        
        if let storeURL = store.url {
            do {
                try FileManager().removeItem(at: storeURL)
            } catch {
                
            }
        }
        Horreum.instance = nil
    }

    @objc func saveNotification(_ notification: Notification) {

        let context  = notification.object as! NSManagedObjectContext?

        if let context = context, context != masterContext {

            let persistentStoreCoordinator = context.persistentStoreCoordinator

            if let parentContext = context.parent, storeCoordinator == persistentStoreCoordinator {

                parentContext.perform {
                    
                    do {
                        
                        try parentContext.save()
                    } catch {
                        
                        print("Failed to merge changes with error: \(error)")
                    }
                }
            } else {

                masterContext.perform {
                    self.masterContext.mergeChanges(fromContextDidSave: notification)
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
    
    public func optionsDictionary() -> [AnyHashable: Any] {
        return [
            NSMigratePersistentStoresAutomaticallyOption: migrateAutomatically,
            NSInferMappingModelAutomaticallyOption: inferMappingModelAutomatically
        ]
    }
}
