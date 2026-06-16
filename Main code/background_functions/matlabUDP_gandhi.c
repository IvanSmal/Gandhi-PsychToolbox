/* matlabUDP_gandhi.C
 *
 *  C MEX routines for fast UDP communication from MATLAB.
 *
 *  Original code by Ben Heasly (Josh Gold lab, UPenn, ~2006).
 *  Modified by Ryan Williamson (Smith Lab) for multi-socket support.
 *  Further fixes:
 *    - MAX_SOCKETS increased to 10 (in header)
 *    - SO_REUSEADDR set on every socket so ports can be rebound immediately
 *      after close without waiting for OS timeout (fixes "locked socket" issue)
 *    - socklen_t used correctly for recvfrom (was int, caused silent truncation
 *      on some platforms)
 *    - mexAtExit handler registered so all sockets are closed cleanly when
 *      the MEX is cleared (mex clear) or MATLAB exits — no more restart needed
 *    - strncmp lengths fixed to match full command strings, preventing
 *      accidental prefix collisions (e.g. "all_close" vs "close")
 *    - nextSocket() now returns -1 and errors properly if all slots are full
 *    - 'closeall' command added as alias for closing every open socket
 *    - MAX_NUM_BYTES raised to 65507 (true UDP max payload)
 *
 *  Usage from MATLAB:
 *    socketindex = matlabUDP2('open', localIP, remoteIP, port)
 *    matlabUDP2('send',     socketindex, message)
 *    available   = matlabUDP2('check',    socketindex)
 *    message     = matlabUDP2('receive',  socketindex)
 *    matlabUDP2('close',    socketindex)
 *    matlabUDP2('closeall')
 */

#include "matlabUDP_gandhi.h"

/* -----------------------------------------------------------------------
 * mexAtExit handler — called when MEX is cleared or MATLAB shuts down.
 * Closes all open sockets so the ports are released immediately.
 * ----------------------------------------------------------------------- */
static void mat_UDP_exit_handler(void)
{
    mat_UDP_close_all();
}

/* -----------------------------------------------------------------------
 * mexFunction — entry point called by MATLAB
 * ----------------------------------------------------------------------- */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    char *command = NULL;
    int   buf_len;
    int   socketindex;

    /* Register cleanup handler once per MEX load */
    mexAtExit(mat_UDP_exit_handler);

    /* No arguments: print usage */
    if (nrhs < 1) {
        mexPrintf(
            "matlabUDP2 usage:\n"
            "  idx = matlabUDP2('open',     localIP, remoteIP, port)\n"
            "  matlabUDP2('send',     idx, message)\n"
            "  avail = matlabUDP2('check',    idx)\n"
            "  msg   = matlabUDP2('receive',  idx)\n"
            "  matlabUDP2('close',    idx)\n"
            "  matlabUDP2('closeall')\n"
        );
        return;
    }

    /* First argument must be a command string */
    if (!mxIsChar(prhs[0]) || mxGetM(prhs[0]) != 1 || mxGetN(prhs[0]) < 1) {
        mexErrMsgTxt("matlabUDP2: First argument must be a command string.");
    }
    buf_len = (int)mxGetN(prhs[0]) + 1;
    command = mxCalloc(buf_len, sizeof(char));
    if (mxGetString(prhs[0], command, buf_len))
        mexWarnMsgTxt("matlabUDP2: Command string truncated.");

    /* ------------------------------------------------------------------ */
    /* OPEN                                                                 */
    /* ------------------------------------------------------------------ */
    if (!strcmp(command, "open")) {
        mxFree(command);

        if (nrhs != 4
            || !mxIsChar(prhs[1]) || mxGetN(prhs[1]) > 15
            || !mxIsChar(prhs[2]) || mxGetN(prhs[2]) > 15
            || !mxIsNumeric(prhs[3])) {
            mexErrMsgTxt("matlabUDP2 open: usage: matlabUDP2('open', localIP, remoteIP, port)");
        }

        char local[16], remote[16];
        mxGetString(prhs[1], local,  16);
        mxGetString(prhs[2], remote, 16);

        socketindex = mat_UDP_open(local, remote, (int)mxGetScalar(prhs[3]));

        if (!(plhs[0] = mxCreateDoubleScalar((double)socketindex)))
            mexErrMsgTxt("matlabUDP2: mxCreateDoubleScalar failed.");

    /* ------------------------------------------------------------------ */
    /* SEND                                                                 */
    /* ------------------------------------------------------------------ */
    } else if (!strcmp(command, "send")) {
        mxFree(command);

        if (nrhs != 3 || !mxIsNumeric(prhs[1]))
            mexErrMsgTxt("matlabUDP2 send: usage: matlabUDP2('send', idx, message)");

        socketindex = (int)mxGetScalar(prhs[1]);
        if (socketindex < 0 || socketindex >= MAX_SOCKETS)
            mexErrMsgTxt("matlabUDP2 send: socket index out of range.");

        if (mat_UDP_sockfd[socketindex] < 0) {
            mexWarnMsgTxt("matlabUDP2 send: socket is not open.");
            return;
        }

        if (!mxIsChar(prhs[2]) && !mxIsUint8(prhs[2]))
            mexErrMsgTxt("matlabUDP2 send: message must be a char or uint8 array.");
        if (mxGetM(prhs[2]) != 1 || mxGetN(prhs[2]) == 0)
            mexErrMsgTxt("matlabUDP2 send: message must be a 1-by-N non-empty array.");

        int msgLen = (int)mxGetN(prhs[2]);
        if (msgLen > MAX_NUM_BYTES)
            mexErrMsgTxt("matlabUDP2 send: message exceeds MAX_NUM_BYTES.");

        if (mxIsUint8(prhs[2])) {
            unsigned char *src = (unsigned char *)mxGetUint8s(prhs[2]);
            memcpy(&mat_UDP_messBuff[socketindex][0], src, msgLen);
        } else {
            mxGetString(prhs[2], (char *)&mat_UDP_messBuff[socketindex][0], msgLen + 1);
        }

        mat_UDP_send(socketindex, (char *)&mat_UDP_messBuff[socketindex][0], msgLen);

    /* ------------------------------------------------------------------ */
    /* RECEIVE                                                              */
    /* ------------------------------------------------------------------ */
    } else if (!strcmp(command, "receive")) {
        mxFree(command);

        if (nrhs < 2 || !mxIsNumeric(prhs[1]))
            mexErrMsgTxt("matlabUDP2 receive: usage: matlabUDP2('receive', idx)");

        socketindex = (int)mxGetScalar(prhs[1]);
        if (socketindex < 0 || socketindex >= MAX_SOCKETS)
            mexErrMsgTxt("matlabUDP2 receive: socket index out of range.");

        int nBytes = 0;
        if (mat_UDP_sockfd[socketindex] >= 0) {
            mat_UDP_read(socketindex,
                         (char *)&mat_UDP_messBuff[socketindex][0],
                         MAX_NUM_BYTES);
            nBytes = mat_UDP_numBytes[socketindex];
        }

        mwSize dims[2] = {1, (mwSize)nBytes};
        if (!(plhs[0] = mxCreateCharArray(2, dims)))
            mexErrMsgTxt("matlabUDP2 receive: mxCreateCharArray failed.");

        unsigned short *outPtr = (unsigned short *)mxGetData(plhs[0]);
        for (int i = nBytes - 1; i >= 0; i--)
            outPtr[i] = (unsigned short)mat_UDP_messBuff[socketindex][i];

    /* ------------------------------------------------------------------ */
    /* CHECK                                                                */
    /* ------------------------------------------------------------------ */
    } else if (!strcmp(command, "check")) {
        mxFree(command);

        if (nrhs < 2 || !mxIsNumeric(prhs[1]))
            mexErrMsgTxt("matlabUDP2 check: usage: matlabUDP2('check', idx)");

        socketindex = (int)mxGetScalar(prhs[1]);
        if (socketindex < 0 || socketindex >= MAX_SOCKETS)
            mexErrMsgTxt("matlabUDP2 check: socket index out of range.");

        double result = (mat_UDP_sockfd[socketindex] >= 0)
                        ? (double)mat_UDP_check(socketindex)
                        : 0.0;

        if (!(plhs[0] = mxCreateDoubleScalar(result)))
            mexErrMsgTxt("matlabUDP2 check: mxCreateDoubleScalar failed.");

    /* ------------------------------------------------------------------ */
    /* CLOSE (single socket)                                                */
    /* ------------------------------------------------------------------ */
    } else if (!strcmp(command, "close")) {
        mxFree(command);

        if (nrhs < 2 || !mxIsNumeric(prhs[1]))
            mexErrMsgTxt("matlabUDP2 close: usage: matlabUDP2('close', idx)");

        socketindex = (int)mxGetScalar(prhs[1]);
        if (socketindex < 0 || socketindex >= MAX_SOCKETS)
            mexErrMsgTxt("matlabUDP2 close: socket index out of range.");

        mat_UDP_close(socketindex);

        if (nlhs == 1) {
            if (!(plhs[0] = mxCreateDoubleScalar((double)mat_UDP_sockfd[socketindex])))
                mexErrMsgTxt("matlabUDP2 close: mxCreateDoubleScalar failed.");
        }

    /* ------------------------------------------------------------------ */
    /* CLOSEALL — close every open socket                                   */
    /* ------------------------------------------------------------------ */
    } else if (!strcmp(command, "closeall")) {
        mxFree(command);
        mat_UDP_close_all();

    /* ------------------------------------------------------------------ */
    /* Unknown command                                                      */
    /* ------------------------------------------------------------------ */
    } else {
        mxFree(command);
        mexWarnMsgTxt("matlabUDP2: Unknown command. Valid: open, send, receive, check, close, closeall");
    }
}

/* -----------------------------------------------------------------------
 * mat_UDP_open — create and bind a UDP socket
 * Returns socket slot index, or errors out via mexErrMsgTxt.
 * SO_REUSEADDR is set so the port can be rebound immediately after close.
 * ----------------------------------------------------------------------- */
int mat_UDP_open(char localIP[], char remoteIP[], int port)
{
    int sockind = nextSocket();   /* errors via mexErrMsgTxt if full */

    /* Remote address (where we send to) */
    memset(&mat_UDP_REMOTE_addr[sockind], 0, sizeof(struct sockaddr_in));
    mat_UDP_REMOTE_addr[sockind].sin_family      = AF_INET;
    mat_UDP_REMOTE_addr[sockind].sin_port        = htons(port);
    mat_UDP_REMOTE_addr[sockind].sin_addr.s_addr = inet_addr(remoteIP);

    /* Local address (what we bind to) */
    memset(&mat_UDP_LOCAL_addr[sockind], 0, sizeof(struct sockaddr_in));
    mat_UDP_LOCAL_addr[sockind].sin_family      = AF_INET;
    mat_UDP_LOCAL_addr[sockind].sin_port        = htons(port);
    mat_UDP_LOCAL_addr[sockind].sin_addr.s_addr = inet_addr(localIP);

    /* Create socket */
    mat_UDP_sockfd[sockind] = socket(AF_INET, SOCK_DGRAM, 0);
    if (mat_UDP_sockfd[sockind] == -1)
        mexErrMsgTxt("matlabUDP2 open: Could not create UDP socket.");

    /* SO_REUSEADDR: allows immediate rebind after close without OS timeout */
    int opt = 1;
    if (setsockopt(mat_UDP_sockfd[sockind], SOL_SOCKET, SO_REUSEADDR,
                   &opt, sizeof(opt)) == -1) {
        close(mat_UDP_sockfd[sockind]);
        mat_UDP_sockfd[sockind] = -1;
        mexErrMsgTxt("matlabUDP2 open: setsockopt(SO_REUSEADDR) failed.");
    }

    /* Bind */
    if (bind(mat_UDP_sockfd[sockind],
             (struct sockaddr *)&mat_UDP_LOCAL_addr[sockind],
             sizeof(struct sockaddr_in)) == -1) {
        close(mat_UDP_sockfd[sockind]);
        mat_UDP_sockfd[sockind] = -1;
        mexErrMsgTxt("matlabUDP2 open: Could not bind socket. Port already in use or invalid local IP?");
    }

    mexPrintf("matlabUDP2: opened socket %d  local=%s:%d  remote=%s:%d\n",
              sockind, localIP, port, remoteIP, port);

    return sockind;
}

/* -----------------------------------------------------------------------
 * mat_UDP_send — send a datagram (non-blocking)
 * ----------------------------------------------------------------------- */
void mat_UDP_send(int sockind, char mBuff[], int mLen)
{
    int sent = (int)sendto(mat_UDP_sockfd[sockind], mBuff, mLen, MSG_DONTWAIT,
                           (struct sockaddr *)&mat_UDP_REMOTE_addr[sockind],
                           sizeof(struct sockaddr_in));
    if (sent == -1)
        mexWarnMsgTxt("matlabUDP2 send: sendto failed. Are the machines connected?");
}

/* -----------------------------------------------------------------------
 * mat_UDP_check — non-blocking poll: is a datagram waiting?
 * Returns 1 if data available, 0 otherwise.
 * ----------------------------------------------------------------------- */
int mat_UDP_check(int sockind)
{
    struct timeval timeout = {0, 0};  /* zero timeout = instant poll */
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(mat_UDP_sockfd[sockind], &readfds);
    select(mat_UDP_sockfd[sockind] + 1, &readfds, NULL, NULL, &timeout);
    return FD_ISSET(mat_UDP_sockfd[sockind], &readfds) ? 1 : 0;
}

/* -----------------------------------------------------------------------
 * mat_UDP_read — receive one datagram (non-blocking)
 * Sets mat_UDP_numBytes[sockind] to number of bytes actually received.
 * ----------------------------------------------------------------------- */
void mat_UDP_read(int sockind, char mBuff[], int messUpToLen)
{
    socklen_t addrLen = sizeof(struct sockaddr_in);
    int n = (int)recvfrom(mat_UDP_sockfd[sockind], mBuff, messUpToLen,
                          MSG_DONTWAIT,
                          (struct sockaddr *)&mat_UDP_REMOTE_addr[sockind],
                          &addrLen);
    mat_UDP_numBytes[sockind] = (n < 0) ? 0 : n;
}

/* -----------------------------------------------------------------------
 * mat_UDP_close — close one socket and mark its slot free
 * SO_REUSEADDR means the port is immediately available for rebinding.
 * ----------------------------------------------------------------------- */
void mat_UDP_close(int sockind)
{
    if (sockind < 0 || sockind >= MAX_SOCKETS) return;
    if (mat_UDP_sockfd[sockind] >= 0) {
        mexPrintf("matlabUDP2: closing socket %d\n", sockind);
        close(mat_UDP_sockfd[sockind]);
        mat_UDP_sockfd[sockind] = -1;
        mat_UDP_numBytes[sockind] = 0;
    }
}

/* -----------------------------------------------------------------------
 * mat_UDP_close_all — close every open socket
 * Called by the mexAtExit handler and by the 'closeall' command.
 * ----------------------------------------------------------------------- */
void mat_UDP_close_all(void)
{
    int i;
    for (i = 0; i < MAX_SOCKETS; i++)
        mat_UDP_close(i);
}

/* -----------------------------------------------------------------------
 * nextSocket — find the first free socket slot
 * Returns slot index, or calls mexErrMsgTxt if all slots are full.
 * ----------------------------------------------------------------------- */
int nextSocket(void)
{
    int n;
    for (n = 0; n < MAX_SOCKETS; n++) {
        if (mat_UDP_sockfd[n] == -1)
            return n;
    }
    mexErrMsgTxt("matlabUDP2 open: All socket slots are in use (MAX_SOCKETS reached).");
    return -1;  /* unreachable, but satisfies the compiler */
}