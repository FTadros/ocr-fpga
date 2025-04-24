"""ILI9341 XPT2046 MNIST Input with Square Save Button & Debug Logging"""
from ili9341 import Display, color565
from xpt2046 import Touch
from machine import Pin, SPI, UART
import time
import sys
import math

def color_rgb(r, g, b):
    return color565(r, g, b)

class TouchScreen(object):
    WHITE = color_rgb(255, 255, 255)
    BLACK = color_rgb(0, 0, 0)

    class TouchArea:
        def __init__(self, x, y, w, h):
            self.x_range = range(x, x + w)
            self.y_range = range(y, y + h)
            print(f"[DEBUG] Created TouchArea at ({x},{y}) {w}x{h}")

    def __init__(self):
        print("\n[SYSTEM] Initializing...")
        # Display setup
        self.spi_display = SPI(1, baudrate=80000000, sck=Pin(14), mosi=Pin(13))
        self.Screen = Display(self.spi_display, dc=Pin(2), cs=Pin(15),
                              rst=Pin(4), width=320, height=240)
        self.backlight = Pin(21, Pin.OUT)
        self.backlight.on()
        self.Screen.clear(self.WHITE)
        print("[DISPLAY] Ready (320x240)")

        # Touch controller
        self.spi_touch = SPI(2, baudrate=1000000, sck=Pin(25), mosi=Pin(32), miso=Pin(39))
        self.Touch = Touch(self.spi_touch, cs=Pin(33), int_pin=Pin(36),
                           int_handler=self.touch_handler)
        print("[TOUCH] Controller ready")

        # State management
        self.last_x = None
        self.last_y = None
        self.freeze = False
        self.buffer = bytearray(9600)  # 320x240 bit buffer

        # UI elements
        self.Touch_items = []
        self.Touch_callbacks = []
#         self.send_uart_data([5])
        self.initialize_ui()
        print("[UI] Ready\n")

    def initialize_ui(self):
        """Create UI with square save button"""
        print("[UI] Building interface...")
        # Square save button parameters
        btn_size = 32
        btn_x = 280
        btn_y = 208

        # Draw button
        self.Screen.fill_rectangle(btn_x, btn_y, btn_size, btn_size, self.WHITE)
        self.Screen.draw_rectangle(btn_x, btn_y, btn_size, btn_size, self.BLACK)
        self.Screen.draw_text8x8(btn_x+8, btn_y+12, "SAVE", self.BLACK, self.WHITE)
        self.addTouchItem(self.TouchArea(btn_x, btn_y, btn_size, btn_size), self.save_mnist)

        # Instructions
        self.Screen.draw_text8x8(10, 10, "Draw Digit", self.BLACK, self.WHITE)
        self.Screen.draw_text8x8(10, 30, "Press SAVE when done", self.BLACK, self.WHITE)
        print("[UI] Interface built")

    def addTouchItem(self, area, callback):
        self.Touch_items.append(area)
        self.Touch_callbacks.append(callback)
        print(f"[UI] Registered {callback.__name__} for area {area.x_range}x{area.y_range}")

    def touch_handler(self, x, y):
        """Process touch events"""
        if self.freeze:
            print("[TOUCH] Input frozen")
            return

        x, y = y, x  # Coordinate swap
        print(f"[TOUCH] Raw ({x},{y})")

        # Check UI elements first
        for i, area in enumerate(self.Touch_items):
            if x in area.x_range and y in area.y_range:
                print(f"[UI] Button {i} pressed")
                self.Touch_callbacks[i]()
                return

        # Handle drawing
        if not self.freeze:
            print(f"[DRAW] Start at ({x},{y})")
            self.process_drawing(x, y)

    def process_drawing(self, x, y):
        """Manage drawing operations"""
        if self.last_x is None:
            self.draw_point(x, y)
        else:
            self.draw_line(x, y)
        self.last_x, self.last_y = x, y

    def draw_point(self, x, y):
        """Draw single pixel"""
        if 0 <= x < 320 and 0 <= y < 240:
            self.Screen.fill_circle(x, y, 3, self.BLACK)
            self.set_pixel(x, y, True)
            print(f"[DRAW] Point ({x},{y})")

    def draw_line(self, x, y):
        """Connect points smoothly"""
        print(f"[DRAW] Line from ({self.last_x},{self.last_y}) to ({x},{y})")
        dx = abs(x - self.last_x)
        dy = abs(y - self.last_y)
        sx = 1 if x > self.last_x else -1
        sy = 1 if y > self.last_y else -1
        err = dx - dy

        while True:
            self.draw_point(self.last_x, self.last_y)
            if self.last_x == x and self.last_y == y:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                self.last_x += sx
            if e2 < dx:
                err += dx
                self.last_y += sy

    def set_pixel(self, x, y, state=True):
        """Update buffer"""
        if 0 <= x < 320 and 0 <= y < 240:
            idx = y * 320 + x
            self.buffer[idx // 8] |= (state << (7 - (idx % 8)))

    def get_pixel(self, x, y):
        """Read buffer"""
        if 0 <= x < 320 and 0 <= y < 240:
            idx = y * 320 + x
            return bool(self.buffer[idx // 8] & (1 << (7 - (idx % 8))))
        return False

    def save_mnist(self):
        """Process and export drawing"""
        print("\n[SAVE] Initiating...")
#         print(self.buffer)
        self.freeze = True
        self.process_mnist_data()
        self.reset_canvas()
        self.freeze = False
        print("[SAVE] Completed\n")
    
    def scale_and_convert_to_bytearray(self, x_start, y_start, src_width, src_height):
        dst_width = dst_height = 28
        scale_x = src_width / dst_width
        scale_y = src_height / dst_height
        filename = "tmp.txt"

        total_bits = dst_width * dst_height
        total_bytes = total_bits // 8  # 784 bits / 8 = 98 bytes
        result = bytearray(total_bytes)

        bit_index = 0  # Tracks bit position in the final bytearray

        for y in range(dst_height):
            for x in range(dst_width):
                src_x = int(x_start + x * scale_x)
                src_y = int(y_start + y * scale_y)

                if 0 <= src_x < 320 and 0 <= src_y < 240:
                    pixel = self.get_pixel(src_x, src_y)
                else:
                    pixel = 0

                byte_index = bit_index // 8
                bit_offset = 7 - (bit_index % 8)  # MSB first
                if pixel:
                    result[byte_index] |= (1 << bit_offset)
                bit_index += 1
        try:
            with open(filename, "wb") as f:
                f.write(result)
            print(f"[FILE] Saved to '{filename}' ({len(result)} bytes)")
        except Exception as e:
            print(f"[ERROR] Failed to write file: {e}")

        return result



    def process_mnist_data(self):
        """Convert to 28x28 format"""
        print("[MNIST] Processing...")
        # Find drawing bounds
        min_x = max_x = min_y = max_y = None
        for y in range(240):
            for x in range(320):
                if self.get_pixel(x, y):
                    min_x = min(x, min_x) if min_x else x
                    max_x = max(x, max_x) if max_x else x
                    min_y = min(y, min_y) if min_y else y
                    max_y = max(y, max_y) if max_y else y

        if not min_x:
            print("[ERROR] No drawing found!")
            return

        print(f"[MNIST] Bounds X({min_x}-{max_x}) Y({min_y}-{max_y})")
        width = max_x - min_x
        height = max_y - min_y
        image_sc = self.scale_and_convert_to_bytearray(min_x - 5, min_y - 5, width + 10, height + 10)
        self.send_uart_data(image_sc)

    def send_uart_data(self, mnist_data):
        """Send MNIST data over UART"""
        print("[UART] Initializing UART...")
        uart = UART(1, baudrate=9600, bits=8, parity=None, stop=1, tx=22, rx=27)  # Using UART1 with TX on GPIO 22
        # uart.init(9600, bits=8, parity=None, stop=1) # init with given parameters
        # Get the MNIST data
#         mnist_data = []
#         for y in range(28):
#             for x in range(28):
#                 # Calculate source coordinates
#                 src_x = int(x * (320/28))
#                 src_y = int(y * (240/28))
#
#                 # Sample the pixel value
#                 intensity = 0
#                 if 0 <= src_x < 320 and 0 <= src_y < 240:
#                     intensity = 255 if self.get_pixel(src_x, src_y) else 0
#                 mnist_data.append(intensity)
#
#         # Validate data size
#         if len(mnist_data) != 784:
#             print(f"[ERROR] Invalid data size: {len(mnist_data)} bytes (expected 784)")
#             return

        # Convert data to bytes and send
#         data_bytes = self.bitmap_1bit_to_bytearray(mnist_data)
        data_bytes = mnist_data
        print(data_bytes)
        print(f"[UART] Sending {len(data_bytes)} bytes...")
        uart.write(data_bytes)
        print(uart.any())
        # Verify data was sent
        #if uart.any():
        #    print("[UART] Data sent successfully")
        #else:
        #    print("[ERROR] Failed to send data")

    def reset_canvas(self):
        """Clear screen and buffers"""
        print("[CLEAN] Resetting...")
        self.Screen.clear(self.WHITE)
        self.buffer = bytearray(9600)
        self.last_x = self.last_y = None
        self.initialize_ui()
        print("[CLEAN] Ready")

    def shutdown(self):
        """Cleanup resources"""
        print("\n[SHUTDOWN] Starting...")
        self.spi_touch.deinit()
        self.backlight.off()
        self.Screen.cleanup()
        print("[SHUTDOWN] Complete")
        sys.exit(0)

# Main execution
try:
    print("=== MNIST Data Collector ===")
    ts = TouchScreen()
    while True:
        time.sleep(0.1)
except KeyboardInterrupt:
    ts.shutdown()

