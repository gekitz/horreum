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
}

extension Horreum {
    
    class func createForTesting() {

        let modelURL = Bundle.main.url(forResource: "Horreum", withExtension: "momd")!
        let storeURL = FileManager().urls(for: .documentationDirectory, in: .userDomainMask)[0]
        let options = HorreumStoreOptions()
        
        Horreum.create(modelURL, storeURL: storeURL, storeType: NSInMemoryStoreType, options: options)
    }
}
