#HERE=$(dir $(lastword $(MAKEFILE_LIST)))
HERE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
ARCH=ar71xx
VERSION_FILE=files/etc/pbx_custom_image
VERSION_TAG="PBX_auto_Image_2.1"
IMAGEBUILDER_URL="http://downloads.openwrt.org/attitude_adjustment/12.09/$(ARCH)/generic/OpenWrt-ImageBuilder-ar71xx_generic-for-linux-i486.tar.bz2"
WGET=wget
DL_FILE="ImageBuilder.tar.bz2"
IB_FOLDER=$(HERE)/OpenWrt-ImageBuilder-$(ARCH)_generic-for-linux-i486

#Is used for creation of the valid flag file for installer
## Which package should be installed later?
#INSTALL_TARGET=piratebox

#Image configuration
FILES_FOLDER=$(HERE)/files/
################  -minimum needed-
GENERAL_PACKAGES:=pbxopkg box-installer kmod-usb2 kmod-usb-storage kmod-fs-vfat kmod-nls-cp437 kmod-nls-cp850 kmod-nls-iso8859-1 kmod-nls-iso8859-15 kmod-fs-ext4 block-mount kmod-loop losetup kmod-batman-adv wireless-tools kmod-lib-crc16 kmod-nls-utf8 kmod-ip6tables kmod-ipt-nat  kmod-ipv6 zlib hostapd-mini iw swap-utils -ppp -ppp-mod-pppoe  


#-----------------------------------------
#  Stuff for Install.zip
#
IPKG_TMP:=$(IB_FOLDER)/tmp/ipkgtmp
IPKG_INSTROOT:=$(IB_FOLDER)/build_dir/target-mips_r2_uClibc-0.9.33.2/root-$(ARCH)
IPKG_CONF_DIR:=$(IB_FOLDER)/tmp
IPKG_OFFLINE_ROOT:=$(IPKG_INSTROOT)
IPKG_STATE_DIR=$(IPKG_OFFLINE_ROOT)/usr/lib/opkg

IMAGE_FILE:=OpenWRT.img.gz
SRC_IMAGE_UNPACKED:=OpenWRT.img
IMAGE_DL_URL:=http://downloads.piratebox.de/OpenWRT.img.gz
EXT_FOLDER:=/prebuilt_ext/
DEST_IMAGE_FOLDER=$(IB_FOLDER)/img_tmp
OPKG_INSTALL_DEST:=$(IPKG_OFFLINE_ROOT)/$(EXT_FOLDER)

eval_install_zip:
ifeq ($(INSTALL_TARGET),)
	$(error "No INSTALL_TARGET set")
else
	- rm $(INSTALLER_CONF)
	$(parse_install_target)
endif


parse_install_target:
ifeq ($(INSTALL_TARGET),piratebox)
#This has to be aligned with current piratebox version :(
ADDITIONAL_PACKAGE_IMAGE_URL:="http://piratebox.aod-rpg.de/piratebox_ws_1.0_img.tar.gz"
ADDITIONAL_PACKAGE_FILE:=piratebox_ws_1.0_img.tar.gz
TARGET_PACKAGE=extendRoot-$(INSTALL_TARGET) piratebox-mod-imageboard
IMAGEPREFIX:=$(INSTALL_TARGET)
endif 
ifeq ($(INSTALL_TARGET),librarybox)
ADDITIONAL_PACKAGE_IMAGE_URL:="http://downloads.librarybox.us/librarybox_2.0_img.tar.gz"
ADDITIONAL_PACKAGE_FILE:=librarybox_2.0_img.tar.gz
TARGET_PACKAGE="extendRoot-$(INSTALL_TARGET)"
# Add additional packages to image build directly on root
GENERAL_PACKAGES:=$(GENERAL_PACKAGES)  usb-config-scripts-librarybox piratebox-mesh 
IMAGEPREFIX:=$(INSTALL_TARGET)
endif

####
INSTALL_ZIP:=$(HERE)/install_$(INSTALL_TARGET).zip
INSTALL_FOLDER:=$(HERE)/install
INSTALL_OPENWRT_IMAGE_FILE:=$(INSTALL_FOLDER)/$(IMAGE_FILE)
INSTALL_CACHE_FOLDER:=$(INSTALL_FOLDER)/cache/
INSTALL_ADDITIONAL_PACKAGE_FILE=$(INSTALL_FOLDER)/$(ADDITIONAL_PACKAGE_FILE)
INSTALLER_CONF=$(INSTALL_FOLDER)/auto_package
 
INSTALL_REPOSITORY_CONF=$(HERE)/my_repositories.conf 
#

REPOSITORY_CONF=$(IB_FOLDER)/repositories.conf
OPKG_CACHE=$(IB_FOLDER)/dl
OPKG_BIN=$(IB_FOLDER)/staging_dir/host/bin/opkg
OPKG_WITHOUT_POSTINSTALL:=  \
  IPKG_TMP=$(IPKG_TMP) \
  IPKG_INSTROOT=$(IPKG_INSTROOT) \
  IPKG_CONF_DIR=$(IPKG_CONF_DIR) \
  IPKG_OFFLINE_ROOT=$(IPKG_OFFLINE_ROOT) \
  IPKG_STATE_DIR=$(IPKG_STATE_DIR) \
  $(OPKG_BIN) \
  --cache $(INSTALL_CACHE_FOLDER) \
  -f $(REPOSITORY_CONF) \
  --offline-root $(IPKG_INSTROOT) \
  --force-depends \
  --force-overwrite \
  --add-dest ext:$(EXT_FOLDER) \
  --add-dest root:/ \
  --add-arch all:100 \
  --add-arch $(ARCH):200
OPKG:= \
  $(OPKG_WITHOUT_POSTINSTALL) \
  --force-postinstall

$(INSTALL_CACHE_FOLDER) $(INSTALL_FOLDER) $(OPKG_INSTALL_DEST):
	mkdir -p $@

$(IMAGE_FILE):
	wget -c -O $@ $(IMAGE_DL_URL)

$(ADDITIONAL_PACKAGE_FILE):
	wget -c -O $@ $(ADDITIONAL_PACKAGE_IMAGE_URL)

$(INSTALL_ADDITIONAL_PACKAGE_FILE): $(ADDITIONAL_PACKAGE_FILE)
	cp -v $(ADDITIONAL_PACKAGE_FILE) $@


$(INSTALL_REPOSITORY_CONF):
	grep src/gz $(REPOSITORY_CONF) > $@
	sed 's|# src/gz|src/gz|' -i $@

$(INSTALLER_CONF):
	echo $(TARGET_PACKAGE) > $@

mount_ext: 
	mkdir -p $(DEST_IMAGE_FOLDER)
	gunzip  $(IMAGE_FILE) -c > $(SRC_IMAGE_UNPACKED)
	sudo  mount -o loop,rw,sync $(SRC_IMAGE_UNPACKED)  $(DEST_IMAGE_FOLDER)

transfer_data_to_ext:
	sudo cp -rv --preserve=mode,links  $(OPKG_INSTALL_DEST)/* $(DEST_IMAGE_FOLDER)

umount_ext: 
	sudo umount $(DEST_IMAGE_FOLDER)

opkg_test:
	cd $(IB_FOLDER) && \
	$(OPKG) update && \
	$(OPKG) -d ext  --download-only install $(TARGET_PACKAGE) > $(HERE)/opkg_log 
	grep file\:packages $(HERE)/opkg_log | sed 's|Downloading file\:||' | sed 's|.ipk.|.ipk|' | xargs -I {} cp -v $(IB_FOLDER)/{} $(INSTALL_CACHE_FOLDER)


create_cache:  $(IMAGE_FILE) $(OPKG_INSTALL_DEST) $(INSTALL_CACHE_FOLDER)
	cd $(IB_FOLDER) && \
	$(OPKG) update && \
	$(OPKG) -d ext --download-only install $(TARGET_PACKAGE)
	# locally packages out of imagebuilder now
	cd $(IB_FOLDER) && \
	$(OPKG) update && \
	$(OPKG) -d ext  --download-only install  $(TARGET_PACKAGE) > $(HERE)/opkg_log 
	grep file\:packages $(HERE)/opkg_log | sed 's|Downloading file\:||' | sed 's|.ipk.|.ipk|' | xargs -I {} cp -v $(IB_FOLDER)/{} $(INSTALL_CACHE_FOLDER)

$(INSTALL_OPENWRT_IMAGE_FILE):
	gzip -c  $(SRC_IMAGE_UNPACKED) > $@

##### Repository-Informations
cache_package_list:
	cp -v $(IPKG_STATE_DIR)/lists/piratebox   $(INSTALL_CACHE_FOLDER)/Package.gz_piratebox
	#On the live image it is called attitiude_adjustment... on the imagebuild - yeah u know
	gzip -c  $(IPKG_STATE_DIR)/lists/imagebuilder  >  $(INSTALL_CACHE_FOLDER)/Package.gz_attitude_adjustment

clean_installer:
	- rm -rvf $(INSTALL_FOLDER)
	- rm -rvf $(OPKG_INSTALL_DEST)
	- sudo umount $(DEST_IMAGE_FOLDER)
	- rm -rvf $(DEST_IMAGE_FOLDER)
	- rm -v $(INSTALL_ZIP) ./install_*.zip
	- rm -v $(SRC_IMAGE_UNPACKED)
	- rm -v $(IMAGE_FILE)
	- rm $(HERE)/opkg_log

$(INSTALL_ZIP):
	zip -r9 $@ install/


prepare_install_zip: create_cache cache_package_list $(INSTALLER_CONF)  mount_ext transfer_data_to_ext umount_ext  $(INSTALL_OPENWRT_IMAGE_FILE) $(INSTALL_ADDITIONAL_PACKAGE_FILE) 
ifeq ($(INSTALL_TARGET),piratebox)
	KAREHA_RELEASE=kareha_3.1.4.zip
	wget http://wakaba.c3.cx/releases/$(KAREHA_RELEASE)
	cp -v $(KAREHA_RELEASE)  $(INSTALL_FOLDER) 
endif 

install_zip: eval_install_zip prepare_install_zip $(INSTALL_ZIP)



#-----------------------------------------



$(DL_FILE):
	$(WGET) -c  -O $(DL_FILE) $(IMAGEBUILDER_URL)

$(IB_FOLDER): $(DL_FILE) $(VERSION_FILE)
	tar -xvjf $(DL_FILE) 
	echo "src/gz piratebox http://dev.openwrt.piratebox.de/all/packages" >> $(IB_FOLDER)/repositories.conf

$(VERSION_FILE): 
	mkdir -p files/etc
	echo $(VERSION_TAG) > $@

imagebuilder: $(IB_FOLDER) 


%.bin: 
ifneq ($(IMAGEPREFIX),) 
	cp $(IB_FOLDER)/bin/ar71xx/$@ ./$(INSTALL_TARGET)_$@
else
	cp $(IB_FOLDER)/bin/ar71xx/$@ ./$@
endif

TLMR3020 TLMR3040 TLWR703 TLWR842 :  parse_install_target
	cd $(IB_FOLDER)  &&	make image PROFILE="$@" PACKAGES="$(GENERAL_PACKAGES)" FILES=$(FILES_FOLDER)

############## uncommented. We can reuse one until we need different packages
#TLMR3040 : 
#	cd $(IB_FOLDER) &&	make image PROFILE="$@" PACKAGES=$(GENERAL_PACKAGES) FILES=$(FILES_FOLDER)
#
#TLWR703 : 
#	cd $(IB_FOLDER) &&	make image PROFILE="$@" PACKAGES=$(GENERAL_PACKAGES) FILES=$(FILES_FOLDER)


all: imagebuilder MR3020 MR3040 WR703N WR842

MR3020: TLMR3020 openwrt-ar71xx-generic-tl-mr3020-v1-squashfs-factory.bin

MR3040: TLMR3040 openwrt-ar71xx-generic-tl-mr3040-v1-squashfs-factory.bin

WR703N: TLWR703 openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory.bin

WR842: TLWR842 openwrt-ar71xx-generic-tl-wr842n-v1-squashfs-factory.bin

clean: clean_installer
	-rm $(VERSION_FILE) $(INSTALLER_CONF)
	-rm  -r $(IB_FOLDER)
	-rm $(DL_FILE)
	-rm openwrt-ar71xx-generic*
