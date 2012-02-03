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
			Clojure.dump(:wat).should == ':wat'
		end

		it 'dumps correctly integers' do
			Clojure.dump(2).should    == '2'
			Clojure.dump(1337).should == '1337'
		end

		it 'dumps correctly floats' do
			Clojure.dump(2.3).should == '2.3'
		end

		it 'dumps correctly rationals' do
			Clojure.dump(Rational('2/3')).should == '2/3'
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
			Clojure.dump(DateTime.rfc3339("2012-02-03T15:20:59+01:00")).should == '1328278859'
			Clojure.dump(DateTime.rfc3339("2012-02-03T15:20:59+01:00"), :alpha => true).should == '#inst "2012-02-03T15:20:59+01:00"'
		end

		it 'dumps correctly arrays' do
			Clojure.dump([]).should           == '[]'
			Clojure.dump([[]]).should         == '[[]]'
			Clojure.dump([[], [], []]).should == '[[] [] []]'

			Clojure.dump([1, 2, 3]).should == '[1 2 3]'
		end

		it 'dumps correctly hases' do
			Clojure.dump({ :a => 'b' }).should == '{:a "b"}'
		end
	end

	describe '#parse' do
		it 'parses correctly true' do
			Clojure.parse('true').should == true
		end

		it 'parses correctly false' do
			Clojure.parse('false').should == false
		end

		it 'parses correctly nil' do
			Clojure.parse('nil').should == nil
		end

		it 'parses correctly strings' do
			Clojure.parse('"lol"').should      == "lol"
			Clojure.parse('"lol\nlol"').should == "lol\nlol"
		end

		it 'parses correctly keywords' do
			Clojure.parse(':wat').should == :wat
		end

		it 'parses correctly integers' do
			Clojure.parse('2').should    == 2
			Clojure.parse('1337').should == 1337
		end

		it 'parses correctly floats' do
			Clojure.parse('2.3').should == 2.3
		end

		it 'parses correctly rationals' do
			Clojure.parse('2/3').should == Rational('2/3')
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
			Clojure.parse('#inst "2012-02-03T15:20:59+01:00"').should == DateTime.rfc3339("2012-02-03T15:20:59+01:00")
		end

		it 'parses correctly vectors' do
			Clojure.parse('[]').should         == []
			Clojure.parse('[[]]').should       == [[]]
			Clojure.parse('[[] [] []]').should == [[], [], []]

			Clojure.parse('[1 2 3]').should == [1, 2, 3]
		end
		
		it 'parses correctly lists' do
			Clojure.parse('()').should         == []
			Clojure.parse('(())').should       == [[]]
			Clojure.parse('(() () ())').should == [[], [], []]

			Clojure.parse('(1 2 3)').should == [1, 2, 3]
		end
		
		it 'parses correctly hashes' do
			Clojure.parse('{:a "b"}').should == { :a => 'b' }
		end
	end
end
