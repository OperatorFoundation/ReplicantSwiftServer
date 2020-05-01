//
//  TunDevice.swift
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

import Foundation
import TunObjC
import Datable
import Darwin.C

struct TunDevice
{
    static let protocolNumberSize = 4
    var name: String! = nil
    var tun: Int32!
    
    public init?(address: String)
    {
        guard let fd = createInterface() else
        {
            return nil
        }
        
        print("Created TUN interface \(fd)")
        
        tun = fd
        
        guard let ifname = getInterfaceName(fd: fd) else
        {
            return nil
        }
        
        print("TUN interface name \(ifname)")
        
        name = ifname
        
        guard setAddress(name: ifname, address: address) else
        {
            return nil
        }
        
        startTunnel(fd: fd)
    }

    /// Create a UTUN interface.
    func createInterface() -> Int32?
    {
        let fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL)
        guard fd >= 0 else
        {
            print("Failed to open TUN socket")
            return nil
        }
        
        let result = TunObjC.connectControl(fd)
        guard result == 0 else
        {
            print("Failed to connect to TUN control socket. Connect result: \(result)")
            close(fd)
            return nil
        }
        
        return fd
    }
    
    /// Get the name of a UTUN interface the associated socket.
    func getInterfaceName(fd: Int32) -> String?
    {
        let length = Int(IFNAMSIZ)
        var buffer = [Int8](repeating: 0, count: length)
        var bufferSize: socklen_t = socklen_t(length)
        let result = getsockopt(fd, SYSPROTO_CONTROL, TUN.nameOption(), &buffer, &bufferSize)
        
        guard result >= 0 else
        {
            let errorString = String(cString: strerror(errno))
            print("getsockopt failed while getting the utun interface name: \(errorString)")
            return nil
        }
        
        return String(cString: &buffer)
    }
    
    func setAddress(name: String, address: String) -> Bool
    {
        return TUN.setAddress(name, withAddress: address)
    }
    
    func startTunnel(fd: Int32)
    {
        
    }
    
    func writeV4(_ packet: Data)
    {
        var protocolNumber = AF_INET
        DatableConfig.endianess = .big
        var protocolNumberBuffer = protocolNumber.data
        var buffer = Data(packet)
        var iovecList =
        [
            iovec(iov_base: &protocolNumberBuffer, iov_len: TunDevice.protocolNumberSize),
            iovec(iov_base: &buffer, iov_len: packet.count)
        ]
        
        let writeCount = writev(tun, &iovecList, Int32(iovecList.count))
        if writeCount < 0
        {
            let errorString = String(cString: strerror(errno))
            print("Got an error while writing to utun: \(errorString)")
        }
    }

    func writeV6(_ packet: Data)
    {
        var protocolNumber = AF_INET6
        DatableConfig.endianess = .big
        var protocolNumberBuffer = protocolNumber.data
        var buffer = Data(packet)
        var iovecList =
            [
                iovec(iov_base: &protocolNumberBuffer, iov_len: TunDevice.protocolNumberSize),
                iovec(iov_base: &buffer, iov_len: packet.count)
        ]
        
        let writeCount = writev(tun, &iovecList, Int32(iovecList.count))
        if writeCount < 0
        {
            let errorString = String(cString: strerror(errno))
            print("Got an error while writing to utun: \(errorString)")
        }
    }
    
    func read(packetSize: Int) -> (Data, UInt32)?
    {
        print("\n📚  Read called on TUN device. 📚")
        print("Requested packet size is \(packetSize)\n")
        var buffer = Data(count: packetSize)
        var protocolNumberBuffer = Data(count: TunDevice.protocolNumberSize)
        
        var iovecList =
        [
            iovec(iov_base: &protocolNumberBuffer, iov_len: TunDevice.protocolNumberSize),
            iovec(iov_base: &buffer, iov_len: buffer.count)
        ]
        
        while true
        {
            let readCount = readv(tun, &iovecList, Int32(TunDevice.protocolNumberSize+buffer.count))

            if errno == EAGAIN
            {
                continue
            }
            
            guard readCount > 0 else
            {
                let errorString = String(cString: strerror(errno))
                print("Got an error while reading from utun: \(errorString)")
                print("readv(\(tun.debugDescription), , \(Int32(TunDevice.protocolNumberSize+buffer.count)))")
                print("\(TunDevice.protocolNumberSize) + \(buffer.count) = \(Int32(TunDevice.protocolNumberSize+buffer.count))")
                print("\(errno) ?= \(EINVAL)")
                
//                print("Trying read to debug readv failure...")
//                let rc = Darwin.read(tun, &protocolNumberBuffer, 4)
//                print("Done!")
//                print("read -> \(rc); \(errno)")
                
                return nil
            }
            
            guard readCount > TunDevice.protocolNumberSize else
            {
                print("Short read")
                return nil
            }

            DatableConfig.endianess = .big
            let protocolNumber=protocolNumberBuffer.uint32

            return (buffer, protocolNumber)
        }
    }
}
