from machine import UART
import time

#This is out baseline/control value that should infer a '7' based on our NN model.

# set up UART on TX=22, RX=27
uart = UART(1, baudrate=9600, bits=8, parity=None, stop=1, tx=22, rx=27)
time.sleep(0.1)

temp = bytearray(b'\x00') #First byte gets eaten for some reason.
for _ in range(1):
    temp += bytearray(b'\x0e',) #01110000
for _ in range(1):
    temp += bytearray(b'\x00',) #00000000
for _ in range(96):             #...
    temp += bytearray(b'\x00',) #00000000
print(temp)
print(len(temp))
uart.write(temp)
