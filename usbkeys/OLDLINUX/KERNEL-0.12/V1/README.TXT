 1216  dd if=/dev/zero of=linux14.img bs=1k count=1440
 1217  dd if=bootimage-0.12 of=linux14.img conv=notrunc
 1219  dd if=/dev/zero of=root14.img bs=1k count=1440
 1220  dd if=rootimage-0.12 of=root14.img conv=notrunc
