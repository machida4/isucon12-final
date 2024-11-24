.DEFAULT_GOAL := help

## 変えるところ
SERVICE:=isuconquest.go.service

## 定数

MYSQL_SLOW_LOG:=/var/log/mysql/mysql-slow.log
NGINX_LOG:=/var/log/nginx/access.log
NGINX_ERROR_LOG:=/var/log/nginx/error.log

ALP_LOG:=alp.txt
DIGEST_LOG:=digest.txt

DISCORD_WEBHOOK_URL:=${DISCORD_WEBHOOK_URL}

define MYSQL_CONFIG
[mysqld]
slow_query_log=ON
long_query_time=0
slow_query_log_file=/var/log/mysql/mysql-slow.log
endef
export MYSQL_CONFIG

## Common

restart: ## Restart all
	@git pull
	@make -s nginx-restart
	@make -s db-restart
	@make -s app-restart

report: ## Generate monitoring report
	@make -s alp
	@make -s digest

restart-1: ## Restart for Server 1
	@make -s restart

restart-2: ## Restart for Server 2
	@make -s restart

restart-3: ## Restart for Server 3
	@make -s restart

## App

app-restart: ## Restart Server
	@cd go; go build -o isuconquest .
	@sudo systemctl daemon-reload
	@sudo systemctl restart $(SERVICE)
	@echo 'Restart service'

app-log: ## Tail server log
	@sudo journalctl -f -n10 -u $(SERVICE)

## Nginx

nginx-restart: ## Restart nginx
	@sudo cp /dev/null $(NGINX_LOG)
	@sudo cp -aT ./nginx /etc/nginx/
	@echo 'Validate nginx.conf'
	@sudo nginx -t
	@sudo systemctl restart nginx
	@echo 'Restart nginx'

nginx-log: ## Tail nginx access.log
	@sudo tail -f $(NGINX_LOG)

nginx-error-log: ## Tail nginx error.log
	@sudo tail -f $(NGINX_ERROR_LOG)

## Alp
# 1xxを除いて少し並べかえる
alp: ## Run alp
	sudo alp ltsv --file $(NGINX_LOG) --sort sum --reverse \
	--matching-groups='/transactions/\d+\.png, /upload/[0-9a-f]+\.jpg, /static/js/.+, /initialize$$ , /new_items.json$$ , /new_items/\d+.json$$ , /users/transactions.json$$ , /users/\d+.json$$ , /items/\d+.json$$ , /items/edit$$ , /buy$$ , /sell$$ , /ship$$ , /ship_done$$ , /complete$$ , /transactions/{transaction_evidence_id}.png$$ , /bump$$ , /settings$$ , /login$$ , /register$$ , /reports.json$$ , /$$ , /login$$ , /register$$ , /timeline$$ , /categories/\d+/items$$ , /sell$$ , /items/\d+$$ , /items/\d+/edit$$ , /items/\d+/buy$$ , /buy/complete$$ , /transactions/\d+$$ , /users/\d+$$ , /users/setting$$' \
	-o 'count,2xx,3xx,4xx,5xx,method,uri,sum,avg,min,max,p90,p95,p99,stddev,min_body,max_body,sum_body,avg_body'\
	> $(ALP_LOG)
	echo $(DISCORD_WEBHOOK_URL)
	@DISCORD_WEBHOOK_URL=$(DISCORD_WEBHOOK_URL) ./dispost -f $(ALP_LOG)

## DB

db-restart: ## Restart mysql
	@sudo cp /dev/null $(MYSQL_SLOW_LOG)
	-@sudo cp -L my.cnf /etc/mysql/
	@sudo systemctl restart mysql
	@echo 'Restart mysql'

digest: ## Analyze mysql-slow.log by pt-query-digest
	@sudo pt-query-digest $(MYSQL_SLOW_LOG) > $(DIGEST_LOG)
	@DISCORD_WEBHOOK_URL=$(DISCORD_WEBHOOK_URL) ./dispost -f $(DIGEST_LOG)

## etc

.PHONY: log
log: ## Tail journalctl
	@sudo journalctl -f

show-running-services: ## Show running systemctl service units
	@sudo systemctl list-units --type=service --state=running

.PHONY: help
help:
	@grep -E '^[a-z0-9A-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

## Setup
.PHONY: setup, setup-alp, setup-slow-query, setup-git, setup-shell

setup: dispost setup-alp setup-slow-query setup-git setup-shell ## Setup

dispost: ## Setup dispost
	@wget https://raw.githubusercontent.com/machida4/dispost/refs/heads/master/dispost
	@sudo chmod 766 dispost

setup-alp: ## Setup alp
	@wget https://gist.githubusercontent.com/machida4/83b84fdc4f39f2066def530e473c9231/raw/b1f8b9445a3525d5a14a8e5edad1ab0a3b756254/install_alp.sh
	@sudo chmod u+x install_alp.sh
	./install_alp.sh
	rm install_alp.sh
	rm alp_linux_amd64.zip

setup-slow-query: ## Setup pt-query-digest
	@wget https://gist.githubusercontent.com/machida4/83b84fdc4f39f2066def530e473c9231/raw/b1f8b9445a3525d5a14a8e5edad1ab0a3b756254/install_pt-query-digest.sh
	@chmod u+x install_pt-query-digest.sh
	./install_pt-query-digest.sh	

	@echo "create mysql-slow.log"
	@sudo touch $(MYSQL_SLOW_LOG)
	@sudo chmod 777 $(MYSQL_SLOW_LOG)
	@echo "mysql-slow.log is created"

	@echo "setup my.cnf"
	echo "$${MYSQL_CONFIG}" | sudo tee -a my.cnf
	@make -s db-restart

	rm install_pt-query-digest.sh
	rm v3.3.1.tar.gz

setup-git: ## Setup git
	which git || sudo apt install -y git
	git config --global user.email isucon@example.com
	git config --global user.name isucon
	@if ! [ -f ~/.ssh/id_ed25519 ]; then\
		mkdir -p ~/.ssh;\
		ssh-keygen -t ed25519 -N "" -f "$${HOME}/.ssh/id_ed25519";\
		echo "register ~/.ssh/id_ed25519.pub to github.com";\
	fi
	sudo ls ./nginx 2>/dev/null || sudo cp -a /etc/nginx ./nginx
	sudo cp -L /etc/mysql/my.cnf ./my.cnf
	git init

define GIT_PS1
source ~/.git-completion.bash
source ~/.git-prompt.sh
GIT_PS1_SHOWDIRTYSTATE=true
GIT_PS1_SHOWUNTRACKEDFILES=true
GIT_PS1_SHOWSTASHSTATE=true
GIT_PS1_SHOWUPSTREAM=auto
PS1="\[\\e[1;32m\]\u@\h\[\\e[m\]:\[\\e[1;34m\]\W\[\\e[m\]\[\\e[33m\]\$$(__git_ps1)\[\\e[m\]\$$ "
endef
export GIT_PS1

setup-shell: ## Setup shell
	wget https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -O ~/.git-completion.bash
	wget https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -O ~/.git-prompt.sh
	echo "$${GIT_PS1}" > .git_ps1.bash
	grep git_ps1.bash ~/.bashrc || echo 'source "$(CURDIR)/.git_ps1.bash"' >> ~/.bashrc
## get alp group (makefile内のalpに渡す時に$は$$でエスケープする必要があるので末尾の$を重ねる実装をしている)
#cat webapp/go/main.go | grep -E 'GET|POST|PUT|DELETE' | sed -E 's/.*\"(.+)\".*/\1$$/' | sed -E 's/:id/[0-9]+/' | perl -pe 's/\n/ , /g'

