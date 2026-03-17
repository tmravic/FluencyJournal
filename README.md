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

## Kamal deployment to single EC2
`aws ec2 describe-vpcs`

`aws ec2 create-security-group --group-name "fluency-journal-sg" --description "For Kamal deploy" --vpc-id vpc-3dcc365b`

```bash
aws ec2 authorize-security-group-ingress --group-name fluency-journal-sg --protocol tcp --port 22 --cidr 0.0.0.0/0 && \
aws ec2 authorize-security-group-ingress --group-name fluency-journal-sg --protocol tcp --port 80 --cidr 0.0.0.0/0 && \
aws ec2 authorize-security-group-ingress --group-name fluency-journal-sg --protocol tcp --port 443 --cidr 0.0.0.0/0
```
`aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=architecture,Values=x86_64" --query "Images | sort_by(@, &CreationDate) | [-1].[ImageId]" --output text`

Replace <sg-fluency-journal-sg> and ami

`aws ec2 run-instances --image-id ami-02dc59944bc69e802 --count 1 --instance-type t3.small --key-name fluency_journal_demo --security-group-ids sg-01f56775d44169bf2 --associate-public-ip-address`

Get instance-id
`aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId"`

Get IP address
`aws ec2 describe-instances --instance-ids i-0316cfead9ad8c666 --query "Reservations[].Instances[].PublicIpAddress" --output text`

SSH into host
`ssh -i ~/.ssh/fluency_journal_demo.pem ubuntu@13.230.239.138`

```bash
sudo apt update && \
sudo apt install -y docker.io && \
sudo usermod -aG docker ubuntu && \
sudo systemctl enable docker && \
sudo systemctl status docker

exit
```
`bundle exec kamal setup`<br>
`kamal app exec -i 'bin/rails db:prepare'`<br>
`kamal deploy`<br>
(For an update)<br>
`kamal accessory reboot solid_queue`<br>
`kamal accessory reboot solid_cable`<br>
`kamal app exec -i 'bin/rails console'`

Check containers<br>
`kamal app containers`<br>
`kamal details`

If you see "unable to remove repository reference" run:<br>
`kamal accessory reboot solid_cable / solid_queue`

## How to take down the Kamal instance and salvage the DB records
Get the IP address from [config/deploy.yml](config/deploy.yml)<br>
SSH into the instance<br>
`ssh -i ~/.ssh/fluency_journal_demo.pem ubuntu@3.112.246.169`<br>
`docker ps -a`<br>
`docker exec -it a7cf031c4994 bash` # the postgres one <br>
`pg_dump -U fluency_journal -d fluency_journal_production > primary_dump.sql`<br>
You can copy the text with `cat primary_dump.sql` into a similarly-named file locally.

```bash
aws ec2 describe-instances
aws ec2 terminate-instances --instance-ids i-047bf70413bc40e54
aws ec2 delete-security-group --group-id sg-0ba4d56db09d1997e
```

## How to use ngrok
```
ngrok http 3000
```

## How to check montly costs
# Cost and billing check (month to-date)
- `aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) --granularity MONTHLY --metrics BlendedCost`
