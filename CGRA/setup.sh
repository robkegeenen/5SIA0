#CHANGE THIS TO ACTUAL LOCATION!
export CGRA_ROOT=/home/CGRA

#license only works with VPN
export LM_LICENSE_FILE=$LM_LICENSE_FILE:1717@o3.ics.ele.tue.nl

#change this to your modelsim install path
export PATH=$PATH:/opt/tools/modelsim/10.2a/modeltech/linux_x86_64/

#no changes required
export PATH=$PATH:${CGRA_ROOT}/tools/Assembler
export PATH=$PATH:${CGRA_ROOT}/tools/HardwareGenerator
export PATH=$PATH:${CGRA_ROOT}/tools/BitConfig
export PATH=$PATH:${CGRA_ROOT}/tools/BinaryBuilder
export PATH=$PATH:${CGRA_ROOT}/tools/CGRAModel
export PATH=$PATH:${CGRA_ROOT}/tools/ImageConvertOut
export PATH=$PATH:${CGRA_ROOT}/tools/ImageConvertIn

