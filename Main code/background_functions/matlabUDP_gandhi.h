/* MATLABUDP2.H
 *
 *  Header file for matlabUDP2.c
 *
 *  Original code by Ben Heasly (Josh Gold lab, UPenn, ~2006).
 *  Modified by Ryan Williamson (Smith Lab) for multi-socket support.
 *  Further modified: increased to 10 sockets, added SO_REUSEADDR,
 *  fixed socklen_t type, added mexAtExit cleanup, fixed strncmp lengths,
 *  added nextSocket() error return.
 */

#ifndef MATLABUDP2_H_
#define MATLABUDP2_H_

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/time.h>

#include "mex.h"

#define MAX_NUM_BYTES 65507   /* max UDP payload */
#define MAX_SOCKETS   10      /* update mat_UDP_sockfd initializer if changed */

/* Globals for UDP sockets */
static int mat_UDP_sockfd[MAX_SOCKETS] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};

static int mat_UDP_numBytes[MAX_SOCKETS];

static unsigned char mat_UDP_messBuff[MAX_SOCKETS][MAX_NUM_BYTES];

static struct sockaddr_in mat_UDP_LOCAL_addr[MAX_SOCKETS];
static struct sockaddr_in mat_UDP_REMOTE_addr[MAX_SOCKETS];

/* Function declarations */
int  mat_UDP_open  (char*, char*, int);
void mat_UDP_send  (int, char*, int);
int  mat_UDP_check (int);
void mat_UDP_read  (int, char*, int);
void mat_UDP_close (int);
int  nextSocket    (void);
void mat_UDP_close_all (void);

void mexFunction(
    int            nlhs,
    mxArray       *plhs[],
    int            nrhs,
    const mxArray *prhs[]
);

#endif /* MATLABUDP2_H_ */