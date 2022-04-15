#include <iostream>

int main() {

	for(int i = 0; i < 256; i++) {

		std::cout << "@opcode_" << std::dec << i << "_" << std::hex << i << std::endl;
	}
	return 0;
}
