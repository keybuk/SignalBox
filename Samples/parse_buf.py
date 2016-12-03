#!/usr/bin/python

import argparse
import math
import sys


def read_buf_file(filename, channel='A'):
	f = open(filename, 'rb')
	try:
		while True:
			try:
				(ch_a, ch_b) = f.read(2)
			except ValueError:
				return

			if channel == 'A':
				value = ch_a
			else:
				value = ch_b

			sample = ord(value) - 128
			yield sample
	finally:
		f.close()


def filter_samples(samples):
	buffer = []
	for sample in samples:
		buffer.append(sample)
		if len(buffer) > 3:
			buffer.pop(0)
			yield sum(buffer) / len(buffer)
		elif len(buffer) == 2:
			yield sum(buffer) / len(buffer)

	buffer.pop(0)
	yield sum(buffer) / len(buffer)


def extract_waveform(samples):
	last_polarity = None
	duration = 0

	for sample in samples:
		polarity = (sample >= 0)

		if polarity != last_polarity:
			if last_polarity is not None:
				yield (last_polarity, duration)

			last_polarity = polarity
			duration = 0

		duration += 1
	else:
		yield (last_polarity, duration)


def pair_durations(waveform):
	high_duration = None

	for polarity, duration in waveform:
		if polarity is True:
			high_duration = duration
		elif high_duration is not None:
			yield (high_duration, duration)
			high_duration = None


def extract_bits(durations, sample_duration=8, one_durations=None, zero_durations=None):
	if sample_duration > 40:
		print >>sys.stderr, "timebase will have insufficient resolution for DCC"

	for high_duration, low_duration in durations:
		if high_duration >= int(52 / sample_duration) and high_duration <= int(64 / sample_duration) + 1:
			if abs(high_duration - low_duration) > int(6 / sample_duration) + 2:
				print >>sys.stderr, "Mismatched pair: %r, %r" % (high_duration, low_duration)

			if one_durations is not None:
				one_durations.append(high_duration * sample_duration)
			yield True

		elif high_duration * sample_duration >= 95 and low_duration * sample_duration >= 95:
			if zero_durations is not None:
				zero_durations.append(high_duration * sample_duration)
			yield False

		else:
			print >>sys.stderr, "Unknown pair: %r, %r" % (high_duration, low_duration)
			yield None


def decode(bits, preample_lengths=None):
	preamble_length = 0
	garbage = False
	while True:
		# Look for the preample
		for bit in bits:
			if bit:
				preamble_length += 1
			elif preamble_length >= 10:
				if preample_lengths is not None:
					preample_lengths.append(preamble_length)
				break
			else:
				if not garbage:
					print >>sys.stderr, "Garbage at start"
					garbage = True
				preamble_length = 0
		else:
			if preamble_length:
				print >>sys.stderr, "Garbage at end"
			return

		# Packet Start Bit is always 0
		if bit is None:
			print >>sys.stderr, "Corrupt packet at start"
			continue

		bytes = []
		more_bytes = True
		while more_bytes:
			n = 0
			byte = 0

			# Look for the next byte
			for bit in bits:
				if bit is None:
					print >>sys.stderr, "Corrupt packet"
					more_bytes = False
					preamble_length = 0
					break

				if n < 8:
					byte <<= 1
					byte |= bit
					n += 1
				else:
					bytes.append(byte)
					if bit:
						yield bytes
						more_bytes = False
						preamble_length = 1
					break
			else:
				print >>sys.stderr, "Partial packet at end"
				return


def check_packet(packet):
	check = reduce(lambda a,b: a^b, packet[:-1], 0)
	if check != packet[-1]:
		print >>sys.stderr, "Checksum error, expected {0:08b} got {1:08b}".format(check, packet[-1])
	return check == packet[-1]


def print_loco(loco, text):
	if loco == 0:
		print "All: %s" % (text,)
	else:
		print "Loco %d: %s" % (loco, text)


def print_packet(packet):
	if packet[0] == 0b00000000:
		# Broadcast
		loco = 0
		instructions = packet[1:]

	elif packet[0] == 0b11111111:
		# Idle
		loco = None
		if len(packet) == 2 and packet[1] == 0b00000000:
			print "Idle"
			return
		else:
			return unknown_packet(packet)

	elif (packet[0] >> 6 == 0b11) and len(packet) > 1:
		# Multi-function decoder with 14-bit address
		loco = packet[0] & 0b00111111 | packet[1]
		instructions = packet[2:]

	elif (packet[0] >> 6 == 0b10):
		# Accessory decoder with 9 or 11-bit address
		return unknown_packet(packet)

	elif (packet[0] >> 7 == 0b0):
		# Multi-function decoder with 7-bit address
		loco = packet[0]
		instructions = packet[1:]

	else:
		return unknown_packet(packet)


	while len(instructions):
		instruction = instructions[0] >> 5
		if instruction == 0b001 and len(instructions) >= 2:
			# Advanced operations instruction
			sub_instruction = instructions[0] & 0b00011111
			if sub_instruction == 0b11111:
				# 128 speed-step control
				fwd = instructions[1] & 0b10000000
				spd = instructions[1] & 0b01111111

				if spd == 0:
					print_loco(loco, "Stop")
				elif spd == 1:
					print_loco(loco, "E-Stop")
				else:
					sspd = "%s %d/126" % (fwd and "fwd" or "rev", spd - 1)
					print_loco(loco, sspd)
			else:
				return unknown_packet(packet)

			instructions = instructions[2:]
		elif instruction == 0b010 or instruction == 0b011:
			# Speed and direction instructions
			fwd = instructions[0] & 0b00100000
			spd_lsb = instructions[0] & 0b00010000
			spd_msb = instructions[0] & 0b00001111

			spd = spd_msb << 1 | (spd_lsb and 1 or 0)
			if spd == 0:
				print_loco(loco, "Stop")
			elif spd == 1:
				print_loco(loco, "Stop (I)")
			elif spd == 2:
				print_loco(loco, "E-Stop")
			elif spd == 3:
				print_loco(loco, "E-Stop (I)")
			else:
				sspd = "%s %d/28" % (fwd and "fwd" or "rev", spd - 3)
				print_loco(loco, sspd)

			instructions = instructions[1:]

		elif instruction == 0b100:
			f = []
			if instructions[0] & 0b00010000:
				f.append("FL")
			if instructions[0] & 0b00000001:
				f.append("F1")
			if instructions[0] & 0b00000010:
				f.append("F2")
			if instructions[0] & 0b00000100:
				f.append("F3")
			if instructions[0] & 0b00001000:
				f.append("F4")

			print_loco(loco, "FG1 " + " ".join(f))
			instructions = instructions[1:]

		elif instruction == 0b101:
			f = []
			if instructions[0] & 0b00010000:
				if instructions[0] & 0b00000001:
					f.append("F5")
				if instructions[0] & 0b00000010:
					f.append("F6")
				if instructions[0] & 0b00000100:
					f.append("F7")
				if instructions[0] & 0b00001000:
					f.append("F8")
			else:
				if instructions[0] & 0b00000001:
					f.append("F9")
				if instructions[0] & 0b00000010:
					f.append("F10")
				if instructions[0] & 0b00000100:
					f.append("F11")
				if instructions[0] & 0b00001000:
					f.append("F12")

			print_loco(loco, "FG2 " + " ".join(f))
			instructions = instructions[1:]

		elif loco == 0 and instructions[0] == 0b00000000:
			print_loco(loco, "Reset All")
		else:
			return unknown_packet(packet)


def unknown_packet(packet):
	print " ".join('{0:08b}'.format(byte) for byte in packet)


def sample_duration(string):
	# Each TimeBase is one square on the display.
	# Display has 10 squares.
	# Seems to record 25 samples per square, and thus 250 samples per page.
	durations = {
		'2.0s': 80000,
		'1.0s': 40000,
		'0.5s': 20000,
		'0.2s': 8000,
		'0.1s': 4000,
		'50ms': 2000,
		'20ms': 800,
		'10ms': 400,
		'5.0ms': 200,
		'2.0ms': 80,
		'1.0ms': 40,
		'0.5ms': 20,
		'0.2ms': 8,
		'0.1ms': 4,
		'50us': 2,
		'20us': 0.8,
		'10us': 0.4,
		'5.0us': 0.2,
		'2.0us': 0.08,
		'1.0us': 0.04
	}

	try:
		return durations[string.lower()]
	except KeyError:
		raise argparse.ArgumentTypeError("%r is not a valid timebase" % string)


def print_stats(legend, numbers, unit):
	min(numbers)
	max(numbers)

	mean = float(sum(numbers))/len(numbers)
	stddev = math.sqrt(sum(math.pow(number - mean, 2) for number in numbers) / len(numbers))

	print "{0:s}: {2:d}-{3:d}{1:s} avg {4:.2f}{1:s} stddev {5:.2f}{1:s}".format(legend, unit, min(numbers), max(numbers), mean, stddev)


def main():
	parser = argparse.ArgumentParser(description='Parse DS202 buffer files.')
	parser.add_argument('filename', metavar='FILE', help='filename to parse')
	parser.add_argument('-A', dest='channel', action='store_const', const='A', default='A', help='use channel A')
	parser.add_argument('-B', dest='channel', action='store_const', const='B', help='use channel B')

	parser.add_argument('--timebase', dest='sample_duration', type=sample_duration, default='0.5ms', help='timebase buffer recorded with')

	parser.add_argument('--output-samples', dest='output_samples', action='store_true', help='output samples in buffer')
	parser.add_argument('--output-bits', dest='output_bits', action='store_true', help='output raw bitstream')

	parser.add_argument('--no-stats', dest='output_stats', action='store_false', help='do not output stats')
	
	args = parser.parse_args()

	samples = read_buf_file(args.filename, channel=args.channel)
	if args.output_samples:
		for sample in samples:
			print sample
		return

	#samples = filter_samples(samples)
	waveform = extract_waveform(samples)
	durations = pair_durations(waveform)

	one_durations = []
	zero_durations = []
	bits = extract_bits(durations, sample_duration=args.sample_duration, one_durations=one_durations, zero_durations=zero_durations)
	if args.output_bits:
		def bit_to_str(bit):
			if bit == True:
				return '1'
			elif bit == False:
				return '0'
			else:
				return '?'
		print "".join(bit_to_str(bit) for bit in bits)
		return

	preample_lengths = []
	packets = decode(bits, preample_lengths=preample_lengths)
	for packet in packets:
		if check_packet(packet):
			print_packet(packet[:-1])
		else:
			print "ERR " + " ".join('{0:08b}'.format(byte) for byte in packet)

	if args.output_stats:
		print
		print_stats('one bit', one_durations, 'us')
		print_stats('zero bit', zero_durations, 'us')
		print_stats('preample', preample_lengths, 'b')


if __name__ == "__main__":
	main()
