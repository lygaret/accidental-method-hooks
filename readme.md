---
name:    method-hooks
version: 0.0.1
summary: |
  a small, simple mixin for adding before/after hooks to methods 
  on your objects
---

Adds the ability to hook methods at a class or instance level, 
in order to colocate side-effects where they belong.

Designed to handle separating "plugins" out of a main class file 
into smaller concerns, but still needing to participate in the
classes full lifecycle.

### Example

```ruby
require 'method-hooks'

class System
  # install by including the module
  include Accidental::MethodHooks

  # any method is a hook point
  def startup(mode)
    puts "System#startup! (#{mode})"
  end

  # any method you'd like to hook needs to be defined first
  # so, include system plugins after hook point definitions
  include System::Plugin
end

# then, add some functionality via mixin

module System::Plugin
  # the "included" callback takes care of registering hooks
  def self.included(mod)
    mod.hook(:after, :startup, method(:plugin_startup))
  end

  # hook blocks (or any callable) are passed: 
  # the target and the original method arguments.
  def plugin_startup(self, mode)
    puts "System::Plugin#plugin_startup! #{mode}"
  end
end

# and then in use, ...

s = System.new
t = System.new

# you can hook at a class level...
System.hook(:after, :startup) do |system, mode|
  puts "class-level hook! #{mode}"
end

# or at an instance level, for hooks pertaining a single instance
t.hook(:after, :startup) do |target, mode|
  assert t.equal? target
  puts "t.startup! #{mode}"
end

s.startup("some mode")
# => System#startup! (some mode)
# => System::Plugin#plugin_startup! some mode
# => class-level hook! some mode

t.startup("other mode")
# => System#startup! (other mode)
# => System::Plugin#plugin_startup! other mode
# => class-level hook! other mode
# => t.startup! other mode
```

## Usage

Add this repo to your `Gemfile`:

```ruby
gem "method-hooks", "~> 0", git: "https://gist.github.com/117441fc5236de9f7d54b76894d69dec.git"
```
