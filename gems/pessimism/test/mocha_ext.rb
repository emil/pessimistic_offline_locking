# Mocha extensions to the <tt>any_instance</tt> <tt>returns</tt> mock object. In the case where
# returns was passed a <tt>Proc</tt> parameter and the proc defines an argument the target instance
# will be passed as the argument.
#   <tt>Product.any_instance.stubs(:save).returns(lambda {|p| p.valid? })</tt>
#   <tt>product = Product.new</tt>
#   <tt>product.save</tt>
module Mocha # :nodoc:

  class AnyInstanceMethod < ClassMethod
    def define_new_method
      definition_target.class_eval(<<-CODE, __FILE__, __LINE__ + 1)
        def #{method}(*args, &block)
          self.class.any_instance.mocha.instance_variable_set('@__target_self__', self)
          self.class.any_instance.mocha.method_missing(:#{method}, *args, &block)
        end
      CODE
      if @original_visibility
        Module.instance_method(@original_visibility).bind(definition_target).call(method)
      end
    end
  end

  class SingleReturnValue # :nodoc:
    def evaluate(arguments = nil)
      if @value.__is_a__(Proc) then
        return @value.call if @value.arity == -1
        return @value.call(*arguments)
      else
        @value
      end
    end
  end

  class ReturnValues # :nodoc:

    def next(arguments = nil)
      case @values.size
      when 0 then nil
      when 1
        item = @values.first
        # Something.stubs(:method).raises(AnError) results in @values containing a Mocha::ExceptionRaiser.
        # Calling evaluate(arguments) on an ExceptionRaiser produces "wrong number of arguments (1 for 0)"
        item.instance_of?(ExceptionRaiser) ? item.evaluate : item.evaluate(arguments)
      else 
        item = @values.shift
        item.instance_of?(ExceptionRaiser) ? item.evaluate : item.evaluate(arguments)
      end
    end
  end

  # Methods on expectations returned from Mock#expects, Mock#stubs, Object#expects and Object#stubs.
  class Expectation
    def invoke(arguments = nil)
      @invocation_count += 1
      perform_side_effects()
      if block_given? then
        @yield_parameters.next_invocation.each do |yield_parameters|
          yield(*yield_parameters)
        end
      end
      @return_values.next(arguments)
    end
  end

  class Mock
    def method_missing(symbol, *arguments, &block)
      target = instance_variable_get('@__target_self__')
      if @responder and not @responder.respond_to?(symbol)
        raise NoMethodError, "undefined method `#{symbol}' for #{self.mocha_inspect} which responds like #{@responder.mocha_inspect}"
      end
      if matching_expectation_allowing_invocation = all_expectations.match_allowing_invocation(symbol, *arguments)
        matching_expectation_allowing_invocation.invoke([target, *arguments], &block)
      else
        if (matching_expectation = all_expectations.match(symbol, *arguments)) || (!matching_expectation && !@everything_stubbed)

          if @unexpected_invocation.nil?
            @unexpected_invocation = UnexpectedInvocation.new(self, symbol, *arguments)
            matching_expectation.invoke([target, *arguments], &block) if matching_expectation
            message = @unexpected_invocation.full_description
            message << @mockery.mocha_inspect
          else
            message = @unexpected_invocation.short_description
          end
          raise ExpectationErrorFactory.build(message, caller)
        end
      end
    end
  end
end
