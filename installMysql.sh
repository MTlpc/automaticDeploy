#!/bin/bash

# 导入AzkabanSQL
function importAzkabanSQL()
{
    sql=$1
    sqlInfoIsExists=`find /opt/frames -name $sql`
    if [[ ${#sqlInfoIsExists} -ne 0 ]];then
        #删除旧的
        azkaban_sql_home_old=`find /tmp -maxdepth 1 -name "*azkaban-sql*"`
        for i in $azkaban_sql_home_old;do
                rm -rf $i
        done
        # 创建安装目录
        mkdir /tmp/azkaban-sql
        # 解压Azkaban-SQL
        tar -zxvf $sqlInfoIsExists -C /tmp/azkaban-sql >& /dev/null
        echo "azkaban-sql压缩包解压完毕"
        sqlPath=`find /tmp/azkaban-sql/ -maxdepth 2 -name "*create-all-sql*"`
        # 导入SQL
        mysql  -uroot -e "drop database azkaban;"
        mysql  -uroot -e "create database azkaban;"
        mysql  -uroot -e "use azkaban;source $sqlPath;"
    fi
    echo "Azkaban SQL导入成功"
}

function installMysql()
{
    #1.在frames.txt中查看是否需要安装mysql
    mysqlInfo=`egrep "^mysql-rpm-pack" /home/hadoop/automaticDeploy/frames.txt`

    # 下载mysql
    # wget http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-community-server-5.7.28-1.el7.x86_64.rpm
    # wget http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-community-client-5.7.28-1.el7.x86_64.rpm
    # wget http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-community-libs-5.7.28-1.el7.x86_64.rpm
    # wget http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-community-common-5.7.28-1.el7.x86_64.rpm


     mysql=`echo $mysqlInfo | cut -d " " -f1`
     isInstall=`echo $mysqlInfo | cut -d " " -f2`
     installNode=`echo $mysqlInfo | cut -d " " -f3` 
     currentNode=`hostname`

    #是否安装
    if [[ $isInstall = "true" && $currentNode = $installNode ]];then

    #2.查看/opt/frames目录下是否有hadoop安装包
    mysqlIsExists=`find /opt/frames -name $mysql`
    echo $mysqlIsExists
    if [[ ${#mysqlIsExists} -ne 0  ]];then

        # 安装依赖
        yum install -y net-tools.x86_64，libaio.x86_64，perl.x86_64
        yum -y install numactl.x86_64

        yum remove mariadb-libs -y
        # yum install *.rpm -y

        rpm -ivh $mysqlIsExists/mysql-community-*

        # 字符集配置
        # echo "default-character-set=utf8" >> /etc/my.cnf
        echo "character-set-server=utf8" >> /etc/my.cnf

        # 启动Mysql
        systemctl start mysqld.service

        # 配置开机自启动
        systemctl enable mysqld

        # 防火墙配置
        systemctl start firewalld.service
        firewall-cmd --zone=public --add-port=3306/tcp --permanent
        # 配置立即生效
        firewall-cmd --reload

        # 安装expect用来自动交互，输入Mysql密码
        # yum install expect -y

        # 查找密码
        # grep 'temporary password' /var/log/mysqld.log
        export MYSQL_PWD=`sudo grep "A temporary password" /var/log/mysqld.log | awk '{print $NF}'`

        # 执行Mysql修改密码
        # select user,host,password, from mysql.user
        mysqlRootPasswd=`egrep "^mysql-root-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
        mysql --connect-expired-password -uroot -e "set password for root@localhost=password('$mysqlRootPasswd');"
        export MYSQL_PWD=$mysqlRootPasswd

        # 为root用户开通远程权限
        mysql --connect-expired-password -uroot -e "grant all privileges on *.* to 'root'@'%' identified by '$mysqlRootPasswd' with grant option;"
        mysql --connect-expired-password -uroot -e "flush privileges;"

        # mysql -uroot --default-character-set=utf8 -e "set password for root@localhost=password('Asddsadsa310*')" -p
        # mysql  -h IP -P端口 -u用户名 -p密码 mysql --default-character-set=utf8 -e "set password for root@localhost=password('$mysql_passwd')"
        # mysql  -h IP -P端口 -u用户名 -p密码 mysql --default-character-set=utf8 -e "set password for root@172.0.0.1=password('$mysql_passwd')"
        # mysql --connect-expired-password -uroot -pAsddsadsa310* -e "set password for root@172.0.0.1=password('Asddsadsa310*');"

        # 删除匿名用户
        mysql -uroot -e "delete from mysql.user where user='';"
        mysql  -uroot -e "flush privileges;"

        # mysql  -h IP -P端口 -u用户名 -p密码 mysql --default-character-set=utf8 -e "delete from mysql.user where user=''"
        # mysql  -h IP -P端口 -u用户名 -p密码 mysql --default-character-set=utf8 -e "flush privileges"

        # 添加新用户
        mysqlHivePasswd=`egrep "^mysql-hive-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
        mysql  -uroot -e "create user 'hive'@'%' identified by '$mysqlHivePasswd';"
        mysql  -uroot -e "flush privileges;"

        # 创建新数据库
        mysql  -uroot -e "create database hive default character set utf8 collate utf8_general_ci;"

        # 为新用户赋权
        mysql  -uroot -e "grant all privileges on hive.* to 'hive'@'%' identified by '$mysqlHivePasswd';"
        # mysql  -uroot -e "grant select,insert,update on {{database}}.* to {{username}}@localhost identified by '{{password}}';"
        mysql  -uroot -e "flush privileges;"
        
        # 导入Azkaban SQL导入
        sqlInfo=`egrep "azkaban-sql" /home/hadoop/automaticDeploy/frames.txt`
        sql=`echo $sqlInfo | cut -d " " -f1`
        isSqlInstall=`echo $sqlInfo | cut -d " " -f2`
        # 判断是否需要导入Azkaban SQL
        if [[ $isSqlInstall = "true" ]];then
            importAzkabanSQL $sql
        fi
        echo "--------------------"
        echo "|  Mysqk安装成功！  |"
        echo "--------------------"
       
    fi
    fi
    
}

installMysql