#! /bin/bash

function configureHue()
{
 hue_home=$1
 hueConf=$2

 mysqlNode=`egrep "^mysql-rpm-pack" /home/hadoop/automaticDeploy/frames.txt | cut -d " " -f3`
 mysqlHivePasswd=`egrep "^mysql-hive-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
 
 # 创建数据库hue，用于存放hue数据
 ssh $mysqlNode "source /etc/profile && export MYSQL_PWD=$mysqlHivePasswd && mysql --connect-expired-password -uroot -e \"drop database if exists hue;\""
 ssh $mysqlNode "source /etc/profile && export MYSQL_PWD=$mysqlHivePasswd && mysql --connect-expired-password -uroot -e \"create database if not exists hue;\""

 # 配置秘钥 
 sed -i "s/secret_key=/secret_key=ad1FA1ka09/g" $hueConf
 # 配置mysql
 num=`sed -n -e "/\[\[database\]\]/=" $hueConf`
 sed -i "${num}a host=${mysqlNode}" $hueConf
 sed -i "`expr $num + 1`a port=3306" $hueConf
 sed -i "`expr $num + 2`a engine=mysql" $hueConf
 sed -i "`expr $num + 3`a user=root" $hueConf
 sed -i "`expr $num + 4`a password=${mysqlHivePasswd}" $hueConf
 sed -i "`expr $num + 5`a name=hue" $hueConf
 
 # 初始化hue数据库数据
 $hue_home/build/env/bin/hue syncdb 
 $hue_home/build/env/bin/hue migrate
}

function addHive()
{
 hueConf=$1

 hiveInfo=`egrep "hive" /home/hadoop/automaticDeploy/frames.txt`
 hive=`echo $hiveInfo | cut -d " " -f1`
 hiveNode=`echo $hiveInfo | cut -d " " -f3`

 # 配置Hive
 num=`sed -n -e "/\[beeswax\]/=" $hueConf`
 sed -i "${num}a hive_server_host=${hiveNode}" $hueConf
 sed -i "`expr $num + 1`a hive_server_port=10000" $hueConf
 sed -i "`expr $num + 2`a thrift_version=7" $hueConf
 
 num2=`sed -n -e "/\[\[interpreters\]\]/=" $hueConf`
 sed -i "${num2}a [[[hive]]]" $hueConf
 sed -i "`expr $num2 + 1`a name=Hive" $hueConf
 sed -i "`expr $num2 + 2`a interface=hiveserver2" $hueConf

}

function addHDFS()
{
hadoopInfo=`egrep "^hadoop" /home/hadoop/automaticDeploy/frames.txt`
masterNode=`echo $hadoopInfo | cut -d " " -f3` 

hueConf=$1

sed -i "s/fs_defaultfs=hdfs:\/\/localhost:8020/fs_defaultfs=hdfs:\/\/$masterNode:9000/g" $hueConf
sed -i "s/webhdfs_url=http:\/\/localhost:50070\/webhdfs\/v1/webhdfs_url=hdfs:\/\/http:\/\/$masterNode:50070\/webhdfs\/v1/g" $hueConf
}

function addYarn()
{
hadoopInfo=`egrep "^hadoop" /home/hadoop/automaticDeploy/frames.txt`
masterNode=`echo $hadoopInfo | cut -d " " -f3` 

hueConf=$1

sed -i "s/## resourcemanager_host=localhost/resourcemanager_host=$masterNode/g" $hueConf
sed -i "s/## resourcemanager_api_url=http:\/\/localhost:8088/resourcemanager_api_url=http:\/\/$masterNode:8088/1" $hueConf
sed -i "s/## proxy_api_url=http:\/\/localhost:8088/proxy_api_url=http:\/\/$masterNode:8088/g" $hueConf
sed -i "s/## resourcemanager_port=8032/resourcemanager_port=8032/g" $hueConf
sed -i "s/## history_server_api_url=http:\/\/localhost:19888/history_server_api_url=http:\/\/$masterNode:19888/g" $hueConf
}

function addHBase()
{
hueConf=$1

hbaseInfo=`egrep "^hbase" /home/hadoop/automaticDeploy/frames.txt`
isInstall=`echo $hbaseInfo | cut -d " " -f2`
hbaseNodes=`echo $hbaseInfo | cut -d " " -f3` 

if [[ $isInstall = "true" ]];then
  sed -i "s/## hbase_clusters=(Cluster|localhost:9090)/hbase_clusters=(Cluster|$hbaseNodes:9090)/g" $hueConf
else
  echo "HBase未安装，未配置与HBase的连接"
fi
}

# 已经安装Mysql的节点，缺少my_config.h的解决方案
function configMysql()
{
  # my_config.h目标存放位置
  target_dir=$1

  # 从https://downloads.mysql.com/archives/c-c/中下载源码版本
  mysqlCon=`egrep "mysql-connector-c" /home/hadoop/automaticDeploy/frames.txt`
  con=`echo $mysqlCon | cut -d " " -f1`
  isInstall=`echo $mysqlCon | cut -d " " -f2`

  if [[ $isInstall = "true" ]];then

    #查看/opt/frames目录下是否有hue安装包
     myIsExists=`find /opt/frames -name $con`
    
     if [[ ${#myIsExists} -ne 0 ]];then

        # 拷贝到临时目录
        cp $myIsExists /tmp/
        # 进入到临时目录
        cd /tmp
        # 解压rpm包
        rpm2cpio $myIsExists | cpio -div
        # 找到解压出来的压缩包
        tar_home=`find /tmp -maxdepth 1 -name "mysql-connector-c*.tar.gz"`
        
        #删除旧的
        tmp_home_old=`find /tmp -maxdepth 1 -name "my_tmp"`
        for i in $tmp_home_old;do
              rm -rf $i
        done
        # 解压压缩包
        mkdir /tmp/my_tmp
        tar -zxvf $tar_home -C /tmp/my_tmp

        # 编译源码
        yum install -y cmake
        my_home=`find /tmp/my_tmp -maxdepth 1 -name "mysql-connector-c*-src"`
        cmake $my_home
        
        # 移动my_config.h到相应位置
        cp /tmp/include/my_config.h $target_dir

     else
        echo "mysql-connector-c源码包不存在"
      fi

  else
    echo "my_config.h不允许安装"
  fi

}

function addUser()
{
  hue_home=$1
  # 为HUE添加HUE用户，并赋予ROOT权限
  sudo useradd hue
  usermod -g root hue
  chown -R hue /home/hue/
  chown -R hue $hue_home
}

function installHue()
{
 #在frames.txt中查看是否需要安装hue
 hueInfo=`egrep "hue" /home/hadoop/automaticDeploy/frames.txt`
 
 hue=`echo $hueInfo | cut -d " " -f1`
 isInstall=`echo $hueInfo | cut -d " " -f2`
 hueNode=`echo $hueInfo | cut -d " " -f3`
 node=`hostname`

 # 查看Mysql安装信息  
 mysqlInfo=`egrep "^mysql-rpm-pack" /home/hadoop/automaticDeploy/frames.txt`
 mysqlNode=`echo $mysqlInfo | cut -d " " -f3` 
 
 #是否在当前节点进行安装
 if [[ $isInstall = "true" && $hueNode = $node ]];then
     
     #查看/opt/frames目录下是否有hue安装包
     hueIsExists=`find /opt/frames -name $hue`
    
     if [[ ${#hueIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          hue_home_old=`find /opt/app -maxdepth 1 -name "*hue*"`
          for i in $hue_home_old;do
                rm -rf $i
          done

          #解压到指定文件夹/opt/app中
          echo "开始解压hue安装包"
          tar -zxvf $hueIsExists -C /opt/app >& /dev/null
          echo "hive安装包解压完毕"

          hue_home=`find /opt/app -maxdepth 1 -name "*hue*"`

          # 安装依赖
          yum install -y openssl-devel

          # 安装编译所需依赖，需提前安装maven、npm
          if [[ $mysqlNode = $node ]];then
              sudo yum install -y ant asciidoc cyrus-sasl-devel cyrus-sasl-gssapi cyrus-sasl-plain gcc gcc-c++ krb5-devel libffi-devel libxml2-devel libxslt-devel make openldap-devel python-devel sqlite-devel gmp-devel
          else
              sudo yum install -y ant asciidoc cyrus-sasl-devel cyrus-sasl-gssapi cyrus-sasl-plain gcc gcc-c++ krb5-devel libffi-devel libxml2-devel libxslt-devel make mysql mysql-devel openldap-devel python-devel sqlite-devel gmp-devel
          fi

          cd $hue_home

          # 检测expect服务是否存在，不存在则使用yum安装expect
#           expectIsExists=`rpm -qa | grep expect` 
#           if [ -z $expectIsExists ]
#           then
#                 yum -y install expect
#           fi

#           expect << EOF
#               #复制公钥到目标主机
#               spawn make apps
#               expect {
#                       #expect实现自动输入密码
#                       "build/env/bin/easy_install\" { spawn "yes\n";exp_continue } 
#                       "password" { send "$pass_word\n";exp_continue }
#                       eof
#               }
# EOF

          # 进行编译
          echo "开始编译，请稍等"
          make apps > /tmp/hue_intall.log 2>&1;

          grep "mysql_config not found" /tmp/hue_intall.log > /dev/null
          if [ $? -eq 0 ]; then
              echo "缺少mysql-devel，请通过yum安装，或rpm方式安装"
              echo "eg: wget http://mirrors.sohu.com/mysql/MySQL-5.7/mysql-community-devel-5.7.23-1.el7.x86_64.rpm"
              echo "eg: rpm -ivh $mysqlIsExists/mysql-community-*"
              exit 1
          fi

          grep "build/env/bin/easy_install\", line 11, in <module>" /tmp/hue_intall.log > /dev/null
          if [ $? -eq 0 ]; then
              # 解决setuptools的问题
              build/env/bin/python -m pip install setuptools==28.6.1 backports.shutil-get-terminal-size pathlib2 decorator pexpect pickleshare prompt-toolkit==1.0.4 traitlets==4.2 simplegeneric==0.8.1
              echo "开始重新编译，请稍等"
              make apps > /tmp/hue_intall.log 2>&1;
          fi

          # 配置HUE
          configureHue $hue_home $hue_home/desktop/conf/pseudo-distributed.ini
          # 添加Hive
          addHive $hue_home/desktop/conf/pseudo-distributed.ini
          # 添加HDFS
          addHDFS $hue_home/desktop/conf/pseudo-distributed.ini
          # 添加Yarn
          addYarn $hue_home/desktop/conf/pseudo-distributed.ini
          # 添加HBase
          addHBase $hue_home/desktop/conf/pseudo-distributed.ini

          #配置HUE_HOME
          profile=/etc/profile
          sed -i "/^export HUE_HOME/d" $profile
          echo "export HUE_HOME=$hue_home" >> $profile

          #配置PATH
          sed -i "/^export PATH=\$PATH:\$HIVE_HOME\/build\/env\/bin/d" $profile
          echo "export PATH=\$PATH:\$HIVE_HOME/build/env/bin" >> $profile

          #更新/etc/profile文件
          source /etc/profile && source /etc/profile

     else
         echo "/opt/frames目录下没有Hue安装包"
     fi
 else
     echo "Hue不允许被安装在当前节点"
 fi
}

installHue
