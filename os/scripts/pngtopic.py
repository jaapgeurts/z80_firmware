#!/usr/bin/python3 

#png to pic

# pic format: raw pixels. no headers
# each pixel is two bytes. 
# 5 bits red, 6 bits green, 5 bits blue

import sys
from PIL import Image

im = Image.open(sys.argv[1])

bytearr = [0] * (im.height * im.width * 2)

i=0
for y in range(int(im.height)):
  for x in range(int(im.width)):
    (r,g,b) = im.getpixel((x,y))
    # simple scale up
    # Reverse b & r from what the datasheet says (can be flipped in MADCTL(36h) register)
    bytearr[i] = ( b & 0xf8) | ((g >> 5) &0x07)
    bytearr[i+1] = ((g << 3) & 0xe0) | r >> 3 
    i = i + 2

with open('out.pic','wb') as f: 
  f.write(bytearray(bytearr))
