#! /bin/bash

# 配置kafka启动、停止脚本
function configKafkaShell()
{

# 获取Kafka安装目录
kafka_home=$1
nodes=$2

cat >> $kafka_home/bin/kafka.sh <<EOF
#! /bin/bash

case \$1 in
"start"){
        for i in ${nodes[*]}
        do
                echo " --------启动 \$i kafka-------"
                # 用于KafkaManager监控

                ssh \$i "source /etc/profile && export JMX_PORT=9988 && $kafka_home/bin/kafka-server-start.sh -daemon $kafka_home/config/server.properties "
        done
};;
"stop"){
        for i in ${nodes[*]}
        do
                echo " --------停止 \$i kafka-------"
                ssh \$i "source /etc/profile && $kafka_home/bin/kafka-server-stop.sh"
        done
};;
esac

EOF

# 为脚本赋权
chmod +x $kafka_home/bin/kafka.sh

}

function installKafka()
{
  #1.在frames.txt中查看是否需要安装kafka
 kafkaInfo=`egrep "^kafka" /home/hadoop/automaticDeploy/frames.txt`
 zkInfo=`egrep "^zookeeper" /home/hadoop/automaticDeploy/frames.txt`
 zkNode=`echo $zkInfo | cut -d " " -f3`
 zkIsInstall=`echo $zkInfo | cut -d " " -f2`

 kafka=`echo $kafkaInfo | cut -d " " -f1`
 isInstall=`echo $kafkaInfo | cut -d " " -f2`
 installNode=`echo $kafkaInfo | cut -d " " -f3`
 node=`hostname`
 
 # 是否安装
 if [[ $isInstall = "true" && $installNode =~ $node ]];then
     
     if [ $zkIsInstall = "true" ];then
     
        # 查看/opt/frames目录下是否有kafka安装包
        kafkaIsExists=`find /opt/frames -name $kafka`
        
        if [[ ${#kafkaIsExists} -ne 0 ]];then
            
            if [[ ! -d /opt/app ]];then
                mkdir /opt/app && chmod -R 775 /opt/app
            fi
    
            # 删除旧的
            kafka_home_old=`find /opt/app -maxdepth 1 -name "kafka*"`
            for i in $kafka_home_old;do
                    rm -rf $i
            done

            # 解压到指定文件夹/opt/app中
            echo "开始解压kafka安装包"
            tar -zxvf $kafkaIsExists -C /opt/app >& /dev/null
            echo "kafka安装包解压完毕"
            
            kafka_home=`find /opt/app -maxdepth 1 -name "kafka*"`
            
            # 修改配置文件server.properties
            serverUrl=$kafka_home/config/server.properties
            zkUrl=""
            # broker_id=0

            #遍历配置Kafka服务节点
            OLD_IFS="$IFS" #保存旧的分隔符
            IFS=","
            nodes=($installNode)
            IFS="$OLD_IFS" # 将IFS恢复成原来的
            for i in "${!nodes[@]}"; do
                # 拼接生成Zookeeper服务地址  
                if [[ $zkUrl = "" ]];then
                    zkUrl="${nodes[i]}:2181"
                else
                    zkUrl="$zkUrl,${nodes[i]}:2181"
                fi

                if [[ ${nodes[i]} = $node ]];then
                # 配置当前节点服务地址    
                num=`sed -n -e "/#listeners=PLAINTEXT:\/\/:9092/=" $serverUrl`
                sed -i "${num}a listeners=PLAINTEXT:\/\/${nodes[i]}:9092" $serverUrl
                # 配置broker id
                broker_num=`sed -n -e "/broker.id=0/=" $serverUrl`
                sed -i 's/broker.id=0/#&/' $serverUrl
                sed -i "${broker_num}a broker.id=$i" $serverUrl
                # broker.id=0
                #    echo "$i" > $zk_home/data/myid
                fi
            done

            num_zk=`sed -n -e "/zookeeper.connect=localhost:2181/=" $serverUrl`
            sed -i 's/zookeeper.connect=localhost:2181/#&/' $serverUrl
            sed -i "${num_zk}a zookeeper.connect=$zkUrl" $serverUrl

            # 配置日志保存   
            num_log=`sed -n -e "/log.dirs=\/tmp\/kafka-logs/=" $serverUrl`
            sed -i 's/log.dirs=\/tmp\/kafka-logs/#&/' $serverUrl
            sed -i "${num_log}a log.dirs=${kafka_home}/logs" $serverUrl
            mkdir $kafka_home/logs

            configKafkaShell $kafka_home $nodes
            
            # 配置KAFKA_HOME
            profile=/etc/profile
            sed -i "/^export KAFKA_HOME/d" $profile
            echo "export KAFKA_HOME=$kafka_home" >> $profile

            # 配置PATH
            sed -i "/^export PATH=\$PATH:\$KAFKA_HOME\/bin/d" $profile
            echo "export PATH=\$PATH:\$KAFKA_HOME/bin" >> $profile

            # 更新/etc/profile文件
            source /etc/profile && source /etc/profile
        else
            echo "/opt/frames目录下没有kafka安装包"
        fi
    else
        echo "Zookeeper未安装，请先完成Zookeper的安装"
    fi
 else
     echo "Kafka不允许被安装在当前节点"
 fi
}

installKafka
