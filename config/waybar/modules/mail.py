#!/usr/bin/python3

import os
import imaplib


def getmails(username, password, server):
    imap = imaplib.IMAP4_SSL(server, 993)
    imap.login(username, password)
    imap.select('INBOX')
    ustatus, uresponse = imap.uid('search', None, 'UNSEEN')
    if ustatus == 'OK':
        unread_msg_nums = uresponse[0].split()
    else:
        unread_msg_nums = []

    fstatus, fresponse = imap.uid('search', None, 'FLAGGED')
    if fstatus == 'OK':
        flagged_msg_nums = fresponse[0].split()
    else:
        flagged_msg_nums = []

    return [len(unread_msg_nums), len(flagged_msg_nums)]

ping = os.system("ping " + 'imap.gmail.com' + " -c1 > /dev/null 2>&1")
if ping == 0:
    mails = getmails('alicanbardakci@gmail.com', 'Jeepogo132963', 'imap.gmail.com')
    text = ''
    alt = ''

    if mails[0] > 0:
        text = alt = str(mails[0])
        if mails[1] > 0:
            alt = str(mails[1]) + "  " + alt
    else:
        print('asd')
        exit(1)

    print('{"text":"' + text + '", "alt": "' + text + '"}')

else:
    print(ping)
    exit(1)
