#!/bin/sh
# https://android.stackexchange.com/questions/63252/how-do-i-back-up-google-authenticator#86861
# https://github.com/tadfisher/pass-otp/wiki/How-to-migrate-your-Google-Authenticator-database-to-pass-otp%3F

# Database path: /data/data/com.google.android.apps.authenticator2/databases/databases
#
#sqlite> .schema accounts
#CREATE TABLE accounts (_id INTEGER PRIMARY KEY, email TEXT NOT NULL, secret TEXT NOT NULL, counter INTEGER DEFAULT 0, type INTEGER, provider INTEGER DEFAULT 0, issuer TEXT DEFAULT NULL, original_name TEXT DEFAULT NULL);

# The idea is to extract and convert this:
#$ sqlite3 -batch ~/tmp/foo "select * from accounts;"
#2|Google:johndoe@example.com|SECRET|0|0|0|Google|Google:johndoe@example.com
#
# To this:
#otpauth://totp/johndoe@example.com@Google?secret=SECRET&issuer=Google

extract_secrets() {
    if [ -e ./databases ]; then
        echo >&2 "./databases file exists already. Abort..."
        return 1
    fi

    # Retrieve the database file
    if [ -z "$ANDROID_PATH" ]; then
        adb shell su -c 'cp /data/data/com.google.android.apps.authenticator2/databases/databases /sdcard/'
        adb pull /sdcard/databases ./
        adb shell rm -v /sdcard/databases
    else
        cd /sdcard
        su -c 'cp /data/data/com.google.android.apps.authenticator2/databases/databases /sdcard/'
    fi

    # Extract secrets
    SQLITE_RUN="sqlite3 -batch ./databases"

    for id in $($SQLITE_RUN "select _id from accounts;"); do
        email=$($SQLITE_RUN "select email from accounts where _id=$id")
        secret=$($SQLITE_RUN "select secret from accounts where _id=$id")
        issuer=$($SQLITE_RUN "select issuer from accounts where _id=$id")
        echo "otpauth://totp/${email}?secret=${secret}&issuer=${issuer}"
    done

    # Cleanup
    rm -v ./databases
}

# Main
extract_secrets
