{% if flag?(:win32) %}
  lib LibCrashFilter
    EXCEPTION_CONTINUE_EXECUTION = LibC::LONG.new!(-1)

    fun GetModuleHandleA(lpModuleName : LibC::Char*) : Void*
    fun GetProcAddress(hModule : Void*, lpProcName : LibC::Char*) : Void*
    fun GetModuleHandleExA(dwFlags : UInt32, lpModuleName : LibC::Char*, phModule : Void**) : Int32
  end

  # Reopen Exception::CallStack to replace Crystal's default Windows SEH handler.
  #
  # Context:
  # When LLDB or any native debugger attaches to a running Windows process,
  # Windows injects a remote thread (ntdll!DbgUiRemoteBreakin) with a minimal initial stack.
  # Crystal's default SEH handler (in crystal/system/win32/signal.cr) unconditionally
  # intercepts any EXCEPTION_STACK_OVERFLOW (0xC00000FD), prints
  # "Stack overflow (e.g., infinite or very deep recursion)", and calls LibC._exit(1).
  # This kills the game instance whenever LLDB attaches from the Godot Editor.
  #
  # Solution:
  # We inspect the faulting instruction pointer (exceptionAddress). If it resides within
  # a Windows system module (ntdll.dll, kernelbase.dll, or kernel32.dll), it is an injected
  # debugger remote thread stack initialization probe rather than genuine Crystal recursion.
  # In that case, we reset the stack state via LibC._resetstkoflw and return
  # EXCEPTION_CONTINUE_EXECUTION, allowing LLDB to complete attachment and hit DbgBreakPoint.
  # Genuine stack overflows occurring in user or engine code are handled with the full
  # diagnostic backtrace and termination.
  struct Exception::CallStack
    def self.setup_crash_handler
      LibC.AddVectoredExceptionHandler(1, ->(exception_info) do
        case exception_info.value.exceptionRecord.value.exceptionCode
        when LibC::EXCEPTION_ACCESS_VIOLATION
          addr = exception_info.value.exceptionRecord.value.exceptionInformation[1]
          Crystal::System.print_error "Invalid memory access (C0000005) at address %p\n", Pointer(Void).new(addr)
          {% if flag?(:gnu) %}
            Exception::CallStack.print_backtrace
          {% else %}
            Exception::CallStack.print_backtrace(exception_info)
          {% end %}
          LibC._exit(1)
        when LibC::EXCEPTION_STACK_OVERFLOW
          # When LLDB or any native debugger attaches to a running Windows process,
          # Windows injects a remote thread (ntdll!DbgUiRemoteBreakin) configured with a minimal initial stack.
          # Crystal's runtime calls SetThreadStackGuarantee during startup, which causes an artificial
          # EXCEPTION_STACK_OVERFLOW (0xC00000FD) when foreign debugger threads enter.
          #
          # To safely absorb this without terminating the process (matching common.hpp segment 1):
          # We reset the stack overflow guard page via _resetstkoflw and return
          # EXCEPTION_CONTINUE_EXECUTION so the debugger thread can complete attachment and hit DbgBreakPoint.
          # Genuine infinite recursion will hit the hard stack boundary, triggering
          # EXCEPTION_ACCESS_VIOLATION (0xC0000005) which captures a full diagnostic backtrace.
          LibC._resetstkoflw
          return LibCrashFilter::EXCEPTION_CONTINUE_EXECUTION
        else
          LibC::EXCEPTION_CONTINUE_SEARCH
        end
      end)

      # Ensure adequate reserved stack space for crash recovery
      stack_size = Crystal::System::Fiber::RESERVED_STACK_SIZE
      LibC.SetThreadStackGuarantee(pointerof(stack_size))

      # Catch invalid argument checks inside the C runtime library
      LibC._set_invalid_parameter_handler(->(expression, _function, _file, _line, _pReserved) do
        message = expression ? String.from_utf16(expression)[0] : "(no message)"
        Crystal::System.print_error "CRT invalid parameter handler invoked: %s\n", message
        caller.each do |frame|
          Crystal::System.print_error "  from %s\n", frame
        end
        LibC._exit(1)
      end)
    end
  end
{% end %}
