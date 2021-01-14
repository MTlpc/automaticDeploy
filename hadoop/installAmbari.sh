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
 
 # 清空MySQL中的Hive Metastore
 ssh $mysqlNode "source /etc/profile && export MYSQL_PWD=$mysqlHivePasswd && mysql --connect-expired-password -uroot -e \"drop database if exists hive;\""

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

  <property>
    <name>hive.metastore.schema.verification</name>
    <value>false</value>
  </property>

  <property>
    <name>datanucleus.schema.autoCreateTables</name>
    <value>true</value>
    <description>
      MetaStore表如果不存在，则自动进行创建
    </description>
  </property>
  
  <property>
    <name>hive.compactor.initiator.on</name>
    <value>true</value>
    <description>
      开启事务必要配置：是否在Metastore上启动初始化和清理线程
    </description>
  </property>

  <property>
    <name>hive.compactor.worker.threads</name>
    <value>3</value>
    <description>
      开启事务必要配置：压缩时，启动的worker线程数
    </description>
  </property>

  <property>
    <name>hive.support.concurrency</name>
    <value>true</value>
    <description>
      开启事务必要配置：HiveServer2 Client配置，是否允许并发
    </description>
  </property>

  <property>
    <name>hive.txn.manager</name>
    <value>org.apache.hadoop.hive.ql.lockmgr.DbTxnManager</value>
    <description>
      开启事务必要配置：HiveServer2 Client配置，提供事务行为
    </description>
  </property>

  <property>
    <name>hive.enforce.bucketing</name>
    <value>true</value>
    <description>
      开启事务必要配置：HiveServer2 Client配置，开启自动分桶
      在2.x之后不需要进行配置，为了兼容之前版本添加此参数
    </description>
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

function installAmbari()
{
 #在frames.txt中查看是否需要安装hive
 ambariInfo=`egrep "ambari" /home/hadoop/automaticDeploy/frames.txt`
 
 ambari=`echo $ambariInfo | cut -d " " -f1`
 isInstall=`echo $ambariInfo | cut -d " " -f2`
 ambariNode=`echo $ambariInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否在当前节点进行安装
 if [[ $isInstall = "true" && $ambariNode =~ $node ]];then
     
     #查看/opt/frames目录下是否有ambari安装包
     ambariIsExists=`find /opt/frames -name $ambari`
    
     if [[ ${#ambariIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          ambari_home_old=`find /opt/app -maxdepth 1 -name "*ambari*"`
          for i in $ambari_home_old;do
                rm -rf $i
          done

          #解压到指定文件夹/opt/app中
          echo "开始解压ambari安装包"
          tar -zxvf $ambariIsExists -C /opt/app >& /dev/null
          echo "ambari安装包解压完毕"

          # 安装rpm编译依赖
          # yum install rpm -y
          yum install rpm-build -y
          yum install gcc-c++
          # yum install git -y

          ambari_home=`find /opt/app -maxdepth 1 -name "*ambari*"`

          version=`echo $ambari_home | cut -d "-" -f3`

          cd $ambari_home
          mvn versions:set -DnewVersion=$version".0.0"
          pushd ambari-metrics
          mvn versions:set -DnewVersion=$version".0.0"
          popd

          # 编译
          mvn -B clean install rpm:rpm -DnewVersion=2.7.5.0.0 -DbuildNumber=5895e4ed6b30a2da8a90fee2403b6cab91d19972 -DskipTests -Dpython.ver="python >= 2.6"

          # 安装ambari
          yum install ambari-server*.rpm    #This should also pull in postgres packages as well.

          # 配置
          # ambari-server setup

          # 启动服务
          # ambari-server start
          
     else
         echo "/opt/frames目录下没有ambari安装包"
     fi
 else
     echo "ambari不允许被安装在当前节点"
 fi
}

installAmbari
