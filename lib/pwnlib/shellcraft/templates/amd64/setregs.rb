::Pwnlib::Shellcraft.define(__FILE__) do |reg_context, stack_allowed: true|
  context.local(arch: 'amd64') do
    cat shellcraft.x86.setregs(reg_context, stack_allowed: stack_allowed)
  end
end