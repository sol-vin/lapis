---
name: crystal-design-patterns
description: Comprehensive implementation guide adapting all 23 Gang of Four (GoF) design patterns to modern, idiomatic Crystal. Covers creational, structural, and behavioral patterns leveraging Crystal macros, blocks, union types, structs, fibers, and zero-cost abstractions.
---

# Crystal Design Patterns: The Complete Gang of Four (GoF) Guide

This guide provides idiomatic implementations of all **23 Gang of Four (GoF) design patterns** adapted specifically for **Crystal**.

Crystal is a statically typed, compiled language with Ruby-like syntax, zero-cost abstractions, macro metaprogramming, and fiber concurrency. Rather than blindly porting Java or C++ object-oriented ceremony, this guide illustrates how to leverage Crystal's unique strengths:
- **Zero-overhead compile-time mixins (`module`)**
- **First-class blocks and yielding (`&block`, `yield`)**
- **Static type unions (`TypeA | TypeB | Nil`) and exhaustive pattern matching (`case / when`)**
- **Value types (`struct`) for cache-friendly, zero-GC flyweights**
- **Compile-time macro delegation (`delegate`)**
- **Cooperative fiber channels (`Channel(T)`)**

---

## Table of Contents
<table>
  <thead>
    <tr>
      <th align="left">Section</th>
      <th align="left">Description</th>
      <th align="center">Lines</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="#pattern-catalog-quick-reference"><strong>Pattern Catalog Quick Reference</strong></a></td>
      <td><table></td>
      <td align="center"><code>L55–L189</code></td>
    </tr>
    <tr>
      <td><a href="#1-creational-patterns"><strong>1. Creational Patterns</strong></a></td>
      <td>### 1.1 Factory Method</td>
      <td align="center"><code>L190–L383</code></td>
    </tr>
    <tr>
      <td><a href="#2-structural-patterns"><strong>2. Structural Patterns</strong></a></td>
      <td>### 2.1 Adapter</td>
      <td align="center"><code>L384–L641</code></td>
    </tr>
    <tr>
      <td><a href="#3-behavioral-patterns"><strong>3. Behavioral Patterns</strong></a></td>
      <td>### 3.1 Chain of Responsibility</td>
      <td align="center"><code>L642–L996</code></td>
    </tr>
  </tbody>
</table>

---

## Pattern Catalog Quick Reference

<table>
  <thead>
    <tr>
      <th align="left">Category</th>
      <th align="left">Pattern</th>
      <th align="left">Crystal Idiomatic Mechanism</th>
      <th align="left">Primary Use Case</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5"><strong>Creational</strong></td>
      <td><strong>Factory Method</strong></td>
      <td>Virtual class methods (<code>def self.create</code>) &amp; macro registries</td>
      <td>Decouple creation from concrete classes</td>
    </tr>
    <tr>
      <td><strong>Abstract Factory</strong></td>
      <td>Abstract modules with typed product families</td>
      <td>Creating suites of compatible objects</td>
    </tr>
    <tr>
      <td><strong>Builder</strong></td>
      <td>Fluent DSL builders yielding <code>self</code> with blocks</td>
      <td>Complex multi-step object configuration</td>
    </tr>
    <tr>
      <td><strong>Prototype</strong></td>
      <td><code>#clone</code> vs <code>#dup</code>, immutable <code>struct</code> / <code>record</code></td>
      <td>Duplicating expensive object graphs</td>
    </tr>
    <tr>
      <td><strong>Singleton</strong></td>
      <td>Module methods or <code>class_property instance</code></td>
      <td>Coordinated single points of access (use sparingly)</td>
    </tr>
    <tr>
      <td rowspan="7"><strong>Structural</strong></td>
      <td><strong>Adapter</strong></td>
      <td>Wrapper classes with <code>delegate</code> macro</td>
      <td>Translating incompatible interfaces</td>
    </tr>
    <tr>
      <td><strong>Bridge</strong></td>
      <td>Generic type parameters (<code>class App(Renderer)</code>)</td>
      <td>Decoupling abstraction from implementation</td>
    </tr>
    <tr>
      <td><strong>Composite</strong></td>
      <td>Tree nodes including <code>Enumerable(T)</code></td>
      <td>Recursive part-whole hierarchies</td>
    </tr>
    <tr>
      <td><strong>Decorator</strong></td>
      <td>Wrapping references + <code>delegate ..., to: @wrapped</code></td>
      <td>Adding dynamic behavior without subclasses</td>
    </tr>
    <tr>
      <td><strong>Facade</strong></td>
      <td>Unified module encapsulating internal subsystems</td>
      <td>Providing a simple top-level entry point</td>
    </tr>
    <tr>
      <td><strong>Flyweight</strong></td>
      <td>Immutable value <code>struct</code> and interning tables</td>
      <td>Sharing state across millions of tiny objects</td>
    </tr>
    <tr>
      <td><strong>Proxy</strong></td>
      <td>Lazy initialization or access-control wrappers</td>
      <td>Surrogate placeholder for expensive resources</td>
    </tr>
    <tr>
      <td rowspan="11"><strong>Behavioral</strong></td>
      <td><strong>Chain of Resp.</strong></td>
      <td>Linked handlers or block-based middleware chains</td>
      <td>Sequential request processing pipeline</td>
    </tr>
    <tr>
      <td><strong>Command</strong></td>
      <td>Action structs/classes with <code>#execute</code> and <code>#undo</code></td>
      <td>Transactional actions, replay, undo/redo</td>
    </tr>
    <tr>
      <td><strong>Interpreter</strong></td>
      <td>AST expression nodes with pattern matching</td>
      <td>Evaluating domain-specific languages (DSL)</td>
    </tr>
    <tr>
      <td><strong>Iterator</strong></td>
      <td>Native <code>Iterator(T)</code> and <code>Enumerable(T)</code> with <code>yield</code></td>
      <td>Sequential traversal without exposing internals</td>
    </tr>
    <tr>
      <td><strong>Mediator</strong></td>
      <td>Central hub with Procs or typed Channels</td>
      <td>Decoupling many-to-many communications</td>
    </tr>
    <tr>
      <td><strong>Memento</strong></td>
      <td>Immutable state snapshots using <code>record</code></td>
      <td>Capturing and restoring internal state safely</td>
    </tr>
    <tr>
      <td><strong>Observer</strong></td>
      <td>Callback arrays (<code>Array(Proc)</code>) or <code>Channel(T)</code></td>
      <td>One-to-many publish-subscribe events</td>
    </tr>
    <tr>
      <td><strong>State</strong></td>
      <td>Polymorphic state classes or union types (<code>Idle | Moving</code>)</td>
      <td>Context behavior varying by internal state</td>
    </tr>
    <tr>
      <td><strong>Strategy</strong></td>
      <td>Blocks, Procs, or duck-typed interchangeable classes</td>
      <td>Swapping algorithms at runtime</td>
    </tr>
    <tr>
      <td><strong>Template Method</strong></td>
      <td>Abstract class defining algorithm skeleton + hooks</td>
      <td>Invariant workflows with customizable steps</td>
    </tr>
    <tr>
      <td><strong>Visitor</strong></td>
      <td>Exhaustive pattern matching (<code>case obj; when ...</code>)</td>
      <td>Adding operations to classes without changing them</td>
    </tr>
  </tbody>
</table>

---

## 1. Creational Patterns

### 1.1 Factory Method
Define an interface for creating an object, but let subclasses decide which class to instantiate.

In Crystal, factory methods are typically written as virtual class methods (`self.create`) or macro-driven registration tables:

```crystal
abstract class Document
  abstract def render : String
end

class PdfDocument < Document
  def render : String
    "[PDF Document Content]"
  end
end

class HtmlDocument < Document
  def render : String
    "<html><body>Content</body></html>"
  end
end

abstract class DocumentCreator
  # Factory Method
  abstract def create_document : Document

  def publish : String
    doc = create_document
    "Publishing: #{doc.render}"
  end
end

class PdfCreator < DocumentCreator
  def create_document : Document
    PdfDocument.new
  end
end

class HtmlCreator < DocumentCreator
  def create_document : Document
    HtmlDocument.new
  end
end
```

### 1.2 Abstract Factory
Provide an interface for creating families of related or dependent objects without specifying their concrete classes.

```crystal
# Abstract Products
abstract class Button
  abstract def paint : String
end

abstract class ScrollBar
  abstract def paint : String
end

# Concrete Products: Light Theme
class LightButton < Button
  def paint : String; "Rendered Light Button"; end
end

class LightScrollBar < ScrollBar
  def paint : String; "Rendered Light ScrollBar"; end
end

# Concrete Products: Dark Theme
class DarkButton < Button
  def paint : String; "Rendered Dark Button"; end
end

class DarkScrollBar < ScrollBar
  def paint : String; "Rendered Dark ScrollBar"; end
end

# Abstract Factory
abstract class GuiFactory
  abstract def create_button : Button
  abstract def create_scrollbar : ScrollBar
end

class LightThemeFactory < GuiFactory
  def create_button : Button; LightButton.new; end
  def create_scrollbar : ScrollBar; LightScrollBar.new; end
end

class DarkThemeFactory < GuiFactory
  def create_button : Button; DarkButton.new; end
  def create_scrollbar : ScrollBar; DarkScrollBar.new; end
end
```

### 1.3 Builder
Separate the construction of a complex object from its representation, allowing the same construction process to create various representations.

In Crystal, the idiomatic builder pattern yields `self` to a configuration block:

```crystal
class ServerConfig
  getter host : String
  getter port : Int32
  getter tls : Boolean
  getter max_connections : Int32

  def initialize(@host : String, @port : Int32, @tls : Boolean, @max_connections : Int32)
  end

  # Fluent Builder with block DSL
  class Builder
    property host : String = "localhost"
    property port : Int32 = 8080
    property tls : Boolean = false
    property max_connections : Int32 = 1000

    def build : ServerConfig
      ServerConfig.new(@host, @port, @tls, @max_connections)
    end
  end

  def self.build(&block : Builder -> Nil) : ServerConfig
    builder = Builder.new
    yield builder
    builder.build
  end
end

# Usage:
config = ServerConfig.build do |b|
  b.host = "api.example.com"
  b.port = 443
  b.tls = true
end
```

### 1.4 Prototype
Specify the kinds of objects to create using a prototypical instance, and create new objects by copying this prototype.

In Crystal:
- Use `#dup` for a shallow copy.
- Implement `#clone` for a recursive deep copy.
- Prefer immutable `struct` or `record` with `.copy()` for value-semantic prototypes.

```crystal
class Monster
  property name : String
  property health : Int32
  property abilities : Array(String)

  def initialize(@name : String, @health : Int32, @abilities : Array(String))
  end

  # Deep clone prototype method
  def clone : Monster
    Monster.new(@name, @health, @abilities.dup)
  end
end

goblin_proto = Monster.new("Goblin", 50, ["slash", "scamper"])
goblin_scout = goblin_proto.clone
goblin_scout.name = "Goblin Scout"
goblin_scout.health = 35
```

### 1.5 Singleton
Ensure a class only has one instance, and provide a global point of access to it.

> [!WARNING]
> In Crystal, global singletons often cause test-isolation and multithreading bottlenecks. Whenever possible, prefer dependency injection. When genuine singletons are required, use `class_property` with thread-safe atomic initialization:

```crystal
class AudioEngine
  # Lazy thread-safe singleton
  class_getter instance : AudioEngine do
    new
  end

  private def initialize
    @initialized = true
  end

  def play(sound_id : String) : Void
    # Audio play logic
  end
end

# Usage:
AudioEngine.instance.play("boom.wav")
```

---

## 2. Structural Patterns

### 2.1 Adapter
Convert the interface of a class into another interface clients expect. Adapter lets classes work together that couldn't otherwise because of incompatible interfaces.

Crystal provides the `delegate` macro for zero-boilerplate forwarding:

```crystal
# Existing 3rd-party interface
class LegacyJsonLogger
  def log_json_payload(raw_json : String) : Void
    # Writes raw JSON
  end
end

# Target interface expected by client
abstract class AppLogger
  abstract def info(message : String) : Void
end

# Adapter using composition and delegation
class JsonLoggerAdapter < AppLogger
  def initialize(@legacy : LegacyJsonLogger)
  end

  def info(message : String) : Void
    payload = %({"level":"info","message":#{message.to_json}})
    @legacy.log_json_payload(payload)
  end
end
```

### 2.2 Bridge
Decouple an abstraction from its implementation so that the two can vary independently.

In Crystal, generics allow compile-time bridges with zero virtual dispatch overhead:

```crystal
abstract class Renderer
  abstract def render_circle(radius : Float64) : String
end

class VectorRenderer < Renderer
  def render_circle(radius : Float64) : String
    "Drawing circle radius #{radius} as SVG vector"
  end
end

class RasterRenderer < Renderer
  def render_circle(radius : Float64) : String
    "Drawing circle radius #{radius} as raster pixels"
  end
end

# Abstraction generic over Renderer
abstract class Shape
  def initialize(@renderer : Renderer)
  end

  abstract def draw : String
end

class Circle < Shape
  def initialize(@radius : Float64, renderer : Renderer)
    super(renderer)
  end

  def draw : String
    @renderer.render_circle(@radius)
  end
end
```

### 2.3 Composite
Compose objects into tree structures to represent part-whole hierarchies. Composite lets clients treat individual objects and compositions of objects uniformly.

```crystal
abstract class Graphic
  abstract def draw(indent : Int32 = 0) : String
end

class Dot < Graphic
  def initialize(@x : Int32, @y : Int32)
  end

  def draw(indent : Int32 = 0) : String
    "#{"  " * indent}Dot at (#{@x}, #{@y})\n"
  end
end

class CompoundGraphic < Graphic
  include Enumerable(Graphic)

  def initialize
    @children = Array(Graphic).new
  end

  def add(graphic : Graphic) : self
    @children << graphic
    self
  end

  def each(&block : Graphic -> Nil) : Nil
    @children.each { |c| yield c }
  end

  def draw(indent : Int32 = 0) : String
    String.build do |str|
      str << "  " * indent << "Group:\n"
      @children.each { |child| str << child.draw(indent + 1) }
    end
  end
end
```

### 2.4 Decorator
Attach additional responsibilities to an object dynamically. Decorators provide a flexible alternative to subclassing for extending functionality.

```crystal
abstract class Coffee
  abstract def cost : Float64
  abstract def description : String
end

class SimpleCoffee < Coffee
  def cost : Float64; 2.0; end
  def description : String; "Simple Coffee"; end
end

abstract class CoffeeDecorator < Coffee
  def initialize(@decorated : Coffee)
  end

  delegate cost, description, to: @decorated
end

class MilkDecorator < CoffeeDecorator
  def cost : Float64
    @decorated.cost + 0.5
  end

  def description : String
    "#{@decorated.description}, with Milk"
  end
end

class SugarDecorator < CoffeeDecorator
  def cost : Float64
    @decorated.cost + 0.25
  end

  def description : String
    "#{@decorated.description}, with Sugar"
  end
end
```

### 2.5 Facade
Provide a unified interface to a set of interfaces in a subsystem. Facade defines a higher-level interface that makes the subsystem easier to use.

```crystal
class VideoDecoder
  def decode(file : String) : String; "decoded_frames"; end
end

class AudioDecoder
  def decode(file : String) : String; "audio_pcm"; end
end

class DisplayPipeline
  def present(video : String, audio : String) : String; "Playing media"; end
end

# Simple Facade
module MediaPlayer
  @@video = VideoDecoder.new
  @@audio = AudioDecoder.new
  @@display = DisplayPipeline.new

  def self.play(file : String) : String
    v = @@video.decode(file)
    a = @@audio.decode(file)
    @@display.present(v, a)
  end
end
```

### 2.6 Flyweight
Use sharing to support large numbers of fine-grained objects efficiently.

In Crystal, immutable value types (`struct`) or interning hash tables eliminate heap allocations completely:

```crystal
# Intrinsic State (shared across all trees of the same type)
record TreeType, name : String, color : String, texture_id : Int32

# Extrinsic State (unique per tree on the map)
struct Tree
  getter x : Float32
  getter y : Float32
  getter type : TreeType

  def initialize(@x : Float32, @y : Float32, @type : TreeType)
  end
end

class Forest
  @tree_types = Hash(String, TreeType).new
  @trees = Array(Tree).new

  def get_type(name : String, color : String, texture_id : Int32) : TreeType
    @tree_types[name] ||= TreeType.new(name, color, texture_id)
  end

  def plant_tree(x : Float32, y : Float32, name : String, color : String, texture_id : Int32) : Void
    type = get_type(name, color, texture_id)
    @trees << Tree.new(x, y, type) # Only extrinsic coordinates stored per tree!
  end
end
```

### 2.7 Proxy
Provide a surrogate or placeholder for another object to control access to it.

```crystal
abstract class Image
  abstract def display : String
end

class RealImage < Image
  def initialize(@filename : String)
    load_from_disk
  end

  private def load_from_disk : Void
    # Heavy I/O operation
  end

  def display : String
    "Displaying #{@filename}"
  end
end

# Virtual Proxy: Lazily loads real image only upon display
class LazyImageProxy < Image
  @real_image : RealImage?

  def initialize(@filename : String)
  end

  def display : String
    (@real_image ||= RealImage.new(@filename)).display
  end
end
```

---

## 3. Behavioral Patterns

### 3.1 Chain of Responsibility
Avoid coupling the sender of a request to its receiver by giving more than one object a chance to handle the request. Chain the receiving objects and pass the request along the chain until an object handles it.

```crystal
abstract class RequestHandler
  property next_handler : RequestHandler?

  def handle(request : String) : String?
    if next_node = @next_handler
      next_node.handle(request)
    else
      nil
    end
  end
end

class AuthHandler < RequestHandler
  def handle(request : String) : String?
    return "Auth Failed" if request.includes?("unauthorized")
    super(request)
  end
end

class CacheHandler < RequestHandler
  def handle(request : String) : String?
    return "Cache Hit: cached_result" if request.includes?("cached_key")
    super(request)
  end
end
```

### 3.2 Command
Encapsulate a request as an object, thereby letting you parameterize clients with different requests, queue or log requests, and support undoable operations.

```crystal
abstract class Command
  abstract def execute : Void
  abstract def undo : Void
end

class TextEditor
  property content : String = ""
end

class InsertTextCommand < Command
  def initialize(@editor : TextEditor, @text : String)
  end

  def execute : Void
    @editor.content += @text
  end

  def undo : Void
    @editor.content = @editor.content[0...-@text.size]
  end
end

class CommandHistory
  @history = Array(Command).new
  @redo_stack = Array(Command).new

  def execute(cmd : Command) : Void
    cmd.execute
    @history << cmd
    @redo_stack.clear
  end

  def undo : Void
    return if @history.empty?
    cmd = @history.pop
    cmd.undo
    @redo_stack << cmd
  end
end
```

### 3.3 Interpreter
Given a language, define a representation for its grammar along with an interpreter that uses the representation to interpret sentences in the language.

In Crystal, algebraic data types / pattern matching make AST interpreters elegant:

```crystal
abstract class Expression
  abstract def interpret(context : Hash(String, Int32)) : Int32
end

class NumberExpression < Expression
  def initialize(@val : Int32); end
  def interpret(context : Hash(String, Int32)) : Int32; @val; end
end

class VariableExpression < Expression
  def initialize(@name : String); end
  def interpret(context : Hash(String, Int32)) : Int32
    context[@name]? || 0
  end
end

class AddExpression < Expression
  def initialize(@left : Expression, @right : Expression); end
  def interpret(context : Hash(String, Int32)) : Int32
    @left.interpret(context) + @right.interpret(context)
  end
end
```

### 3.4 Iterator
Provide a way to access the elements of an aggregate object sequentially without exposing its underlying representation.

Crystal has built-in, first-class iterator protocols:
1. **Block yielding (`each(&block)`)**: Zero-overhead internal iteration.
2. **`Iterator(T)` protocol**: External pull-based iteration implementing `#next`.

```crystal
class NumberSeries
  include Enumerable(Int32)

  def initialize(@limit : Int32)
  end

  def each(&block : Int32 -> Nil) : Nil
    (1..@limit).each { |i| yield i }
  end
end

# Pull-based external iterator
class FibonacciIterator
  include Iterator(Int32)

  def initialize(@max_steps : Int32)
    @a = 0
    @b = 1
    @step = 0
  end

  def next : Int32 | Iterator::Stop
    return stop if @step >= @max_steps
    res = @a
    @a, @b = @b, @a + @b
    @step += 1
    res
  end
end
```

### 3.5 Mediator
Define an object that encapsulates how a set of objects interact. Mediator promotes loose coupling by keeping objects from referring to each other explicitly.

```crystal
abstract class Component
  property! mediator : Mediator
end

abstract class Mediator
  abstract def notify(sender : Component, event : String) : Void
end

class ButtonComponent < Component
  def click : Void
    mediator.notify(self, "button_click")
  end
end

class TextBoxComponent < Component
  property text : String = ""
end

class DialogMediator < Mediator
  def initialize(@button : ButtonComponent, @text_box : TextBoxComponent)
    @button.mediator = self
    @text_box.mediator = self
  end

  def notify(sender : Component, event : String) : Void
    if event == "button_click"
      @text_box.text = "Submitted"
    end
  end
end
```

### 3.6 Memento
Without violating encapsulation, capture and externalize an object's internal state so that the object can be restored to this state later.

```crystal
# Immutable Memento
record EditorMemento, text : String, cursor_pos : Int32

class CodeEditor
  property text : String = ""
  property cursor_pos : Int32 = 0

  def save : EditorMemento
    EditorMemento.new(@text, @cursor_pos)
  end

  def restore(m : EditorMemento) : Void
    @text = m.text
    @cursor_pos = m.cursor_pos
  end
end
```

### 3.7 Observer
Define a one-to-many dependency between objects so that when one object changes state, all its dependents are notified and updated automatically.

```crystal
class Event(T)
  def initialize
    @subscribers = Array(T -> Nil).new
  end

  def subscribe(&block : T -> Nil) : Nil
    @subscribers << block
  end

  def emit(data : T) : Void
    @subscribers.each { |subscriber| subscriber.call(data) }
  end
end

class UserAccount
  getter on_login = Event(String).new

  def login(username : String) : Void
    on_login.emit(username)
  end
end

# Usage:
account = UserAccount.new
account.on_login.subscribe do |user|
  puts "Welcome back, #{user}!"
end
account.login("Alice")
```

### 3.8 State
Allow an object to alter its behavior when its internal state changes. The object will appear to change its class.

In Crystal, State can be written with classic polymorphic classes **or** static union types:

```crystal
# Idiom A: Polymorphic State Classes
abstract class PlayerState
  abstract def handle_input(player : PlayerContext, action : String) : Void
end

class StandingState < PlayerState
  def handle_input(player : PlayerContext, action : String) : Void
    if action == "jump"
      player.state = JumpingState.new
    end
  end
end

class JumpingState < PlayerState
  def handle_input(player : PlayerContext, action : String) : Void
    # While jumping, ignore jumps
  end
end

class PlayerContext
  property state : PlayerState = StandingState.new

  def handle_input(action : String) : Void
    @state.handle_input(self, action)
  end
end
```

### 3.9 Strategy
Define a family of algorithms, encapsulate each one, and make them interchangeable. Strategy lets the algorithm vary independently from clients that use it.

In Crystal, strategies are often simply `Proc` arguments or duck-typed classes:

```crystal
# Proc-based Strategy
alias Sorter = Array(Int32) -> Array(Int32)

class DataList
  property sorter : Sorter

  def initialize(@items : Array(Int32), @sorter : Sorter = ->(arr : Array(Int32)) { arr.sort })
  end

  def organized : Array(Int32)
    @sorter.call(@items)
  end
end

# Usage:
list = DataList.new([3, 1, 4, 1, 5])
list.sorter = ->(arr : Array(Int32)) { arr.sort.reverse }
```

### 3.10 Template Method
Define the skeleton of an algorithm in an operation, deferring some steps to subclasses. Template Method lets subclasses redefine certain steps of an algorithm without changing the algorithm's structure.

```crystal
abstract class DataMiner
  # Template method defining algorithm skeleton
  def mine(path : String) : String
    data = open_file(path)
    parsed = parse_data(data)
    hook_after_parse(parsed)
    analyze(parsed)
  end

  abstract def open_file(path : String) : String
  abstract def parse_data(raw : String) : String

  # Optional hook
  def hook_after_parse(parsed : String) : Void
  end

  private def analyze(parsed : String) : String
    "Analyzed: #{parsed}"
  end
end

class CsvMiner < DataMiner
  def open_file(path : String) : String; "CSV raw bytes"; end
  def parse_data(raw : String) : String; "CSV table records"; end
end
```

### 3.11 Visitor
Represent an operation to be performed on the elements of an object structure. Visitor lets you define a new operation without changing the classes of the elements on which it operates.

In Crystal, **pattern matching (`case / when`)** is usually far cleaner than double dispatch:

```crystal
abstract class DocumentItem; end
class Paragraph < DocumentItem; getter text : String = "Hello"; end
class ImageItem < DocumentItem; getter src : String = "hero.png"; end

class HtmlExporter
  def export(items : Array(DocumentItem)) : String
    String.build do |str|
      items.each do |item|
        case item
        when Paragraph
          str << "<p>" << item.text << "</p>\n"
        when ImageItem
          str << "<img src='" << item.src << "'/>\n"
        end
      end
    end
  end
end
```
