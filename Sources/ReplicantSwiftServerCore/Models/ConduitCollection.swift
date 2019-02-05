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
    private var conduits: [String : Conduit] = [ : ]
    
    func addConduit(address: String, transportConnection: Connection)
    {
        let newConduit = Conduit(address: address, transportConnection: transportConnection)
        
        conduits[address] = newConduit
    }
    
    func removeConduit(with address: String)
    {
        conduits.removeValue(forKey: address)
    }
    
    func getConduit(with address: String) -> Conduit?
    {
        if let conduit = conduits[address]
        {
            return conduit
        }
        else
        {
            return nil
        }
    }
}
