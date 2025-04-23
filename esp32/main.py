from machine import UART
import time

# set up UART1 on TX=22, RX=27
uart = UART(1, baudrate=9600, bits=8, parity=None, stop=1, tx=22, rx=27)
time.sleep(0.1)

segment_decoder = [
    0x3f, 0x06, 0x5b, 0x4f,
    0x66, 0x6d, 0x7d, 0x07,
    0x7f, 0x6f, 0x77, 0x7c,
    0x39, 0x5e, 0x79, 0x71,
    0x3d, 0x76
]

# invert each byte and mask to 8 bits
a = bytearray([ (~x & 0xFF) for x in segment_decoder ])
print("Out‑of‑order display codes:", a)

# send the whole array in one go
# uart.write(a)

temp = bytearray(b'\x00') #First byte get eaten for some reason.
for _ in range(96):
    temp += bytearray(b'\x00',)
for _ in range(1):
    temp += bytearray(b'\x00',) #0
for _ in range(1):
    temp += bytearray(b'\x80',)#98
print(temp)
print(len(temp))
uart.write(temp)
# 
# print(temp)

# or, if you really want a delay between bytes:
# for _ in range(100):
# for b in a:
#     uart.write(bytes([b]))
#     time.sleep(0.1)
