.PHONY: *

gogo: stop-services build truncate-logs start-services bench

build:
	cd go && make all

stop-services:
	sudo systemctl stop nginx
	sudo systemctl stop isucholar.go.service
	ssh s3 "sudo systemctl stop mysql"

start-services:
	ssh s3 "sudo systemctl start mysql"
	sleep 5
	sudo systemctl start isucholar.go.service
	sudo systemctl start nginx

truncate-logs:
	sudo truncate --size 0 /var/log/nginx/access.log
	sudo truncate --size 0 /var/log/nginx/error.log
	ssh s3 "sudo truncate --size 0 /var/log/mysql/mysql-slow.log"
	ssh s3 "sudo chmod 777 /var/log/mysql/mysql-slow.log"
	sudo journalctl --vacuum-size=1K

kataribe: 
	cd ../ && sudo cat /var/log/nginx/access.log  | ./kataribe	

pprof: TIME=60
pprof: PROF_FILE=~/pprof.samples.`TZ=Asia/Tokyo date +"%H%M"`.`git rev-parse HEAD | cut -c 1-8`.pb.gz
pprof:
	echo $(PROF_FILE)
	curl -sSf "http://localhost:6060/debug/fgprof?seconds=$(TIME)" > $(PROF_FILE)
	go tool pprof $(PROF_FILE)

bench:
	ssh bench "cd ./benchmarker/ && ./bin/benchmarker -target 172.31.13.72:443 -tls"
