module Accidental
  # Included on a class, {Accidental::MethodHooks} extends that class -- and instances of
  # that class -- to support arbitrary hooks to be run before/after any method.
  #
  # One use case is to allow "plugins", where a plugin is a module that's included
  # in a class, and can participate in that class instance's lifecycle by hooking
  # lifecycle hook points exposed at the top level. See {System} for an example.
  #
  # Hooks are added by replacing the hooked method, and as such, hooks will not
  # be run if a method is redefined, or is defined _after_ the hook attempt.
  #
  # @example
  #   class Foo
  #     include Accidental::MethodHooks
  #     def foobar
  #       puts "Foo#foobar"
  #     end
  #   end
  #
  #   Foo.hook(:before, :foobar) do |foo|
  #     puts "hooked #{foo} before foobar!"
  #   end
  #
  #   f = Foo.new#
  #   f.foobar
  #   #=> hooked #<Foo:0x000000010bce5908> before foobar!
  #   #=> Foo#foobar
  #
  #   g = Foo.new
  #   g.hook(:after, :foobar) do |foo|
  #     puts "hooked g, specifically, after foobar! #{foo} == g is #{foo == g}"
  #   end
  #   #=> hooked #<Foo:0x000000010c6c84c0> before foobar!
  #   #=> Foo#foobar
  #   #=> hooked g, specifically, after foobar! #<Foo:0x000000010c6c84c0> == g is true
  module MethodHooks

    VALID_HOOKS = %i[before after around error].freeze

    def self.included(mod)
      mod.const_set(:HookHost, Module.new)

      mod.extend ClassMethods
      mod.prepend mod::HookHost
    end

    # @see ClassMethods#hook
    def hook(...) = singleton_class.hook(...)

    module ClassMethods

      # extend class methods into singleton class
      # this lets us define hooks on specific instances as well
      def new(...)
        super.tap { _1.singleton_class.include MethodHooks }
      end

      # Hook the given stage of the given method call on the reciever.
      # @param hook [string] a valid hook stage, see {VALID_HOOKS}
      # @param meth [symbol] the name of the method to hook, must _already_ be defined on the class/instance
      # @param callee [#call,nil] a callable, which will be the target of the hook, or nil if a block is given
      # @return the hooked object
      def hook(hook, meth, callee = nil, &block)
        raise ArgumentError, "hook: #{hook}?" unless VALID_HOOKS.include? hook
        raise ArgumentError, "hook: #{callee} _and_ block given!" if callee && block
        raise ArgumentError, "hook: #{callee} not callable?" if callee && !callee.respond_to?(:call)

        hooks_for(hook, meth) << (callee || block)
        ensure_hook(meth)

        self
      end

    private

      # @return [Module] the host module for hooked methods
      def hook_host = const_get(:HookHost)

      # @param hook [symbol] the hook stage to search for hooks
      # @param meth [symbol] the method to search for hooks
      # @return [Array<#call>] a modifiable array of callable hooks for the given method/hook
      def hooks_for(hook, meth)
        @hooks       ||= {}
        @hooks[meth] ||= VALID_HOOKS.each_with_object({}) { |h, m| m[h] = [] }
        @hooks[meth][hook]
      end

      # ensure the given method has been overridden to invoke hooks
      # @param meth [symbol] the method to override with a hook
      def ensure_hook(meth)
        return if hook_host.instance_methods.include?(meth.to_sym)

        # this way we don't have to deal with aliasing
        host = const_get(:HookHost)

        # this is a proc so that _self_ is correctly defined
        # because this is going to get closed over in the define_method block
        hooks = ->(hook) { hooks_for(hook, meth) }

        # define the hooked method in the hook host module
        host.define_method(meth) do |*args, **kwargs, &block|
          exec_hook = ->(hook, *args, **kwargs) do
            hooks.call(hook).each { |h| h.call(self, *args, **kwargs) }
          end

          begin
            exec_hook.call(:before, *args, **kwargs)
            super(*args, **kwargs, &block).tap do
              exec_hook.call(:after, *args, **kwargs)
            end
          rescue => ex
            exec_hook.call(:error, ex, *args, **kwargs)
            raise
          end
        end

        # define_method(meth) do |*args, **kwargs, &block|
        #   self.class.hooks_for(meth, :around)
        #     .reverse
        #     .reduce(runner) { |h, hs| ->(*a,**k) { hs.call(*a,**k,&h) } }
        #     .call(*args, **kwargs, &block)
        # end

        # return with the hook registry for this method
      end
    end

  end
end
