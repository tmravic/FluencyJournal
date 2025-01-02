# README

* Ruby version: 3.3.6
* Rails version: 8.0.0
* Node version: v20.18.0
* Yarn version: 1.22.22
* npm Version: 10.9.0

## How I made this app
This app was created by initializing a new rails app within a Ruby docker container.
- `docker run -i -t --rm -v ${PWD}:/usr/src/app ruby:latest bash`
- `cd /usr/src/app`
```
touch ~/.bashrc \
&& curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash \
&& source ~/.bashrc \
&& nvm install --lts \
&& npm install -g yarn \
&& gem install rails \
&& rails new fluency_journal --database postgresql --css sass --skip-test -T   \
&& cd fluency_journal/ \
```

## Docker
- Build command
```
docker compose build --build-arg USER=$(whoami) --build-arg UID=$(id -u) --build-arg GID=$(id -g) --no-cache
```
- Create the database
  `docker compose run --rm web rails db:create`



- Total reset deleting all Fluency Journal resources:
```
docker compose down && \
docker rmi -f fluency_journal-cable:latest fluency_journal-css:latest fluency_journal-js:latest fluency_journal-web:latest fluency_journal-worker:latest && \
docker volume rm -f fluency_journal_bundle fluency_journal_postgres fluency_journal_redis fluency_journal_node_modules
```

- [x] Can run yarn --version and npm --version
- [x] Can install a node_module like: `npm install lodash --save`

## Redis
WARNING Memory overcommit must be enabled! Without it, a background save or replication may fail under low memory<br>
condition. Being disabled, it can also cause failures without low memory condition, see<br>
https://github.com/jemalloc/jemalloc/issues/1328. To fix this issue add 'vm.overcommit_memory = 1' to /etc/sysctl.conf<br>
and then reboot or run the command 'sysctl vm.overcommit_memory=1' for this to take effect.

`echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf`

