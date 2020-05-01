//
//  TUN.c
//  ReplicantSwiftServerCore
//
//  Created by Dr. Brandon Wiley on 1/29/19.
//

#import "include/TunC.h"

int connectControl(int socket)
{
    struct ctl_info kernelControlInfo;
    
    bzero(&kernelControlInfo, sizeof(kernelControlInfo));
    strlcpy(kernelControlInfo.ctl_name, UTUN_CONTROL_NAME, sizeof(kernelControlInfo.ctl_name));
    
    if (ioctl(socket, CTLIOCGINFO, &kernelControlInfo))
    {
        printf("ioctl failed on kernel control socket: %s\n", strerror(errno));
        return 0;
    }
    
    // uses CTLIOCGINFO ioctl to translate from a kernel control name to a control id.
    unsigned int controlIdentifier = kernelControlInfo.ctl_id;
    
    if(controlIdentifier <= 0)
    {
        return -1;
    }
    
    struct sockaddr_ctl *control = malloc(sizeof(struct sockaddr_ctl));
    control->sc_len=sizeof(struct sockaddr_ctl);
    control->sc_family=AF_SYSTEM;
    control->ss_sysaddr=AF_SYS_CONTROL;
    control->sc_id=controlIdentifier;
    control->sc_unit=0;
    
    int connectResult = connect(socket, (struct sockaddr *)control, sizeof(struct sockaddr_ctl));
    
    return connectResult;
}

int getNameOption(void)
{
    return UTUN_OPT_IFNAME;
}
