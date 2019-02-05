//
//  IPPacket.swift
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 2/4/19.
//

import Foundation
import Network

// https://en.wikipedia.org/wiki/IPv4#Packet_structure
struct IPv4Packet
{
    let version: UInt8
    let ihl: UInt8
    let dscp : UInt8
    let ecn: UInt8
    let totalLength: UInt16
    let identification: UInt16
    let flags: UInt8
    let fragmentOffset: UInt16
    let timeToLive: UInt8
    let protocolNumber: UInt8
    let headerChecksum: UInt16
    let sourceIPAddress: IPv4Address
    let destinationIPAddress: IPv4Address
    var options: Data? = nil
    var payload: Data? = nil
    
    init?(data: Data)
    {
        var maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        var (head, tail) = maybePair!
        
        (version, ihl) = splitNibbles(byte: head.first!)
        
        maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!

        (dscp, ecn) = splitBits(byte: tail.first!, leftSize: 6)
        
        maybePair = data.splitOn(position: 2)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        totalLength = head.uint16
        
        maybePair = data.splitOn(position: 2)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        identification=head.uint16
        
        maybePair = data.splitOn(position: 2)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!

        (flags, fragmentOffset) = splitBits(integer: head.uint16, leftSize: 3)
        
        maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!

        timeToLive = head.uint8
        
        maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        protocolNumber = head.uint8
        
        maybePair = data.splitOn(position: 2)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        headerChecksum = head.uint16
        
        maybePair = data.splitOn(position: 4)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        let maybeSourceIPAddress = IPv4Address(data: head)
        if maybeSourceIPAddress == nil
        {
            return nil
        }
        
        sourceIPAddress = maybeSourceIPAddress!
        
        maybePair = data.splitOn(position: 4)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        let maybeDestinationIPAddress = IPv4Address(data: head)
        if maybeDestinationIPAddress == nil
        {
            return nil
        }
        destinationIPAddress = maybeDestinationIPAddress!

        var optionsLength: UInt = 0
        
        if (ihl > 5)
        {
            optionsLength = UInt(ihl - 5) * 4
            maybePair = data.splitOn(position: optionsLength)
            if maybePair == nil
            {
                return nil
            }
            
            (head, tail) = maybePair!
            
            options = head
        }
        
        let payloadSize = UInt(totalLength) - (20 + optionsLength)
        
        if payloadSize > 0
        {
            maybePair = data.splitOn(position: payloadSize)
            if maybePair == nil
            {
                return nil
            }
            
            (head, tail) = maybePair!
            
            payload = head
        }
        
        if(!validate())
        {
            return nil
        }
    }
    
    func validate() -> Bool
    {
        guard version == 4 else
        {
            return false
        }
        
        guard ihl >= 5, ihl <= 15 else
        {
            return false
        }
        
        guard totalLength >= 20, totalLength <= 65535 else
        {
            return false
        }
        
        guard flags & 0b11111011 == 0 else
        {
            return false
        }
        
        guard fragmentOffset <= 65535 else
        {
            return false
        }
        
        return true
    }
}

// https://en.wikipedia.org/wiki/IPv6_packet
struct IPv6Packet
{
    let version: UInt8
    let trafficClass: UInt8
    let flowLabel: UInt32
    let payloadLength: UInt16
    let nextHeader: UInt8
    let hopLimit: UInt8
    let sourceIPAddress: IPv6Address
    let destinationIPAddress: IPv6Address
    var payload: Data? = nil

    // FIXME - support IPv6
    init?(data: Data)
    {
        var maybePair = data.splitOn(position: 4)
        if maybePair == nil
        {
            return nil
        }
        
        var (head, tail) = maybePair!
        
        (version, trafficClass, flowLabel) = splitBitFields(head.uint32, 4, 8)
        
        maybePair = data.splitOn(position: 2)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!

        payloadLength = head.uint16
        
        maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        nextHeader = head.uint8

        maybePair = data.splitOn(position: 1)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        hopLimit = head.uint8
        
        maybePair = data.splitOn(position: 16)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        let maybeSourceIPAddress = IPv6Address(data: head)
        if maybeSourceIPAddress == nil
        {
            return nil
        }
        
        sourceIPAddress = maybeSourceIPAddress!
        
        maybePair = data.splitOn(position: 4)
        if maybePair == nil
        {
            return nil
        }
        
        (head, tail) = maybePair!
        
        let maybeDestinationIPAddress = IPv6Address(data: head)
        if maybeDestinationIPAddress == nil
        {
            return nil
        }
        destinationIPAddress = maybeDestinationIPAddress!
        
        if payloadLength > 0
        {
            maybePair = data.splitOn(position: UInt(payloadLength))
            if maybePair == nil
            {
                return nil
            }
            
            (head, tail) = maybePair!
            
            payload = head
        }
    }
}

func splitBits(byte: UInt8, leftSize: Int) -> (UInt8, UInt8)
{
    let rightSize = 8 - leftSize
    
    let left = byte >> rightSize
    let right = (byte << rightSize) >> rightSize
    
    return (left, right)
}

func splitBits(integer: UInt16, leftSize: Int) -> (UInt8, UInt16)
{
    let rightSize = 8 - leftSize
    
    let left = UInt8(integer >> rightSize)
    let right = (integer << rightSize) >> rightSize
    
    return (left, right)
}

func splitBitFields(_ integer: UInt32, _ leftSize: Int, _ middleSize: Int) -> (UInt8, UInt8, UInt32)
{
    let rightSize = 32 - (leftSize + middleSize)

    let left = UInt8(integer >> (middleSize + rightSize))
    let middle = UInt8((integer << leftSize) >> (leftSize + rightSize))
    let right = (integer << (leftSize + middleSize)) >> (leftSize + middleSize)
    
    return (left, middle, right)
}

func splitNibbles(byte: UInt8) -> (UInt8, UInt8)
{
    let left = byte >> 4
    let right = (byte << 4) >> 4
    
    return (left, right)
}
