require "minitest/mock"
require "minitest/autorun"
require "./accidental/method-hooks"

describe Accidental::MethodHooks do

  before do
    @klass = Class.new do
      include Accidental::MethodHooks

      def some_hookpoint(*args, **kwargs, &block)
        [args, kwargs, block&.call(self, args, kwargs)]
      end
    end

    @subject = @klass.new
  end

  specify "with no hooks defined" do
    resp = @subject.some_hookpoint(1, 2, foo: "bar") { "block response" }

    refute_empty resp, "it should have been the args"
    args, kwargs, block = resp

    assert_equal args, [1, 2]
    assert_equal kwargs, { foo: "bar" }
    assert_equal block, "block response"
  end

  describe "with a class level hook defined" do
    before do
      @callspy = Minitest::Mock.new
      @klass.hook(:before, :some_hookpoint) do |target, *args, **kwargs|
        @callspy.hit(target, args, kwargs)
      end
    end

    it "should have called the spy with the args" do
      @callspy.expect(:hit, nil, [@subject, Array, Hash])

      @subject.some_hookpoint(1, 2, foo: "bar")
      assert @callspy.verify
    end

    it "should only have executed the caller block once (not in the hook)" do
      @blockspy = Minitest::Mock.new
      @blockspy.expect(:hit, nil, [@subject, [1,2], {foo:"bar"}])
      @callspy.expect(:hit, nil, [@subject, Array, Hash])
    
      @subject.some_hookpoint(1, 2, foo: "bar") do |target, args, kwargs| 
        @blockspy.hit(target,args,kwargs)
      end

      assert @blockspy.verify
      assert @callspy.verify
    end
  end

  describe "with an instance level hook defined" do
    before do
      @classspy = Minitest::Mock.new
      @instancespy = Minitest::Mock.new

      @klass.hook(:before, :some_hookpoint) do |target|
        @classspy.hit(target)
      end

      @subject.hook(:before, :some_hookpoint) do |target|
        @instancespy.hit(target)
      end
    end

    it "should call both hooks" do
      @blockspy = Minitest::Mock.new
      @blockspy.expect(:hit, nil)
      @classspy.expect(:hit, nil, [@subject])
      @instancespy.expect(:hit, nil, [@subject])
 
      @subject.some_hookpoint { @blockspy.hit }
      
      assert @blockspy.verify
      assert @classspy.verify
      assert @instancespy.verify
    end
  end
end
