#! /bin/bash

# 配置集群统一采集脚本
function configFlumeShell()
{

# 获取Flume安装目录
flume_home=$1
nodes=$2

cat >> $flume_home/bin/flume.sh <<EOF
#! /bin/bash

if [ ! -n "\$1" ]; then
    echo "请输入指令start 或 stop"
    exit
fi

if [ ! -n "\$2" ]; then
    echo "请输入flume-ng配置文件名，配置文件存放在flune的conf目录下"
    echo "eg: flume.sh start fileName"
     echo "eg: flume.sh stop fileName"
    exit
fi

if [ ! -n "\$3" ]; then
    isAll="false"
else
    if [ \$3 = "all" ]; then
        isAll="true"
    else 
        echo "非法参数，参数应为all"
        exit
    fi
fi

configFile=\$2
fileName=`echo \$2 | cut -d "." -f1`

case \$1 in
"start"){
        if [ \$isAll = "true" ]; then
            for i in ${nodes[*]}
            do
                    echo " --------启动 \$i flume-------"

                    ssh -n \$i "source /etc/profile && nohup $flume_home/bin/flume-ng agent --conf-file \$configFile --name a1 -Dflume.root.logger=INFO,LOGFILE >/dev/null 2>&1 &"
            done
        else
            source /etc/profile && nohup $flume_home/bin/flume-ng agent --conf-file \$configFile --name a1 -Dflume.root.logger=INFO,LOGFILE >/dev/null 2>&1 &
        fi
};;
"stop"){
    if [ \$isAll = "true" ]; then
        for i in ${nodes[*]}
        do
                echo " --------停止 \$i flume-------"
                ssh -n \$i "source /etc/profile && ps -ef | grep \$fileName | grep -v grep |awk '{print \\$2}' | xargs kill"
        done
    else
        source /etc/profile && ps -ef | grep \$fileName | grep -v grep |awk '{print \$2}' | xargs kill
    fi
};;
esac

EOF

# 为脚本赋权
chmod +x $flume_home/bin/flume.sh

}

function configFlumeEnv()
{
 flumeEnvUrl=$1
 
 cp $flumeEnvUrl.template $flumeEnvUrl

 # 配置JAVA_HOME
 profile=/etc/profile
 java_home=`egrep "^export JAVA_HOME=" $profile`
 
 echo "$java_home" >> $flumeEnvUrl

 # 配置JVM
 echo "export JAVA_OPTS=\"-Xms100m -Xmx2000m -Dcom.sun.management.jmxremote\"" >>  $flumeEnvUrl
}

function installFlume()
{
 #1.在frames.txt中查看是否需要安装flume
 flumeInfo=`egrep "flume" /home/hadoop/automaticDeploy/frames.txt`
 
 flume=`echo $flumeInfo | cut -d " " -f1`
 isInstall=`echo $flumeInfo | cut -d " " -f2`
 installNode=`echo $flumeInfo | cut -d " " -f3`
 node=`hostname`
 
 #是否安装
 if [[ $isInstall = "true" && $installNode =~ $node ]];then
    
    #2.查看/opt/frames目录下是否有flume安装包
    flumeIsExists=`find /opt/frames -name $flume`
    if [[ ${#flumeIsExists} -ne 0 ]];then
        if [[ ! -d /opt/app ]];then
            mkdir /opt/app && chmod -R 775 /opt/app
        fi
   
        #删除旧的
        flume_home_old=`find /opt/app -maxdepth 1 -name "*flume*"`
        for i in $flume_home_old;do
            rm -rf $i
        done

        #3.解压到指定文件夹/opt/app中
        echo "开始解压flume安装包"
        tar -zxvf $flumeIsExists -C /opt/app >& /dev/null
        echo "flume安装包解压完毕"

        flume_home=`find /opt/app -maxdepth 1 -name "*flume*"`

        configFlumeEnv $flume_home/conf/flume-env.sh

        # 配置flume启动脚本
        OLD_IFS="$IFS" #保存旧的分隔符
        IFS=","
        nodes=($installNode)
        IFS="$OLD_IFS" # 将IFS恢复成原来的

        configFlumeShell $flume_home $nodes

        #4.配置FLUME_HOME
        profile=/etc/profile
        sed -i "/^export FLUME_HOME/d" $profile
        echo "export FLUME_HOME=$flume_home" >> $profile

        #5.配置PATH
        sed -i "/^export PATH=\$PATH:\$FLUME_HOME\/bin/d" $profile
        echo "export PATH=\$PATH:\$FLUME_HOME/bin:" >> $profile

        #6.更新/etc/profile文件
        source /etc/profile && source /etc/profile
    else
        echo "/opt/frames目录下没有flume安装包"
    fi
 else
     echo "Flume不允许被安装在当前节点"
 fi

}

installFlume
