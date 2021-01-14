#! /bin/bash
#
#基于CentOS7
#

function configureCoreSite()
{
 coreSiteUrl=$1
 masterNode=$2
 hadoop_home=$3
 
 sed -i "/^<\/configuration>/d" $coreSiteUrl
 
 #配置fs默认名字
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>fs.default.name</name>" >> $coreSiteUrl
 echo "      <value>hdfs://$masterNode:9000</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 #配置默认FS
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>fs.defaultFS</name>" >> $coreSiteUrl
 echo "      <value>hdfs://$masterNode:9000</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 #配置IO操作的文件缓冲区大小
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>io.file.buffer.size</name>" >> $coreSiteUrl
 echo "      <value>131072</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 #tmp目录
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>hadoop.tmp.dir</name>" >> $coreSiteUrl
 echo "      <value>file:$hadoop_home/tmp</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 #代理用户hosts
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>hadoop.proxyuser.root.hosts</name>" >> $coreSiteUrl
 echo "      <value>*</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 #代理用户组
 echo "  <property>" >> $coreSiteUrl
 echo "      <name>hadoop.proxyuser.root.groups</name>" >> $coreSiteUrl
 echo "      <value>*</value>" >> $coreSiteUrl
 echo "  </property>" >> $coreSiteUrl

 echo "</configuration>" >> $coreSiteUrl

}

function configureHdfsSite()
{
 hdfsSiteUrl=$1
 masterNode=$2
 hadoop_home=$3
 
 n=`sed -n -e "/<configuration>/="  $hdfsSiteUrl`
 sed -i "`expr $n + 1`d" $hdfsSiteUrl
 sed -i "/^<\/configuration>/d" $hdfsSiteUrl
 
 #namenode的secondary配置
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.namenode.secondary.http-address</name>" >> $hdfsSiteUrl
 echo "      <value>$masterNode:9001</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl

 #namenode的name配置
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.namenode.name.dir</name>" >> $hdfsSiteUrl
 echo "      <value>file:$hadoop_home/name</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl

 #datanode的data配置
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.datanode.data.dir</name>" >> $hdfsSiteUrl
 echo "      <value>file:$hadoop_home/data</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl

 #备份数目设置置
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.replication</name>" >> $hdfsSiteUrl
 echo "      <value>2</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl
 
 #开启webhdfs
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.webhdfs.enabled</name>" >> $hdfsSiteUrl
 echo "      <value>true</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl
  
 #开启ACL权限管控
 echo "  <property>" >> $hdfsSiteUrl
 echo "      <name>dfs.namenode.acls.enabled</name>" >> $hdfsSiteUrl
 echo "      <value>true</value>" >> $hdfsSiteUrl
 echo "  </property>" >> $hdfsSiteUrl

 echo "</configuration>" >> $hdfsSiteUrl
}

function configureMapredSite()
{
 mapredSiteUrl=$1
 masterNode=$2

 cp $mapredSiteUrl.template $mapredSiteUrl
 
 n=`sed -n -e "/<configuration>/="  $mapredSiteUrl`
 sed -i "`expr $n + 1`d" $mapredSiteUrl
 sed -i "/^<\/configuration>/d" $mapredSiteUrl

 #mapreduce的框架
 echo "  <property>" >> $mapredSiteUrl
 echo "      <name>mapreduce.framework.name</name>" >> $mapredSiteUrl
 echo "      <value>yarn</value>" >> $mapredSiteUrl
 echo "  </property>" >> $mapredSiteUrl

 #jobhistory的地址
 echo "  <property>" >> $mapredSiteUrl
 echo "      <name>mapreduce.jobhistory.address</name>" >> $mapredSiteUrl
 echo "      <value>$masterNode:10020</value>" >> $mapredSiteUrl
 echo "  </property>" >> $mapredSiteUrl

 #jobhistory的webapp地址
 echo "  <property>" >> $mapredSiteUrl
 echo "      <name>mapreduce.jobhistory.webapp.address</name>" >> $mapredSiteUrl
 echo "      <value>$masterNode:19888</value>" >> $mapredSiteUrl
 echo "  </property>" >> $mapredSiteUrl

 #MapReduce日志保存位置
 echo "  <property>" >> $mapredSiteUrl
 echo "      <name>mapreduce.jobhistory.intermediate-done-dir</name>" >> $mapredSiteUrl
 echo "      <value>/mr-history/log</value>" >> $mapredSiteUrl
 echo "  </property>" >> $mapredSiteUrl

 #History Server日志保存位置
 echo "  <property>" >> $mapredSiteUrl
 echo "      <name>mapreduce.jobhistory.done-dir</name>" >> $mapredSiteUrl
 echo "      <value>/mr-history/done</value>" >> $mapredSiteUrl
 echo "  </property>" >> $mapredSiteUrl

 echo "</configuration>" >> $mapredSiteUrl
}

function configureYarnSite()
{
 yarnSiteUrl=$1
 masterNode=$2

 n=`sed -n -e "/<configuration>/="  $yarnSiteUrl`
 sed -i "`expr $n + 1`d" $yarnSiteUrl
 sed -i "/^<\/configuration>/d" $yarnSiteUrl

 #nodemanager的aux-services
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.nodemanager.aux-services</name>" >> $yarnSiteUrl
 echo "      <value>mapreduce_shuffle</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #nodemanager的aux-service类配置
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>" >> $yarnSiteUrl
 echo "      <value>org.apache.hadoop.mapred.ShuffleHandler</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #resourcemanager的地址
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.resourcemanager.address</name>" >> $yarnSiteUrl
 echo "      <value>$masterNode:8032</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #resourcemanager的scheduler地址
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.resourcemanager.scheduler.address</name>" >> $yarnSiteUrl
 echo "      <value>$masterNode:8030</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #resourcemanager的resource-tracker地址
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.resourcemanager.resource-tracker.address</name>" >> $yarnSiteUrl
 echo "      <value>$masterNode:8031</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #resourcemanager的admin地址
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.resourcemanager.admin.address</name>" >> $yarnSiteUrl
 echo "      <value>$masterNode:8033</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 #resourcemanager的webapp地址
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.resourcemanager.webapp.address</name>" >> $yarnSiteUrl
 echo "      <value>$masterNode:8088</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

# 关闭虚拟内存检查，防止因为tez内存占用过多被kill掉
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.nodemanager.vmem-check-enabled</name>" >> $yarnSiteUrl
 echo "      <value>false</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

# 开启日志聚合功能，开启Job-History服务必须的配置
 echo "  <property>" >> $yarnSiteUrl
 echo "      <name>yarn.log-aggregation-enable</name>" >> $yarnSiteUrl
 echo "      <value>true</value>" >> $yarnSiteUrl
 echo "  </property>" >> $yarnSiteUrl

 echo "</configuration>" >> $yarnSiteUrl
}

function configureSlaves()
{
 slavesUrl=$1
 
 sed -i 's/^[^#]/#&/' $slavesUrl
 
 echo "node01" >> $slavesUrl
 echo "node02" >> $slavesUrl
 echo "node03" >> $slavesUrl
}


function configureLZO()
{
 hadoop_home=$1
 coreSiteUrl=$2

 #在frames.txt中查看是否需要开启LZO
 lzoInfo=`egrep "hadoop-lzo" /home/hadoop/automaticDeploy/frames.txt`
 lzo=`echo $lzoInfo | cut -d " " -f1`
 isInstall=`echo $lzoInfo | cut -d " " -f2`

 if [[ $isInstall = "true" ]];then

    lzoIsExists=`find /opt/frames -name $lzo`
    echo $lzoIsExists

    if [[ ${#lzoIsExists} -ne 0 ]]; then
        cp $lzoIsExists $hadoop_home/share/hadoop/common >& /dev/null

        # 配置core-site.xml
        sed -i "/^<\/configuration>/d" $coreSiteUrl
        
        #配置loz
        echo "  <property>" >> $coreSiteUrl
        echo "      <name>io.compression.codecs</name>" >> $coreSiteUrl
        echo "      <value>" >> $coreSiteUrl
        echo "          org.apache.hadoop.io.compress.GzipCodec," >> $coreSiteUrl
        echo "          org.apache.hadoop.io.compress.DefaultCodec," >> $coreSiteUrl
        echo "          org.apache.hadoop.io.compress.BZip2Codec," >> $coreSiteUrl
        echo "          org.apache.hadoop.io.compress.SnappyCodec," >> $coreSiteUrl
        echo "          com.hadoop.compression.lzo.LzoCodec," >> $coreSiteUrl
        echo "          com.hadoop.compression.lzo.LzopCodec" >> $coreSiteUrl
        echo "      </value>" >> $coreSiteUrl
        echo "  </property>" >> $coreSiteUrl

        echo "  <property>" >> $coreSiteUrl
        echo "      <name>io.compression.codec.lzo.class</name>" >> $coreSiteUrl
        echo "      <value>com.hadoop.compression.lzo.LzoCodec</value>" >> $coreSiteUrl
        echo "  </property>" >> $coreSiteUrl

        echo "</configuration>" >> $coreSiteUrl

    else
        echo "lzo安装包不存在，功能添加失败！"
    fi
 fi
}

# 为配置文件添加单条记录
function addConfigs()
{
 key=$1
 value=$2
 config_file=$3
    
 sed -i "/^<\/configuration>/d" $config_file
 
 #namenode的secondary配置
 echo "  <property>" >> $config_file
 echo "      <name>$key</name>" >> $config_file
 echo "      <value>$value</value>" >> $config_file
 echo "  </property>" >> $config_file
  
 echo "</configuration>" >> $config_file
}

function configHue()
{
 
 hadoop_home=$1
 #在frames.txt中查看是否需要安装hue
 hueInfo=`egrep "hue" /home/hadoop/automaticDeploy/frames.txt`
 
 hue=`echo $hueInfo | cut -d " " -f1`
 isInstall=`echo $hueInfo | cut -d " " -f2`

 if [[ $isInstall = "true" ]];then
    
    # 添加hue用户操作权限
    addConfigs "hadoop.proxyuser.hue.hosts" "*" $hadoop_home/etc/hadoop/core-site.xml
    addConfigs "hadoop.proxyuser.hue.groups" "*" $hadoop_home/etc/hadoop/core-site.xml
    addConfigs "hadoop.proxyuser.httpfs.hosts" "*" $hadoop_home/etc/hadoop/core-site.xml
    addConfigs "hadoop.proxyuser.httpfs.groups" "*" $hadoop_home/etc/hadoop/core-site.xml
    
    # 添加hue web权限
    addConfigs "httpfs.proxyuser.hue.hosts" "*" $hadoop_home/etc/hadoop/httpfs-site.xml
    addConfigs "httpfs.proxyuser.hue.groups" "*" $hadoop_home/etc/hadoop/httpfs-site.xml
 fi

}

function installHadoop()
{
 #在frames.txt中查看是否需要安装hadoop
 hadoopInfo=`egrep "^hadoop" /home/hadoop/automaticDeploy/frames.txt`

 hadoop=`echo $hadoopInfo | cut -d " " -f1`
 isInstall=`echo $hadoopInfo | cut -d " " -f2`
 masterNode=`echo $hadoopInfo | cut -d " " -f3` 

 echo $hadoop
 echo $isInstall

 #是否安装
 if [[ $isInstall = "true" ]];then

   #查看/opt/frames目录下是否有hadoop安装包
   hadoopIsExists=`find /opt/frames -name $hadoop`
   echo $hadoopIsExists
   if [[ ${#hadoopIsExists} -ne 0  ]];then
     
       if [[ ! -d /opt/app ]];then
           mkdir /opt/app && chmod -R 775 /opt/app
       fi 

       #删除旧的
       hadoop_home_old=`find /opt/app -maxdepth 1 -name "hadoop*"`
       for i in $hadoop_home_old;do
           rm -rf $i
       done

       #解压到指定文件夹/opt/app中
       echo "开始解压hadoop安装包"
       tar -zxvf $hadoopIsExists -C /opt/app >& /dev/null
       echo "hadoop安装包解压完毕"

       hadoop_home=`find /opt/app -maxdepth 1 -name "hadoop*"`
       
       #在hadoop安装目录下创建tmp、name和data目录
       if [[ ! -d $hadoop_home/tmp ]];then
           mkdir $hadoop_home/tmp
       fi
       if [[ ! -d $hadoop_home/name ]];then
           mkdir $hadoop_home/name
       fi
       if [[ ! -d $hadoop_home/data ]];then
           mkdir $hadoop_home/data
       fi

       chmod -R 775 $hadoop_home
  
       #配置hadoop-env.sh文件
       java_home=`egrep "^export JAVA_HOME=" /etc/profile`
       echo "" >> $hadoop_home/etc/hadoop/hadoop-env.sh
       echo "$java_home" >> $hadoop_home/etc/hadoop/hadoop-env.sh
       echo "export PATH=\$PATH:$hadoop_home/bin" >> $hadoop_home/etc/hadoop/hadoop-env.sh
       source $hadoop_home/etc/hadoop/hadoop-env.sh && source $hadoop_home/etc/hadoop/hadoop-env.sh
       
       #配置yarn-env.sh文件
       num=`sed -n -e "/# export JAVA_HOME=/="  $hadoop_home/etc/hadoop/yarn-env.sh`  
       sed -i "${num}a ${java_home}" $hadoop_home/etc/hadoop/yarn-env.sh
 
       #配置core-site.xml文件
       configureCoreSite $hadoop_home/etc/hadoop/core-site.xml $masterNode $hadoop_home
 
       #配置hdfs-site.xml
       configureHdfsSite $hadoop_home/etc/hadoop/hdfs-site.xml $masterNode $hadoop_home

       #配置mapred-site.xml
       configureMapredSite $hadoop_home/etc/hadoop/mapred-site.xml $masterNode

       #配置yarn-site.xml
       configureYarnSite $hadoop_home/etc/hadoop/yarn-site.xml $masterNode

       #配置slaves
       configureSlaves $hadoop_home/etc/hadoop/slaves

       # 配置lzo
       configureLZO $hadoop_home $hadoop_home/etc/hadoop/core-site.xml

       # 配置hue
       configHue $hadoop_home

       #配置HadoopHome和Path
       profile=/etc/profile
       sed -i "/^export HADOOP_HOME/d" $profile
       echo "export HADOOP_HOME=$hadoop_home" >> $profile
       sed -i "/^export PATH=\$PATH:\$HADOOP_HOME\/bin/d" $profile
       echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> $profile
       
       #更新/etc/profile文件
       source /etc/profile && source /etc/profile
       echo "--------------------"
       echo "|  Hadoop安装成功！ |"
       echo "--------------------"
   fi
 fi
}

installHadoop
