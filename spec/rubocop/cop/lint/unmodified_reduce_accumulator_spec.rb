# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Lint::UnmodifiedReduceAccumulator do
  subject(:cop) { described_class.new }

  shared_examples 'reduce/inject' do |method|
    it "does not affect #{method} called without a block" do
      expect_no_offenses(<<~RUBY)
        values.#{method}(:+)
      RUBY
    end

    context "given a #{method} block" do
      it 'does not register an offense when returning a literal' do
        expect_no_offenses(<<~RUBY)
          values.reduce(true) do |result, value|
            next false if something?
            true
          end
        RUBY
      end

      it 'registers an offense when returning the element' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            el
            ^^ Ensure the accumulator `acc` will be modified by `#{method}`.
          end
        RUBY
      end

      it 'does not register an offense when comparing' do
        aggregate_failures do
          expect_no_offenses(<<~RUBY)
            values.#{method}(false) do |acc, el|
              acc == el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            values.#{method}(false) do |acc, el|
              el == acc
            end
          RUBY
        end
      end

      it 'does not register an offense when returning the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc
          end
        RUBY
      end

      it 'does not register an offense when assigning the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc = el
          end
        RUBY
      end

      it 'does not register an offense when op-assigning the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc += el
          end
        RUBY
      end

      it 'does not register an offense when or-assigning the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc ||= el
          end
        RUBY
      end

      it 'does not register an offense when returning the accumulator in a boolean statement' do
        aggregate_failures do
          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              acc || el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              el || acc
            end
          RUBY
        end
      end

      it 'does not register an offense when and-assigning the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc &&= el
          end
        RUBY
      end

      it 'does not register an offense when shovelling the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc << el
          end
        RUBY
      end

      it 'does not register an offense with the accumulator in interpolation' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            "\#{acc}\#{el}"
          end
        RUBY
      end

      it 'registers an offense with the element in interpolation' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            "\#{el}"
            ^^^^^^^ Ensure the accumulator `acc` will be modified by `#{method}`.
          end
        RUBY
      end

      it 'does not register an offense with the accumulator in heredoc' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            <<~RESULT
              \#{acc}\#{el}
            RESULT
          end
        RUBY
      end

      it 'registers an offense with the element in heredoc' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            <<~RESULT
            ^^^^^^^^^ Ensure the accumulator `acc` will be modified by `#{method}`.
              \#{el}
            RESULT
          end
        RUBY
      end

      it 'does not register an offense when returning the accumulator in an expression' do
        aggregate_failures do
          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              acc + el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              el + acc
            end
          RUBY
        end
      end

      it 'does not register an offense when returning a method called on the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            acc.method
          end
        RUBY
      end

      it 'does not register an offense when returning a method called with the accumulator' do
        expect_no_offenses(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            method(acc)
          end
        RUBY
      end

      it 'registers an offense when returning an index setter on the accumulator' do
        expect_offense(<<~RUBY)
          %w(a b c).#{method}({}) do |acc, letter|
            acc[letter] = true
            ^^^^^^^^^^^^^^^^^^ Do not return an element of the accumulator in `#{method}`.
          end
        RUBY
      end

      it 'registers an offense when returning an expression with the element' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            el + 2
            ^^^^^^ Ensure the accumulator `acc` will be modified by `#{method}`.
          end
        RUBY
      end

      it 'registers an offense for values returned with `next`' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            next el if el.even?
                 ^^ Ensure the accumulator `acc` will be modified by `#{method}`.
            acc += 1
          end
        RUBY
      end

      it 'registers an offense for values returned with `break`' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            break el if el.even?
                  ^^ Ensure the accumulator `acc` will be modified by `#{method}`.
            acc += 1
          end
        RUBY
      end

      it 'registers an offense for every violating return value' do
        expect_offense(<<~RUBY)
          (1..4).#{method}(0) do |acc, el|
            next el if el.even?
                 ^^ Ensure the accumulator `acc` will be modified by `#{method}`.
            el * 2
            ^^^^^^ Ensure the accumulator `acc` will be modified by `#{method}`.
          end
        RUBY
      end

      it 'does not register an offense if the return value cannot be determined' do
        aggregate_failures do
          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              x + el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              x + y
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              x = acc + el
              x
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              x = acc + el
              x ** 2
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              x = acc
              x + el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              @var + el
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              el + @var
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            (1..4).#{method}(0) do |acc, el|
              foo.bar(el)
            end
          RUBY

          expect_no_offenses(<<~RUBY)
            enum.inject do |acc, elem|
              x = [*acc, elem]
              x << 42 if foo
              x
            end
          RUBY
        end
      end

      it 'does not look inside inner blocks' do
        expect_no_offenses(<<~RUBY)
          foo.#{method}(bar) do |acc, el|
            values.map do |v|
              next el if something?
              el
            end
          end
        RUBY
      end

      it 'handles break with no value' do
        expect_no_offenses(<<~RUBY)
          foo.#{method}([]) do |acc, el|
            break if something?
            acc << el
          end
        RUBY
      end

      it 'allows the element to be the return value if the accumulator is returned in any branch' do
        expect_no_offenses(<<~RUBY)
          values.#{method}(nil) do |result, value|
            break result if something?
            value
          end
        RUBY

        expect_no_offenses(<<~RUBY)
          values.#{method}(nil) do |result, value|
            next value if something?
            result
          end
        RUBY
      end
    end
  end

  it_behaves_like 'reduce/inject', :reduce
  it_behaves_like 'reduce/inject', :inject
end
