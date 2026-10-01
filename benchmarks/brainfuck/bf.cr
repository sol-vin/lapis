# Brainfuck AST interpreter benchmark (based on kostya/benchmarks)

module Op
  record Inc, val : Int32
  record Move, val : Int32
  record Print
  alias T = Inc | Move | Print | Array(Op::T)
end

class Tape
  def initialize
    @tape = [0]
    @pos = 0
  end

  def get : Int32
    @tape[@pos]
  end

  def inc(x : Int32)
    @tape[@pos] += x
  end

  def move(x : Int32)
    @pos += x
    while @pos >= @tape.size
      @tape << 0
    end
  end
end

class Printer
  getter quiet : Bool

  def initialize(@quiet : Bool = true)
    @sum1 = 0
    @sum2 = 0
  end

  def print(n : Int32)
    if @quiet
      @sum1 = (@sum1 + n) % 255
      @sum2 = (@sum2 + @sum1) % 255
    else
      ::print(n.chr)
    end
  end

  def checksum : Int32
    (@sum2 << 8) | @sum1
  end
end

class Program
  @ops : Array(Op::T)

  def initialize(code : String, @p : Printer)
    @ops = parse(code.each_char)
  end

  def run
    _run(@ops, Tape.new)
  end

  private def _run(program, tape)
    program.each do |op|
      case op
      when Op::Inc
        tape.inc(op.val)
      when Op::Move
        tape.move(op.val)
      when Array(Op::T)
        while tape.get > 0
          _run(op, tape)
        end
      when Op::Print
        @p.print(tape.get)
      end
    end
  end

  private def parse(iterator)
    res = [] of Op::T
    iterator.each do |c|
      op = case c
           when '+'; Op::Inc.new(1)
           when '-'; Op::Inc.new(-1)
           when '>'; Op::Move.new(1)
           when '<'; Op::Move.new(-1)
           when '.'; Op::Print.new
           when '['; parse(iterator)
           when ']'; break
           else; nil
           end
      res << op if op
    end
    res
  end
end

# Self-verification
text = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>\n---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
p_left = Printer.new(true)
Program.new(text, p_left).run
left = p_left.checksum

p_right = Printer.new(true)
"Hello World!\n".each_char { |c| p_right.print(c.ord) }
right = p_right.checksum

if left != right
  STDERR.puts "Verification failed: #{left} != #{right}"
  exit(1)
end

file_path = ARGV[0]? || File.join(__DIR__, "bench.b")
code = File.read(file_path)

printer = Printer.new(true)
start_time = Time.instant
Program.new(code, printer).run
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "RESULT: checksum=#{printer.checksum}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
