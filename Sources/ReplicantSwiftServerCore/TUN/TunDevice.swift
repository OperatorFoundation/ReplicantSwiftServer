//
//  TunDevice.swift
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

import Foundation
import TunObjC
import Datable

struct TunDevice
{
    var name: String! = nil
    var tun: Int32!
    
    public init?(address: String)
    {
        guard let fd = createInterface() else
        {
            return nil
        }
        
        tun = fd
        
        guard let ifname = getInterfaceName(fd: fd) else
        {
            return nil
        }
        
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
        guard result > 0 else
        {
            print("Failed to connect to TUN control socket")
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
        return true
    }
    
    func startTunnel(fd: Int32)
    {
        
    }
    
    func writeV4(_ packet: Data)
    {
        var protocolNumber: UInt32 = 4
        DatableConfig.endianess = .big
        var protocolNumberBuffer = protocolNumber.data
        var buffer = Data(packet)
        var iovecList =
        [
            iovec(iov_base: &protocolNumberBuffer, iov_len: 4),
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
        var protocolNumber: UInt32 = 6
        DatableConfig.endianess = .big
        var protocolNumberBuffer = protocolNumber.data
        var buffer = Data(packet)
        var iovecList =
            [
                iovec(iov_base: &protocolNumberBuffer, iov_len: 4),
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
        var buffer = Data(count: packetSize)
        var protocolNumberBuffer = Data(count: 4)
        
        var iovecList =
        [
            iovec(iov_base: &protocolNumberBuffer, iov_len: 4),
            iovec(iov_base: &buffer, iov_len: buffer.count)
        ]
        
        while true
        {
            let readCount = readv(tun, &iovecList, Int32(4+buffer.count))

            if errno == EAGAIN
            {
                continue
            }
            
            guard readCount > 0 else
            {
                let errorString = String(cString: strerror(errno))
                print("Got an error while reading from utun: \(errorString)")
                return nil
            }
            
            guard readCount > 4 else
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
