install :
	cp lenon-judge-main.sh lenon /usr/bin/;

uninstall :
	rm /usr/bin/lenon-judge-main.sh /usr/bin/lenon;

update :
	git pull && make install;
