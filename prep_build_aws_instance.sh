#!/usr/bin/bash

      HOST_IP="3.16.36.39"
    HTTP_PORT="80"

      MY_HOME="/home/dnorris"
     EC2_HOME="/home/ec2-user"
   SOURCE_DIR="${MY_HOME}/homework/hello-python"
DB_SCRIPT_DIR="${MY_HOME}/homework/scriptfiles"
     PEM_FILE="${MY_HOME}/dockerdave00_aws_instance_keypair.pem"
 RSA_KEY_FILE="${MY_HOME}/.ssh/id_rsa.pub"
  TARGET_FILE="${EC2_HOME}/.ssh/authorized_keys"

echo -e "\nScript start"
echo -e "Preparing to copy files to instance"

for FILE in app.py \
    	    docker-compose.yaml \
	    init.sql \
	    requirements.txt \
	    postgres_setup.sh
	do
		if [ ${FILE} != "postgres_setup.sh" ]; then
			echo -e "\tCopying ${FILE}"
			 scp -i ${PEM_FILE} ${SOURCE_DIR}/${FILE} ec2-user@${HOST_IP}:./ 2<&1 > /dev/null
	
			if [ ${FILE} == "app.py" ]; then
				echo -e "\t\tChanging permissions on ${FILE}"
				ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "chmod 755 ${FILE}"
			fi
		else
			echo -e "\tCopying ${FILE}"
			scp -i ${PEM_FILE} ${DB_SCRIPT_DIR}/${FILE} ec2-user@${HOST_IP}:./ 2<&1 > /dev/null
	
			if [ ${FILE} == "postgres_setup.sh" ]; then
				echo -e "\t\tChanging permissions on ${FILE}"
				ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "chmod 755 ${FILE}"
			fi
		fi
	done

echo -e "\nSetting up instance"
echo -e "\tyum: Verify system is up to date"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo yum update" 2<&1 > /dev/null

echo -e "\tyum: Install docker"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "echo y | sudo amazon-linux-extras install docker" 2<&1 > /dev/null
#ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "echo y | sudo amazon-linux-extras install docker"

echo -e "\tusermod: Add ec2-user to docker group"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo usermod -a -G docker ec2-user" 2<&1 > /dev/null
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo grep docker /etc/group" )
echo -e "\t\tDocker group info: ${RESULT}"

echo -e "\tdocker: Get docker info"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo docker info | grep Server\ Version:")
echo -e "\t\tDocker server version: ${RESULT}"

echo -e "\tsystemctl: Start docker service"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo systemctl start docker"

echo -e "\tsystemctl: Verify docker service"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo systemctl status docker | grep Active | sed -e 's/^ *//g'")
echo -e "\t\tDocker status: ${RESULT}"

echo -e "\tifconfig: Display instance IPs"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo ifconfig eth0 | grep inet\  | sed -e 's/^ *//g'")
echo -e "\t\tServer eth0 address: $(echo ${RESULT}| awk '{print $2}')"

echo -e "\tifconfig: Display instance IPs"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo ifconfig docker0 | grep inet\  | sed -e 's/^ *//g'")
echo -e "\t\tServer docker0 address: $(echo ${RESULT}| awk '{print $2}')"

echo -e "\tdocker: Installing docker compose"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m` \
                                      | sudo tee /usr/local/bin/docker-compose > /dev/null" 2<&1 > /dev/null

echo -e "\tdocker: Setup docker compose permissions"
ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo chmod +x /usr/local/bin/docker-compose"

echo -e "\tdocker: Setup docker compose link"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo ls -al /usr/bin/docker-compose 2<&1")
if [ "${RESULT}" != "/usr/bin/docker-compose" ]; then
	ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose"
fi

echo -e "\tdocker compose: Verify docker compose version"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "docker-compose --version")
echo -e "\t\tDocker status: ${RESULT}"

echo -e "\tdocker compose: Fix flask image definition"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sed -i 's/image: hello:latest/image: davidwnorrisjr\/hello-python:latest/g' docker-compose.yaml")

echo -e "\tdocker compose: Fix flask port definition"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sed -i 's/- 5000:5000/- 80:5000/g' docker-compose.yaml")

echo -e "\tdocker compose: Bringing up docker containers"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "docker-compose up --force-recreate --build -d")

echo -e "\tpostgres_setup: Run postgres_setup.sh script on instance"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "sudo /home/ec2-user/postgres_setup.sh")

echo -e "\tdocker: Restarting flask_server container"
RESULT=$(ssh -i ${PEM_FILE} ec2-user@${HOST_IP} "docker start flask_server")

echo -e "\tnetcat: Checking port 80 setup in security group"
RESULT=$(nc -z -v -w1 ${HOST_IP} ${HTTP_PORT} 2<&1)
sleep 5
SUCCESS="80 port [tcp/http] succeeded"
while [[ ${RESULT} != *"${SUCCESS}"* ]]
	do
		echo -e "\t\tERROR: HTTP port 80 NOT setup in security group."
		echo -e "\t\tHIT RETURN TO CONTINUE...\r\c"
		read CONTINUE
		RESULT=$(nc -z -v -w1 ${HOST_IP} ${HTTP_PORT} 2<&1)
	done
echo -e "\t\tPort 80 available"

echo -e "Script complete\n"
