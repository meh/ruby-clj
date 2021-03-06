#! /usr/bin/env ruby
require 'rubygems'
require 'clj'
require 'bigdecimal'

describe Clojure do
	describe '#dump' do
		it 'dumps correctly true' do
			Clojure.dump(true).should == 'true'
		end

		it 'dumps correctly false' do
			Clojure.dump(false).should == 'false'
		end

		it 'dumps correctly nil' do
			Clojure.dump(nil).should == 'nil'
		end

		it 'dumps correctly strings' do
			Clojure.dump("lol").should      == '"lol"'
			Clojure.dump("lol\nlol").should == '"lol\nlol"'
			Clojure.dump("\\e\e").should    == '"\\\\e\u001b"'
			Clojure.dump("\\a\a").should    == '"\\\\a\u0003"'
		end

		it 'dumps correctly symbols' do
			Clojure.dump(:wat.symbol!).should == 'wat'
		end

		it 'dumps correctly keywords' do
			Clojure.dump(:wat).should == ':wat'

			expect {
				Clojure.dump(:"lol wat")
			}.should raise_error
		end

		it 'dumps correctly integers' do
			Clojure.dump(2).should    == '2'
			Clojure.dump(1337).should == '1337'
		end

		it 'dumps correctly floats' do
			Clojure.dump(2.3).should == '2.3'
		end

		it 'dumps correctly rationals' do
			unless RUBY_VERSION.include? '1.8'
				Clojure.dump(Rational('2/3')).should == '2/3'
			end
		end

		it 'dumps correctly bignums' do
			Clojure.dump(324555555555555555555555555555555555555555555555324445555555555555).should == '324555555555555555555555555555555555555555555555324445555555555555N'
		end

		it 'dumps correctly bigdecimals' do
			Clojure.dump(BigDecimal('0.2345636456')).should == '0.2345636456M'
		end

		it 'dumps correctly regexps' do
			Clojure.dump(/(\d+)/).should == '#"(\d+)"'
		end

		it 'dumps correctly dates' do
			unless RUBY_VERSION.include? '1.8'
				Clojure.dump(DateTime.rfc3339("2012-02-03T15:20:59+01:00")).should == '1328278859'
				Clojure.dump(DateTime.rfc3339("2012-02-03T15:20:59+01:00"), :alpha => true).should == '#inst "2012-02-03T15:20:59+01:00"'
			end
		end

		it 'dumps correctly arrays' do
			Clojure.dump([]).should           == '[]'
			Clojure.dump([[]]).should         == '[[]]'
			Clojure.dump([[], [], []]).should == '[[] [] []]'

			Clojure.dump([1, 2, 3]).should         == '[1 2 3]'
			Clojure.dump([1, 2, 3].to_list).should == '(1 2 3)'
		end

		it 'dumps correctly hashes' do
			Clojure.dump({ :a => 'b' }).should == '{:a "b"}'
		end

		it 'dumps correctly metadata' do
			Clojure.dump([1, 2, 3].to_vector.tap { |x| x.metadata = :lol }).should == '^:lol [1 2 3]'
		end

		it 'dumps correctly sets' do
			Clojure.dump(Set.new([1, 2, 3])).should == '#{1 2 3}'
		end
	end

	describe '#parse' do
		it 'parses correctly true' do
			Clojure.parse('true').should == true
			
			Clojure.parse('truf').should == :truf.symbol!
		end

		it 'parses correctly false' do
			Clojure.parse('false').should == false

		  Clojure.parse('falfe').should == :falfe.symbol!
		end

		it 'parses correctly nil' do
			Clojure.parse('nil').should == nil

			Clojure.parse('nol').should == :nol.symbol!
		end

		it 'parses correctly chars' do
			Clojure.parse('\d').should == 'd'
			Clojure.parse('\a').should == 'a'
			Clojure.parse('\0').should == '0'

			Clojure.parse('\newline').should   == "\n"
			Clojure.parse('\space').should     == ' '
			Clojure.parse('\tab').should       == "\t"
			Clojure.parse('\backspace').should == "\b"
			Clojure.parse('\formfeed').should  == "\f"
			Clojure.parse('\return').should    == "\r"

			Clojure.parse('\o54').should == ','
			Clojure.parse('[\o3 "lol"]').should == ["\x03", "lol"]

			unless RUBY_VERSION.include? '1.8'
				Clojure.parse('\u4343').should == "\u4343"
			end
		end

		it 'parses correctly strings' do
			Clojure.parse('"lol"').should      == "lol"
			Clojure.parse('"lol\nlol"').should == "lol\nlol"

			unless RUBY_VERSION.include? '1.8'
				Clojure.parse('"\u4343"').should   == "\u4343"
			end
		end

		it 'parses correctly symbols' do
			Clojure.parse('ni').should == :ni.symbol!
		end

		it 'parses correctly keywords' do
			Clojure.parse(':wat').should == :wat
		end

		it 'parses correctly numbers' do
			Clojure.parse('2').should    == 2
			Clojure.parse('1337').should == 1337

			Clojure.parse('16rFF').should == 255
			Clojure.parse('2r11').should  == 3

			Clojure.parse('2.3').should == 2.3
			Clojure.parse('2e3').should == 2000
		end

		it 'parses correctly rationals' do
			unless RUBY_VERSION.include? '1.8'
				Clojure.parse('2/3').should == Rational('2/3')
			end
		end

		it 'parses correctly bignums' do
			Clojure.parse('324555555555555555555555555555555555555555555555324445555555555555N').should == 324555555555555555555555555555555555555555555555324445555555555555
		end

		it 'parses correctly bigdecimals' do
			Clojure.parse('0.2345636456M').should == BigDecimal('0.2345636456')
		end

		it 'parses correctly regexps' do
			Clojure.parse('#"(\d+)"').should == /(\d+)/
		end

		it 'parses correctly dates' do
			unless RUBY_VERSION.include? '1.8'
				Clojure.parse('#inst "2012-02-03T15:20:59+01:00"').should == DateTime.rfc3339("2012-02-03T15:20:59+01:00")
			end
		end

		it 'parses correctly vectors' do
			Clojure.parse('[]').should         == []
			Clojure.parse('[[]]').should       == [[]]
			Clojure.parse('[[] [] []]').should == [[], [], []]

			Clojure.parse('[1 2 3]').should == [1, 2, 3]
			Clojure.parse('[23[]]').should  == [23, []]
		end
		
		it 'parses correctly lists' do
			Clojure.parse('()').should         == []
			Clojure.parse('(())').should       == [[]]
			Clojure.parse('(() () ())').should == [[], [], []]

			Clojure.parse('(1 2 3)').should == [1, 2, 3]
			Clojure.parse('(23())').should == [23, []]
		end

		it 'parses correctly sets' do
			Clojure.parse('#{1 2 3}').should == [1, 2, 3].to_set

			expect { Clojure.parse('#{1 1}') }.should raise_error
		end
		
		it 'parses correctly maps' do
			Clojure.parse('{:a "b"}').should == { :a => 'b' }
		end

		it 'parses correctly metadata' do
			Clojure.parse('^:lol [1 2 3]').tap { |data|
				data.should == [1, 2, 3]
				data.metadata.should == { :lol => true }
			}
		end
	end
end
