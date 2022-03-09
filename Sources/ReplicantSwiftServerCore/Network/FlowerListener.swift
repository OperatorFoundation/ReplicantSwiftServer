//
//  FlowerListener.swift
//  
//
//  Created by Dr. Brandon Wiley on 12/8/21.
//

import Foundation
import Logging

import ReplicantSwift
import SwiftQueue
import Flower
import Net
import Transmission
//import TransmissionTransport

public class FlowerListener
{
    let logger: Logger
    let replicantListener: Transmission.Listener

    required public init?(port: Int, replicantConfig: ReplicantServerConfig, logger: Logger)
    {
        self.logger = logger

        guard let replicantListener = ReplicantListener(port: port, replicantConfig: replicantConfig, logger: logger) else {return nil}
        self.replicantListener = replicantListener
    }

    public func accept() -> FlowerConnection
    {
        let replicantConnection = self.replicantListener.accept()
        return FlowerConnection(connection: replicantConnection, log: self.logger)
    }
}
