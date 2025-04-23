import os

def convert_mif_to_32bit(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Count the number of lines to determine depth
    depth = len(lines)

    # Create the new MIF file with 32-bit width
    with open(output_file, 'w') as f:
        f.write('WIDTH = 32;\n')
        f.write(f'DEPTH = {depth};\n\n')
        f.write('ADDRESS_RADIX = DEC;\n')
        f.write('DATA_RADIX = HEX;\n\n')
        f.write('CONTENT BEGIN\n')

        # Process each line
        for i, line in enumerate(lines):
            value = line.strip()
            if not value:
                continue

            # Convert to 32-bit hex
            # If the value is less than 32 bits, pad with zeros
            # If it's more than 32 bits, truncate to 32 bits
            value = f"{int(value, 16) & 0xFFFFFFFF:08x}"
            f.write(f'{i} : {value};\n')

        f.write('END;\n')

def main():
    # Create output directory if it doesn't exist
    if not os.path.exists('converted'):
        os.makedirs('converted')

    # Process all .mif files in the original directory
    for filename in os.listdir('original'):
        if filename.endswith('.mif'):
            input_path = os.path.join('original', filename)
            output_path = os.path.join('converted', filename.replace('.mif', 'v2.mif'))
            print(f"Converting {filename}...")
            try:
                convert_mif_to_32bit(input_path, output_path)
                print(f"Successfully converted {filename}")
            except Exception as e:
                print(f"Error converting {filename}: {str(e)}")

if __name__ == "__main__":
    main()
