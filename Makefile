SOURCE_DIR=/home/artemis/perl510/lib/site_perl/5.10.0/Artemis/
DEST_DIR=/opt/artemis/lib/perl5/site_perl/5.10.0/Artemis/


live:
	./scripts/dist_upload_wotan.sh
	ssh artemis@bancroft "sudo /opt/artemis/bin/cpan  Artemis::MCP"
devel:
	perl Build.PL
	./Build install
