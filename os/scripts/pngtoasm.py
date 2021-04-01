from PIL import Image

im = Image.open(r'12x16_Terminal_Microsoft.png')


for row in range(int(im.height/16)):
  for col in range(int(im.width/12)):
    print('; \'', chr(row*16+col),'\'',sep='')
    for x in range(12):
      print('  db  ',end='')
      for b in range(2): # 2 bytes at a time
        val = 0
        for y in range(8):
          val = val << 1
          val = val | (0 if im.getpixel((col*12+x,row*16+b*8+y))[1]==0 else 1)
          #print(im.getpixel((col*12+x,row*16+b*8+y))[1],",");
        #print('{0:#0{1}x},'.format(val,4),end='')
        print('{0:#0{1}b},'.format(val,10),end='')
      print()
    print()

