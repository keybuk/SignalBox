//
//  mailbox.c
//  SignalBox
//
//  Created by Scott James Remnant on 12/21/16.
//
//

#include <sys/ioctl.h>

#ifdef __linux__
#include <linux/ioctl.h>

#define MAJOR_NUM 100
#define IOCTL_MBOX_PROPERTY _IOWR(MAJOR_NUM, 0, char *)
#else
#define IOCTL_MBOX_PROPERTY 0
#endif


#include "mailbox.h"

int MailboxProperty(int fd, const unsigned int * _Nonnull buffer) {
    return ioctl(fd, IOCTL_MBOX_PROPERTY, buffer);
}
