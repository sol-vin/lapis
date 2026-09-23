require "spec"
require "../src/libgodot/crash_handler"

describe "LibGodot Crash Handler & Debugger Remote Break-in Stack Overflow Absorption" do
  it "defines LibCrashFilter with system module lookup capabilities" do
    {% if flag?(:win32) %}
      h_ntdll = LibCrashFilter.GetModuleHandleA("ntdll.dll")
      h_ntdll.should_not be_nil
      h_ntdll.null?.should be_false

      p_breakin = LibCrashFilter.GetProcAddress(h_ntdll, "DbgUiRemoteBreakin")
      p_breakin.should_not be_nil
      p_breakin.null?.should be_false

      h_mod = Pointer(Void).null
      flags = 0x00000004_u32 | 0x00000002_u32
      ret = LibCrashFilter.GetModuleHandleExA(flags, p_breakin.as(LibC::Char*), pointerof(h_mod))
      ret.should eq(1)
      (h_mod == h_ntdll).should be_true
    {% else %}
      true.should be_true
    {% end %}
  end

  it "successfully absorbs simulated EXCEPTION_STACK_OVERFLOW originating from system modules" do
    {% if flag?(:win32) %}
      # Dynamically query RaiseException to simulate an exception originating in KernelBase/ntdll
      h_kbase = LibCrashFilter.GetModuleHandleA("kernelbase.dll")
      h_kbase = LibCrashFilter.GetModuleHandleA("kernel32.dll") if h_kbase.null?
      h_kbase.null?.should be_false

      p_raise = LibCrashFilter.GetProcAddress(h_kbase, "RaiseException")
      p_raise.null?.should be_false

      raise_fn = Proc(UInt32, UInt32, UInt32, UInt64*, Void).new(p_raise, Pointer(Void).null)

      # Trigger 0xC00000FD. If the VEH crash handler didn't absorb this, the process would abort.
      continued = false
      raise_fn.call(0xC00000FD_u32, 0_u32, 0_u32, Pointer(UInt64).null)
      continued = true
      continued.should be_true
    {% else %}
      true.should be_true
    {% end %}
  end
end
