//
//  AddressPool.swift
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

import Foundation

struct AddressPool
{
    let base: String = "10.0.0."
    var used: [Bool] = [Bool](repeating: false, count: 256)

    init()
    {
        // Reserved
        used[0] = true
        used[1] = true
        used[255] = true
    }
        
    mutating func allocate() -> String?
    {
        guard let index = used.firstIndex(of: false) else
        {
            return nil
        }
        
        used[index] = true
        
        return base + index.string
    }
    
    mutating func deallocate(address: String)
    {
        let stringIndex = address.split(separator: ".")[3]
        
        guard let index = Int(stringIndex) else
        {
            return
        }
        
        used[index]=false
    }
}
