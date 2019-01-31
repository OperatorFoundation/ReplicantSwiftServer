//
//  TUN.m
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

#import "include/TUN.h"
#import "../TunC/include/TunC.h"

@implementation TUN

+ (int)connectControl: (int) socket
{
    return connectControl(socket);
}

+ (int)nameOption
{
    return getNameOption();
}

@end
