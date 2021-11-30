//
//  ConduitCollection.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Transmission

public class ConduitCollection: NSObject
{
    private var conduits: [String : Conduit] = [ : ]
    
    func addConduit(address: String, transmissionConnection: Transmission.Connection)
    {
        print("\nAdding a conduit to the conduit collection.")
        let newConduit = Conduit(address: address, transmissionConnection: transmissionConnection)
        
        conduits[address] = newConduit
    }
    
    func removeConduit(with address: String)
    {
        print("Removing a conduit from the conduit collection.")
        conduits.removeValue(forKey: address)
    }
    
    func getConduit(with address: String) -> Conduit?
    {
        print("Getting conduit with address \(address)")
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
