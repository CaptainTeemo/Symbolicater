import sys
import ntpath
from subprocess import Popen, PIPE, STDOUT
import os
from collections import Counter

predefined_archs = ['x86_64', 'arm64']

def get_arch_and_base_address(file_path_diag, module_name):
    found_binary = False
    with open(file_path_diag) as f:
        lines = f.readlines()
        arch = 'x86_64'
        for line in lines:
            if 'Code Type' in line and 'ARM-64' in line:
                arch = 'arm64'
           
            if found_binary and module_name in line and "0x" in line:
                base_address = None
                words = line.split()
                for index, word in enumerate(words): 
                    if base_address == None and "0x" in word:
                        print ("Found base address: " + word)
                        base_address = word

                    if arch and base_address:
                        print ("Architecture: " + arch)
                        return (arch, base_address)
            elif "Binary Images:" in line:
                found_binary = True

    raise ValueError("Didn't find architecture or base address of module " + module_name)


def get_method_address(line, module):
    if module in line and "0x" in line:
        words = line.split()
        for word in words:
            if "0x" in word:
                word = word.replace('[', '')
                word = word.replace(']', '')
                return word
    return ''


def read_crash(file_path_sym, file_path_diag, output_file_path, bundle_id):
    output_file = open(output_file_path, "w")

    module_name = bundle_id or ntpath.basename(file_path_sym)
    sym_cmd_path = file_path_sym.replace(' ', '\ ')

    (arch, base_address) = get_arch_and_base_address(file_path_diag, module_name)

    crash_thread_lines = []

    with open(file_path_diag) as f:
        lines = f.readlines()

        crash_start_index = -1
        crash_end_index = sys.maxsize

        for (index, line) in enumerate(lines):

            if "Crashed:" in line:
                crash_start_index = index

            if "Thread " in line and crash_start_index >= 0 and index > crash_start_index:
                crash_end_index = index

            is_translated = False
            if module_name in line:
                method_address = get_method_address(line, module_name)
                if method_address != "":
                    cmd = 'atos -arch ' + arch + " -o " + sym_cmd_path + " -l " + base_address + " " + method_address
                    p = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
                    atos_output = p.stdout.read()
                    table = str.maketrans(dict.fromkeys('\n'))
                    out_line = line.translate(table) + "   " + str(atos_output) + "\n"
                    output_file.write(out_line)

                    if crash_start_index >= 0 and index < crash_end_index:
                        crash_thread_lines.append(out_line)

                    is_translated = True

            if not is_translated:
                output_file.write(line)
                if crash_start_index >= 0 and index < crash_end_index:
                    crash_thread_lines.append(line)

    return crash_thread_lines

arglen = len(sys.argv)

if arglen < 3:
    print ('Missing input - symbolicate.py {xxx.dSYM/Contents/Resources/DWARF/xxx} {file.crash} {bundle id}')

log_file_path = sys.argv[2]
filename = log_file_path + ".symbolicated.crash"
filename = os.path.join('/tmp', os.path.basename(filename))

bundle_id = ""
    
if arglen > 3:
    bundle_id = sys.argv[3]

try:
    os.remove(filename)
except OSError:
    pass

print ('Symbolicating...')

thread = read_crash(sys.argv[1], log_file_path, filename, bundle_id)

# print "\n".join(thread)

# import re
# os.system('open '+ re.escape(filename))
print(open(filename).read())