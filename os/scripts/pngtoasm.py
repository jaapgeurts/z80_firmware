#!/usr/bin/python3 

from PIL import Image

im = Image.open(r'12x16_Terminal_Microsoft.png')


for row in range(int(im.height/16)):
  for col in range(int(im.width/12)):
    print('letter',row*16+col,':  ; \'', chr(row*16+col),'\'',sep='')
    val = 0
    count = 0
    for y in range(16):
        for x in range(12):
          val = val << 1
          val = val | (0 if im.getpixel((col*12+x,row*16+y))[1]==0 else 1)
          count += 1
          if (count % 8) == 0:
            print('  db {0:#0{1}b}'.format(val,10))
            count = 0
            val = 0
    print()

# for row in range(int(im.height/16)):
#   for col in range(int(im.width/12)):
#     print('; \'', chr(row*16+col),'\'',sep='')
#     for x in range(12):
#       print('  db  ',end='')
#       for b in range(2): # 2 bytes at a time
#         val = 0
#         for y in range(8):
#           val = val << 1
#           val = val | (0 if im.getpixel((col*12+x,row*16+b*8+y))[1]==0 else 1)
#           #print(im.getpixel((col*12+x,row*16+b*8+y))[1],",");
#         #print('{0:#0{1}x},'.format(val,4),end='')
#         print('{0:#0{1}b},'.format(val,10),end='')
#       print()
#     print()
