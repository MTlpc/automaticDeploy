#! /bin/bash

function configureHiveEnv()
{
 hiveEnvUrl=$1
 hive_home=$2
 
 cp $hiveEnvUrl.template $hiveEnvUrl

 profile=/etc/profile
 java_home=`egrep "^export JAVA_HOME=" $profile`
 hadoop_home=`egrep "^export HADOOP_HOME=" $profile`
 
 echo "$java_home" >> $hiveEnvUrl
 echo "$hadoop_home" >> $hiveEnvUrl
 echo "export HIVE_CONF_DIR=$hive_home/conf" >> $hiveEnvUrl

}

# 配置hive-site.xml
function configureHiveSite()
{
 hiveSiteUrl=$1
 mysqlNode=`egrep "^mysql-rpm-pack" /home/hadoop/automaticDeploy/frames.txt | cut -d " " -f3`
 mysqlHivePasswd=`egrep "^mysql-hive-password" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
 
 cat >> $hiveSiteUrl <<EOF
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://$mysqlNode:3306/hive?createDatabaseIfNotExist=true&amp;useSSL=false</value>
    <description>JDBC connect string for a JDBC metastore</description>
  </property>
 
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>com.mysql.jdbc.Driver</value>
    <description>Driver class name for a JDBC metastore</description>
  </property>
 
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
    <description>username to use against metastore database</description>
  </property>
 
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>$mysqlHivePasswd</value>
    <description>password to use against metastore database</description>
  </property>
</configuration>
EOF
}

# 配置hive-site.xml，开启Thrift服务
configureHiveThrift()
{
hiveSite=$1
hiveNode=`hostname`
  
sed -i "s#</configuration>##g" $hiveSite

cat >> $hiveSite <<EOF
  <property>
  <name>hive.server2.thrift.port</name>
  <value>10000</value>
  </property>
  <property>
  <name>hive.server2.thrift.bind.host</name>
  <value>$hiveNode</value>
  </property>
  <property>
  <name>hive.metastore.uris</name>
  <value>thrift://$hiveNode:9083</value>
  </property>
  </configuration>
EOF
}

function installHive()
{
 #在frames.txt中查看是否需要安装hive
 hiveInfo=`egrep "hive" /home/hadoop/automaticDeploy/frames.txt`
 
 hive=`echo $hiveInfo | cut -d " " -f1`
 isInstall=`echo $hiveInfo | cut -d " " -f2`
 hiveNode=`echo $hiveInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否在当前节点进行安装
 if [[ $isInstall = "true" && $hiveNode = $node ]];then
     
     #查看/opt/frames目录下是否有hive安装包
     hiveIsExists=`find /opt/frames -name $hive`
    
     if [[ ${#hiveIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          hive_home_old=`find /opt/app -maxdepth 1 -name "*hive*"`
          for i in $hive_home_old;do
                rm -rf $i
          done

          #解压到指定文件夹/opt/app中
          echo "开始解压hive安装包"
          tar -zxvf $hiveIsExists -C /opt/app >& /dev/null
          echo "hive安装包解压完毕"

          hive_home=`find /opt/app -maxdepth 1 -name "*hive*"`
 
          #配置hive-env.sh文件
          configureHiveEnv $hive_home/conf/hive-env.sh $hive_home

          #配置hive-log4j2.properties文件
          cp $hive_home/conf/hive-log4j2.properties.template $hive_home/conf/hive-log4j2.properties

          #配置远程登录模式
          configureHiveSite $hive_home/conf/hive-site.xml
          
          #拷贝Mysql连接驱动
          mysqlDrive=`egrep "^mysql-drive" /home/hadoop/automaticDeploy/configs.txt | cut -d " " -f2 | sed s/\r//`
          #判断驱动是否存在
          driveIsExists=`find /opt/frames/lib -name $mysqlDrive`
          if [[ ${#driveIsExists} -ne 0 ]];then
            cp /opt/frames/lib/$mysqlDrive $hive_home/lib/
          else
            echo "/opt/frames/lib目录下没有Mysql驱动"
          fi

          #为Presto开启Thrift服务
          prestoInstall=`egrep "presto" /home/hadoop/automaticDeploy/frames.txt | cut -d " " -f2`
          if [[ $prestoInstall = "true" ]];then
            echo "开始配置Hive Thrift服务"
            configureHiveThrift $hive_home/conf/hive-site.xml
            # 开启Hive元数据服务
            # hive --service hiveserver2 &
            # hive --service metastore &
          fi
   
          #配置HIVE_HOME
          profile=/etc/profile
          sed -i "/^export HIVE_HOME/d" $profile
          echo "export HIVE_HOME=$hive_home" >> $profile

          #配置PATH
          sed -i "/^export PATH=\$PATH:\$HIVE_HOME\/bin/d" $profile
          echo "export PATH=\$PATH:\$HIVE_HOME/bin" >> $profile

          #更新/etc/profile文件
          source /etc/profile && source /etc/profile

          # 判断是否安装Tez
          tezInstall=`egrep "tez" /home/hadoop/automaticDeploy/frames.txt | cut -d " " -f2`
          if [[ $tezInstall = "true" ]];then
            echo "开始安装Tez服务"
            /home/hadoop/automaticDeploy/hadoop/installTez.sh
          fi

          # 输出提示信息
          echo "--------------------"
          echo "|   Hive安装成功！  |"
          echo "--------------------"
          echo "Hive服务启动命令: hive"
          if [[ $prestoInstall = "true" ]];then
          echo "为Presto开启Hive元数据服务命令: hive --service hiveserver2 &"
          echo "为Presto开启Hive元数据服务命令: hive --service metastore &"
          fi
          if [[ $tezInstall = "true" ]];then
              echo "Hive将运行在Tez引擎之上"
          fi
     else
         echo "/opt/frames目录下没有hive安装包"
     fi
 else
     echo "Hive不允许被安装在当前节点"
 fi
}

installHive
