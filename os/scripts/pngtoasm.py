#!/usr/bin/python3 

from PIL import Image
im = Image.open(r'08x16_Novafont_Alejandro-Lieber.png')
#im = Image.open(r'06x08_Terminal_Microsoft.png')

# for 8x16 font
for row in range(int(im.height/16)):
  for col in range(int(im.width/8)):
    asciival = row*16+col;
    if asciival >=32 and asciival<127 or asciival >= 160:
      let = chr(asciival)
    else:
      let = '\\x' + str(asciival)
    print('letter',asciival,':  ',sep='',end='')
    val = 0
    count = 0
    print('  db ',end='')
    for y in range(16):
        for x in range(8):
          val = val << 1
          val = val | (0 if im.getpixel((col*8+x,row*16+y))[1]==0 else 1)
          count += 1
          if (count % 8) == 0:
            print('{0:#0{1}x}'.format(val,4),end='')
            count = 0
            val = 0
        if y < 15:
            print(',',end='')
        else:
            print(' ; \'', let,'\'',sep='')            


# # for 6x8 font
# for row in range(int(im.height/8)):
#   for col in range(int(im.width/6)):
#     print('letter',row*8+col,':  ; \'', chr(row*8+col),'\'',sep='')
#     val = 0
#     count = 0
#     for y in range(8):
#         for x in range(6):
#           val = val << 1
#           val = val | (0 if im.getpixel((col*6+x,row*8+y))[1]==0 else 1)
#           count += 1
#           if (count % 8) == 0:
#             print('  db {0:#0{1}b}'.format(val,10))
#             count = 0
#             val = 0
#     print()

# for 12x16 font
# for row in range(int(im.height/16)):
#   for col in range(int(im.width/12)):
#     print('letter',row*16+col,':  ; \'', chr(row*16+col),'\'',sep='')
#     val = 0
#     count = 0
#     for y in range(16):
#         for x in range(12):
#           val = val << 1
#           val = val | (0 if im.getpixel((col*12+x,row*16+y))[1]==0 else 1)
#           count += 1
#           if (count % 8) == 0:
#             print('  db {0:#0{1}b}'.format(val,10))
#             count = 0
#             val = 0
#     print()

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
