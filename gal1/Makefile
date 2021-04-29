all:
	galasm iodecode.pld
	galasm memdecode.pld

upload_io:
	minipro -P -p ATF16v8b -w iodecode.jed

upload_mem:
	minipro -P -p ATF16v8b -w memdecode.jed
