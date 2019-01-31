//
//  ConduitCollection.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Transport

public class ConduitCollection: NSObject
{
    private var conduits: [Int : Conduit] = [ : ]
    private var lastConnectionID = 0
    
    func addConduit(address: String, transportConnection: Connection) -> Int
    {
        lastConnectionID += 1
        
        let newConduit = Conduit(address: address, transportConnection: transportConnection, idNumber: lastConnectionID)
        
        conduits[lastConnectionID] = newConduit
        
        return lastConnectionID
    }
    
    func removeConduit(with clientID: Int)
    {
        conduits.removeValue(forKey: clientID)
    }
    
    func getConduit(with clientID: Int) -> Conduit?
    {
        if let conduit = conduits[clientID]
        {
            return conduit
        }
        else
        {
            return nil
        }
    }
}
