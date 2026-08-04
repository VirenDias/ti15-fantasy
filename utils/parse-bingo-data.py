import sys
import vdf

# Read in the data
with open(sys.argv[1]) as file:
    data = vdf.load(file)['bingo_2024.vdata']

# Extract the data
names = [data[key] for key in sorted(data) if key.endswith('LocName')]
descs = [data[key] for key in sorted(data) if key.endswith('LocTooltip')]
squares = tuple(zip(names, descs))

# Output the data
print("\"", "name", "\",\"", "desc", "\"")
for square in squares:
    print("\"", square[0], "\",\"", square[1], "\"")