#!/bin/sh

dbsettings=`php -f /home/bitrix/backup/scripts/get_mysql_settings.php`
// далее выдёргиваются из get_mysql_settings.php параметры для подключения к БД и ???
iCnt=0;
for settings in $dbsettings
do
	arSettings[$iCnt]=$settings;
	let "iCnt++"; //не совсем ясно зачем цикл? типа если одно из условий не выполняется, то выход? просто полдедовательно условия нельзя проверять?
done

i=0;
if [ "${arSettings[$i]}" != "mysql" ]; then //если база не mysql, то выходим
	exit;
fi

i=1;
mysqlHost=""
if [ "${arSettings[$i]}" != "localhost" ]; then
	mysqlHost="-h ${arSettings[$i]} ";
fi

i=2;
mysqlUser="${arSettings[$i]}";
if [ "$mysqlUser" = "" ]; then
	exit;
fi

i=3;
mysqlDB="${arSettings[$i]}";
if [ "$mysqlDB" = "" ]; then
	exit;
fi

i=4;
characterSet="${arSettings[$i]}";
if [ "$characterSet" = "" ]; then
	exit;
fi

i=5;
mysqlPassword=""
if [ "${arSettings[$i]}" != "" ]; then
	mysqlPassword="${arSettings[$i]}";
fi

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

extSite=
test -f /home/bitrix/backup/scripts/extsite.txt && { extSite=`cat /home/bitrix/backup/scripts/extsite.txt` ; } ;
test -z "$extSite" && { backupFolder="." ; } || { backupFolder=". $extSite" ; } ;

test ! -d /home/bitrix/www/bitrix/backup && {
	mkdir -p /home/bitrix/www/bitrix/backup ;
	echo "<head><meta http-equiv=\"REFRESH\" content=\"0;URL=/bitrix/admin/index.php\"></head>" > /home/bitrix/www/bitrix/backup/index.php ;
	chown -R bitrix:bitrix /home/bitrix/www/bitrix/backup ;
	chmod -R 0755 /home/bitrix/www/bitrix/backup ;
}

if [ "$mysqlPassword" = "" ]; then
    mysqldump --user=${mysqlUser} ${mysqlHost} --default-character-set=${characterSet} ${mysqlDB} > /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
else
    mysqldump --user=${mysqlUser} ${mysqlHost} -p${mysqlPassword} --default-character-set=${characterSet} ${mysqlDB} > /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
fi

test ! -d /home/bitrix/backup/archive && { mkdir -p /home/bitrix/backup/archive ; }

sed -i '//d' /etc/php.ini >/dev/null 2>&1

# Clean mysql log
sed -i "/\/*40101 SET/d" /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
sed -i "/\/*40103 SET/d" /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
sed -i "/\!40111 SET/d" /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
sed -i "/\!40014 SET/d" /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
sed -i "/\!40000 ALTER/d" /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql

if [ "$characterSet" == "cp1251" ]; then
	echo "SET NAMES 'cp1251' COLLATE 'cp1251_general_ci';" > /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}_after_connect.sql
else
	echo "SET NAMES 'utf8' COLLATE 'utf8_unicode_ci';" > /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}_after_connect.sql
fi

# remove backups older 1 day
find /mnt/backup_ext/rgm/bitrix -mtime +0 -exec rm {} \;

tar -cf /mnt/backup_ext/egi/bitrix/www_backup_${data}_main_${randFName}.tar --exclude-from=/home/bitrix/backup/scripts/ex_main.txt -C /home/bitrix/www $backupFolder
tar -rf /mnt/backup_ext/egi/bitrix/www_backup_${data}_main_${randFName}.tar -C /home/bitrix/www bitrix/backup/mysql_dump_${data}_${randFName}.sql
tar -rf /mnt/backup_ext/egi/bitrix/www_backup_${data}_main_${randFName}.tar -C /home/bitrix/www bitrix/backup/mysql_dump_${data}_${randFName}_after_connect.sql
tar -rf /mnt/backup_ext/egi/bitrix/www_backup_${data}_main_${randFName}.tar -C /home/bitrix/www upload/main

gzip /mnt/backup_ext/egi/bitrix/www_backup_${data}_main_${randFName}.tar

rm -f /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}.sql
rm -f /home/bitrix/www/bitrix/backup/mysql_dump_${data}_${randFName}_after_connect.sql

i=0;
