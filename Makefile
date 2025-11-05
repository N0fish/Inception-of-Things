SHELL := /bin/bash

help:
	@echo "Usage:"
	@echo "  make install      - 
	@echo
	@echo "Local:"
	@echo "  make start        - 
	@echo "  make clean        - 
	@echo "  make fclean       - 
	@echo "  make re           - 
	@echo


clean:


fclean: clean
	

re: fclean install

.PHONY: help \
	clean fclean re
