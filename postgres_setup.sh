#!/bin/bash

#set -x

# Simplify commands with single word
STOP="docker stop"
CONT="docker container rm"
RUN="docker run"
EXEC="docker exec"

echo -e "\tCheck if postgres container is running"
postgres_container_id=$(docker ps -a | grep postgres_db | awk '{print $1}')

if [ "${postgres_container_id}" ]; then

	echo -e "\t\tStopping postgres container"
	result1=$(${STOP} postgres_db)
	if [ ${result1} != "postgres_db" ]; then
		echo -e "\t\tContainer stop failed"
		exit 1
	fi
	sleep 1 

	if [ "${postgres_container_id}" ]; then
		echo -e "\t\tRemoving container"
		result2=$(${CONT} ${postgres_container_id})
		if [ ${result2} != ${postgres_container_id} ]; then
			echo -e "\t\tContainer remove failed"
			exit 1
		fi
	fi
	
fi
sleep 1 


#-v /var/lib/postgresql/data:/var/lib/postgresql/data \
echo -e "\tStarting postgres database container"
result3=$(${RUN} --name postgres_db \
		  -p 5432:5432 \
		  -e POSTGRES_USER=postgres \
		  -e POSTGRES_PASSWORD=postgres \
		  -d postgres:13.2)
	          # -it \
if [ ! "${result3}" ]; then
	echo -e "\t\tDatabase container not created"
	exit 1
fi
sleep 1 # give docker/psql time to complete

echo -e "\tCreating 'hello' database"
# result4=$(${EXEC} -it postgres_db psql --username postgres -a -c 'CREATE DATABASE hello;')
result4=$(${EXEC} postgres_db psql --username postgres -a -c 'CREATE DATABASE hello;')
# modify command result output down to simple, usable string
result4_mod=$(echo ${result4} | tr '\r\n' ' ' | awk -F\; '{print $2}' | xargs)
if [ "${result4_mod}" != "CREATE DATABASE" ]; then
	echo -e "\t\t'hello' database not created"
	exit 1
fi
sleep 1 # give docker/psql time to complete

echo -e "\tCreating 'users' table in 'hello' database"
# result5=$(${EXEC} -it postgres_db psql --username postgres -d hello -a -c \
result5=$(${EXEC} postgres_db psql --username postgres -d hello -a -c \
	'CREATE TABLE users (id SERIAL PRIMARY KEY, name varchar, address varchar, phone varchar);')
# modify command result output down to simple, usable string
result5_mod=$(echo ${result5} | tr '\r\n' ' ' | awk -F\; '{print $2}' | xargs)
if [ "${result5_mod}" != "CREATE TABLE" ]; then
	echo -e "\t\t'users' table not created in 'hello' database"
	exit 1 
fi
sleep 1 # give docker/psql time to complete

echo -e "\tPopulating a row of 'users' table in 'hello' database"
# result6=$(${EXEC} -it postgres_db psql --username postgres -d hello -a -c \
result6=$(${EXEC} postgres_db psql --username postgres -d hello -a -c \
	"INSERT INTO users(name, address, phone) VALUES ('Teresa', '1234 W Main Street', '123-456-7890');")
# modify command result output down to simple, usable string
result6_mod=$(echo ${result6} | tr '\r\n' ' ' | awk -F\; '{print $2}' | xargs)
if [ "${result6_mod}" == "INSERT 0 1" ]; then
	echo -e "\t\t** Value store successful **"
else
	echo -e "\tValue store failure"
	exit 1
fi

echo -e "\tPopulating next row of 'users' table in 'hello' database"
# result7=$(${EXEC} -it postgres_db psql --username postgres -d hello -a -c \
result7=$(${EXEC} postgres_db psql --username postgres -d hello -a -c \
	"INSERT INTO users(name, address, phone) VALUES ('Dave', '1234 W Main Street', '123-456-7891');")
# modify command result output down to simple, usable string
result7_mod=$(echo ${result7} | tr '\r\n' ' ' | awk -F\; '{print $2}' | xargs)
if [ "${result7_mod}" == "INSERT 0 1" ]; then
	echo -e "\t\t** Value store successful **"
else
	echo -e "\t\tValue store failure"
	exit 1
fi

echo -e "\n\tDisplaying contents of 'hello' database, 'users' table\n"
# RESULTS=$(${EXEC} -it postgres_db psql --username postgres -d hello -a -c "SELECT * FROM users;")
RESULTS=$(${EXEC} postgres_db psql --username postgres -d hello -a -c "SELECT * FROM users;")
echo -e "\t${RESULTS}"

# ----------------------------------------

echo -e "\tCheck if redis container is running"
redis_container_id=$(docker ps -a | grep redis_db | awk '{print $1}')

if [ "${redis_container_id}" ]; then

	echo -e "\tStopping redis container"
	result1a=$(${STOP} redis_db)
	if [ ${result1a} != "redis_db" ]; then
		echo -e "\t\tContainer stop failed"
		exit 1
	fi
	sleep 1 

	if [ "${redis_container_id}" ]; then
		echo -e "\tRemoving container"
		result2a=$(${CONT} ${redis_container_id})
		if [ ${result2a} != ${redis_container_id} ]; then
			echo -e "\t\tContainer remove failed"
			exit 1
		fi
	fi

fi
sleep 1 

echo -e "\tStarting redis container"
# result3a=$(${RUN} --name redis_db -it -p 6379:6379 -d redis:6.2.3)
result3a=$(${RUN} --name redis_db -p 6379:6379 -d redis:6.2.3)
if [ ! "${result3a}" ]; then
	echo -e "\t\tRedis container not created"
	exit 1
fi
sleep 1 # give docker time to complete

exit
