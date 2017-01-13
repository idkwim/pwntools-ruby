# encoding: ASCII-8BIT
require 'test_helper'
require 'pwnlib/shellcraft/shellcraft'
require 'pwnlib/context'

class ExecveTest < MiniTest::Test
  include ::Pwnlib::Context

  def setup
    @shellcraft = ::Pwnlib::Shellcraft.instance
  end

  def test_amd64
    context.local(arch: 'amd64') do
      assert_equal(<<-'EOS', @shellcraft.execve('/bin///sh', 0, nil))
  /* push "/bin///sh\x00" */
  push 0x68
  mov rax, 0x732f2f2f6e69622f
  push rax

  /* call execve("rsp", 0, 0) */
  push (SYS_execve) /* 0x3b */
  pop rax
  mov rdi, rsp
  xor esi, esi /* 0 */
  cdq /* rdx=0 */
  syscall
      EOS
      assert_equal(<<-'EOS', @shellcraft.execve('rax', ['sh'], PWD: '.'))
  /* push argument array ["sh\x00"] */
  /* push "sh\x00" */
  push 0x1010101 ^ 0x6873
  xor dword ptr [rsp], 0x1010101
  xor esi, esi /* 0 */
  push rsi /* null terminate */
  push 8
  pop rsi
  add rsi, rsp
  push rsi /* "sh\x00" */
  mov rsi, rsp

  /* push argument array ["PWD=.\x00"] */
  /* push "PWD=.\x00" */
  mov rax, 0x101010101010101
  push rax
  mov rax, 0x101010101010101 ^ 0x2e3d445750
  xor [rsp], rax
  xor edx, edx /* 0 */
  push rdx /* null terminate */
  push 8
  pop rdx
  add rdx, rsp
  push rdx /* "PWD=.\x00" */
  mov rdx, rsp

  /* call execve("rax", "rsi", "rdx") */
  mov rdi, rax
  push (SYS_execve) /* 0x3b */
  pop rax
  syscall
      EOS
      assert_equal(<<-'EOS', @shellcraft.execve('rdi', 'rsi', 'rdx'))
  /* call execve("rdi", "rsi", "rdx") */
  push (SYS_execve) /* 0x3b */
  pop rax
  syscall
      EOS
      err = assert_raises(ArgumentError) { @shellcraft.execve('rdi', 'rdi', 'xdd') }
      assert_match(/not a valid register/, err.message)
      err = assert_raises(ArgumentError) { @shellcraft.execve('rdi', 'qqpie', 'rdi') }
      assert_match(/not a valid register/, err.message)
    end
  end
end
