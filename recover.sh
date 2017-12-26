#!/bin/sh

# проверяем, установлен ли wget и если нет, то ставим его
TPKG=$(rpm -qa | grep wget)

if [ -n "$TPKG" ]; then 
        echo "wget already installed"
    else
        yum install wget
    fi
    
# качаем установщик bitrix окружения
test ! -f /root/bitrix-env.sh && {
    wget http://repos.1c-bitrix.ru/yum/bitrix-env.sh ;
    chown -R bitrix:bitrix ./bitrix-env.sh ;
    chmod +x bitrix-env.sh ;
}

BFILE='/root/bitrix-env.sh'

# включаем репозитарий php56
sed -i 's/Disable php56 repository/Enable php56 repository/' $BFILE
sed -i '/php56_conf$/s/\/enabled=1\/enabled=0\//\/enabled=0\/enabled=1\//' $BFILE

sed -i 's/Enable php70 repository/Disable php70 repository/' $BFILE
sed -i '/php70_conf$/s/\/enabled=0\/enabled=1\//\/enabled=1\/enabled=0\//' $BFILE

echo "bitrix-env.sh was changed"

# попытка сделать однократный запуск скрипта после перезагрузки (после удаления sellinux)
#echo "/root/bitrix-env.sh" >> /root/.bash_profile

#запускаем установщик
./bitrix-env.sh

# очистка
#sed -i '/\/root\/bitrix-env\.sh/d' /root/.bash_profile

# вытаскиваем данные для подключения к БД из dbconn.php
DBFILE='/home/bitrix/www/bitrix/php_interface/dbconn.php'
SETFILE='/home/bitrix/www/bitrix/.settings.php'

SQLUSER=$(grep 'DBLogin' $DBFILE | cut -d '"' -f2)
SQLDB=$(grep 'DBName' $DBFILE | cut -d '"' -f2)
SQLPASS=$(grep 'DBPassword' $DBFILE | cut -d '"' -f2)

# монтируем диск с бекапами
mount /dev/sdb1 /mnt
cd /mnt

# выбираем самый новый файл
NEWFILE=$(ls -t | grep main | head -1)

# распаковываем веб-окружение
tar -xvzf $NEWFILE -C /home/bitrix/www

# повторно вытаскиваем данные для подключения к БД из dbconn.php для последующей замены
NEWDBFILE='/home/bitrix/www/bitrix/php_interface/dbconn.php'
NEWSETFILE='/home/bitrix/www/bitrix/.settings.php'

NEWSQLUSER=$(grep 'DBLogin' $NEWDBFILE | cut -d '"' -f2)
NEWSQLDB=$(grep 'DBName' $NEWDBFILE | cut -d '"' -f2)
NEWSQLPASS=$(grep 'DBPassword' $NEWDBFILE | cut -d '"' -f2)

# замена в /home/bitrix/www/bitrix/.settings.php на данные из бекапа
sed -i '/className/s/MysqlConnection/MysqliConnection/' $NEWSETFILE
sed -i '/database/s/'"$SQLDB1"'/'"$SQLDB"'/' $NEWSETFILE
sed -i "/login/s/$NEWSQLUSER/$SQLUSER/" $NEWSETFILE
sed -i '/password/s/'"$SQLPASS1"'/'"$SQLPASS"'/' $NEWSETFILE

sed -i '/?>/i define(\"BX_USE_MYSQLI\", true);' $NEWDBFILE

#замена в /home/bitrix/www/bitrix/php_interface/dbconn.php на данные из бекапа
sed -i "/DBName/s/$NEWSQLDB/$SQLDB/" $NEWDBFILE
sed -i "/DBLogin/s/$NEWSQLUSER/$SQLUSER/" $NEWDBFILE
sed -i '/DBPassword /s/'"$NEWSQLPASS"'/'"$SQLPASS"'/' $NEWDBFILE

cd /home/bitrix/www/bitrix/backup/

# выбираеем самый новый дамп базы и делаем импорт
SQLFILE=$(ls -t | grep dump | head -1)
mysql -u $SQLUSER -p$SQLPASS $SQLDB < /home/bitrix/www/bitrix/backup/$SQLFILE
