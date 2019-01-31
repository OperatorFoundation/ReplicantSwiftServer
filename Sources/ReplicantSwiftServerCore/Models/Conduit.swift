//
//  Conduit.swift
//  ReplicantSwiftServer
//
//  Created by Adelita Schule on 11/29/18.
//

import Foundation
import Transport

public struct Conduit
{
    var address: String
    var transportConnection: Connection
    var idNumber: Int
}
