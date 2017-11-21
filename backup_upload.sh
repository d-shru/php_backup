#!/bin/sh

sourceDir="/home/bitrix/www/upload"

backupDir="/mnt/backup_ext/egi/bitrix"

data=`/bin/date +%Y.%m.%d`

function randString ()
{
	local randLength
	if [ $1 ]; then
		randLength=$1
	else
		randLength=8
	fi
	rndStr=</dev/urandom tr -dc A-Za-z0-9 | head -c $randLength
	echo $rndStr
}

randFName=`randString`

tar -cf "${backupDir}/www_backup_${data}_upload_${randFName}.tar" -C ${sourceDir} --exclude-from=/home/bitrix/backup/scripts/ex_upload.txt .

