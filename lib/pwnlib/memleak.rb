# encoding: ASCII-8BIT

require 'pwnlib/util/packing'

module Pwnlib
  # A class caching and heuristic tool for exploiting memory leaks.
  class MemLeak
    PAGE_SIZE = 0x1000
    PAGE_MASK = ~(PAGE_SIZE - 1)

    def initialize(&block)
      @leak = block
      @cache = {}
    end

    # Get the base address of the ELF, based on heuristic of finding ELF header.
    # A known address in ELF should be given.
    #
    # @param [Integer] addr
    #   An address that is known to be inside ELF.
    #
    # @return [Integer]
    #   The base address of ELF.
    def find_elf_base(addr)
      addr &= PAGE_MASK
      loop do
        return addr if n(addr, 4) == "\x7fELF"
        addr -= PAGE_SIZE
      end
    end

    # Leak +numb+ bytes at +addr+.
    # Returns a string with the leaked bytes.
    #
    # @param [Integer] addr
    #   The starting address of the leak.
    # @param [Integer] numb
    #   Number of bytes to be leaked.
    #
    # @return [String]
    #   The leaked byte string.
    def n(addr, numb)
      (0...numb).map { |i| do_leak(addr + i) }.pack('C*')
    end

    # Leak a byte at +*((uint8_t*) addr)+.
    #
    # @param [Integer] addr
    #   The address of the leak.
    #
    # @return [Integer]
    #   The leaked byte.
    def b(addr)
      Util::Packing.u8(n(addr, 1))
    end

    # Leak a word at +*((uint16_t*) addr)+.
    #
    # @param [Integer] addr
    #   The address of the leak.
    #
    # @return [Integer]
    #   The leaked word.
    def w(addr)
      Util::Packing.u16(n(addr, 2))
    end

    # Leak a dword at +*((uint32_t*) addr)+.
    #
    # @param [Integer] addr
    #   The address of the leak.
    #
    # @return [Integer]
    #   The leaked dword.
    def d(addr)
      Util::Packing.u32(n(addr, 4))
    end

    # Leak a qword at +*((uint64_t*) addr)+.
    #
    # @param [Integer] addr
    #   The address of the leak.
    #
    # @return [Integer]
    #   The leaked qword.
    def q(addr)
      Util::Packing.u64(n(addr, 8))
    end

    private

    # Call the leaker function on address +addr+.
    # The result would be cached.
    def do_leak(addr)
      unless @cache.key?(addr)
        data = @leak.call(addr)
        data.bytes.each.with_index(addr) { |b, i| @cache[i] = b }
      end
      @cache[addr]
    end
  end
end
