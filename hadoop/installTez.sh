#! /bin/bash

function configureHiveEnv()
{
 hiveEnvUrl=$1
 tez_home=$2

 profile=/etc/profile
 java_home=`egrep "^export JAVA_HOME=" $profile`
 hadoop_home=`egrep "^export HADOOP_HOME=" $profile`
 
 echo "$java_home" >> $hiveEnvUrl
 echo "$hadoop_home" >> $hiveEnvUrl
#  echo "$tez_home" >> $hiveEnvUrl

echo "export TEZ_HOME=$tez_home" >> $hiveEnvUrl
cat >> $hiveEnvUrl <<EOF
export TEZ_JARS=""
for jar in \`ls \$TEZ_HOME |grep jar\`; do
    export TEZ_JARS=\$TEZ_JARS:\$TEZ_HOME/\$jar
done
for jar in \`ls \$TEZ_HOME/lib\`; do
    export TEZ_JARS=\$TEZ_JARS:\$TEZ_HOME/lib/\$jar
done
EOF

hadoop_path=`echo $hadoop_home | cut -d "=" -f2`
lzo_home=`find $hadoop_path/share/hadoop/common -maxdepth 1 -name "*lzo*"`

echo "export HIVE_AUX_JARS_PATH=$lzo_home\$TEZ_JARS" >> $hiveEnvUrl
}

# 配置tez-site.xml文件
function configureTezSite()
{
 hiveConf=$1
 tezName=$2
 
cat << EOF > $hiveConf/tez-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
	<name>tez.lib.uris</name>    
    <value>\${fs.defaultFS}/tez/{tez-path},\${fs.defaultFS}/tez/{tez-path}/lib</value>
</property>
<property>
	<name>tez.lib.uris.classpath</name>    	
    <value>\${fs.defaultFS}/tez/{tez-path},\${fs.defaultFS}/tez/{tez-path}/lib</value>
</property>
<property>
     <name>tez.use.cluster.hadoop-libs</name>
     <value>true</value>
</property>
<property>
     <name>tez.history.logging.service.class</name>        
     <value>org.apache.tez.dag.history.logging.ats.ATSHistoryLoggingService</value>
</property>
</configuration>
EOF

# 将配置文件中的{tez-path}替换成当前tez的路径
sed -i "s/{tez-path}/$tezName/g" $hiveConf/tez-site.xml
}

function configureHiveSite()
{
 hiveSite=$1
 
sed -i "s#</configuration>##g" $hiveSite

cat >> $hiveSite <<EOF
<property>
  <name>hive.execution.engine</name>
  <value>tez</value>
</property>
</configuration>
EOF
}

function installTez()
{
 #1.在frames.txt中查看是否需要安装tez
 tezInfo=`egrep "tez" /home/hadoop/automaticDeploy/frames.txt`

 tez=`echo $tezInfo | cut -d " " -f1`
 isInstall=`echo $tezInfo | cut -d " " -f2`
 tezVersion=`echo $tez | cut -d "-" -f3`
 installNode=`echo $tezInfo | cut -d " " -f3`
 node=`hostname`

 
 #是否安装
 if [[ $isInstall = "true" && $installNode = $node ]];then
     
     #2.查看/opt/frames目录下是否有tez安装包
     tezIsExists=`find /opt/frames -name $tez`
    
     if [[ ${#tezIsExists} -ne 0 ]];then
           
          if [[ ! -d /opt/app ]];then
              mkdir /opt/app && chmod -R 775 /opt/app
          fi
   
          #删除旧的
          tez_home_old=`find /opt/app -maxdepth 1 -name "*tez*"`
          for i in $tez_home_old;do
                rm -rf $i
          done

          #3.解压到指定文件夹/opt/app中
          echo "开始解压tez安装包"
          tar -zxvf $tezIsExists -C /opt/app >& /dev/null
          echo "tez安装包解压完毕"
          
          profile=/etc/profile
          hadoop_home=`egrep "^export HADOOP_HOME=" $profile`
          hadoop_path=`echo $hadoop_home | cut -d "=" -f2`

          # 移动lzo包到hadoop目录下
          lzoIsExists=`find /opt/frames/lib -maxdepth 1 -name "*lzo*"`
          cp $lzoIsExists $hadoop_path/share/hadoop/common/

          tez_home=`find /opt/app -maxdepth 1 -name "*tez*"`
          hive_home=`find /opt/app -maxdepth 1 -name "*hive*"`

          #4.配置hive-env.sh文件
          configureHiveEnv $hive_home/conf/hive-env.sh $tez_home
          
          #5.配置tez-site.sh文件
          tezName=`echo $tezInfo | awk -F'.tar' '{print $1}'`
          configureTezSite $hive_home/conf $tezName

          #6.配置hive-site.sh文件
          configureHiveSite $hive_home/conf/hive-site.xml

          # 上传tez到HDFS中
          hadoop fs -mkdir /tez
          hadoop fs -put $tez_home /tez

          echo "Tez安装成功"
     else
         echo "/opt/frames目录下没有tez安装包"
     fi
 else
     echo "tez不允许被安装"
 fi
}

installTez
