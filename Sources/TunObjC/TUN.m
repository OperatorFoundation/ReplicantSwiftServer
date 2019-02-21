//
//  TUN.m
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

#import "include/TUN.h"
#import "../TunC/include/TunC.h"
#import <net/if_utun.h>
#include <netinet/in.h>
#include <net/if.h>
#include <sys/ioctl.h>

@implementation TUN

+ (int)connectControl: (int) socket
{
    return connectControl(socket);
}

+ (int)nameOption
{
    return getNameOption();
}

+ (BOOL)setAddress: (NSString *) interfaceName withAddress: (NSString *) addressString
{
    struct in_addr address;
    
    if (inet_pton(AF_INET, [addressString UTF8String], &address) == 1) {
        struct ifaliasreq interfaceAliasRequest __attribute__ ((aligned (4)));
        struct in_addr mask = { 0xffffffff };
        int socketDescriptor = socket(AF_INET, SOCK_DGRAM, 0);
        
        if (socketDescriptor < 0) {
            printf("Failed to create a DGRAM socket: %s\n", strerror(errno));
            return NO;
        }
        
        memset(&interfaceAliasRequest, 0, sizeof(interfaceAliasRequest));
        
        strlcpy(interfaceAliasRequest.ifra_name, [interfaceName UTF8String], sizeof(interfaceAliasRequest.ifra_name));
        
        interfaceAliasRequest.ifra_addr.sa_family = AF_INET;
        interfaceAliasRequest.ifra_addr.sa_len = sizeof(struct sockaddr_in);
        memcpy(&((struct sockaddr_in *)&interfaceAliasRequest.ifra_addr)->sin_addr, &address, sizeof(address));
        
        interfaceAliasRequest.ifra_broadaddr.sa_family = AF_INET;
        interfaceAliasRequest.ifra_broadaddr.sa_len = sizeof(struct sockaddr_in);
        memcpy(&((struct sockaddr_in *)&interfaceAliasRequest.ifra_broadaddr)->sin_addr, &address, sizeof(address));
        
        interfaceAliasRequest.ifra_mask.sa_family = AF_INET;
        interfaceAliasRequest.ifra_mask.sa_len = sizeof(struct sockaddr_in);
        memcpy(&((struct sockaddr_in *)&interfaceAliasRequest.ifra_mask)->sin_addr, &mask, sizeof(mask));
        
        if (ioctl(socketDescriptor, SIOCAIFADDR, &interfaceAliasRequest) < 0) {
            printf("Failed to set the address of %s interface address to %s: %s\n", [interfaceName UTF8String], [addressString UTF8String], strerror(errno));
            close(socketDescriptor);
            return NO;
        }
        
        close(socketDescriptor);
    }
    
    return YES;
}

@end
