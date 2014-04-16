#!/usr/bin/env bash

die () {
    echo -e >&2 "$@"
    exit 1
}

################
#Some constants
#

DEBUG=${1:-0}
WEBSERVER="root@127.0.0.1"
SSHPORT=2222
HOMEDIR="/root"

################
#Main
#

#Default to stderr
output="1>&2"

[ "0" = $DEBUG ] && output="/dev/null"

echo "========================="
echo "Building package..."
echo "========================="

eval "debuild --no-lintian -us -uc > \$output"

printf "\n"
echo "========================="
echo "Uploading to server..."
echo "========================="

debianPackage=$(basename $(find ../ -iname "webvalidation*.deb"))
echo "Upload $debianPackage to ${WEBSERVER}"

scp -P $SSHPORT ../${debianPackage} ${WEBSERVER}:$HOMEDIR

[ "0" = "$?" ] || die "Fail to upload package!"

printf "\n"
echo "========================="
echo "Installing package..."
echo "========================="

ssh -p $SSHPORT ${WEBSERVER} "sudo dpkg -i $debianPackage"

[ "0" = "$?" ] || die "Fail to install package!"

printf "\n"
echo "========================="
echo "Restarting apache..."
echo "========================="

ssh -p $SSHPORT ${WEBSERVER} 'sudo /etc/init.d/apache2 restart'

[ "0" = "$?" ] || die "Fail to restart apache!"

