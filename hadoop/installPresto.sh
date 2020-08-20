#! /bin/bash

# 配置node.properties文件
function configureNodeEnv()
{
 prestoEnvUrl=$1
 node=`hostname`
 
cat >> $prestoEnvUrl <<EOF
node.environment=production
node.id=$node
node.data-dir=/var/presto/data
EOF
}

# 配置jvm.config文件
function configureJvm()
{
 prestoJvmUrl=$1
 
cat >> $prestoJvmUrl <<EOF
-server
-Xmx16G
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+UseGCOverheadLimit
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
EOF
}

# 配置主节点
function configurePrestoMaster()
{
 prestoSiteUrl=$1
 node=$2
 
 cat >> $prestoSiteUrl <<EOF
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
query.max-memory=50GB
query.max-memory-per-node=1GB
discovery-server.enabled=true
discovery.uri=http://$node:8080
EOF
}

# 配置从节点
function configurePrestoSlave()
{
 prestoSiteUrl=$1
 node=$2
 
 cat >> $prestoSiteUrl <<EOF
coordinator=false
http-server.http.port=8080
query.max-memory=50GB
query.max-memory-per-node=1GB
discovery.uri=http://$node:8080
EOF
}

# 配置日志级别
function configureLogLevel()
{
 prestoLogUrl=$1
 echo "com.facebook.presto=INFO" > $prestoLogUrl
}

# 配置Jmx catalog
function configureJmxCatalog()
{
 prestoCatalogUrl=$1
 echo "connector.name=jmx" > $prestoCatalogUrl
}

# 配置Hive Catalog
function configureHiveCatalog()
{
 prestoCatalogUrl=$1
 hiveNode=$2
 echo "connector.name=hive-hadoop2" >> $prestoCatalogUrl
 echo "hive.metastore.uri=thrift://$hiveNode:9083" >> $prestoCatalogUrl
}

# 配置hive-site.xml
# function configureHiveSite()
# {
#  hiveSite=$1
#  hiveNode=`hostname`
 
# sed -i "s#</configuration>##g" $hiveSite

# cat >> $hiveSite <<EOF
# <property>
# <name>hive.server2.thrift.port</name>
# <value>10000</value>
# </property>
# <property>
# <name>hive.server2.thrift.bind.host</name>
# <value>$hiveNode</value>
# </property>
# <property>
# <name>hive.metastore.uris</name>
# <value>thrift://$hiveNode:9083</value>
# </property>
# </configuration>
# EOF
# }

function installPresto()
{
 #1.在frames.txt中查看是否需要安装presto
 prestoInfo=`egrep "presto" /home/hadoop/automaticDeploy/frames.txt`
 hiveInfo=`egrep "hive" /home/hadoop/automaticDeploy/frames.txt`

 presto=`echo $prestoInfo | cut -d " " -f1`
 isInstall=`echo $prestoInfo | cut -d " " -f2`
 installNode=`echo $prestoInfo | cut -d " " -f3`
 hiveNode=`echo $hiveInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否安装
 if [[ $isInstall = "true" ]];then
     
     #2.查看/opt/frames目录下是否有presto安装包
     prestoIsExists=`find /opt/frames -name $presto`
    
     if [[ ${#prestoIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          presto_home_old=`find /opt/app -maxdepth 1 -name "*presto*"`
          for i in $presto_home_old;do
                rm -rf $i
          done

          #3.解压到指定文件夹/opt/app中
          echo "开始解压presto安装包"
          tar -zxvf $prestoIsExists -C /opt/app >& /dev/null
          echo "presto安装包解压完毕"

          presto_home=`find /opt/app -maxdepth 1 -name "*presto*"`
          mkdir $presto_home/etc
 
          #4.配置node.properties文件
          configureNodeEnv $presto_home/etc/node.properties

          #配置jvm.config   
          configureJvm $presto_home/etc/jvm.config

          #判断在当前节点安装主节点还是从节点
          if [[ $installNode = $node ]];then
            # 安装主节点
            configurePrestoMaster $presto_home/etc/config.properties $installNode
          else
            # 安装从节点
            configurePrestoSlave $presto_home/etc/config.properties $installNode
          fi

          #配置日志级别
          configureLogLevel $presto_home/etc/log.properties

          #配置catalog
          mkdir $presto_home/etc/catalog
          configureJmxCatalog $presto_home/etc/catalog/jmx.properties
          
          #安装Prosto客户端
          client_home=`find /opt/frames/lib -maxdepth 1 -name "*presto-cli*"`
          cp $client_home $presto_home/bin/presto
          chmod a+x $presto_home/bin/presto
          # presto --server localhost:8080 --catalog hive --schema default
          
          # 配置hive-site.xml开启Hive Thrift客户端
          # node=`hostname`
          # if [[ $hiveNode = $node ]];then   
          #   echo "开始配置Hive"
          #   hive_home=`find /opt/app -maxdepth 1 -name "*hive*"`
          #   configureHiveSite $hive_home/conf/hive-site.xml
          #   # 开启Hive元数据服务
          #   hive --service hiveserver2 &
          #   hive --service metastore &
          # fi

          # 配置HiveCatalog
          configureHiveCatalog $presto_home/etc/catalog/hive.properties $hiveNode

          # 配置PRESTO_HOME
          profile=/etc/profile
          sed -i "/^export PRESTO_HOME/d" $profile
          echo "export PRESTO_HOME=$presto_home" >> $profile

          # 配置PATH
          sed -i "/^export PATH=\$PATH:\$PRESTO_HOME\/bin/d" $profile
          echo "export PATH=\$PATH:\$PRESTO_HOME/bin" >> $profile

          # 更新/etc/profile文件
          source /etc/profile && source /etc/profile

          # 输出提示信息
          echo "--------------------"
          echo "|  Presto安装成功！ |"
          echo "--------------------"
          echo "Presto服务端口为：8080"
          
     else
         echo "/opt/frames目录下没有Presto安装包"
     fi
 else
     echo "Presto不允许被安装在当前节点"
 fi
}

installPresto
