//
//  HorreumTests.swift
//  HorreumTests
//
//  Created by Georg Kitz on 17/12/15.
//  Copyright (c) 2015 Alpic GmbH. All rights reserved.
//

import XCTest
import CoreData
@testable import Horreum

class HorreumTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Horreum.createForTesting()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitWorks() {
        XCTAssert(Horreum.instance != nil)
    }
    
    func testContext() {
        let mainContext = Horreum.instance!.mainContext
        let workerContext = Horreum.instance!.workerContext()
        
        XCTAssert(mainContext.parent != nil)
        XCTAssert(mainContext.concurrencyType == .mainQueueConcurrencyType)
        XCTAssert(workerContext.parent == mainContext)
        XCTAssert(workerContext.concurrencyType == .privateQueueConcurrencyType)
    }
    
    func testInsertInWorkerContext() {
        
        let mainContext = Horreum.instance!.mainContext
        let workerContext = Horreum.instance!.workerContext()
        
        let name = "Foo"
        var entity: Entity? = nil
        
        workerContext.performAndWait { () -> Void in
            
            entity = NSEntityDescription.insertNewObject(forEntityName: "Entity", into: workerContext) as? Entity
            entity?.name = name
            
            try! workerContext.save()
        }
        
        sleep(2)
        
        let fetch = NSFetchRequest<Entity>(entityName: "Entity")
        let items = try! mainContext.fetch(fetch)
        
        XCTAssert(items.count == 1)
        XCTAssert(items[0].name == name)
    }
    
    func testInsertIntoChildOfMaster() {
        
        let mainContext = Horreum.instance!.mainContext
        let masterContext = Horreum.instance!.masterContext
        
        let childMainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        childMainContext.parent = mainContext
        childMainContext.automaticallyMergesChangesFromParent = true
        
        let fetch = NSFetchRequest<Entity>(entityName: "Entity")
        
        XCTAssertEqual(try! childMainContext.fetch(fetch).count, 0)
        
        let name = "Foo1"
        var entity: Entity? = nil
        
        childMainContext.performAndWait { () -> Void in
            
            entity = NSEntityDescription.insertNewObject(forEntityName: "Entity", into: childMainContext) as? Entity
            entity?.name = name
            
            try! childMainContext.save()
        }
        
        delay(4)
        
        var its1 = try! masterContext.fetch(fetch)
        var its2 = try! mainContext.fetch(fetch)
        var its3 = try! childMainContext.fetch(fetch)
        
        XCTAssertEqual(its1.count, 1)
        XCTAssertEqual(its2.count, 1)
        XCTAssertEqual(its3.count, 1)
        
        XCTAssertEqual(its1.first!.name, name)
        XCTAssertEqual(its2.first!.name, name)
        XCTAssertEqual(its3.first!.name, name)
        
        let newName1 = "Foo2"
        mainContext.performAndWait { () -> Void in
            
            its2.first?.name = newName1
            try! mainContext.save()
        }
        
        delay(4)
        
        its1 = try! masterContext.fetch(fetch)
        its2 = try! mainContext.fetch(fetch)
        its3 = try! childMainContext.fetch(fetch)
        
        XCTAssertEqual(its1.count, 1)
        XCTAssertEqual(its2.count, 1)
        XCTAssertEqual(its3.count, 1)
        
        XCTAssertEqual(its1.first!.name, newName1)
        XCTAssertEqual(its2.first!.name, newName1)
        XCTAssertEqual(its3.first!.name, newName1)
        
        let newName2 = "Foo3"
        masterContext.performAndWait{
            
            let items = try! masterContext.fetch(fetch)
            items.first!.name = newName2
            
            try? masterContext.save()
        }
        
        delay(4)
        
        its1 = try! masterContext.fetch(fetch)
        its2 = try! mainContext.fetch(fetch)
        its3 = try! childMainContext.fetch(fetch)
        
        XCTAssertEqual(its1.count, 1)
        XCTAssertEqual(its2.count, 1)
        XCTAssertEqual(its3.count, 1)
        
        XCTAssertEqual(its1.first!.name, newName2)
        XCTAssertEqual(its2.first!.name, newName2)
        XCTAssertEqual(its3.first!.name, newName1) // this keeps the old name, since automaticallyMergesChangesFromParent is not recursive
        
        XCTAssertEqual(childMainContext.parent, mainContext)
        XCTAssertEqual(mainContext.parent, masterContext)
    }
    
    func delay(_ interval: TimeInterval) {
        let e = expectation(description: #function)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval) {
            e.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
}

extension Horreum {
    
    class func createForTesting() {

        let modelURL = Bundle.main.url(forResource: "Horreum", withExtension: "momd")!
        let storeURL = FileManager().urls(for: .documentationDirectory, in: .userDomainMask)[0]
        let options = HorreumStoreOptions()
        
        Horreum.create(modelURL, storeURL: storeURL, storeType: NSInMemoryStoreType, options: options)
    }
}
