NAME		= inception

LOGIN		= bbeaurai
DATA_DIR	= /home/$(LOGIN)/data

SRCS_DIR	= srcs
COMPOSE_FILE	= $(SRCS_DIR)/docker-compose.yml
COMPOSE		= docker compose -f $(COMPOSE_FILE)

SECRETS_DIR	= secrets

all: up

up: data-dirs secrets
	$(COMPOSE) up -d --build

build: secrets
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

data-dirs:
	mkdir -p $(DATA_DIR)/mariadb
	mkdir -p $(DATA_DIR)/wordpress

secrets: $(SECRETS_DIR)/db_password.txt $(SECRETS_DIR)/db_root_password.txt $(SECRETS_DIR)/credentials.txt

$(SECRETS_DIR)/db_password.txt:
	mkdir -p $(SECRETS_DIR)
	openssl rand -base64 24 > $@

$(SECRETS_DIR)/db_root_password.txt:
	mkdir -p $(SECRETS_DIR)
	openssl rand -base64 24 > $@

$(SECRETS_DIR)/credentials.txt:
	mkdir -p $(SECRETS_DIR)
	{ \
		echo "WP_ADMIN_PASSWORD=$$(openssl rand -base64 16)"; \
		echo "WP_USER_PASSWORD=$$(openssl rand -base64 16)"; \
	} > $@

clean: down
	docker system prune -f

fclean: down
	docker system prune -af --volumes
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up build down stop start restart logs ps data-dirs clean fclean re
