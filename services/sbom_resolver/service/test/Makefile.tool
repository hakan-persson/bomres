#
# Work in progress 
#
build: 
	echo "FROM alpine_sandbox_base_os:3.14.1" > Containerfile
	docker build .  -f Containerfile -t abuilder

PACKAGE=pcre
abuild: 
	mkdir -p apk
	docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root build PACKAGE=$(PACKAGE)

shell:
	docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest sh 


REPOS =  $(shell ls alpine/build/base_os/source/repo )

ECHO      = $(shell which echo 2> /dev/null)
CMD=all
CMD=pre
ARCH=x86_64

VERIFY_LOG=verify.log

check:
	rm -f $(VERIFY_LOG)
	@for repo in ${REPOS};                   \
	do                                      \
	for i in `ls alpine/build/base_os/source/repo/$${repo}`;             \
	do                                  \
		if docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root check ARCH=${ARCH} PACKAGE=$${i} REPO=$${repo} ; then \
		   $(ECHO) -e "passed\t$${repo}\t$${i}" >> $(VERIFY_LOG);  \
                else \
		   $(ECHO) -e "failed\t$${repo}\t$${i}" >> $(VERIFY_LOG);  \
                fi \
	done                                \
	done
	sort -r $(VERIFY_LOG) >  /tmp/check.$$$$ ; cp  /tmp/check.$$$$   $(VERIFY_LOG)

PROGRESS_LOG=verify.log

pkg:
	rm -f $(PROGRESS_LOG)
	@for repo in ${REPOS};                   \
	do                                      \
	for i in `ls alpine/build/base_os/source/repo/$${repo}`;             \
	do                                  \
		$(ECHO) -e "start\t$${repo}\t$${i}" >> $(PROGRESS_LOG);  \
		if docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root check ARCH=${ARCH} PACKAGE=$${i} REPO=$${repo} ; then \
		   docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root build ARCH=${ARCH} PACKAGE=$${i} REPO=$${repo} ; \
		   tm=`date +"%s"`; \
		   $(ECHO) -e "$$tm\tstop\tOK" >> $(PROGRESS_LOG);  \
                else \
		   tm=`date +"%s"`; \
		   $(ECHO) -e "$$tm\tstop\tError" >> $(PROGRESS_LOG);  \
                fi \
	done                                \
	done

keygen:
	mkdir -p pki 
	openssl genrsa -out pki/iafw.rsa 1024
	openssl rsa -in pki/iafw.rsa -pubout > pki/iafw.rsa.pub
	chmod 755 -R pki

sign:
	@for repo in ${REPOS};                   \
	do                                      \
	   docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root index ARCH=${ARCH}  REPO=$${repo} ; \
	   docker run -i -t -v "$(PWD)/apk:/var/local/packages" -v "$(PWD)/pki:/pki"  -v $(PWD)/alpine/build/base_os/source/repo:/aports  -v $(PWD)/builder:/root abuilder:latest  make -C /root sign  ARCH=${ARCH}  REPO=$${repo} ; \
	done

TEST_MAKEFILE = builder/Makefile
.PHONY: $(TEST_MAKEFILE)
$(TEST_MAKEFILE) :
	mkdir -p  fisk
	echo "" > $@
	echo "# Generated by, do not edit"  >> $@
	echo "" >> $@
	echo "BUILD_DIR=/var/local/aports" >> $@
	echo "REPODEST=/var/local/packages" >> $@
	echo "ABUILD=abuild -F -P \$$(REPODEST)" >> $@
	echo "" >> $@
	echo "ARCH=x86_64" >> $@
	echo "PACKAGE=zlib" >> $@
	echo "REPO=main" >> $@
	echo "" >> $@
	echo "prepare:" >> $@
	echo "\t@mkdir -p \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE)" >> $@
	echo "\t@cp -r /aports/\$$(REPO)/\$$(PACKAGE)/*  \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE)" >> $@
	echo "\t@echo 'PACKAGER_PRIVKEY="/pki/iafw.rsa"' > /etc/abuild.conf" >> $@
	echo "\t@rm -f \$$(REPODEST)/\$$(REPO)/\$$(ARCH)/APKINDEX.tar.gz" >> $@
	echo "" >> $@
	echo "fetch:" >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) fetch )" >> $@
	echo "" >> $@
	echo "verify: fetch" >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) sanitycheck )" >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) verify )" >> $@
	echo "" >> $@
	echo "unpack: " >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) unpack )" >> $@
	echo "" >> $@
	echo "patch: " >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) prepare )" >> $@
	echo "" >> $@
	echo "deps: " >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD) deps )" >> $@
	echo "" >> $@
	echo "abuild: " >> $@
	echo "\t@( cd \$$(BUILD_DIR)/\$$(REPO)/\$$(PACKAGE) && \$$(ABUILD)  )" >> $@
	echo "\t@rm -f \$$(REPODEST)/\$$(REPO)/\$$(ARCH)/APKINDEX.tar.gz" >> $@
	echo "index: " >> $@
	echo "\t@( cd \$$(REPODEST)/\$$(REPO)/\$$(ARCH)  && rm -f  APKINDEX.unsigned.tar.gz  )" >> $@
	echo "\t@( cd \$$(REPODEST)/\$$(REPO)/\$$(ARCH)  && apk index -o APKINDEX.tar.gz *.apk  )" >> $@
	echo "" >> $@
	echo "sign: " >> $@
	echo "\t@( cd \$$(REPODEST)/\$$(REPO)/\$$(ARCH)  && abuild-sign -k /pki/iafw.rsa APKINDEX.tar.gz  )" >> $@
	echo "" >> $@
	echo "build: prepare verify unpack patch abuild" >> $@
	echo "" >> $@
	echo "check: prepare verify" >> $@
	echo "" >> $@
