# encoding: ASCII-8BIT

require 'pwnlib/timer'
require 'pwnlib/tubes/buffer'

module Pwnlib
  module Tubes
    # Things common to all tubes (sockets, tty, ...)
    class Tube
      BUFSIZE = 4096

      def initialize(timeout: nil)
        @timer = Timer.new(timeout)
        @buffer = Buffer.new
      end

      def recv(num_bytes, timeout: nil)
        return '' if @buffer.empty? && !fillbuffer(timeout: timeout)
        @buffer.get(num_bytes)
      end
      alias read recv

      def unrecv(data)
        @buffer.unget(data)
      end

      def recvpred(timeout: nil)
        raise ArgumentError, 'recvpred with no pred' unless block_given?
        @timer.countdown(timeout) do
          data = ''
          begin
            until yield(data)
              return '' unless @timer.active?

              begin
                # TODO(Darkpi): Some form of binary search to speed up?
                c = recv(1)
              rescue
                return ''
              end

              return '' if c.empty?
              data << c
            end
            data.slice!(0..-1)
          ensure
            unrecv(data)
          end
        end
      end

      def recvn(num_bytes, timeout: nil)
        @timer.countdown(timeout) do
          # TODO(Darkpi): Select!
          fillbuffer while @timer.active? && @buffer.size < num_bytes
          @buffer.size >= num_bytes ? @buffer.get(num_bytes) : ''
        end
      end

      # DIFF: We return the string that ends the earliest, rather then starts the earliest,
      #       since the latter can't be done greedly. Still, it would be bad to call this
      #       for case with ambiguity.
      def recvuntil(delims, drop: false, timeout: nil)
        delims = Array(delims)
        max_len = delims.map(&:size).max
        @timer.countdown(timeout) do
          data = Buffer.new
          matching = ''
          begin
            while @timer.active?
              begin
                s = recv(1)
              rescue # TODO(Darkpi): QQ
                return ''
              end

              return '' if s.empty?
              matching << s

              sidx = matching.size
              match_len = 0
              delims.each do |d|
                idx = matching.index(d)
                next unless idx
                if idx + d.size <= sidx + match_len
                  sidx = idx
                  match_len = d.size
                end
              end

              if sidx < matching.size
                r = data.get + matching.slice!(0, sidx + match_len)
                r.slice!(-match_len..-1) if drop
                return r
              end

              data << matching.slice!(0...-max_len) if matching.size > max_len
            end
            ''
          ensure
            unrecv(matching)
            unrecv(data)
          end
        end
      end

      def recvline(drop: false, timeout: nil)
        recvuntil("\n", drop: drop, timeout: timeout)
      end
      alias gets recvline

      def send(data)
        send_raw(data)
      end
      alias write send

      def sendline(data)
        send_raw(data + "\n")
      end
      alias puts sendline

      def interact
        $stdout.write(@buffer.get)
        until io.closed?
          rs, = IO.select([$stdin, io])
          if rs.include?($stdin)
            s = $stdin.readpartial(BUFSIZE)
            io.write(s)
          end
          if rs.include?(io)
            s = io.readpartial(BUFSIZE)
            $stdout.write(s)
          end
        end
      end

      private

      def fillbuffer(timeout: nil)
        data = @timer.countdown(timeout) do
          self.timeout_raw = @timer.timeout
          recv_raw(BUFSIZE)
        end
        # TODO(Darkpi): Logging.
        @buffer << data if data
        data
      end
    end
  end
end